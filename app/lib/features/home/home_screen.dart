import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/prefs.dart';
import '../../core/settings.dart';
import '../../core/units.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../dashboard/quick_report_section.dart';
import '../groups/groups_providers.dart';
import '../notifications/notifications_providers.dart';

/// 全局功课项(主清单),匿名即可读(RLS:group_id is null 公开)
class PracticeType {
  const PracticeType({
    required this.id,
    required this.nameHant,
    required this.nameHans,
    required this.category,
    required this.unit,
  });

  final String id;
  final String nameHant;
  final String nameHans;
  final String category;
  final String unit;

  factory PracticeType.fromJson(Map<String, dynamic> json) => PracticeType(
        id: json['id'] as String,
        nameHant: json['name_hant'] as String,
        nameHans: json['name_hans'] as String,
        category: json['category'] as String,
        unit: json['unit'] as String,
      );

  String nameFor(Locale locale) => locale.scriptCode == 'Hans' ? nameHans : nameHant;
}

final globalPracticeTypesProvider = FutureProvider<List<PracticeType>>((ref) async {
  final rows = await Supabase.instance.client
      .from('practice_types')
      .select('id, name_hant, name_hans, category, unit')
      .isFilter('group_id', null)
      .order('sort_order', ascending: true);
  return rows.map(PracticeType.fromJson).toList();
});

/// 骨架期首页:展示全局功课清单,验证「App 启动并匿名读到公开表数据」(PLAN P0.6 验收)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final types = ref.watch(globalPracticeTypesProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(user == null ? l10n.practiceListTitle : l10n.appTitle),
        // 登录态导航走首页功能宫格,顶栏只留通知铃(PRD v0.5.5)
        actions: user == null
            ? [
                TextButton(
                  onPressed: () => context.push('/auth'),
                  child: Text(l10n.authSignIn),
                ),
                IconButton(
                  tooltip: l10n.calendarTitle,
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () => context.push('/calendar'),
                ),
                IconButton(
                  tooltip: l10n.toolsTitle,
                  icon: const Icon(Icons.self_improvement),
                  onPressed: () => context.push('/tools'),
                ),
                IconButton(
                  tooltip: l10n.settingsTitle,
                  icon: const Icon(Icons.settings),
                  onPressed: () => context.push('/settings'),
                ),
              ]
            : [
                // 通知/設定:顶栏小图标与宫格双入口(PRD v0.5.5)
                _NotificationBell(onTap: () => context.push('/notifications')),
                IconButton(
                  tooltip: l10n.settingsTitle,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push('/settings'),
                ),
              ],
      ),
      body: user == null
          // 匿名:浏览全局功课清单(公开内容)
          ? _buildPracticeList(context, ref, l10n, locale, types)
          // 登录:分组式功能布局(PRD v0.5.5:日課 / 共修 / 修行 / 通用)
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // ---- 日課:最高频动作,大色块强调 ----
                SectionHeader(l10n.sectionDaily),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BigTile(
                          icon: Icons.edit_note,
                          label: l10n.reportLog,
                          emphasis: _TileEmphasis.primary,
                          onTap: () => _startReport(context, ref),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BigTile(
                          icon: Icons.bolt,
                          label: l10n.quickReportTitle,
                          emphasis: _TileEmphasis.container,
                          onTap: () => showQuickReportSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---- 共修 ----
                SectionHeader(l10n.sectionSangha),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BigTile(
                          icon: Icons.groups,
                          label: l10n.groupsTitle,
                          onTap: () => context.push('/groups'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BigTile(
                          icon: Icons.calendar_month,
                          label: l10n.calendarTitle,
                          onTap: () => context.push('/calendar'),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---- 修行:个人纪录与工具 ----
                SectionHeader(l10n.sectionSelf),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _BigTile(
                              icon: Icons.insights,
                              label: l10n.myStats,
                              onTap: () => context.push('/dashboard'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BigTile(
                              icon: Icons.volunteer_activism_outlined,
                              label: l10n.vowsTitle,
                              onTap: () => context.push('/vows'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _BigTile(
                              icon: Icons.self_improvement,
                              label: l10n.timerTitle,
                              onTap: () => context.push('/tools/timer'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BigTile(
                              icon: Icons.radio_button_checked,
                              label: l10n.counterTitle,
                              onTap: () => context.push('/tools/counter'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ---- 通用 ----
                SectionHeader(l10n.sectionGeneral),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BigTile(
                          icon: Icons.notifications_outlined,
                          label: l10n.notificationsTitle,
                          onTap: () => context.push('/notifications'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BigTile(
                          icon: Icons.settings_outlined,
                          label: l10n.settingsTitle,
                          onTap: () => context.push('/settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// 報數直达:0 群 → 去入群;1 群 → 直进表单;多群 → 底部选择器(上次的排最前)
  Future<void> _startReport(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final groups = (ref.read(myGroupsProvider).value ?? const [])
        .where((m) => m['status'] == 'approved')
        .map((m) => m['groups'] as Map<String, dynamic>)
        .toList();
    if (groups.isEmpty) {
      context.push('/groups');
      return;
    }
    final prefs = ref.read(sharedPrefsProvider);
    if (groups.length == 1) {
      final gid = groups.single['id'] as String;
      prefs.setString(PrefKeys.lastReportGroup, gid);
      context.push('/groups/$gid/report');
      return;
    }
    final last = prefs.getString(PrefKeys.lastReportGroup);
    groups.sort((a, b) => (b['id'] == last ? 1 : 0) - (a['id'] == last ? 1 : 0));
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.chooseGroup,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final g in groups)
              ListTile(
                leading: const Icon(Icons.groups),
                title: Text(g['name'] as String),
                trailing: g['id'] == last ? const Icon(Icons.history) : null,
                onTap: () => Navigator.pop(context, g['id'] as String),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    prefs.setString(PrefKeys.lastReportGroup, picked);
    context.push('/groups/$picked/report');
  }

  Widget _buildPracticeList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Locale locale,
    AsyncValue<List<PracticeType>> types,
  ) {
    return types.when(
        loading: () => const SkeletonList(),
        error: (_, _) =>
            ErrorRetry(onRetry: () => ref.invalidate(globalPracticeTypesProvider)),
        data: (items) => items.isEmpty
            ? EmptyState(icon: Icons.menu_book_outlined, title: l10n.emptyList)
            // 按分类分组:經/咒/懺/念佛/靜坐(PRD v0.5.2)
            : ListView(
                children: [
                  for (final cat in practiceCategories)
                    if (items.any((t) => t.category == cat)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          categoryLabel(l10n, cat),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      for (final item in items.where((t) => t.category == cat))
                        ListTile(
                          dense: true,
                          title: Text(item.nameFor(locale)),
                          trailing: Text(
                            unitLabel(l10n, item.unit),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                    ],
                ],
              ),
    );
  }
}

enum _TileEmphasis { surface, container, primary }

/// 大功能块:图标 + 文字的半宽色块(分组布局主元素,大气简约)
class _BigTile extends ConsumerWidget {
  const _BigTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasis = _TileEmphasis.surface,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _TileEmphasis emphasis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (emphasis) {
      _TileEmphasis.primary => (scheme.primary, scheme.onPrimary),
      _TileEmphasis.container => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _TileEmphasis.surface => (scheme.surfaceContainerLow, scheme.onSurface),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 30,
                  color: emphasis == _TileEmphasis.surface ? scheme.primary : fg),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: fg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 通知铃铛(带未读红点),App 内通知中心入口(大陆 Android 唯一通道)
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: AppLocalizations.of(context).notificationsTitle,
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
