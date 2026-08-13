import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';
import '../community/community_providers.dart';

/// 我可**选来报数**的功课项:全局主清单 + **我自己**加的自定义项,均须 active。
///
/// PRD v0.6.0 §4.1 / 设计 Q8:自定义功课项仅创建者可选。
/// ⚠️ 与 `allPracticeTypesMapProvider`(渲染他人记录的名称,不过滤)分工明确,
///    不要把这里的过滤条件搬过去,否则别人用自定义项报的记录会显示成无名条目。
final reportablePracticeTypesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return Supabase.instance.client
      .from('practice_types')
      .select('id, name_hant, name_hans, category, unit, group_id, sort_order')
      .eq('active', true)
      .or('group_id.is.null,created_by.eq.${user.id}')
      .order('sort_order', ascending: true);
});

/// 代报名单(自由名字自动记忆,按最近使用排序;PRD §4.2,v0.6.0 起全站共享)
final proxyNamesProvider = FutureProvider<List<String>>((ref) async {
  final gid = ref.watch(communityIdProvider);
  if (gid == null) return const [];
  final rows = await Supabase.instance.client
      .from('proxy_names')
      .select('name')
      .eq('group_id', gid)
      .order('last_used_at', ascending: false)
      .limit(20);
  return [for (final r in rows) r['name'] as String];
});

/// 共修报数记录(近 100 条流水;软删的由 RLS 排除)
final communityLogsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final gid = ref.watch(communityIdProvider);
  if (gid == null) return const [];
  return Supabase.instance.client
      .from('practice_logs')
      .select(
          'id, reporter_id, subject_user_id, subject_name, practice_type_id, quantity, unit, note, local_date, created_at')
      .eq('group_id', gid)
      .order('created_at', ascending: false)
      .limit(100);
});

/// 记录流水里出现过的用户 → 显示名。
///
/// v0.6.0:成员规模变成全站,**不再全量拉成员列表** —— 只按当前这一屏记录里
/// 实际出现的 id 反查(`group_member_display` 视图,窄口且有界)。
/// 取不到的(已注销)由调用方回退为「同修」。
final logDisplayNamesProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final logs = await ref.watch(communityLogsProvider.future);
  final ids = <String>{};
  for (final l in logs) {
    final r = l['reporter_id'] as String?;
    final s = l['subject_user_id'] as String?;
    if (r != null) ids.add(r);
    if (s != null) ids.add(s);
  }
  if (ids.isEmpty) return const {};
  final rows = await Supabase.instance.client
      .from('group_member_display')
      .select('user_id, display_name')
      .inFilter('user_id', ids.toList());
  return {
    for (final r in rows)
      r['user_id'] as String: (r['display_name'] as String?) ?? ''
  };
});
