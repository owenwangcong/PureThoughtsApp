import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../l10n/gen/app_localizations.dart';
import '../vows/vows_providers.dart';
import 'dashboard_providers.dart';

String _fmtNum(Object? n) {
  final d = double.tryParse('$n') ?? 0;
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

/// 个人統計(PRD §4.3):今日 / 連續用功天數 / 近 14 天趨勢(筆數)/ 累計 / 歷史查看。
/// 仅本人数据,不与任何人对比(不攀比)。
class MyDashboardScreen extends ConsumerStatefulWidget {
  const MyDashboardScreen({super.key});

  @override
  ConsumerState<MyDashboardScreen> createState() => _MyDashboardScreenState();
}

class _MyDashboardScreenState extends ConsumerState<MyDashboardScreen> {
  String? _historyDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final daily = ref.watch(myDailyStatsProvider);
    final totals = ref.watch(myTotalsProvider);

    final names = ref.watch(allPracticeTypesMapProvider);

    String nameOf(String id) {
      final t = names.value?[id];
      if (t == null) return '…';
      return (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant']) as String;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myStats)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myDailyStatsProvider);
          ref.invalidate(myTotalsProvider);
        },
        child: daily.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l10n.loadFailed)),
          data: (rows) {
            final streak =
                calcStreak(rows.map((r) => r['local_date'] as String), DateTime.now());
            final todayRows = rows.where((r) => r['local_date'] == today).toList();

            // 近 14 天趋势:每日筆數(entries 无法从视图直接得,按行数近似:每行=群×功课项×日)
            final trendDays = List.generate(14, (i) {
              final d = DateTime.now().subtract(Duration(days: 13 - i));
              return DateFormat('yyyy-MM-dd').format(d);
            });
            final perDay = {
              for (final d in trendDays)
                d: rows.where((r) => r['local_date'] == d).length
            };
            final maxCount =
                perDay.values.fold<int>(1, (m, v) => v > m ? v : m);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---- 連續用功 ----
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_fire_department_outlined),
                    title: Text(l10n.streakLabel),
                    trailing: Text('$streak',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                ),
                const SizedBox(height: 16),

                // ---- 發願進度(PRD §4.4:Dashboard 展示目标进度条) ----
                _ActiveVowsSection(nameOf: nameOf),

                // ---- 今日 ----
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

                // ---- 近 14 天趋势(笔数) ----
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

                // ---- 累计 ----
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
                const Divider(height: 32),

                // ---- 历史查看 ----
                Text(l10n.historyTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_historyDate ?? l10n.pickDate),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() =>
                          _historyDate = DateFormat('yyyy-MM-dd').format(picked));
                    }
                  },
                ),
                if (_historyDate != null) _HistoryList(date: _historyDate!, nameOf: nameOf),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 进行中发愿的紧凑进度区(点击进入發願页)
class _ActiveVowsSection extends ConsumerWidget {
  const _ActiveVowsSection({required this.nameOf});
  final String Function(String) nameOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vows = (ref.watch(myVowsProvider).value ?? const [])
        .where((v) => v['status'] == 'active')
        .take(3)
        .toList();
    if (vows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.vowsTitle, style: Theme.of(context).textTheme.titleMedium),
        for (final vow in vows)
          Consumer(builder: (context, ref, _) {
            final p = ref.watch(vowProgressProvider(vow['id'] as String)).value ?? 0;
            final target = double.tryParse('${vow['target_qty']}') ?? 1;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(nameOf(vow['practice_type_id'] as String)),
              subtitle: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: (p / target).clamp(0.0, 1.0), minHeight: 8),
              ),
              trailing: Text('${_fmtNum(p)}/${_fmtNum(target)}'),
              onTap: () => context.push('/vows'),
            );
          }),
        const Divider(height: 32),
      ],
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.date, required this.nameOf});
  final String date;
  final String Function(String) nameOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final logs = ref.watch(myLogsOnDateProvider(date));
    return logs.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text(l10n.loadFailed),
      data: (list) => list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.emptyList),
            )
          : Column(
              children: [
                for (final r in list)
                  ListTile(
                    dense: true,
                    title: Text(nameOf(r['practice_type_id'] as String)),
                    subtitle: r['note'] != null ? Text(r['note'] as String) : null,
                    trailing: Text(
                      '${_fmtNum(r['quantity'])} ${unitLabel(l10n, r['unit'] as String)}',
                    ),
                  ),
              ],
            ),
    );
  }
}
