import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// P1.9 端到端冒烟:举报 / 拉黑 / 账号删除(Edge Function)。
/// 依赖本地栈(supabase start 自带 edge runtime 服务 functions);未运行则跳过。
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

  SupabaseClient newClient() => SupabaseClient(url, anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit));

  test('举报 + 拉黑 + 删号(匿名化保留群总量)', () async {
    if (!await stackReachable()) {
      markTestSkipped('本地 Supabase 栈未运行,跳过(npx supabase start 后重跑)');
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final a = newClient(); // 将删号的用户
    final b = newClient(); // 举报/拉黑的用户
    addTearDown(() {
      a.dispose();
      b.dispose();
    });

    await a.auth.signUp(email: 'del_$ts@test.local', password: 'secret-123456');
    await b.auth.signUp(email: 'mod_$ts@test.local', password: 'secret-123456');
    final aId = a.auth.currentUser!.id;
    final bId = b.auth.currentUser!.id;

    // ---- 举报:B 举报 A,只能看到自己提交的 ----
    await b.from('reports').insert({
      'reporter_id': bId,
      'target_type': 'user',
      'target_id': aId,
      'reason': '測試檢舉',
    });
    final mine = await b.from('reports').select('id, status');
    expect(mine.length, 1);
    expect(mine.single['status'], 'open');
    final othersView = await a.from('reports').select('id');
    expect(othersView, isEmpty, reason: '非管理员看不到别人提交的举报');

    // ---- 拉黑:B 拉黑 A,再取消 ----
    await b.from('user_blocks').insert({'user_id': bId, 'blocked_user_id': aId});
    expect((await b.from('user_blocks').select()).length, 1);
    await b.from('user_blocks').delete().eq('user_id', bId).eq('blocked_user_id', aId);
    expect(await b.from('user_blocks').select(), isEmpty);

    // ---- 删号被拒:A 建群成为群主 ----
    final gid = (await a
        .from('groups')
        .insert({'name': '刪號測試群 $ts', 'owner_id': aId})
        .select('id')
        .single())['id'] as String;
    try {
      await a.functions.invoke('delete-account');
      fail('群主删号应被拒绝');
    } on FunctionException catch (e) {
      expect(e.status, 409);
    }

    // ---- 解散后删号成功;登录失效 ----
    await a.rpc('dissolve_group', params: {'p_group_id': gid});
    final res = await a.functions.invoke('delete-account');
    expect((res.data as Map)['ok'], true);

    await expectLater(
      newClient().auth.signInWithPassword(
          email: 'del_$ts@test.local', password: 'secret-123456'),
      throwsA(isA<AuthException>()),
      reason: '删号后无法再登录',
    );
  });
}
