import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/channels.dart';
import '../../core/prefs.dart';
import '../../core/settings.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../dashboard/quick_report_section.dart';
import '../groups/groups_providers.dart';
import '../logs/offline_queue.dart';
import '../notifications/notifications_providers.dart';

/// 首页(PRD v0.5.8):登录与未登录**同一套分组界面**(日課/共修/修行/通用);
/// 未登录时点击账号类功能(報數/快捷報數/群組/統計/發願/通知)强制跳登录页;
/// 直播/經本/日曆/工具/設定匿名可用。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// 账号类功能守卫:未登录 → 登录页
  void _guard(BuildContext context, WidgetRef ref, VoidCallback action) {
    if (ref.read(currentUserProvider) == null) {
      context.push('/auth');
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    // 离线报数自动补传(每会话一次,P5.1)
    if (user != null) scheduleOfflineFlush(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (user == null)
            TextButton(
              onPressed: () => context.push('/auth'),
              child: Text(l10n.authSignIn),
            ),
          _NotificationBell(
            onTap: () =>
                _guard(context, ref, () => context.push('/notifications')),
          ),
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
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
                    onTap: () =>
                        _guard(context, ref, () => _startReport(context, ref)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigTile(
                    icon: Icons.bolt,
                    label: l10n.quickReportTitle,
                    emphasis: _TileEmphasis.container,
                    onTap: () =>
                        _guard(context, ref, () => showQuickReportSheet(context)),
                  ),
                ),
              ],
            ),
          ),

          // ---- 共修 ----
          SectionHeader(l10n.sectionSangha),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BigTile(
                        icon: Icons.live_tv,
                        label: l10n.liveTitle,
                        onTap: () => context.push('/live'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BigTile(
                        icon: Icons.menu_book_outlined,
                        label: l10n.scripturesTitle,
                        // 直达经本网站,不经列表层(2026-07-09 用户定案)
                        onTap: () => context.push(Uri(
                          path: '/webview',
                          queryParameters: {
                            'url': Channels.scripturesUrl,
                            'title': l10n.scripturesTitle,
                            'zoom': '1',
                          },
                        ).toString()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BigTile(
                        icon: Icons.groups,
                        label: l10n.groupsTitle,
                        onTap: () =>
                            _guard(context, ref, () => context.push('/groups')),
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
                        onTap: () =>
                            _guard(context, ref, () => context.push('/dashboard')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BigTile(
                        icon: Icons.volunteer_activism_outlined,
                        label: l10n.vowsTitle,
                        onTap: () =>
                            _guard(context, ref, () => context.push('/vows')),
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
