import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';

/// 我的发愿(RLS 仅本人;不在群内公示,PRD §4.4)
final myVowsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return Supabase.instance.client
      .from('vows')
      .select('id, group_id, practice_type_id, target_qty, start_date, end_date, status')
      .order('created_at', ascending: false);
});

/// 发愿进度(RPC:跨群或指定群,含被代报,不含自由名字;退群后仍可算)
final vowProgressProvider =
    FutureProvider.family<double, String>((ref, vowId) async {
  final res = await Supabase.instance.client
      .rpc('vow_progress', params: {'p_vow_id': vowId});
  return double.tryParse('$res') ?? 0;
});

/// 剩余天数(含今天;负数=已过期)
int vowDaysLeft(Map<String, dynamic> vow, DateTime today) {
  final end = DateTime.parse(vow['end_date'] as String);
  return end.difference(DateTime(today.year, today.month, today.day)).inDays;
}
