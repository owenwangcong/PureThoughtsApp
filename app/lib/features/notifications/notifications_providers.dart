import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      .order('created_at', ascending: false)
      .limit(50);
});

bool isUnread(Map<String, dynamic> n) =>
    (n['notification_reads'] as List?)?.isEmpty ?? true;

/// 未读数(首页红点)
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(myNotificationsProvider).value ?? const [];
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
