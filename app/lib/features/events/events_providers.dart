import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 全部活动(匿名可读,PRD §2/§12.3;数量级小,整表拉取客户端展开)
final eventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('events')
      .select(
          'id, title, type, start_at, duration_minutes, recurrence_rule, webex_url, youtube_url, content')
      .order('start_at', ascending: true);
});

/// 单次修改(改期/取消)
final eventOverridesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('event_overrides')
      .select('event_id, occurrence_date, patch');
});
