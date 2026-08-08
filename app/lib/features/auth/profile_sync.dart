import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../notifications/notification_prefs.dart';

/// 登录后把本地偏好同步到 profiles(偏好云端 + 本地双存,PRD §11)。
/// 失败静默(离线等场景),下次登录再同步。
///
/// v0.5.21:补同步 `profiles.timezone` —— 免打扰时段要按用户本地时区判定顺延到几点
/// (此前该列建库以来从未被写入,一直是默认 'UTC')。
/// 报数的统计日期仍由客户端显式传 local_date,不依赖该字段。
Future<void> syncProfileFromPrefs(WidgetRef ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;
  try {
    String? tz;
    try {
      tz = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      tz = null; // 拿不到就不动这一列,服务端保留旧值
    }
    await client.from('profiles').update({
      'locale': ref.read(localeProvider.notifier).dbValue,
      'font_scale': ref.read(fontScaleProvider),
      'region': ref.read(regionProvider),
      if (tz != null && tz.isNotEmpty) 'timezone': tz,
    }).eq('id', user.id);
  } catch (_) {
    // 静默:同步偏好非关键路径
  }
}

/// 老版本的两个佛历开关是纯本地 SharedPreferences(服务端照推,关了也没用)。
/// 首次登录时一次性迁入 notification_prefs.muted_types,之后以云端为准。
/// 只在该用户还没有偏好行时执行,避免覆盖用户在别的设备上的设置。
Future<void> migrateLegacyAlmanacPrefs(WidgetRef ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;
  try {
    final existing = await client
        .from('notification_prefs')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
    if (existing != null) return; // 云端已有偏好,不覆盖

    final muted = legacyAlmanacMuted(
      showFestival: ref.read(almanacFestivalNotifyProvider),
      showZhai: ref.read(almanacZhaiNotifyProvider),
    );
    await client.from('notification_prefs').insert({
      'user_id': user.id,
      'muted_types': muted,
    });
    ref.invalidate(notificationPrefsProvider);
  } catch (_) {
    // 静默:迁移失败下次登录再试,期间按默认值(全部接收)
  }
}
