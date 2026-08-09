import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import 'notification_prefs.dart';

/// 每页条数(改造前是硬编码 limit(50) 且无分页)
const notificationsPageSize = 30;

/// 我的通知(RLS 按 scope 命中:all / user=我 / group=我所在群),内嵌我的已读记录。
/// App 内通知中心是大陆 Android 唯一通道(PRD §5.1 刚需)。
///
/// v0.5.21:游标分页 + 只取 channels 含 inapp 的行 —— 免打扰顺延克隆出的副本是
/// channels={push}(只推不进列表),否则用户会在通知中心看到重复条目。
class NotificationFeed extends AsyncNotifier<List<Map<String, dynamic>>> {
  var _hasMore = true;
  bool get hasMore => _hasMore;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      _hasMore = false;
      return const [];
    }
    final rows = await _fetch();
    _hasMore = rows.length >= notificationsPageSize;
    return rows;
  }

  Future<List<Map<String, dynamic>>> _fetch({String? before}) async {
    var q = Supabase.instance.client
        .from('notifications')
        .select('id, scope, target_id, title, body, type, payload, event_id, '
            'created_at, notification_reads(read_at)')
        .contains('channels', ['inapp'])
        // 定时通知到点前不出现在通知中心(PRD v0.5.16;推送侧由 push_audience 同口径把关)
        .or('scheduled_at.is.null,scheduled_at.lte.'
            '${DateTime.now().toUtc().toIso8601String()}');
    if (before != null) q = q.lt('created_at', before);
    final rows =
        await q.order('created_at', ascending: false).limit(notificationsPageSize);
    return rows.cast<Map<String, dynamic>>();
  }

  /// 触底加载下一页(游标 = 当前最后一条的 created_at)
  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || cur.isEmpty || !_hasMore) return;
    final rows = await _fetch(before: cur.last['created_at'] as String);
    _hasMore = rows.length >= notificationsPageSize;
    if (rows.isNotEmpty) state = AsyncData([...cur, ...rows]);
  }
}

final notificationFeedProvider =
    AsyncNotifierProvider<NotificationFeed, List<Map<String, dynamic>>>(
        NotificationFeed.new);

/// 测试用:直接给定列表的通知源。
/// AsyncNotifierProvider 不像 FutureProvider 那样能 `overrideWith((ref) async => ...)`,
/// 必须提供一个 Notifier 实例工厂 —— `overrideWith(() => StubNotificationFeed([...]))`。
@visibleForTesting
class StubNotificationFeed extends NotificationFeed {
  StubNotificationFeed(this.rows, {bool hasMore = false}) : _more = hasMore;

  final List<Map<String, dynamic>> rows;
  final bool _more;

  @override
  bool get hasMore => _more;

  @override
  Future<List<Map<String, dynamic>>> build() async => rows;

  @override
  Future<void> loadMore() async {}
}

/// Realtime 红点(P2.17):App 前台时新通知即时反映到铃铛,
/// 改造前只有冷启动 / 下拉刷新才会更新。
final notificationRealtimeProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  try {
    final client = Supabase.instance.client;
    final channel = client
        .channel('realtime-notifications-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          // 不加 filter:scope=all / user / group 三种命中方式无法用单一列表达,
          // 由 RLS 保证只推送有权限的行
          callback: (_) => ref.invalidate(notificationFeedProvider),
        )
        .subscribe();
    ref.onDispose(() => client.removeChannel(channel));
  } catch (_) {
    // Realtime 订阅是纯增强(拉取式通知中心才是刚需,PRD §5.1):
    // 连不上就退回下拉刷新,不能让整个页面崩(widget 测试里 Supabase 未初始化亦然)
  }
});

bool isUnread(Map<String, dynamic> n) =>
    (n['notification_reads'] as List?)?.isEmpty ?? true;

/// 按用户偏好过滤后的通知列表(通知中心与红点统一用它)。
/// v0.5.21:过滤依据从本地 SharedPreferences 改为云端 notification_prefs.muted_types,
/// 与服务端投递过滤同一份数据 —— 此前「关了开关仍收推送」正是两边不同源导致。
final visibleNotificationsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final muted =
      ref.watch(notificationPrefsProvider).value?.mutedTypes ??
          const <String>[];
  return ref.watch(notificationFeedProvider).whenData((list) => [
        for (final n in list)
          if (!isNotificationMuted(n, muted)) n,
      ]);
});

/// 未读数(首页红点;不含被静音的类别)
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(visibleNotificationsProvider).value ?? const [];
  return list.where(isUnread).length;
});

/// 点击通知的落地路由。
/// ⚠️ 必须与服务端 supabase/functions/push-dispatch/index.ts 的 routeOf() 保持一致
/// (跨语言无法共享常量,两端改动必须成对;对照表见 design/notification-overhaul.md §8.2)。
/// 返回 null = 该条不可点。
String? routeOfNotification(Map<String, dynamic> n) {
  final p = (n['payload'] as Map?) ?? const {};
  final eid = p['event_id'] ?? n['event_id'];
  switch (n['type']) {
    case 'event_reminder':
    case 'event_changed':
      // 活动已删(action=deleted)时不带 event_id,深链过去只有空态 → 退化到日历
      if (eid == null) return '/calendar';
      final d = p['occurrence_date'] ?? p['date'];
      return d == null ? '/calendar/event/$eid' : '/calendar/event/$eid?date=$d';
    case 'almanac':
      return '/calendar';
    case 'live_started':
      return '/live';
    case 'qa_reply':
      final t = p['thread_id'];
      return t == null ? '/study-qa' : '/study-qa/$t';
    case 'qa_question':
      final t = p['thread_id'];
      return t == null ? '/study-qa' : '/study-qa/$t?as=admin';
    case 'announcement':
      final g = n['target_id'];
      return g == null ? '/groups' : '/groups/$g';
    case 'proxy_log':
      return '/dashboard';
    default:
      return null;
  }
}

/// 标记已读(幂等 upsert)
Future<void> markNotificationsRead(List<String> ids) async {
  if (ids.isEmpty) return;
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  await Supabase.instance.client.from('notification_reads').upsert(
    [
      for (final id in ids) {'notification_id': id, 'user_id': uid}
    ],
    onConflict: 'notification_id,user_id',
    ignoreDuplicates: true,
  );
}
