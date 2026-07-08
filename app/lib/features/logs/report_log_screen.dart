import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../l10n/gen/app_localizations.dart';
import '../dashboard/dashboard_providers.dart';
import '../groups/groups_providers.dart';
import 'logs_providers.dart';

enum _SubjectMode { self, member, name }

/// 报数表单(PRD §4.2):
/// - 功课项 = 全局 + 群自定义(active)
/// - 被报对象三来源:自己 / 群成员(计入其统计)/ 自由名字(仅计群总量,自动记忆)
/// - 补报:统一计入报数当天(local_date = 设备本地日期),实际日期写备注
class ReportLogScreen extends ConsumerStatefulWidget {
  const ReportLogScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<ReportLogScreen> createState() => _ReportLogScreenState();
}

class _ReportLogScreenState extends ConsumerState<ReportLogScreen> {
  String? _typeId;
  var _mode = _SubjectMode.self;
  String? _memberId;
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  /// 选中功课项;数量为空时自动填上次报过的数量(快捷报数的记忆默认值,P1.7)
  void _selectType(String typeId) {
    setState(() => _typeId = typeId);
    if (_quantity.text.trim().isNotEmpty) return;
    final recent = ref.read(myRecentSelfLogsProvider).value;
    final last = recent
        ?.where((r) =>
            r['group_id'] == widget.groupId && r['practice_type_id'] == typeId)
        .firstOrNull;
    if (last != null) {
      final d = double.tryParse('${last['quantity']}') ?? 0;
      _quantity.text = d == d.roundToDouble() ? '${d.round()}' : '$d';
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final qty = double.tryParse(_quantity.text.trim());
    if (_typeId == null || qty == null || qty <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.quantityInvalid)));
      return;
    }
    if (_mode == _SubjectMode.member && _memberId == null) return;
    if (_mode == _SubjectMode.name && _name.text.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('practice_logs').insert({
        'group_id': widget.groupId,
        'reporter_id': uid,
        'practice_type_id': _typeId,
        'quantity': qty,
        // 统计口径:设备本地自然日(PRD §4.3;补报也计入当天)
        'local_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        if (_mode == _SubjectMode.member) 'subject_user_id': _memberId,
        if (_mode == _SubjectMode.name) 'subject_name': _name.text.trim(),
      });
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

    final selectedType = types.value
        ?.where((t) => t['id'] == _typeId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportLog)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 功课项 ----
          Text(l10n.selectPracticeType, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          // 按分类分组(經/咒/懺/念佛/靜坐/其他),功课项具体到经名(PRD v0.5.2)
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
                          ChoiceChip(
                            label: Text(
                              (locale.scriptCode == 'Hans'
                                  ? t['name_hans']
                                  : t['name_hant']) as String,
                            ),
                            selected: _typeId == t['id'],
                            onSelected: (_) => _selectType(t['id'] as String),
                          ),
                      ],
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ---- 被报对象 ----
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
          const SizedBox(height: 24),

          // ---- 数量 ----
          TextField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: InputDecoration(
              labelText: l10n.quantityTitle,
              suffixText:
                  selectedType != null ? unitLabel(l10n, selectedType['unit'] as String) : null,
            ),
          ),
          const SizedBox(height: 16),

          // ---- 备注 ----
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
                : Text(l10n.submitLog),
          ),
        ],
      ),
    );
  }
}
