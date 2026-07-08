import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';

/// 我的群(任意状态:approved 可进入,pending 显示审核中)
final myGroupsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final rows = await Supabase.instance.client
      .from('group_members')
      .select('status, role, group_id, groups(id, name, description, announcement)')
      .eq('user_id', user.id)
      .inFilter('status', ['approved', 'pending']);
  // groups 为 null 说明群已解散(软删,RLS 不可见)
  return rows.where((r) => r['groups'] != null).toList();
});

/// 群详情(基本信息)
final groupProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, groupId) async {
  return Supabase.instance.client
      .from('groups')
      .select('id, name, description, announcement, owner_id')
      .eq('id', groupId)
      .maybeSingle();
});

/// 群成员显示名(经 group_member_display 视图,仅本群成员可见)
final groupMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  return Supabase.instance.client
      .from('group_member_display')
      .select('user_id, display_name, role')
      .eq('group_id', groupId);
});

/// 待审核申请(RLS:仅群主查得到,成员返回空)
final pendingApplicationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  return Supabase.instance.client
      .from('group_members')
      .select('user_id, apply_message, created_at')
      .eq('group_id', groupId)
      .eq('status', 'pending');
});

/// join code(RPC,仅群主/管理员;无权限返回 null)
final joinCodeProvider = FutureProvider.family<String?, String>((ref, groupId) async {
  try {
    final res = await Supabase.instance.client
        .rpc('get_group_join_code', params: {'p_group_id': groupId});
    return res as String?;
  } catch (_) {
    return null;
  }
});
