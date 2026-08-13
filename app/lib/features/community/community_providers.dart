import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';

/// 共修体(单例)——PRD v0.6.0 §3 去群化后全 App 唯一的报数归属。
///
/// RLS:每个注册用户都是它的 approved 成员,`has_group_relation()` 命中即可读。
/// **不做本地硬编码**:共修体 id 在本地栈与生产不同,一律运行时取。
final communityProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider); // 登录态变化即重取
  if (user == null) return null;
  return Supabase.instance.client
      .from('groups')
      .select('id, name, announcement')
      .eq('is_default', true)
      .maybeSingle();
});

/// 共修体 id;未登录或尚未取到时为 null —— 调用方须处理(报数落库必须有它)。
final communityIdProvider = Provider<String?>(
    (ref) => ref.watch(communityProvider).value?['id'] as String?);

/// 共修公告(无公告时为 null,页面不占位)
final communityAnnouncementProvider = Provider<String?>((ref) {
  final text = ref.watch(communityProvider).value?['announcement'] as String?;
  return (text == null || text.trim().isEmpty) ? null : text;
});

/// 我自己创建的自定义功课项(含已停用的,供「我的自訂功課」区管理)。
///
/// 注意与 `allPracticeTypesMapProvider` 的分工(设计 §5.2 可读 / 可选两层):
/// 本 provider 是「我能管的」;渲染他人记录的功课名仍走全量映射。
final myCustomPracticeTypesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return Supabase.instance.client
      .from('practice_types')
      .select('id, name_hant, name_hans, category, unit, active, sort_order')
      .eq('is_custom', true)
      .eq('created_by', user.id)
      .order('sort_order', ascending: true);
});
