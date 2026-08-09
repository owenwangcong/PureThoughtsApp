// 通知偏好(PRD v0.5.21 §5/§5.2,设计 design/notification-overhaul.md §5,任务 P2.13)
// 免打扰时段 + 分类订阅,存服务端 notification_prefs(跨设备同步)。
//
// 改造前的问题:设置页「佛教節日提醒 / 十齋日提醒」只在客户端过滤列表,服务端照推,
// 用户关了开关仍会收到系统推送。现在开关上云,push-dispatch 在投递前就过滤掉。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_providers.dart';

/// 设置页里的可开关通知类别。一个类别可能对应多个 muted key
/// (如「佛教節日」同时覆盖当天节日与次日预告两种 payload.kind)。
enum NotifyCategory {
  eventReminder,
  eventChanged,
  almanacFestival,
  almanacZhai,
  qaReply,
}

const Map<NotifyCategory, List<String>> notifyCategoryKeys = {
  NotifyCategory.eventReminder: ['event_reminder'],
  NotifyCategory.eventChanged: ['event_changed'],
  // ★重大节日的「明日预告」也归在节日开关下,否则关了还会收到前一天的预告
  NotifyCategory.almanacFestival: ['almanac:festival', 'almanac:festival_eve'],
  NotifyCategory.almanacZhai: ['almanac:zhai'],
  NotifyCategory.qaReply: ['qa_reply'],
};

@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.quietEnabled = true,
    this.quietStart = const TimeOfDay(hour: 22, minute: 0),
    this.quietEnd = const TimeOfDay(hour: 7, minute: 0),
    this.mutedTypes = const [],
    this.pushUnavailable = false,
  });

  final bool quietEnabled;
  final TimeOfDay quietStart;
  final TimeOfDay quietEnd;
  final List<String> mutedTypes;
  final bool pushUnavailable;

  bool enabledFor(NotifyCategory c) =>
      !(notifyCategoryKeys[c] ?? const []).any(mutedTypes.contains);

  /// 打开/关闭一个类别 → 新的 muted 列表
  List<String> toggled(NotifyCategory c, bool on) {
    final keys = notifyCategoryKeys[c] ?? const <String>[];
    final next = [...mutedTypes]..removeWhere(keys.contains);
    if (!on) next.addAll(keys);
    next.sort();
    return next;
  }

  NotificationPrefs copyWith({
    bool? quietEnabled,
    TimeOfDay? quietStart,
    TimeOfDay? quietEnd,
    List<String>? mutedTypes,
    bool? pushUnavailable,
  }) =>
      NotificationPrefs(
        quietEnabled: quietEnabled ?? this.quietEnabled,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        mutedTypes: mutedTypes ?? this.mutedTypes,
        pushUnavailable: pushUnavailable ?? this.pushUnavailable,
      );

  Map<String, dynamic> toRow(String userId) => {
        'user_id': userId,
        'quiet_enabled': quietEnabled,
        'quiet_start': formatDbTime(quietStart),
        'quiet_end': formatDbTime(quietEnd),
        'muted_types': mutedTypes,
      };

  static NotificationPrefs fromRow(Map<String, dynamic>? row) {
    if (row == null) return const NotificationPrefs();
    return NotificationPrefs(
      quietEnabled: row['quiet_enabled'] as bool? ?? true,
      quietStart: parseDbTime(row['quiet_start'] as String?, 22),
      quietEnd: parseDbTime(row['quiet_end'] as String?, 7),
      mutedTypes:
          ((row['muted_types'] as List?) ?? const []).cast<String>().toList(),
      pushUnavailable: row['push_unavailable'] as bool? ?? false,
    );
  }
}

/// Postgres `time` 经 PostgREST 返回形如 "22:00:00"
TimeOfDay parseDbTime(String? v, int fallbackHour) {
  final parts = (v ?? '').split(':');
  if (parts.length < 2) return TimeOfDay(hour: fallbackHour, minute: 0);
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h > 23 || m > 59) {
    return TimeOfDay(hour: fallbackHour, minute: 0);
  }
  return TimeOfDay(hour: h, minute: m);
}

String formatDbTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 一条通知是否被用户静音(不显示、不计红点;服务端同口径不推送)。
/// 匹配裸 type 与「type:kind」两种形式 —— 后者用于同一 type 下的细分开关(佛历)。
bool isNotificationMuted(Map<String, dynamic> n, List<String> muted) {
  if (muted.isEmpty) return false;
  final type = n['type'] as String?;
  if (type == null) return false;
  if (muted.contains(type)) return true;
  final kind = (n['payload'] as Map?)?['kind'];
  return kind != null && muted.contains('$type:$kind');
}

/// 老版本两个本地开关 → muted_types(首次登录时一次性迁移)
List<String> legacyAlmanacMuted({
  required bool showFestival,
  required bool showZhai,
}) =>
    [
      if (!showFestival) ...notifyCategoryKeys[NotifyCategory.almanacFestival]!,
      if (!showZhai) ...notifyCategoryKeys[NotifyCategory.almanacZhai]!,
    ]..sort();

/// 我的通知偏好;未登录用默认值(匿名不推送,偏好也无处存)
final notificationPrefsProvider =
    FutureProvider<NotificationPrefs>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const NotificationPrefs();
  try {
    final row = await Supabase.instance.client
        .from('notification_prefs')
        .select(
            'quiet_enabled, quiet_start, quiet_end, muted_types, push_unavailable')
        .eq('user_id', user.id)
        .maybeSingle();
    return NotificationPrefs.fromRow(row);
  } catch (_) {
    // 取不到偏好时按默认值(全部接收)渲染,而不是让通知中心整个报错 —— 通知中心是
    // 大陆 Android 用户唯一的通道(PRD §5.1),不能因为一个附属查询失败就打不开。
    // 服务端投递侧另有一份同源过滤,不会因此误推。
    return const NotificationPrefs();
  }
});

Future<void> saveNotificationPrefs(
    WidgetRef ref, NotificationPrefs prefs) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  await Supabase.instance.client
      .from('notification_prefs')
      .upsert(prefs.toRow(uid), onConflict: 'user_id');
  ref.invalidate(notificationPrefsProvider);
}
