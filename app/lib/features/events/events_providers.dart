import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_detail_models.dart';

/// 全部活动(匿名可读,PRD §2/§12.3;数量级小,整表拉取客户端展开)
final eventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('events')
      .select(
          'id, title, event_type_id, start_at, duration_minutes, recurrence_rule, webex_url, youtube_url, content, event_agenda_items(count), event_attachments(count)')
      .order('start_at', ascending: true);
});

/// 事件类型(动态表,管理员维护;PRD v0.5.7)
final eventTypesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('event_types')
      .select('id, name_hant, name_hans, icon, sort_order, active')
      .order('sort_order', ascending: true);
});

/// 单次修改(改期/取消)
final eventOverridesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('event_overrides')
      .select('event_id, occurrence_date, patch');
});

/// 某活动的时间表行(匿名可读;PRD v0.5.12)
final agendaItemsProvider =
    FutureProvider.family<List<AgendaItem>, String>((ref, eventId) async {
  final rows = await Supabase.instance.client
      .from('event_agenda_items')
      .select(
          'id, day_index, start_time, end_time, activity, link_url, link_label, sort_order')
      .eq('event_id', eventId)
      .order('day_index')
      .order('sort_order')
      .order('start_time');
  return rows.map(AgendaItem.fromJson).toList();
});

/// 某活动的相关资料(PDF);公开 URL 由 Storage.getPublicUrl 计算后注入。
final attachmentsProvider =
    FutureProvider.family<List<EventAttachment>, String>((ref, eventId) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from('event_attachments')
      .select('id, title, storage_path, size_bytes, content_type, sort_order')
      .eq('event_id', eventId)
      .order('sort_order');
  return rows.map((r) {
    final url =
        client.storage.from('event-files').getPublicUrl(r['storage_path'] as String);
    return EventAttachment.fromRow(r, url);
  }).toList();
});
