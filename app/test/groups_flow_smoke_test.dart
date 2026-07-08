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

    // ---- 通知中心(P2.3):公告更新 → 成员收到群通知 → 标记已读 ----
    await owner
        .from('groups')
        .update({'announcement': '週六共修 19:30'}).eq('id', gid);
    final notifs = await joiner
        .from('notifications')
        .select('id, type, payload, notification_reads(read_at)')
        .eq('type', 'announcement')
        .eq('target_id', gid);
    expect(notifs.length, 1);
    expect((notifs.single['notification_reads'] as List), isEmpty,
        reason: '初始未读');
    await joiner.from('notification_reads').upsert([
      {
        'notification_id': notifs.single['id'],
        'user_id': joiner.auth.currentUser!.id,
      }
    ], onConflict: 'notification_id,user_id', ignoreDuplicates: true);
    final read = await joiner
        .from('notifications')
        .select('id, notification_reads(read_at)')
        .eq('id', notifs.single['id'] as String)
        .single();
    expect((read['notification_reads'] as List), isNotEmpty, reason: '已读生效');

    // ---- 功课项(P1.5):成员可加自定义项;群主可停用 ----
    final custom = await joiner
        .from('practice_types')
        .insert({
          'group_id': gid,
          'name_hant': '楞嚴咒',
          'name_hans': '楞严咒',
          'unit': 'recitation',
          'is_custom': true,
        })
        .select('id, active')
        .single();
    expect(custom['active'], true);
    await owner
        .from('practice_types')
        .update({'active': false}).eq('id', custom['id'] as String);
    final disabled = await joiner
        .from('practice_types')
        .select('active')
        .eq('id', custom['id'] as String)
        .single();
    expect(disabled['active'], false, reason: '群主可停用自定义功课项');

    // ---- 生命周期(P1.4):转让 → 新群主重置码 → 原群主退群 → 解散 ----
    await owner.rpc('transfer_group_ownership',
        params: {'p_group_id': gid, 'p_new_owner': joiner.auth.currentUser!.id});
    final newCode =
        await joiner.rpc('reset_group_join_code', params: {'p_group_id': gid}) as String;
    expect(newCode.length, 8);
    expect(newCode, isNot(code));

    // 原群主已是普通成员,可退群
    await owner
        .from('group_members')
        .update({'status': 'left'})
        .eq('group_id', gid)
        .eq('user_id', owner.auth.currentUser!.id);

    // 新群主解散;群对成员不可见(顺便清理本次测试数据)
    await joiner.rpc('dissolve_group', params: {'p_group_id': gid});
    final gone = await joiner.from('groups').select('id').eq('id', gid);
    expect(gone, isEmpty);
  });
}
