import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/prefs.dart';
import '../../core/settings.dart';
import '../../core/units.dart';
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
        actions: [
          if (user == null)
            TextButton(
              onPressed: () => context.push('/auth'),
              child: Text(l10n.authSignIn),
            )
          else
            _NotificationBell(onTap: () => context.push('/notifications')),
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: user == null
          // 匿名:浏览全局功课清单(公开内容)
          ? _buildPracticeList(context, ref, l10n, locale, types)
          // 登录:快捷报数 + 统计与群入口(Dashboard 首屏)
          : ListView(
              children: [
                // 報數直达:单群直进,多群选择并记住上次(PRD v0.5.3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit_note, size: 28),
                    label: Text(l10n.reportLog,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary)),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                    onPressed: () => _startReport(context, ref),
                  ),
                ),
                const QuickReportSection(),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.insights),
                  title: Text(l10n.myStats),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/dashboard'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.volunteer_activism_outlined),
                  title: Text(l10n.vowsTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/vows'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text(l10n.groupsTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/groups'),
                ),
                const Divider(height: 1),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.loadFailed),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(globalPracticeTypesProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.emptyList))
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
