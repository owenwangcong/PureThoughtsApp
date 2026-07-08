import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// P1.3 端到端冒烟:建群 → 取群 ID → 申请入群 → 群主审核 → 成员可见群与成员名单。
/// 依赖本地栈;未运行则跳过。每次运行用新注册账号,不污染 seed 数据。
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

  test('建群 → 入群申请 → 审核 → 成员可见', () async {
    if (!await stackReachable()) {
      markTestSkipped('本地 Supabase 栈未运行,跳过(npx supabase start 后重跑)');
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final owner = newClient();
    final joiner = newClient();
    addTearDown(() {
      owner.dispose();
      joiner.dispose();
    });

    // 群主注册并建群(AFTER 触发器自动加群主成员 + 生成 join code)
    await owner.auth.signUp(email: 'gowner_$ts@test.local', password: 'secret-123456');
    final group = await owner
        .from('groups')
        .insert({
          'name': '冒煙測試群 $ts',
          'owner_id': owner.auth.currentUser!.id,
        })
        .select('id')
        .single();
    final gid = group['id'] as String;

    // join code 仅群主可经 RPC 取得
    final code =
        await owner.rpc('get_group_join_code', params: {'p_group_id': gid}) as String;
    expect(code.length, 8);

    // 申请者注册并入群申请
    await joiner.auth.signUp(email: 'gjoin_$ts@test.local', password: 'secret-123456');
    final joinedGid = await joiner
        .rpc('join_group', params: {'p_code': code, 'p_message': '請通過'});
    expect(joinedGid, gid);

    // 群主看到待审核申请(含申请说明)并通过
    final pending = await owner
        .from('group_members')
        .select('user_id, apply_message')
        .eq('group_id', gid)
        .eq('status', 'pending');
    expect(pending.length, 1);
    expect(pending.first['apply_message'], '請通過');
    await owner
        .from('group_members')
        .update({'status': 'approved', 'approved_at': DateTime.now().toUtc().toIso8601String()})
        .eq('group_id', gid)
        .eq('user_id', pending.first['user_id'] as String);

    // 成员视角:可见群、可见 2 名成员显示名
    final myGroups = await joiner
        .from('group_members')
        .select('status, groups(name)')
        .eq('user_id', joiner.auth.currentUser!.id);
    expect(myGroups.single['status'], 'approved');
    expect((myGroups.single['groups'] as Map)['name'], '冒煙測試群 $ts');

    final memberNames =
        await joiner.from('group_member_display').select('display_name').eq('group_id', gid);
    expect(memberNames.length, 2);
  });
}
