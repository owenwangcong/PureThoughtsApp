import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/settings.dart';
import '../../core/units.dart';
import '../../l10n/gen/app_localizations.dart';
import '../community/add_practice_type_dialog.dart';
import '../community/community_providers.dart';
import '../dashboard/dashboard_providers.dart';
import 'batch_utils.dart';
import 'logs_providers.dart';
import 'offline_queue.dart';

enum _SubjectMode { self, member, name }

String _fmtNum(Object? n) {
  final d = double.tryParse('$n') ?? 0;
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

/// 报数表单(PRD v0.5.3 §4.2 交互定案):
/// - 批量多选,每项独立数量(默认上次值,± 步进)
/// - 「重複上次」一键带入上次自报组合;「常用」组置顶
/// - 对象默认自己,「替他人報數」展开三来源;备注与对象对整批生效
/// - 提交栏固定底部;成功后随喜反馈 + 本次摘要
class ReportLogScreen extends ConsumerStatefulWidget {
  const ReportLogScreen({super.key});

  @override
  ConsumerState<ReportLogScreen> createState() => _ReportLogScreenState();
}

class _ReportLogScreenState extends ConsumerState<ReportLogScreen> {
  /// 已选功课 → 数量输入(保持点选顺序)
  final Map<String, TextEditingController> _qtyByType = {};
  final List<String> _selectedOrder = [];
  var _showSubject = false; // 「替他人報數」展开
  var _mode = _SubjectMode.self;

  // 代报来源①「同修」:改为搜索(v0.6.0 去群化,成员规模变成全站,不再全量下拉)
  final _memberQuery = TextEditingController();
  Timer? _memberDebounce;
  List<Map<String, dynamic>> _memberResults = const [];
  var _memberSearching = false;
  String? _memberId;
  String? _memberName;

  final _name = TextEditingController();
  final _note = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    for (final c in _qtyByType.values) {
      c.dispose();
    }
    _memberDebounce?.cancel();
    _memberQuery.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  /// 同修搜索(防抖 300ms;空关键词不发请求 —— 与 search_members 的服务端约束一致)
  void _onMemberQueryChanged(String q) {
    _memberDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _memberResults = const [];
        _memberSearching = false;
      });
      return;
    }
    setState(() => _memberSearching = true);
    _memberDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final res = await Supabase.instance.client
            .rpc('search_members', params: {'p_q': q.trim(), 'p_limit': 20});
        if (!mounted) return;
        setState(() {
          _memberResults =
              (res as List).cast<Map<String, dynamic>>().toList(growable: false);
          _memberSearching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _memberResults = const [];
          _memberSearching = false;
        });
      }
    });
  }

  /// 点选/取消功课项;新选中时数量默认上次报过的值
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
      final last =
          recent?.where((r) => r['practice_type_id'] == typeId).firstOrNull;
      if (last != null) c.text = _fmtNum(last['quantity']);
      _qtyByType[typeId] = c;
      _selectedOrder.add(typeId);
    });
  }

  /// 「重複上次」:带入上次(最近一天)自报组合与数量
  void _repeatLast(Map<String, double> batch) {
    setState(() {
      for (final e in batch.entries) {
        final existing = _qtyByType[e.key];
        if (existing != null) {
          existing.text = _fmtNum(e.value);
        } else {
          _qtyByType[e.key] = TextEditingController(text: _fmtNum(e.value));
          _selectedOrder.add(e.key);
        }
      }
    });
  }

  /// 数量 ± 步进(点按代替打字,适老)
  void _bump(String typeId, double delta) {
    final c = _qtyByType[typeId];
    if (c == null) return;
    final current = double.tryParse(c.text.trim()) ?? 0;
    final next = (current + delta).clamp(1, double.maxFinite);
    c.text = _fmtNum(next);
  }

  Future<void> _submit(Map<String, Map<String, dynamic>> typeById) async {
    final l10n = AppLocalizations.of(context);
    final locale = ref.read(localeProvider);
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
    final mode = _showSubject ? _mode : _SubjectMode.self;
    if (mode == _SubjectMode.member && _memberId == null) return;
    if (mode == _SubjectMode.name && _name.text.trim().isEmpty) return;

    // 共修体 id 是落库必需字段;未就绪(冷启动/离线首开)时不静默丢失,给可读提示
    final gid = ref.read(communityIdProvider);
    if (gid == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.loadFailed)));
      return;
    }

    setState(() => _busy = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final localDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final note = _note.text.trim();
      final result = await submitPracticeLogs(ref, [
        for (final id in _selectedOrder)
          {
            'group_id': gid,
            'reporter_id': uid,
            'practice_type_id': id,
            'quantity': quantities[id],
            'local_date': localDate,
            if (note.isNotEmpty) 'note': note,
            if (mode == _SubjectMode.member) 'subject_user_id': _memberId,
            if (mode == _SubjectMode.name) 'subject_name': _name.text.trim(),
          }
      ]);
      if (result == SubmitResult.queued) {
        // 离线:已暂存,联网自动补传(P5.1)
        messenger.showSnackBar(SnackBar(content: Text(l10n.offlineQueued)));
        if (mounted) context.pop();
        return;
      }
      ref.invalidate(communityLogsProvider);
      ref.invalidate(proxyNamesProvider);
      ref.invalidate(myRecentSelfLogsProvider);
      ref.invalidate(myDailyStatsProvider);
      ref.invalidate(myTotalsProvider);

      // 随喜反馈 + 本次摘要(PRD v0.5.3)
      final summary = [
        for (final id in _selectedOrder)
          if (typeById[id] != null)
            '${(locale.scriptCode == 'Hans' ? typeById[id]!['name_hans'] : typeById[id]!['name_hant'])} '
                '${_fmtNum(quantities[id])} ${unitLabel(l10n, typeById[id]!['unit'] as String)}',
      ].join('\n');
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.spa_outlined, size: 36),
            title: Text(l10n.logSubmitted),
            content: Text(summary, style: Theme.of(context).textTheme.bodyLarge),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.done),
              ),
            ],
          ),
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final types = ref.watch(reportablePracticeTypesProvider);
    final proxyNames = ref.watch(proxyNamesProvider);
    final recent = ref.watch(myRecentSelfLogsProvider).value ?? const [];

    final typeById = <String, Map<String, dynamic>>{
      for (final t in types.value ?? const []) t['id'] as String: t,
    };
    String nameOfType(Map<String, dynamic> t) =>
        (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant']) as String;

    final lastBatch = latestBatch(recent.cast<Map<String, dynamic>>());
    final frequent = frequentTypeIds(recent.cast<Map<String, dynamic>>())
        .where(typeById.containsKey)
        .toList();

    Widget chip(Map<String, dynamic> t) => FilterChip(
          label: Text(nameOfType(t)),
          selected: _qtyByType.containsKey(t['id']),
          onSelected: (_) => _toggleType(t['id'] as String),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportLog),
        actions: [
          if (lastBatch.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.replay),
              label: Text(l10n.repeatLast),
              onPressed: () => _repeatLast(lastBatch),
            ),
        ],
      ),
      // 底部固定提交栏(不用滚到底,PRD v0.5.3)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _busy ? null : () => _submit(typeById),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: _busy
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_selectedOrder.isEmpty
                    ? l10n.submitLog
                    : '${l10n.submitLog}(${_selectedOrder.length})'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 功课项(常用置顶 + 分类分组;多选) ----
          Text(l10n.selectPracticeType, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          types.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(l10n.loadFailed),
            data: (list) {
              final frequentSet = frequent.toSet();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (frequent.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        l10n.frequentGroup,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final id in frequent) chip(typeById[id]!)],
                    ),
                  ],
                  for (final cat in practiceCategories)
                    if (list.any(
                        (t) => t['category'] == cat && !frequentSet.contains(t['id']))) ...[
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
                          for (final t in list.where((t) =>
                              t['category'] == cat && !frequentSet.contains(t['id'])))
                            chip(t),
                        ],
                      ),
                    ],
                  // 就地自定义任意功课(名称/分类/单位自定;PRD §4.1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addPracticeType),
                      onPressed: () async {
                        final newId =
                            await showAddPracticeTypeDialog(context, ref);
                        if (newId == null) return;
                        ref.invalidate(reportablePracticeTypesProvider);
                        ref.invalidate(myCustomPracticeTypesProvider);
                        ref.invalidate(allPracticeTypesMapProvider);
                        _toggleType(newId); // 建完即选中,直接填数量
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          // ---- 已选清单:每项独立数量(± 步进) ----
          if (_selectedOrder.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    for (final id in _selectedOrder)
                      if (typeById[id] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  nameOfType(typeById[id]!),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _bump(id, -1),
                              ),
                              SizedBox(
                                width: 108,
                                child: TextField(
                                  controller: _qtyByType[id],
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: unitLabel(
                                        l10n, typeById[id]!['unit'] as String),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _bump(id, 1),
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
          const SizedBox(height: 16),

          // ---- 替他人報數(默认折叠,PRD v0.5.3) ----
          if (!_showSubject)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.group_add_outlined),
                label: Text(l10n.forOthers),
                onPressed: () => setState(() => _showSubject = true),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(l10n.subjectTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.expand_less),
                  onPressed: () => setState(() {
                    _showSubject = false;
                    _mode = _SubjectMode.self;
                  }),
                ),
              ],
            ),
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
            // 来源①「同修」:搜索(v0.6.0;原为群成员全量下拉,全站规模下不可用)
            if (_mode == _SubjectMode.member)
              if (_memberId != null)
                // 已选中:收起结果列表,只留「已選:某某」+ 清除
                InputChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(_memberName ?? ''),
                  onDeleted: () => setState(() {
                    _memberId = null;
                    _memberName = null;
                    _memberQuery.clear();
                    _memberResults = const [];
                  }),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _memberQuery,
                      onChanged: _onMemberQueryChanged,
                      decoration: InputDecoration(
                        labelText: l10n.searchMemberHint,
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    if (_memberSearching)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      )
                    else if (_memberQuery.text.trim().isNotEmpty &&
                        _memberResults.isEmpty)
                      // 无结果不留死路:直接引导到来源③「任意名字」
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          l10n.searchMemberEmpty,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      )
                    else
                      for (final m in _memberResults)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_outline),
                          title: Text(m['display_name'] as String? ?? ''),
                          onTap: () => setState(() {
                            _memberId = m['user_id'] as String;
                            _memberName = m['display_name'] as String? ?? '';
                            _memberResults = const [];
                          }),
                        ),
                  ],
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
          ],
          const SizedBox(height: 8),

          // ---- 备注(对整批生效) ----
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.noteLabel),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
