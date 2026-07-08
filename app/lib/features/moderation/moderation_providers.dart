import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';

/// 我拉黑的用户 id 集合(客户端过滤其申请/报数展示,PRD §10.2)
final myBlocksProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const {};
  final rows = await Supabase.instance.client
      .from('user_blocks')
      .select('blocked_user_id');
  return {for (final r in rows) r['blocked_user_id'] as String};
});

Future<void> toggleBlock(String targetUserId, bool block) async {
  final client = Supabase.instance.client;
  if (block) {
    await client.from('user_blocks').insert({
      'user_id': client.auth.currentUser!.id,
      'blocked_user_id': targetUserId,
    });
  } else {
    await client
        .from('user_blocks')
        .delete()
        .eq('user_id', client.auth.currentUser!.id)
        .eq('blocked_user_id', targetUserId);
  }
}

/// 待处理举报(RLS:管理员全量;普通用户只见自己提交的)
final openReportsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('reports')
      .select('id, target_type, target_id, reason, created_at')
      .eq('status', 'open')
      .order('created_at', ascending: true);
});
