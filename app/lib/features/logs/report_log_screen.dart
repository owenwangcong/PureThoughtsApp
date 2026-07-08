import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../l10n/gen/app_localizations.dart';
import '../dashboard/dashboard_providers.dart';
import '../groups/add_practice_type_dialog.dart';
import '../groups/groups_providers.dart';
import 'logs_providers.dart';

enum _SubjectMode { self, member, name }

String _fmtNum(Object? n) {
  final d = double.tryParse('$n') ?? 0;
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

/// 报数表单(PRD §4.2):
/// - **批量报数**:功课项多选,每项独立数量(默认上次报的值),一次提交多条
/// - 被报对象三来源:自己 / 群成员(计入其统计)/ 自由名字(仅计群总量,自动记忆);
///   对象与备注对整批生效
/// - 补报:统一计入报数当天(local_date = 设备本地日期),实际日期写备注
class ReportLogScreen extends ConsumerStatefulWidget {
  const ReportLogScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<ReportLogScreen> createState() => _ReportLogScreenState();
}

class _ReportLogScreenState extends ConsumerState<ReportLogScreen> {
  /// 已选功课 → 数量输入(保持点选顺序)
  final Map<String, TextEditingController> _qtyByType = {};
  final List<String> _selectedOrder = [];
  var _mode = _SubjectMode.self;
  String? _memberId;
  final _name = TextEditingController();
  final _note = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    for (final c in _qtyByType.values) {
      c.dispose();
    }
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  /// 点选/取消功课项;新选中时数量默认上次报过的值(记忆默认值,P1.7)
  void _toggleType(String typeId) {
    setState(() {
      final existing = _qtyByType.remove(typeId);
      if (existing != null) {
        existing.dispose();
        _selectedOrder.remove(typeId);
        return;
      }
      final c = TextEditingController();
      final recent = ref.read(myRecentSelfLogsProvider).value;
      final last = recent
          ?.where((r) =>
              r['group_id'] == widget.groupId && r['practice_type_id'] == typeId)
          .firstOrNull;
      if (last != null) c.text = _fmtNum(last['quantity']);
      _qtyByType[typeId] = c;
      _selectedOrder.add(typeId);
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_selectedOrder.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.selectPracticeType)));
      return;
    }
    final quantities = <String, double>{};
    for (final id in _selectedOrder) {
      final q = double.tryParse(_qtyByType[id]!.text.trim());
      if (q == null || q <= 0) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.quantityInvalid)));
        return;
      }
      quantities[id] = q;
    }
    if (_mode == _SubjectMode.member && _memberId == null) return;
    if (_mode == _SubjectMode.name && _name.text.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final localDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final note = _note.text.trim();
      // 批量插入:一次请求写入多条,触发器逐行生效(unit 快照/名单记忆/代报通知)
      await Supabase.instance.client.from('practice_logs').insert([
        for (final id in _selectedOrder)
          {
            'group_id': widget.groupId,
            'reporter_id': uid,
            'practice_type_id': id,
            'quantity': quantities[id],
            'local_date': localDate,
            if (note.isNotEmpty) 'note': note,
            if (_mode == _SubjectMode.member) 'subject_user_id': _memberId,
            if (_mode == _SubjectMode.name) 'subject_name': _name.text.trim(),
          }
      ]);
      ref.invalidate(groupLogsProvider(widget.groupId));
      ref.invalidate(proxyNamesProvider(widget.groupId));
      ref.invalidate(myRecentSelfLogsProvider);
      ref.invalidate(myDailyStatsProvider);
      ref.invalidate(myTotalsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.logSubmitted)));
      if (mounted) context.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final types = ref.watch(reportablePracticeTypesProvider(widget.groupId));
    final members = ref.watch(groupMembersProvider(widget.groupId));
    final proxyNames = ref.watch(proxyNamesProvider(widget.groupId));
    ref.watch(myRecentSelfLogsProvider); // 预载,供记忆默认值使用
    final myId = Supabase.instance.client.auth.currentUser?.id;

    final typeById = <String, Map<String, dynamic>>{
      for (final t in types.value ?? const []) t['id'] as String: t,
    };
    String nameOfType(Map<String, dynamic> t) =>
        (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant']) as String;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportLog)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 功课项(多选,按分类分组;PRD v0.5.2 具体到经名) ----
          Text(l10n.selectPracticeType, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          types.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(l10n.loadFailed),
            data: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final cat in practiceCategories)
                  if (list.any((t) => t['category'] == cat)) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        categoryLabel(l10n, cat),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in list.where((t) => t['category'] == cat))
                          FilterChip(
                            label: Text(nameOfType(t)),
                            selected: _qtyByType.containsKey(t['id']),
                            onSelected: (_) => _toggleType(t['id'] as String),
                          ),
                      ],
                    ),
                  ],
                // 就地自定义任意功课(名称/分类/单位自定;PRD §4.1 成员均可加)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addPracticeType),
                    onPressed: () async {
                      final newId = await showAddPracticeTypeDialog(context,
                          groupId: widget.groupId);
                      if (newId == null) return;
                      ref.invalidate(reportablePracticeTypesProvider(widget.groupId));
                      ref.invalidate(groupPracticeTypesProvider(widget.groupId));
                      ref.invalidate(allPracticeTypesMapProvider);
                      _toggleType(newId); // 建完即选中,直接填数量
                    },
                  ),
                ),
              ],
            ),
          ),

          // ---- 已选清单:每项独立数量 ----
          if (_selectedOrder.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    for (final id in _selectedOrder)
                      if (typeById[id] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  nameOfType(typeById[id]!),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: _qtyByType[id],
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context).textTheme.titleLarge,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: unitLabel(
                                        l10n, typeById[id]!['unit'] as String),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _toggleType(id),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ---- 被报对象(对整批生效) ----
          Text(l10n.subjectTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<_SubjectMode>(
            segments: [
              ButtonSegment(value: _SubjectMode.self, label: Text(l10n.subjectSelf)),
              ButtonSegment(value: _SubjectMode.member, label: Text(l10n.subjectMember)),
              ButtonSegment(value: _SubjectMode.name, label: Text(l10n.subjectName)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          if (_mode == _SubjectMode.member)
            members.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.loadFailed),
              data: (list) {
                final others = list.where((m) => m['user_id'] != myId).toList();
                return DropdownButtonFormField<String>(
                  value: _memberId,
                  hint: Text(l10n.subjectMember),
                  items: [
                    for (final m in others)
                      DropdownMenuItem(
                        value: m['user_id'] as String,
                        child: Text(m['display_name'] as String? ?? ''),
                      ),
                  ],
                  onChanged: (v) => setState(() => _memberId = v),
                );
              },
            ),
          if (_mode == _SubjectMode.name) ...[
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.subjectName),
            ),
            const SizedBox(height: 8),
            // 本群代报名单:点选复用,避免同一人多种写法(PRD §4.2)
            proxyNames.maybeWhen(
              data: (names) => names.isEmpty
                  ? const SizedBox.shrink()
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final n in names)
                          ActionChip(
                            label: Text(n),
                            onPressed: () => setState(() => _name.text = n),
                          ),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
          const SizedBox(height: 16),

          // ---- 备注(对整批生效) ----
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.noteLabel),
          ),
          const SizedBox(height: 32),

          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: _busy
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_selectedOrder.length > 1
                    ? '${l10n.submitLog}(${_selectedOrder.length})'
                    : l10n.submitLog),
          ),
        ],
      ),
    );
  }
}
