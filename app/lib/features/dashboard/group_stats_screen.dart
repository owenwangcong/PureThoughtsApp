import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../l10n/gen/app_localizations.dart';
import 'dashboard_providers.dart';

String _fmtNum(Object? n) {
  final d = double.tryParse('$n') ?? 0;
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

/// 群統計(PRD §4.3):只展示群总量与聚合指标,不做任何成员排名/对比。
class GroupStatsScreen extends ConsumerWidget {
  const GroupStatsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final daily = ref.watch(groupDailyStatsProvider(groupId));
    final totals = ref.watch(groupTotalsProvider(groupId));
    final reporters = ref.watch(groupTodayReportersProvider(groupId));

    final typeIds = <String>{
      ...?daily.value?.map((r) => r['practice_type_id'] as String),
      ...?totals.value?.map((r) => r['practice_type_id'] as String),
    }.toList();
    final names = ref.watch(practiceTypeNamesProvider(typeIds));

    String nameOf(String id) {
      final t = names.value?[id];
      if (t == null) return '';
      return (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant']) as String;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupStats)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupDailyStatsProvider(groupId));
          ref.invalidate(groupTotalsProvider(groupId));
          ref.invalidate(groupTodayReportersProvider(groupId));
        },
        child: daily.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l10n.loadFailed)),
          data: (rows) {
            final todayRows = rows.where((r) => r['local_date'] == today).toList();
            final trendDays = List.generate(14, (i) {
              final d = DateTime.now().subtract(Duration(days: 13 - i));
              return DateFormat('yyyy-MM-dd').format(d);
            });
            final perDay = {
              for (final d in trendDays)
                d: rows
                    .where((r) => r['local_date'] == d)
                    .fold<int>(0, (s, r) => s + (r['entries'] as int))
            };
            final maxCount = perDay.values.fold<int>(1, (m, v) => v > m ? v : m);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: Text(l10n.reportedToday),
                    trailing: Text(
                      '${reporters.value ?? '—'}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(l10n.todayTitle, style: Theme.of(context).textTheme.titleMedium),
                if (todayRows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l10n.noDataToday),
                  )
                else
                  for (final r in todayRows)
                    ListTile(
                      dense: true,
                      title: Text(nameOf(r['practice_type_id'] as String)),
                      trailing: Text(
                        '${_fmtNum(r['total'])} ${unitLabel(l10n, r['unit'] as String)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                const Divider(height: 32),

                Text(l10n.trend14, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 96,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in trendDays)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Container(
                              height: perDay[d] == 0
                                  ? 3
                                  : 8 + 80 * (perDay[d]! / maxCount),
                              decoration: BoxDecoration(
                                color: perDay[d] == 0
                                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                                    : Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 32),

                Text(l10n.totalTitle, style: Theme.of(context).textTheme.titleMedium),
                totals.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text(l10n.loadFailed),
                  data: (list) => Column(
                    children: [
                      for (final r in list)
                        ListTile(
                          dense: true,
                          title: Text(nameOf(r['practice_type_id'] as String)),
                          trailing: Text(
                            '${_fmtNum(r['total'])} ${unitLabel(l10n, r['unit'] as String)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
