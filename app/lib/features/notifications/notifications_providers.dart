import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../auth/auth_providers.dart';

/// 我的通知(RLS 按 scope 命中:all / user=我 / group=我所在群),
/// 内嵌我的已读记录;App 内通知中心是大陆 Android 唯一通道(PRD §5.1 刚需)
final myNotificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return Supabase.instance.client
      .from('notifications')
      .select(
          'id, scope, target_id, title, body, type, payload, created_at, notification_reads(read_at)')
      // 定时通知到点前不出现在通知中心(PRD v0.5.16;推送侧由 push-dispatch 同口径把关)
      .or('scheduled_at.is.null,scheduled_at.lte.${DateTime.now().toUtc().toIso8601String()}')
      .order('created_at', ascending: false)
      .limit(50);
});

bool isUnread(Map<String, dynamic> n) =>
    (n['notification_reads'] as List?)?.isEmpty ?? true;

/// 单条佛历通知是否按用户开关显示(PRD v0.5.15:节日/十斋日两开关,默认开)
bool almanacNotificationVisible(
    Map<String, dynamic> n, bool showFestival, bool showZhai) {
  if (n['type'] != 'almanac') return true;
  final kind = (n['payload'] as Map?)?['kind'];
  return kind == 'zhai' ? showZhai : showFestival;
}

/// 按用户偏好过滤后的通知列表(通知中心与红点统一用它)
final visibleNotificationsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final showFestival = ref.watch(almanacFestivalNotifyProvider);
  final showZhai = ref.watch(almanacZhaiNotifyProvider);
  return ref.watch(myNotificationsProvider).whenData((list) => [
        for (final n in list)
          if (almanacNotificationVisible(n, showFestival, showZhai)) n,
      ]);
});

/// 未读数(首页红点;不含被开关隐藏的佛历通知)
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(visibleNotificationsProvider).value ?? const [];
  return list.where(isUnread).length;
});

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
