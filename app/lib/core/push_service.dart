import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 推送 token 注册(PRD §5.1 / PLAN P2.1):
/// - iOS:MethodChannel `purethoughts/push` → 原生 APNs 注册(不经 FCM,大陆 iOS 可用);
/// - Android:firebase_messaging 取 FCM token(仅海外;大陆机无 Google 服务拿不到 →
///   静默跳过,依赖 App 内通知中心 + 邮件兜底,PRD §5.1);
/// - token upsert 进 push_tokens(RLS 仅本人行);登出前 unregister 删本设备 token。
/// 时机:登录态首页首帧调用 register()(幂等,每会话一次)。
class PushService {
  PushService._();

  static final instance = PushService._();
  static const _channel = MethodChannel('purethoughts/push');
  static const _prefsKey = 'push_token';

  var _registered = false;

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

  Future<void> _registerIos() async {
    // 先挂回调再触发注册,避免 token 回来时无人接
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onToken') {
        await _saveToken(call.arguments as String, 'apns');
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
    // 大陆机(无 Google 服务)这里抛异常或返回 null → 上层 catch 静默降级
    final token = await messaging.getToken();
    if (token != null) await _saveToken(token, 'fcm');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    try {
      await FlutterLocalNotificationsPlugin().show(
        id: message.hashCode,
        title: n.title,
        body: n.body,
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
