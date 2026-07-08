import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
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
    final notifications = ref.watch(myNotificationsProvider);
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.loadFailed)),
        data: (list) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead(list));
          if (list.isEmpty) return Center(child: Text(l10n.emptyList));
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
                      _ => Icons.notifications_outlined,
                    },
                    color: unread ? Theme.of(context).colorScheme.primary : null,
                  ),
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
