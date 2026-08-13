import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/settings.dart';
import '../../core/units.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../dashboard/dashboard_providers.dart';
import '../logs/logs_providers.dart';
import 'add_practice_type_dialog.dart';
import 'community_providers.dart';

String _fmtNum(Object? n) {
  final d = double.tryParse('$n') ?? 0;
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// 共修報數(PRD v0.6.0 §3.2):公告 + 今日/趋势/累计的「我的 / 全體」双栏
/// + 共修报数记录入口 + 我的自訂功課。
///
/// 双栏是**自己与整体**的对照,不是成员之间的对比 —— 不违反"不做任何成员间排名"。
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final community = ref.watch(communityProvider);
    final announcement = ref.watch(communityAnnouncementProvider);
    final myDaily = ref.watch(myDailyStatsProvider);
    final allDaily = ref.watch(communityDailyStatsProvider);
    final myTotals = ref.watch(myTotalsProvider);
    final allTotals = ref.watch(communityTotalsProvider);
    final reporters = ref.watch(communityTodayReportersProvider);
    final names = ref.watch(allPracticeTypesMapProvider);
    ref.watch(communityLogsRealtimeProvider); // 实时刷新(P5.2)

    String nameOf(String id) {
      final t = names.value?[id];
      if (t == null) return '…';
      return (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant'])
          as String;
    }

    final today = _dayKey(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityTitle)),
      body: community.when(
        loading: () => const SkeletonList(rows: 5),
        error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(communityProvider)),
        data: (_) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(communityProvider);
            ref.invalidate(myDailyStatsProvider);
            ref.invalidate(communityDailyStatsProvider);
            ref.invalidate(myTotalsProvider);
            ref.invalidate(communityTotalsProvider);
            ref.invalidate(communityTodayReportersProvider);
            ref.invalidate(myCustomPracticeTypesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // ---- 共修公告(App 内只读;编辑在管理后台) ----
              if (announcement != null) _AnnouncementCard(text: announcement),

              // ---- 今日:我的 / 全體 ----
              SectionHeader(l10n.todayTitle),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TwoColumn(
                  mine: _StatCard(
                    label: l10n.statsMine,
                    lines: _lines(myDaily.value, today, nameOf, l10n),
                    emptyText: '—',
                  ),
                  all: _StatCard(
                    label: l10n.statsAll,
                    lines: _lines(allDaily.value, today, nameOf, l10n),
                    emptyText: l10n.communityEmptyToday,
                    footer: reporters.value == null
                        ? null
                        : '${l10n.reportedToday} ${reporters.value}',
                  ),
                ),
              ),

              // ---- 近 14 天趋势(双系列,各自归一化) ----
              SectionHeader(l10n.trend14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DualTrend(
                  mine: _entriesPerDay(myDaily.value),
                  all: _entriesPerDay(allDaily.value),
                ),
              ),

              // ---- 累计:我的 / 全體 ----
              SectionHeader(l10n.totalTitle),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TwoColumn(
                  mine: _StatCard(
                    label: l10n.statsMine,
                    lines: _totalLines(myTotals.value, nameOf, l10n),
                    emptyText: '—',
                  ),
                  all: _StatCard(
                    label: l10n.statsAll,
                    lines: _totalLines(allTotals.value, nameOf, l10n),
                    emptyText: '—',
                  ),
                ),
              ),

              // ---- 共修报数记录 ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(l10n.communityLogs),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  onPressed: () => context.push('/community/logs'),
                ),
              ),

              // ---- 我的自訂功課 ----
              const _MyCustomTypes(),
            ],
          ),
        ),
      ),
    );
  }

  /// 某日按功课项的汇总行(最多 4 行,其余折叠计数)
  static List<String> _lines(List<Map<String, dynamic>>? rows, String day,
      String Function(String) nameOf, AppLocalizations l10n) {
    if (rows == null) return const [];
    // 同一功课项可能跨多行(个人视图按 group_id 分组),这里合并
    final byType = <String, ({double total, String unit})>{};
    for (final r in rows.where((r) => r['local_date'] == day)) {
      final id = r['practice_type_id'] as String;
      final total = double.tryParse('${r['total']}') ?? 0;
      final prev = byType[id];
      byType[id] = (
        total: (prev?.total ?? 0) + total,
        unit: r['unit'] as String,
      );
    }
    return _render(byType, nameOf, l10n);
  }

  static List<String> _totalLines(List<Map<String, dynamic>>? rows,
      String Function(String) nameOf, AppLocalizations l10n) {
    if (rows == null) return const [];
    final byType = <String, ({double total, String unit})>{};
    for (final r in rows) {
      final id = r['practice_type_id'] as String;
      final total = double.tryParse('${r['total']}') ?? 0;
      final prev = byType[id];
      byType[id] = (
        total: (prev?.total ?? 0) + total,
        unit: r['unit'] as String,
      );
    }
    return _render(byType, nameOf, l10n);
  }

  static List<String> _render(Map<String, ({double total, String unit})> byType,
      String Function(String) nameOf, AppLocalizations l10n) {
    final entries = byType.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    final shown = entries.take(4).map((e) =>
        '${nameOf(e.key)} ${_fmtNum(e.value.total)} ${unitLabel(l10n, e.value.unit)}');
    return [
      ...shown,
      if (entries.length > 4) '⋯ +${entries.length - 4}',
    ];
  }

  /// 近 14 天每天的笔数(两个数据源同口径:daily_*_stats 的 entries)
  static Map<String, int> _entriesPerDay(List<Map<String, dynamic>>? rows) {
    final days = List.generate(
        14, (i) => _dayKey(DateTime.now().subtract(Duration(days: 13 - i))));
    return {
      for (final d in days)
        d: (rows ?? const [])
            .where((r) => r['local_date'] == d)
            .fold<int>(0, (s, r) => s + ((r['entries'] as int?) ?? 0))
    };
  }
}

/// 「我的 / 全體」两列;大字号(卡片宽度不足)时自动改为上下堆叠
class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.mine, required this.all});

  final Widget mine;
  final Widget all;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // 每卡至少 150px 才并排;大字号下宁可堆叠也不挤成两条窄柱
        final stack = c.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        if (stack) {
          return Column(children: [mine, const SizedBox(height: 12), all]);
        }
        // ⚠️ 必须包 IntrinsicHeight:Row + CrossAxisAlignment.stretch 在 ListView 里
        // 拿到的是无限高约束,会直接 assert 崩(T-APP-08 实测抓到)。
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: mine),
              const SizedBox(width: 12),
              Expanded(child: all),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.lines,
    required this.emptyText,
    this.footer,
  });

  final String label;
  final List<String> lines;
  final String emptyText;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.primary)),
            const SizedBox(height: 8),
            if (lines.isEmpty)
              Text(emptyText,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant))
            else
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line,
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
            if (footer != null) ...[
              const SizedBox(height: 6),
              Text(footer!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 近 14 天双系列条形图:每天两根并排细条。
/// ⚠️ 两条**各自归一化到自己的最大值** —— 全体量级远大于个人,同轴的话
///    「我的」永远贴底看不见(设计 §16-5)。故图例注明「各自比例」。
class _DualTrend extends StatelessWidget {
  const _DualTrend({required this.mine, required this.all});

  final Map<String, int> mine;
  final Map<String, int> all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final days = all.keys.toList();
    final maxMine = mine.values.fold<int>(1, (m, v) => v > m ? v : m);
    final maxAll = all.values.fold<int>(1, (m, v) => v > m ? v : m);

    Widget bar(int value, int max, Color color) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.8),
            child: Container(
              height: value == 0 ? 3 : 6 + 66 * (value / max),
              decoration: BoxDecoration(
                color: value == 0 ? scheme.surfaceContainerHighest : color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Legend(color: scheme.primary, label: l10n.statsMine),
            _Legend(
                color: scheme.primary.withValues(alpha: 0.38),
                label: l10n.statsAll),
            Text(l10n.statsScaledNote,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        bar(mine[d] ?? 0, maxMine, scheme.primary),
                        bar(all[d] ?? 0, maxAll,
                            scheme.primary.withValues(alpha: 0.38)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: scheme.secondaryContainer,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.communityAnnouncement,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onSecondaryContainer)),
                    const SizedBox(height: 4),
                    Text(text,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: scheme.onSecondaryContainer)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 我的自訂功課:仅列自己创建的项,可停用/启用 + 就地新增(PRD v0.6.0 §4.1)
class _MyCustomTypes extends ConsumerWidget {
  const _MyCustomTypes();

  Future<void> _toggle(BuildContext context, WidgetRef ref,
      Map<String, dynamic> t, bool active) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .from('practice_types')
          .update({'active': active}).eq('id', t['id'] as String);
      ref.invalidate(myCustomPracticeTypesProvider);
      ref.invalidate(reportablePracticeTypesProvider);
      ref.invalidate(allPracticeTypesMapProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final mine = ref.watch(myCustomPracticeTypesProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(l10n.myCustomTypes),
        for (final t in mine)
          SwitchListTile(
            title: Text((locale.scriptCode == 'Hans'
                ? t['name_hans']
                : t['name_hant']) as String),
            subtitle: Text(unitLabel(l10n, t['unit'] as String)),
            value: t['active'] as bool? ?? true,
            onChanged: (v) => _toggle(context, ref, t, v),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(l10n.addPracticeType),
              onPressed: () async {
                final id = await showAddPracticeTypeDialog(context, ref);
                if (id == null) return;
                ref.invalidate(myCustomPracticeTypesProvider);
                ref.invalidate(reportablePracticeTypesProvider);
                ref.invalidate(allPracticeTypesMapProvider);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n.customTypePrivateHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
