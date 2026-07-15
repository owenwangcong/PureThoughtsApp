import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'mindfulness_model.dart';

/// OS 级正念提醒的调度封装(design §4/§10.1)。
///
/// 本质:把"周几×时间窗×间隔"展开成一组**按周重复**的本地通知,一次性注册给系统,
/// 由 OS 到点触发——App 关闭/息屏/重启都照常响(iOS ≤64,安卓无限;design §3)。
///
/// - 非精确闹钟(inexactAllowWhileIdle):免 SCHEDULE_EXACT_ALARM,Play 审核更顺、更省电(design §8)。
/// - 尊重系统静音:渠道 importance=HIGH 但**不**请求越过勿扰(design §1)。
/// - 专属通知 id 区间 [_idBase, _idBase+_reserved),与 P2.1 活动通知隔离(design §11)。
class ReminderScheduler {
  ReminderScheduler._();
  static final ReminderScheduler instance = ReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  var _initialized = false;
  var _tzReady = false;

  /// 本功能保留的通知 id 起点;单周最多 7×144=1008 槽,预留 1100 足够。
  static const int _idBase = 900000;
  static const int _reserved = 1100;
  /// 立即测试用(在保留区间之外,cancel 本功能通知不会误删)
  static const int _testId = _idBase - 1;

  /// main() 启动时调用一次:初始化时区与插件。失败不致命(功能降级但 App 正常)。
  Future<void> init() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      _tzReady = true;
    } catch (e) {
      // 时区拿不到时退回 UTC(触发时刻可能偏移,但不崩溃)
      debugPrint('[reminder] timezone init failed: $e');
    }
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[reminder] plugin init failed: $e');
    }
  }

  /// 申请通知权限(design §7 权限首启)。返回是否已授予。
  /// 安卓 13+ 运行时通知权限;iOS alert+sound。**不**申请精确闹钟(用非精确)。
  Future<bool> requestPermissions() async {
    await init();
    try {
      if (Platform.isAndroid) {
        final impl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await impl?.requestNotificationsPermission();
        return granted ?? true;
      }
      if (Platform.isIOS) {
        final impl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await impl?.requestPermissions(alert: true, sound: true, badge: false);
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('[reminder] requestPermissions failed: $e');
    }
    return false;
  }

  /// 当前通知权限是否开启(设置页顶部"提醒已失效"提示用,design §11)。
  Future<bool> hasPermission() async {
    await init();
    try {
      if (Platform.isAndroid) {
        final impl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return (await impl?.areNotificationsEnabled()) ?? true;
      }
      if (Platform.isIOS) {
        final impl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final s = await impl?.checkPermissions();
        return s?.isEnabled ?? false;
      }
    } catch (e) {
      debugPrint('[reminder] hasPermission failed: $e');
    }
    return false;
  }

  /// 按最新配置全量重排:先清本功能全部通知,再按槽位重新注册(design §11)。
  /// [title]/[body]/[channelName]/[channelDescription] 由调用方传入(已本地化)。
  Future<void> reschedule(
    MindfulnessSchedule s, {
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    await init();
    await cancelOurs();
    if (!s.enabled || !s.isWindowValid) return;

    final slots = expandSlots(s);
    // iOS 系统上限 64:仅注册前 64 槽(设置页已实时警告让用户调整,design §5)
    final toSchedule = (Platform.isIOS && slots.length > MindfulnessSchedule.iosSlotCap)
        ? slots.sublist(0, MindfulnessSchedule.iosSlotCap)
        : slots;

    final details = _detailsFor(s, channelName, channelDescription);

    for (var i = 0; i < toSchedule.length; i++) {
      final slot = toSchedule[i];
      try {
        await _plugin.zonedSchedule(
          id: _idBase + i,
          title: title,
          body: body,
          scheduledDate: _nextInstanceOfWeekdayTime(slot.weekday, slot.hour, slot.minute),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'mindfulness',
        );
      } catch (e) {
        debugPrint('[reminder] schedule slot $i failed: $e');
      }
    }
  }

  /// 立即发一条通知,验证响铃/震动/静音行为(design §7 立即测试)。
  Future<void> showTest(
    MindfulnessSchedule s, {
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    await init();
    try {
      await _plugin.show(
          id: _testId,
          title: title,
          body: body,
          notificationDetails: _detailsFor(s, channelName, channelDescription),
          payload: 'mindfulness');
    } catch (e) {
      debugPrint('[reminder] showTest failed: $e');
    }
  }

  /// 取消本功能全部已注册通知(仅本 id 区间,勿动 P2.1)。
  Future<void> cancelOurs() async {
    await init();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= _idBase && p.id < _idBase + _reserved) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      debugPrint('[reminder] cancelOurs failed: $e');
    }
  }

  // —— 内部 —— //

  NotificationDetails _detailsFor(
      MindfulnessSchedule s, String channelName, String channelDescription) {
    final bell = s.sound == 'bell';
    // 渠道声音/震动在 Android O+ 创建后不可变,故按 (sound,vibrate) 组合用不同渠道 id。
    final channelId = 'mindfulness_${bell ? 'bell' : 'silent'}_${s.vibrate ? 'v' : 'n'}';
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      playSound: bell,
      sound: bell ? const RawResourceAndroidNotificationSound('bell') : null,
      enableVibration: s.vibrate,
    );
    final darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: bell,
      sound: bell ? 'bell.wav' : null,
    );
    return NotificationDetails(android: android, iOS: darwin);
  }

  /// 计算下一个匹配 (weekday, hour:minute) 的本地时刻;配合
  /// matchDateTimeComponents: dayOfWeekAndTime 实现按周重复。
  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final location = _tzReady ? tz.local : tz.UTC;
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
