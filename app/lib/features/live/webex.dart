import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/channels.dart';
import '../auth/auth_providers.dart';

/// 统一的 Webex 应用内加入入口(PRD §6):
/// 1. 预请求麦克风/摄像头系统权限(拒绝也继续,网页内可仅收看);
/// 2. 带上 App 显示名 + 账号邮箱,供 WebView 自动填访客表单并加入;
/// 3. 进入应用内 WebView(右上角始终可切 Webex App)。
Future<void> openWebexInApp(
  BuildContext context,
  WidgetRef ref, {
  required String url,
}) async {
  try {
    await [Permission.microphone, Permission.camera].request();
  } catch (_) {
    // 权限框架不可用时照常进入(纯收看不需要)
  }
  // 等个人档案就绪再取显示名(直接 read .value 在档案未加载完时会拿到 null,
  // 导致自动填充静默跳过);超时/出错则退回已缓存值
  String? name;
  try {
    final profile = await ref
        .read(myProfileProvider.future)
        .timeout(const Duration(seconds: 5));
    name = profile?['display_name'] as String?;
  } catch (_) {
    name = ref.read(myProfileProvider).value?['display_name'] as String?;
  }
  final email = Supabase.instance.client.auth.currentUser?.email;
  if (!context.mounted) return;
  context.push(Uri(
    path: '/webview',
    queryParameters: {
      'url': url,
      'title': 'Webex',
      // 右上角"外部打開"用 join 鏈接(可喚起 Webex App,用户定案永久保留)
      'ext': Channels.webexJoinUrl,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (email != null && email.isNotEmpty) 'mail': email,
    },
  ).toString());
}
