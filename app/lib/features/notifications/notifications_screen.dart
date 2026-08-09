import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/almanac/lunar_format.dart';
import '../../core/settings.dart';
import '../../core/timezones.dart';
import '../../core/units.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../dashboard/dashboard_providers.dart';
import '../groups/groups_providers.dart';
import 'notifications_providers.dart';

/// 通知中心(P2.3 · P2.17 改造):按类型渲染本地化文案 + 深链。
///
/// v0.5.21:
/// - 已读改为**点击单条**标记 + 顶部「全部已讀」按钮(原为进页面即全部标记,
///   会把用户没细看的一并清掉,红点也就不反映真实未读量);
/// - 游标分页触底加载(原 50 条硬上限、无分页);
/// - 时间按设备本地时区显示(原直接截取 UTC 字符串,跨时区用户看到的是错的);
/// - 点击落地路由统一走 routeOfNotification,与推送报文里的 route 同一张对照表。
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<void> _markOne(String id) async {
    try {
      await markNotificationsRead([id]);
      ref.invalidate(notificationFeedProvider);
    } catch (_) {
      // 静默:标记已读失败不影响阅读
    }
  }

  Future<void> _markAll(List<Map<String, dynamic>> list) async {
    final ids = [for (final n in list.where(isUnread)) n['id'] as String];
    if (ids.isEmpty) return;
    try {
      await markNotificationsRead(ids);
      ref.invalidate(notificationFeedProvider);
    } catch (_) {}
  }

  /// 活动当地时间(提前一天的预告要说清是哪天几点,与详情页「活動當地時間」同口径)
  String _eventLocalText(String? iso, String? tzName) {
    if (iso == null) return '';
    try {
      final t = tz.TZDateTime.from(
          DateTime.parse(iso), locationOf(tzName ?? 'Asia/Shanghai'));
      return DateFormat('MM-dd HH:mm')
          .format(DateTime(t.year, t.month, t.day, t.hour, t.minute));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final notifications = ref.watch(visibleNotificationsProvider);
    ref.watch(notificationRealtimeProvider); // 新通知即时进列表
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
        // 活动提醒(PRD v0.5.21 §5,默认三档 1440/30/0)
        case 'event_reminder':
          final ofs = (payload['offset_minutes'] as num?)?.toInt() ?? 0;
          final name = (payload['title'] as String?) ?? '';
          if (ofs >= 1440) {
            final when = _eventLocalText(
                payload['start_at'] as String?, payload['timezone'] as String?);
            return (
              l10n.notifEventReminderEve,
              when.isEmpty ? name : '$name · $when',
            );
          }
          if (ofs >= 60) {
            return (
              l10n.notifEventReminderSoon,
              '$name · ${l10n.notifEventReminderInHours((ofs / 60).round())}',
            );
          }
          if (ofs >= 1) {
            return (
              l10n.notifEventReminderSoon,
              '$name · ${l10n.notifEventReminderInMinutes(ofs)}',
            );
          }
          final hasLink =
              payload['has_webex'] == true || payload['has_youtube'] == true;
          return (
            l10n.notifEventReminderNow,
            hasLink ? '$name · ${l10n.notifEventReminderEnter}' : name,
          );
        case 'event_changed':
          final word = switch (payload['action']) {
            'created' => l10n.actCreated,
            'updated' => l10n.actUpdated,
            'deleted' => l10n.actDeleted,
            'occurrence_cancelled' => l10n.actOccCancelled,
            'occurrence_restored' => l10n.actOccRestored,
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
        // 学修问答(PRD §16):隐私定案,通知中心不显示问题正文
        case 'qa_reply':
          return (l10n.notifQaReply, '');
        case 'qa_question':
          return (l10n.notifQaQuestion, '');
        default:
          return (
            (n['title'] as String?)?.isNotEmpty == true ? n['title'] as String : n['type'] as String,
            n['body'] as String? ?? '',
          );
      }
    }

    /// 收到时间按设备本地时区显示
    String timeText(String raw) {
      try {
        return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(raw).toLocal());
      } catch (_) {
        return raw;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if ((notifications.value ?? const []).any(isUnread))
            TextButton(
              onPressed: () => _markAll(notifications.value ?? const []),
              child: Text(l10n.notifyMarkAllRead),
            ),
        ],
      ),
      body: notifications.when(
        loading: () => const SkeletonList(),
        error: (_, _) =>
            ErrorRetry(onRetry: () => ref.invalidate(notificationFeedProvider)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
                icon: Icons.notifications_none_outlined, title: l10n.emptyList);
          }
          final hasMore = ref.read(notificationFeedProvider.notifier).hasMore;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationFeedProvider),
            child: ListView.separated(
              itemCount: list.length + (hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i >= list.length) {
                  // 触底加载下一页
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(notificationFeedProvider.notifier).loadMore();
                  });
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final n = list[i];
                final (title, subtitle) = render(n);
                final unread = isUnread(n);
                final route = routeOfNotification(n);
                return ListTile(
                  leading: Icon(
                    switch (n['type']) {
                      'proxy_log' => Icons.volunteer_activism_outlined,
                      'announcement' => Icons.campaign_outlined,
                      'live_started' => Icons.live_tv,
                      'event_reminder' => Icons.notifications_active_outlined,
                      'event_changed' => Icons.event_note,
                      'almanac' => Icons.spa_outlined,
                      'qa_reply' || 'qa_question' => Icons.question_answer_outlined,
                      _ => Icons.notifications_outlined,
                    },
                    color: unread ? Theme.of(context).colorScheme.primary : null,
                  ),
                  // 点击 = 标记这一条已读(+ 有落地页则跳转)
                  onTap: () {
                    if (unread) _markOne(n['id'] as String);
                    if (route != null) context.push(route);
                  },
                  title: Text(
                    title,
                    style: unread ? const TextStyle(fontWeight: FontWeight.bold) : null,
                  ),
                  subtitle: Text('$subtitle\n${timeText(n['created_at'] as String)}'),
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
