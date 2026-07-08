import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// P1.1 端到端冒烟:注册 → 自动建 profile(默认繁体)→ 更新偏好 → 登出。
/// 依赖本地栈(npx supabase start,本地默认关闭邮箱确认,注册即得会话);未运行则跳过。
void main() {
  const url = 'http://127.0.0.1:54321';
  const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  Future<bool> stackReachable() async {
    try {
      final socket = await Socket.connect('127.0.0.1', 54321,
          timeout: const Duration(seconds: 2));
      await socket.close();
      return true;
    } on SocketException {
      return false;
    }
  }

  test('邮箱注册 → profile 自动创建 → 偏好同步 → 登出', () async {
    if (!await stackReachable()) {
      markTestSkipped('本地 Supabase 栈未运行,跳过(npx supabase start 后重跑)');
      return;
    }

    // 测试环境无持久化存储,用 implicit 流程(App 内由 supabase_flutter 提供 PKCE 存储)
    final client = SupabaseClient(url, anonKey,
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit));
    addTearDown(() => client.dispose());

    final email = 'smoke_${DateTime.now().millisecondsSinceEpoch}@test.local';
    final res = await client.auth.signUp(email: email, password: 'secret-123456');
    expect(res.session, isNotNull, reason: '本地栈默认关闭邮箱确认,注册应直接得到会话');
    final uid = res.user!.id;

    // handle_new_user 触发器:profile 已建,默认繁体、字号 1.0
    final profile =
        await client.from('profiles').select().eq('id', uid).single();
    expect(profile['locale'], 'zh_Hant');
    expect(profile['display_name'], startsWith('smoke_'));

    // 模拟登录后偏好同步(profile_sync 的数据路径)
    await client.from('profiles').update({
      'locale': 'zh_Hans',
      'font_scale': 1.4,
      'region': 'cn',
    }).eq('id', uid);
    final updated =
        await client.from('profiles').select('locale, region').eq('id', uid).single();
    expect(updated['locale'], 'zh_Hans');
    expect(updated['region'], 'cn');

    await client.auth.signOut();
    expect(client.auth.currentUser, isNull);
  });
}
