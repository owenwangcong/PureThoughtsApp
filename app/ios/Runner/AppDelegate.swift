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
}
