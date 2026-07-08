import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// P1.6 端到端冒烟:报数全链路(客户端查询模式与 PostgREST 层验证;
/// 深层 RLS/触发器行为由 pgTAP 覆盖)。依赖本地栈;未运行则跳过。
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

  test('报数 → 修改 → 代报(名字/成员)→ 通知 → 删除', () async {
    if (!await stackReachable()) {
      markTestSkipped('本地 Supabase 栈未运行,跳过(npx supabase start 后重跑)');
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final owner = newClient();
    final member = newClient();
    addTearDown(() {
      owner.dispose();
      member.dispose();
    });

    // 建群 + 入群(复用已验证的流程)
    await owner.auth.signUp(email: 'lowner_$ts@test.local', password: 'secret-123456');
    final gid = (await owner
        .from('groups')
        .insert({'name': '報數測試群 $ts', 'owner_id': owner.auth.currentUser!.id})
        .select('id')
        .single())['id'] as String;
    final code = await owner.rpc('get_group_join_code', params: {'p_group_id': gid});
    await member.auth.signUp(email: 'lmember_$ts@test.local', password: 'secret-123456');
    await member.rpc('join_group', params: {'p_code': code, 'p_message': 'hi'});
    final memberId = member.auth.currentUser!.id;
    await owner
        .from('group_members')
        .update({'status': 'approved'})
        .eq('group_id', gid)
        .eq('user_id', memberId);

    // 可报功课项 = 全局 5 项(or 过滤查询模式)
    final types = await member
        .from('practice_types')
        .select('id, name_hans, unit')
        .eq('active', true)
        .or('group_id.is.null,group_id.eq.$gid');
    expect(types.length, greaterThanOrEqualTo(5));
    final jingangjing = types.firstWhere((t) => t['name_hans'] == '金刚经')['id'] as String;
    final dabeizhou = types.firstWhere((t) => t['name_hans'] == '大悲咒')['id'] as String;

    // 自报(显式 local_date)
    final today = DateTime.now();
    final localDate =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final log = await member
        .from('practice_logs')
        .insert({
          'group_id': gid,
          'reporter_id': memberId,
          'practice_type_id': jingangjing,
          'quantity': 2,
          'local_date': localDate,
        })
        .select('id, unit, local_date')
        .single();
    expect(log['unit'], 'volume', reason: 'unit 由触发器从功课项快照');
    expect(log['local_date'], localDate);

    // 报数人可改数量/备注
    await member
        .from('practice_logs')
        .update({'quantity': 3, 'note': '補記昨日'}).eq('id', log['id'] as String);

    // 自由名字代报 → 名单自动记忆
    await member.from('practice_logs').insert({
      'group_id': gid,
      'reporter_id': memberId,
      'subject_name': '劉奶奶',
      'practice_type_id': dabeizhou,
      'quantity': 108,
      'local_date': localDate,
    });
    final names = await member
        .from('proxy_names')
        .select('name')
        .eq('group_id', gid)
        .order('last_used_at', ascending: false);
    expect([for (final n in names) n['name']], contains('劉奶奶'));

    // 代报群成员(owner)→ owner 收到 App 内通知记录
    await member.from('practice_logs').insert({
      'group_id': gid,
      'reporter_id': memberId,
      'subject_user_id': owner.auth.currentUser!.id,
      'practice_type_id': dabeizhou,
      'quantity': 21,
      'local_date': localDate,
    });
    final notifs = await owner
        .from('notifications')
        .select('type, payload')
        .eq('scope', 'user')
        .eq('target_id', owner.auth.currentUser!.id)
        .eq('type', 'proxy_log');
    expect(notifs.length, 1);

    // 群统计:3 条记录进统计
    final stats = await member
        .from('daily_group_stats')
        .select('entries')
        .eq('group_id', gid);
    expect(
        stats.fold<int>(0, (s, r) => s + (r['entries'] as int)), 3);

    // owner(被代报人)经 RPC 删除自己名下记录 → 统计扣减
    final proxyLog = await owner
        .from('practice_logs')
        .select('id')
        .eq('group_id', gid)
        .eq('subject_user_id', owner.auth.currentUser!.id)
        .single();
    await owner.rpc('delete_practice_log', params: {'p_log_id': proxyLog['id']});
    final stats2 = await member
        .from('daily_group_stats')
        .select('entries')
        .eq('group_id', gid);
    expect(
        stats2.fold<int>(0, (s, r) => s + (r['entries'] as int)), 2);

    // 累计视图(P1.8):个人只见自己的(金刚经 3,不含自由名字/已删),群见全部
    final myTotals = await member
        .from('user_practice_totals')
        .select('practice_type_id, total, entries');
    expect(myTotals.length, 1);
    expect(double.parse('${myTotals.single['total']}'), 3);
    final groupTotals = await member
        .from('group_practice_totals')
        .select('total, entries')
        .eq('group_id', gid);
    expect(groupTotals.fold<int>(0, (s, r) => s + (r['entries'] as int)), 2);

    // 清理:解散测试群
    await owner.rpc('dissolve_group', params: {'p_group_id': gid});
  });
}
