import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../groups/groups_providers.dart';
import '../logs/logs_providers.dart';
import 'dashboard_providers.dart';

String _fmtNum(Object? n) {
  final d = double.tryParse('$n') ?? 0;
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

/// 快捷报数(PRD v0.5.5 §4.2):最近报过的(群 × 功课)组合,**可多选**(可跨群),
/// 底部弹层核对各项数量(默认上次值,± 步进)后一次提交。
class QuickReportSection extends ConsumerStatefulWidget {
  const QuickReportSection({super.key});

  @override
  ConsumerState<QuickReportSection> createState() => _QuickReportSectionState();
}

class _QuickReportSectionState extends ConsumerState<QuickReportSection> {
  final _selected = <String>{}; // 'groupId|typeId'

  Future<void> _submitSelected(
    List<Map<String, dynamic>> items,
    Map<String, Map<String, dynamic>> types,
    Map<String, String> groupNames,
  ) async {
    final l10n = AppLocalizations.of(context);
    final locale = ref.read(localeProvider);
    final messenger = ScaffoldMessenger.of(context);
    final chosen =
        items.where((r) => _selected.contains('${r['group_id']}|${r['practice_type_id']}')).toList();
    if (chosen.isEmpty) return;

    final qty = {
      for (final r in chosen)
        '${r['group_id']}|${r['practice_type_id']}':
            TextEditingController(text: _fmtNum(r['quantity'])),
    };

    void bump(String key, double delta) {
      final c = qty[key]!;
      final v = ((double.tryParse(c.text.trim()) ?? 0) + delta)
          .clamp(1, double.maxFinite);
      c.text = _fmtNum(v);
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.reportLog,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                for (final r in chosen)
                  Builder(builder: (context) {
                    final key = '${r['group_id']}|${r['practice_type_id']}';
                    final t = types[r['practice_type_id']];
                    if (t == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (locale.scriptCode == 'Hans'
                                      ? t['name_hans']
                                      : t['name_hant']) as String,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  groupNames[r['group_id']] ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setSheet(() => bump(key, -1)),
                          ),
                          SizedBox(
                            width: 104,
                            child: TextField(
                              controller: qty[key],
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                isDense: true,
                                suffixText: unitLabel(l10n, t['unit'] as String),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setSheet(() => bump(key, 1)),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('${l10n.submitLog}(${chosen.length})'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final localDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await Supabase.instance.client.from('practice_logs').insert([
        for (final r in chosen)
          {
            'group_id': r['group_id'],
            'reporter_id': uid,
            'practice_type_id': r['practice_type_id'],
            'quantity': double.tryParse(
                    qty['${r['group_id']}|${r['practice_type_id']}']!.text.trim()) ??
                double.parse('${r['quantity']}'),
            'local_date': localDate,
          }
      ]);
      setState(_selected.clear);
      ref.invalidate(myRecentSelfLogsProvider);
      ref.invalidate(myDailyStatsProvider);
      ref.invalidate(myTotalsProvider);
      for (final r in chosen) {
        ref.invalidate(groupLogsProvider(r['group_id'] as String));
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.logSubmitted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final recent = ref.watch(myRecentSelfLogsProvider);
    final myGroups = ref.watch(myGroupsProvider);
    final types = ref.watch(allPracticeTypesMapProvider).value ?? const {};

    return recent.maybeWhen(
      data: (rows) {
        // 去重:每个(群 × 功课)取最近一条,最多 8 个
        final seen = <String>{};
        final items = <Map<String, dynamic>>[];
        for (final r in rows) {
          final key = '${r['group_id']}|${r['practice_type_id']}';
          if (seen.add(key)) items.add(r);
          if (items.length >= 8) break;
        }
        if (items.isEmpty) return const SizedBox.shrink();

        final groupNames = <String, String>{
          for (final m in myGroups.value ?? const [])
            (m['groups'] as Map)['id'] as String: (m['groups'] as Map)['name'] as String,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(l10n.quickReport),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in items)
                    Builder(builder: (context) {
                      final key = '${r['group_id']}|${r['practice_type_id']}';
                      final t = types[r['practice_type_id']];
                      if (t == null) return const SizedBox.shrink();
                      final name = (locale.scriptCode == 'Hans'
                          ? t['name_hans']
                          : t['name_hant']) as String;
                      return FilterChip(
                        selected: _selected.contains(key),
                        label: Text(
                            '$name ${_fmtNum(r['quantity'])} ${unitLabel(l10n, t['unit'] as String)}'),
                        onSelected: (v) => setState(
                            () => v ? _selected.add(key) : _selected.remove(key)),
                      );
                    }),
                ],
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: FilledButton.tonal(
                  onPressed: () => _submitSelected(items, types.cast(), groupNames),
                  child: Text('${l10n.submitLog}(${_selected.length})'),
                ),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
