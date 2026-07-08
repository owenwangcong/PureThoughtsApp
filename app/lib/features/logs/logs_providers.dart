import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 本群可报的功课项:全局主清单 + 群自定义,均须 active
final reportablePracticeTypesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  return Supabase.instance.client
      .from('practice_types')
      .select('id, name_hant, name_hans, unit, group_id, sort_order')
      .eq('active', true)
      .or('group_id.is.null,group_id.eq.$groupId')
      .order('sort_order', ascending: true);
});

/// 本群代报名单(自由名字自动记忆,按最近使用排序;PRD §4.2)
final proxyNamesProvider =
    FutureProvider.family<List<String>, String>((ref, groupId) async {
  final rows = await Supabase.instance.client
      .from('proxy_names')
      .select('name')
      .eq('group_id', groupId)
      .order('last_used_at', ascending: false)
      .limit(20);
  return [for (final r in rows) r['name'] as String];
});

/// 本群近期报数记录(软删的由 RLS 排除)
final groupLogsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  return Supabase.instance.client
      .from('practice_logs')
      .select(
          'id, reporter_id, subject_user_id, subject_name, practice_type_id, quantity, unit, note, local_date, created_at')
      .eq('group_id', groupId)
      .order('created_at', ascending: false)
      .limit(100);
});
