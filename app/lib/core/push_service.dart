import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 推送 token 注册 + 点击深链(PRD §5.1/§5.4 · PLAN P2.1/P2.16):
/// - iOS:MethodChannel `purethoughts/push` → 原生 APNs 注册(不经 FCM,大陆 iOS 可用);
/// - Android:firebase_messaging 取 FCM token(仅海外;大陆机无 Google 服务拿不到 →
///   静默降级并标记 notification_prefs.push_unavailable,依赖 App 内通知中心 + 邮件兜底);
/// - token upsert 进 push_tokens(RLS 仅本人行);登出前 unregister 删本设备 token。
/// 时机:登录态首页首帧调用 register()(幂等,每会话一次)。
///
/// v0.5.21 深链:服务端在报文里带 `route`(APNs 与 aps 同级 / FCM 在 data),
/// 点击通知 → 取 route → 交给 [onRoute]。冷启动时 router 尚未就绪,先存
/// [pendingRoute],由首页首帧消费。改造前点推送只是把 App 拉起到当前页。
class PushService {
  PushService._();

  static final instance = PushService._();
  static const _channel = MethodChannel('purethoughts/push');
  static const _prefsKey = 'push_token';

  /// 前台横幅的本地通知 id 区间。⚠️ 必须避开正念提醒占用的 [900000, 901100)
  /// (reminder_scheduler.dart 的 cancelOurs 只清那段,撞上会被误清或互相覆盖)。
  static const _foregroundIdBase = 800000;

  var _registered = false;

  /// 路由消费回调(由 App 层注入;未注入时落 [pendingRoute])
  void Function(String route)? onRoute;

  /// 冷启动时点通知进来、router 还没准备好 → 暂存,首页首帧取走
  String? pendingRoute;

  Future<void> register() async {
    if (kIsWeb || _registered) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    _registered = true;
    try {
      if (Platform.isIOS) {
        await _registerIos();
      } else if (Platform.isAndroid) {
        await _registerAndroid();
      }
    } catch (e) {
      debugPrint('[push] register failed: $e');
      _registered = false; // 失败不粘住,下次会话再试
    }
  }

  /// 收到一个深链路由:有消费者就直接跳,否则暂存
  void handleRoute(String? route) {
    if (route == null || route.isEmpty) return;
    final cb = onRoute;
    if (cb != null) {
      cb(route);
    } else {
      pendingRoute = route;
    }
  }

  /// 首页首帧调用:消费冷启动期间攒下的路由
  String? takePendingRoute() {
    final r = pendingRoute;
    pendingRoute = null;
    return r;
  }

  Future<void> _registerIos() async {
    // 先挂回调再触发注册,避免 token 回来时无人接
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onToken':
          await _saveToken(call.arguments as String, 'apns');
        case 'onNotificationTap':
          // AppDelegate 的 userNotificationCenter(_:didReceive:) 把 payload 里的
          // route 传上来(前台/后台/冷启动三种场景同一条路径)
          handleRoute(call.arguments as String?);
      }
    });
    final ios = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
    await _channel.invokeMethod('register');
  }

  Future<void> _registerAndroid() async {
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission(); // Android 13+ 运行时权限
    await Firebase.initializeApp(); // 配置来自 google-services.json(原生注入)
    final messaging = FirebaseMessaging.instance;
    messaging.onTokenRefresh.listen((t) => _saveToken(t, 'fcm'));
    // 前台也弹横幅(FCM 前台默认不显示,用本地通知镜像;后台由系统显示,无重复)
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    // 点后台通知进来
    FirebaseMessaging.onMessageOpenedApp
        .listen((m) => handleRoute(m.data['route'] as String?));
    // 冷启动:App 被通知唤醒时的那一条
    final initial = await messaging.getInitialMessage();
    if (initial != null) handleRoute(initial.data['route'] as String?);

    try {
      // 大陆机(无 Google 服务)这里抛异常或返回 null
      final token = await messaging.getToken();
      if (token != null) {
        await _saveToken(token, 'fcm');
        await _setPushUnavailable(false);
      } else {
        await _setPushUnavailable(true);
      }
    } catch (e) {
      debugPrint('[push] fcm token unavailable: $e');
      await _setPushUnavailable(true);
      rethrow; // 交给 register() 的 catch 静默降级
    }
  }

  /// 标记「本账号收不到 FCM 推送」= 需要邮件兜底(PRD §5.1,P2.2 的判据来源)。
  /// 为什么不用 push_tokens.fcm_failed:大陆机根本拿不到 token,那张表里没有该设备的
  /// 行可标记 —— 那个字段生产恒为 false,已在 v0.5.21 标注废弃。
  Future<void> _setPushUnavailable(bool value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('notification_prefs').upsert(
        {'user_id': user.id, 'push_unavailable': value},
        onConflict: 'user_id',
      );
    } catch (e) {
      debugPrint('[push] mark push_unavailable failed: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    try {
      await FlutterLocalNotificationsPlugin().show(
        id: _foregroundIdBase + (message.hashCode.abs() % 1000),
        title: n.title,
        body: n.body,
        payload: message.data['route'] as String?,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'push', '通知', // 频道名会出现在系统设置里,简繁同形
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[push] foreground show failed: $e');
    }
  }

  Future<void> _saveToken(String token, String platform) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    // 注:同设备换账号必经登出(unregister 已删旧行),不会撞他人 token 行的 RLS
    await Supabase.instance.client.from('push_tokens').upsert({
      'token': token,
      'user_id': user.id,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
    (await SharedPreferences.getInstance()).setString(_prefsKey, token);
  }

  /// 登出前调用:删除本设备 token,避免登出后继续收到原账号的推送
  Future<void> unregister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_prefsKey);
      if (token != null) {
        await Supabase.instance.client
            .from('push_tokens')
            .delete()
            .eq('token', token);
        await prefs.remove(_prefsKey);
      }
      _registered = false;
    } catch (_) {} // 网络异常不阻断登出
  }
}
