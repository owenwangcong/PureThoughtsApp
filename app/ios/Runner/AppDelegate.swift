import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// 推送 token 通道(P2.1):Dart 调 register 触发 APNs 注册,原生拿到
  /// device token 后经 onToken 回传(原生直连 APNs、不经 FCM,大陆 iOS 可用)
  private var pushChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 正念提醒本地通知(P2.8):设通知中心委托,保证前台呈现与点按转发给
    // flutter_local_notifications(FlutterAppDelegate 已实现该委托)。
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      pushChannel = FlutterMethodChannel(
        name: "purethoughts/push", binaryMessenger: controller.binaryMessenger)
      pushChannel?.setMethodCallHandler { call, result in
        if call.method == "register" {
          UIApplication.shared.registerForRemoteNotifications()
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    pushChannel?.invokeMethod("onToken", arguments: token)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[push] APNs register failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  /// 前台也展示远程推送横幅(2026-07-19 用户需求:开着 App 也要看到推送)。
  /// 仅拦截 APNs 远程通知;本地通知(正念提醒等)仍走 FlutterAppDelegate → 插件的原路径。
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.trigger is UNPushNotificationTrigger {
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .list, .sound])
      } else {
        completionHandler([.alert, .sound])
      }
    } else {
      super.userNotificationCenter(
        center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }

  /// 点击远程推送 → 把 payload 里的 route 交给 Dart 做深链(P2.16)。
  /// 服务端把 route 放在 aps 同级(push-dispatch 的 sendApns)。
  /// 三种场景同一条路径:前台点横幅、后台点通知、冷启动被通知唤醒。
  /// 冷启动时 Dart 侧可能还没挂上 handler,PushService 会把 route 暂存,首页首帧再消费。
  /// 本地通知(正念提醒等)不带 route,原样交回插件路径。
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.trigger is UNPushNotificationTrigger,
       let route = response.notification.request.content.userInfo["route"] as? String,
       !route.isEmpty {
      pushChannel?.invokeMethod("onNotificationTap", arguments: route)
    }
    super.userNotificationCenter(
      center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
