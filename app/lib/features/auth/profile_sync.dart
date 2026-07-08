import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';

/// 登录后把本地偏好同步到 profiles(偏好云端 + 本地双存,PRD §11)。
/// 失败静默(离线等场景),下次登录再同步。
/// 注:profiles.timezone 暂不同步(推送免打扰在 P2 才用到);
/// 报数的统计日期由客户端显式传 local_date,不依赖该字段。
Future<void> syncProfileFromPrefs(WidgetRef ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;
  try {
    await client.from('profiles').update({
      'locale': ref.read(localeProvider.notifier).dbValue,
      'font_scale': ref.read(fontScaleProvider),
      'region': ref.read(regionProvider),
    }).eq('id', user.id);
  } catch (_) {
    // 静默:同步偏好非关键路径
  }
}
