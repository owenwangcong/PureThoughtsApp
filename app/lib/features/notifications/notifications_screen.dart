import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/almanac/lunar_format.dart';
import '../../core/settings.dart';
import '../../core/units.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../dashboard/dashboard_providers.dart';
import '../groups/groups_providers.dart';
import 'notifications_providers.dart';

/// 通知中心(P2.3):按类型渲染本地化文案;进入即把当前列表标记已读。
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  var _marked = false;

  void _markAllRead(List<Map<String, dynamic>> list) {
    if (_marked) return;
    _marked = true;
    final unreadIds = [
      for (final n in list.where(isUnread)) n['id'] as String,
    ];
    if (unreadIds.isEmpty) return;
    // 后台标记,完成后刷新红点
    markNotificationsRead(unreadIds)
        .then((_) => ref.invalidate(myNotificationsProvider))
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final notifications = ref.watch(visibleNotificationsProvider);
    final types = ref.watch(allPracticeTypesMapProvider).value ?? const {};
    final groupNames = <String, String>{
      for (final m in ref.watch(myGroupsProvider).value ?? const [])
        (m['groups'] as Map)['id'] as String: (m['groups'] as Map)['name'] as String,
    };

    (String, String) render(Map<String, dynamic> n) {
      final payload = (n['payload'] as Map?) ?? const {};
      final groupName = groupNames[payload['group_id']] ?? '';
      switch (n['type']) {
        case 'proxy_log':
          final t = types[payload['practice_type_id']];
          final typeName = t == null
              ? ''
              : (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant']) as String;
          final qty = payload['quantity'];
          final unit = t == null ? '' : unitLabel(l10n, t['unit'] as String);
          return (l10n.notifProxyLog, '$groupName · $typeName $qty $unit');
        case 'announcement':
          return (l10n.notifAnnouncement, '$groupName · ${payload['text'] ?? ''}');
        case 'live_started':
          return (l10n.notifLiveStarted, (payload['title'] as String?) ?? 'YouTube');
        case 'event_changed':
          final word = switch (payload['action']) {
            'created' => l10n.actCreated,
            'updated' => l10n.actUpdated,
            'deleted' => l10n.actDeleted,
            'occurrence_cancelled' => l10n.actOccCancelled,
            _ => l10n.actOccChanged,
          };
          return (l10n.notifEventChanged, '$word · ${payload['title'] ?? ''}');
        case 'almanac':
          // 佛历通知(PRD v0.5.15 §5.2):payload 携带简繁名与农历数字,客户端渲染
          final hans = locale.scriptCode == 'Hans';
          final names = ((hans ? payload['names_hans'] : payload['names_hant'])
                      as List?)
                  ?.cast<String>() ??
              const <String>[];
          final lunar = lunarFullText(
            (payload['lunar_month'] as num?)?.toInt() ?? 1,
            (payload['lunar_day'] as num?)?.toInt() ?? 1,
            payload['is_leap_month'] == true,
            hans: hans,
          );
          return switch (payload['kind']) {
            'zhai' => (l10n.notifAlmanacZhai, lunar),
            'festival_eve' => (l10n.notifAlmanacEve, '${names.join('、')} · $lunar'),
            _ => (l10n.notifAlmanacFestival, '${names.join('、')} · $lunar'),
          };
        default:
          return (
            (n['title'] as String?)?.isNotEmpty == true ? n['title'] as String : n['type'] as String,
            n['body'] as String? ?? '',
          );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: notifications.when(
        loading: () => const SkeletonList(),
        error: (_, _) =>
            ErrorRetry(onRetry: () => ref.invalidate(myNotificationsProvider)),
        data: (list) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead(list));
          if (list.isEmpty) {
            return EmptyState(
                icon: Icons.notifications_none_outlined, title: l10n.emptyList);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myNotificationsProvider),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = list[i];
                final (title, subtitle) = render(n);
                final unread = isUnread(n);
                return ListTile(
                  leading: Icon(
                    switch (n['type']) {
                      'proxy_log' => Icons.volunteer_activism_outlined,
                      'announcement' => Icons.campaign_outlined,
                      'live_started' => Icons.live_tv,
                      'event_changed' => Icons.event_note,
                      'almanac' => Icons.spa_outlined,
                      _ => Icons.notifications_outlined,
                    },
                    color: unread ? Theme.of(context).colorScheme.primary : null,
                  ),
                  onTap: switch (n['type']) {
                    'live_started' => () => context.push('/live'),
                    'event_changed' => () => context.push('/calendar'),
                    'almanac' => () => context.push('/calendar'),
                    _ => null,
                  },
                  title: Text(
                    title,
                    style: unread ? const TextStyle(fontWeight: FontWeight.bold) : null,
                  ),
                  subtitle: Text(
                    '$subtitle\n${(n['created_at'] as String).substring(0, 16).replaceAll('T', ' ')}',
                  ),
                  isThreeLine: true,
                  trailing: unread
                      ? Icon(Icons.circle, size: 10, color: Theme.of(context).colorScheme.error)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
