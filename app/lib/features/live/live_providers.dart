import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 当前 YouTube 直播状态(PRD v0.5.6 §6):
/// 打开直播页时触发服务端探测(live-probe:开播即建通知,按场次去重);
/// 探测失败时回退读 live_streams 表(生产环境由 pg_cron 维护)。
final currentLiveProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final res = await Supabase.instance.client.functions.invoke('live-probe');
    final data = res.data;
    if (data is Map && data['live'] == true) {
      return {'video_id': data['video_id'], 'title': data['title']};
    }
    if (data is Map && data['live'] == false) return null;
  } catch (_) {
    // 探测不可用 → 回退查表
  }
  final rows = await Supabase.instance.client
      .from('live_streams')
      .select('video_id, title')
      .eq('platform', 'youtube')
      .isFilter('ended_at', null)
      .limit(1);
  return rows.isEmpty ? null : rows.first;
});

/// 往期回看(media_items 驱动,管理员维护)
final replayVideosProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('media_items')
      .select('id, title_hant, title_hans, url')
      .eq('kind', 'video')
      .eq('active', true)
      .order('sort_order', ascending: true);
});

/// 从 YouTube URL 提取 videoId
String? youtubeVideoId(String url) {
  final m = RegExp(r'(?:v=|youtu\.be/|/live/)([\w-]{11})').firstMatch(url);
  return m?.group(1);
}
