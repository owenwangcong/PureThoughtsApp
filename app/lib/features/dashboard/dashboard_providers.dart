import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';

/// 我最近的自报记录(快捷报数来源 + 记忆上次数量;PRD §4.2 快捷报数)
final myRecentSelfLogsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return Supabase.instance.client
      .from('practice_logs')
      .select('group_id, practice_type_id, quantity, created_at')
      .eq('reporter_id', user.id)
      .isFilter('subject_user_id', null)
      .isFilter('subject_name', null)
      .order('created_at', ascending: false)
      .limit(50);
});

/// 我的按日统计(近 60 天,跨群;连续天数 / 今日 / 趋势的数据源)
final myDailyStatsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final since = DateTime.now().subtract(const Duration(days: 60));
  final sinceStr =
      '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
  return Supabase.instance.client
      .from('daily_user_stats')
      .select('group_id, practice_type_id, unit, local_date, total')
      .gte('local_date', sinceStr)
      .order('local_date', ascending: false);
});

/// 我的历史累计(按功课项)
final myTotalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return Supabase.instance.client
      .from('user_practice_totals')
      .select('practice_type_id, unit, total, entries');
});

/// 某日我的报数明细(历史查看)
final myLogsOnDateProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
    (ref, date) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return Supabase.instance.client
      .from('practice_logs')
      .select('group_id, practice_type_id, quantity, unit, note, subject_user_id, reporter_id')
      .eq('local_date', date)
      .isFilter('subject_name', null)
      .or('reporter_id.eq.${user.id},subject_user_id.eq.${user.id}')
      .order('created_at', ascending: false);
});

/// 功课项名称映射(按 id 批量取,跨群;RLS 保证只取得到有权限的)
final practiceTypeNamesProvider =
    FutureProvider.family<Map<String, Map<String, dynamic>>, List<String>>(
        (ref, ids) async {
  if (ids.isEmpty) return const {};
  final rows = await Supabase.instance.client
      .from('practice_types')
      .select('id, name_hant, name_hans, unit')
      .inFilter('id', ids);
  return {for (final r in rows) r['id'] as String: r};
});

/// 群按日统计(近 14 天)
final groupDailyStatsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  final since = DateTime.now().subtract(const Duration(days: 14));
  final sinceStr =
      '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
  return Supabase.instance.client
      .from('daily_group_stats')
      .select('practice_type_id, unit, local_date, total, entries')
      .eq('group_id', groupId)
      .gte('local_date', sinceStr)
      .order('local_date', ascending: false);
});

/// 群历史累计(按功课项)
final groupTotalsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  return Supabase.instance.client
      .from('group_practice_totals')
      .select('practice_type_id, unit, total, entries')
      .eq('group_id', groupId);
});

/// 群今日已报人数(聚合指标,不排名;PRD §4.3 群主视角)
final groupTodayReportersProvider =
    FutureProvider.family<int, String>((ref, groupId) async {
  final now = DateTime.now();
  final today =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final rows = await Supabase.instance.client
      .from('practice_logs')
      .select('reporter_id, subject_user_id, subject_name')
      .eq('group_id', groupId)
      .eq('local_date', today);
  final users = <String>{};
  for (final r in rows) {
    if (r['subject_name'] != null) continue;
    final u = (r['subject_user_id'] ?? r['reporter_id']) as String?;
    if (u != null) users.add(u);
  }
  return users.length;
});

/// 连续用功天数(仅自己可见;中断温和归零,PRD §4.3)
int calcStreak(Iterable<String> localDates, DateTime today) {
  final days = localDates.toSet();
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  var cursor = today;
  // 今天还没报不算中断,从昨天起算
  if (!days.contains(fmt(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (days.contains(fmt(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
