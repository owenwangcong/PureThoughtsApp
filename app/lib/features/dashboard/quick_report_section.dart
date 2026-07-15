import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/settings.dart';
import '../../core/units.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../groups/groups_providers.dart';
import '../logs/logs_providers.dart';
import '../logs/offline_queue.dart';
import 'dashboard_providers.dart';

String _fmtNum(Object? n) {
  final d = double.tryParse('$n') ?? 0;
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

/// 打开快捷报数弹层(首页「快捷報數」宫格入口)
Future<void> showQuickReportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const QuickReportSheet(),
  );
}

/// 快捷报数弹层(PRD v0.5.5 §4.2):最近报过的(群 × 功课)组合**多选**(可跨群),
/// 选中项在下方核对数量(默认上次值,± 步进),一次提交。
class QuickReportSheet extends ConsumerStatefulWidget {
  const QuickReportSheet({super.key});

  @override
  ConsumerState<QuickReportSheet> createState() => _QuickReportSheetState();
}

class _QuickReportSheetState extends ConsumerState<QuickReportSheet> {
  final _selectedOrder = <String>[]; // 'groupId|typeId',保持点选顺序
  final _qty = <String, TextEditingController>{};
  var _busy = false;

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggle(String key, Map<String, dynamic> item) {
    setState(() {
      final existing = _qty.remove(key);
      if (existing != null) {
        existing.dispose();
        _selectedOrder.remove(key);
      } else {
        _qty[key] = TextEditingController(text: _fmtNum(item['quantity']));
        _selectedOrder.add(key);
      }
    });
  }

  void _bump(String key, double delta) {
    final c = _qty[key];
    if (c == null) return;
    final v = ((double.tryParse(c.text.trim()) ?? 0) + delta).clamp(1, double.maxFinite);
    c.text = _fmtNum(v);
  }

  Future<void> _submit(Map<String, Map<String, dynamic>> itemByKey) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final quantities = <String, double>{};
    for (final key in _selectedOrder) {
      final q = double.tryParse(_qty[key]!.text.trim());
      if (q == null || q <= 0) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.quantityInvalid)));
        return;
      }
      quantities[key] = q;
    }
    setState(() => _busy = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final localDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final result = await submitPracticeLogs(ref, [
        for (final key in _selectedOrder)
          {
            'group_id': itemByKey[key]!['group_id'],
            'reporter_id': uid,
            'practice_type_id': itemByKey[key]!['practice_type_id'],
            'quantity': quantities[key],
            'local_date': localDate,
          }
      ]);
      if (result == SubmitResult.queued) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.offlineQueued)));
        if (mounted) Navigator.pop(context);
        return;
      }
      ref.invalidate(myRecentSelfLogsProvider);
      ref.invalidate(myDailyStatsProvider);
      ref.invalidate(myTotalsProvider);
      for (final key in _selectedOrder) {
        ref.invalidate(
            groupLogsProvider(itemByKey[key]!['group_id'] as String));
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.logSubmitted)));
      if (mounted) Navigator.pop(context);
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
    final recent = ref.watch(myRecentSelfLogsProvider).value ?? const [];
    final types = ref.watch(allPracticeTypesMapProvider).value ?? const {};
    final groupNames = <String, String>{
      for (final m in ref.watch(myGroupsProvider).value ?? const [])
        (m['groups'] as Map)['id'] as String: (m['groups'] as Map)['name'] as String,
    };

    // 去重:每个(群 × 功课)取最近一条,最多 8 个
    final seen = <String>{};
    final itemByKey = <String, Map<String, dynamic>>{};
    for (final r in recent) {
      final key = '${r['group_id']}|${r['practice_type_id']}';
      if (seen.add(key)) itemByKey[key] = r;
      if (itemByKey.length >= 8) break;
    }

    String nameOf(String typeId) {
      final t = types[typeId];
      if (t == null) return '…';
      return (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant']) as String;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: itemByKey.isEmpty
            ? SizedBox(
                height: 220,
                child: EmptyState(
                  icon: Icons.bolt_outlined,
                  title: l10n.quickReport,
                  hint: l10n.quickEmptyHint,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.quickReport,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in itemByKey.entries)
                          FilterChip(
                            selected: _qty.containsKey(e.key),
                            label: Text(
                              '${nameOf(e.value['practice_type_id'] as String)} '
                              '${_fmtNum(e.value['quantity'])} '
                              '${unitLabel(l10n, types[e.value['practice_type_id']]?['unit'] as String? ?? '')}',
                            ),
                            onSelected: (_) => _toggle(e.key, e.value),
                          ),
                      ],
                    ),
                    if (_selectedOrder.isNotEmpty) ...[
                      const Divider(height: 32),
                      for (final key in _selectedOrder)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nameOf(itemByKey[key]!['practice_type_id']
                                          as String),
                                      style:
                                          Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      groupNames[itemByKey[key]!['group_id']] ?? '',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => setState(() => _bump(key, -1)),
                              ),
                              SizedBox(
                                width: 104,
                                child: TextField(
                                  controller: _qty[key],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: unitLabel(
                                        l10n,
                                        types[itemByKey[key]![
                                                'practice_type_id']]?['unit']
                                                as String? ??
                                            ''),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => setState(() => _bump(key, 1)),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _selectedOrder.isEmpty || _busy
                          ? null
                          : () => _submit(itemByKey),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_selectedOrder.isEmpty
                              ? l10n.submitLog
                              : '${l10n.submitLog}(${_selectedOrder.length})'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
