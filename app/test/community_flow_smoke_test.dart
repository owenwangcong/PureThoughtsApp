import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// P9.2 端到端冒烟(取代原 groups_flow_smoke_test):**去群化后的零门槛入会**。
///
/// 覆盖 PRD v0.6.0 §3.1 与设计 §12.3 的 T-E2E-01 / T-E2E-05:
/// 注册 → 自动入会 → 立刻报数;建群与 join_group 已关闭;
/// 自定义功课项仅创建者可选(别人既选不到、也不能拿去报数)。
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

  test('注册即入会 → 直接报数;建群/入群已关闭;自订功課僅自己可選', () async {
    if (!await stackReachable()) {
      markTestSkipped('本地 Supabase 栈未运行,跳过(npx supabase start 后重跑)');
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final a = newClient(); // 新同修 A
    final b = newClient(); // 新同修 B
    addTearDown(() {
      a.dispose();
      b.dispose();
    });

    // ---- 注册即入会:没有群 ID、没有申请、没有审核 ----
    await a.auth.signUp(email: 'ca_$ts@test.local', password: 'secret-123456');
    await b.auth.signUp(email: 'cb_$ts@test.local', password: 'secret-123456');
    final aId = a.auth.currentUser!.id;
    final bId = b.auth.currentUser!.id;

    final community = await a
        .from('groups')
        .select('id, name')
        .eq('is_default', true)
        .single();
    final gid = community['id'] as String;

    final membership = await a
        .from('group_members')
        .select('status')
        .eq('group_id', gid)
        .eq('user_id', aId)
        .single();
    expect(membership['status'], 'approved',
        reason: '注册触发器已把新用户加入共修体,无需申请与审核');

    // ---- 建群与入群申请已关闭 ----
    await expectLater(
      a.from('groups').insert({'name': '偷偷建群 $ts', 'owner_id': aId}),
      throwsA(isA<PostgrestException>()),
      reason: '建群已关闭(authenticated 无 groups insert 权限)',
    );
    await expectLater(
      a.rpc('join_group', params: {'p_code': 'ANYCODE8', 'p_message': 'hi'}),
      throwsA(isA<PostgrestException>()),
      reason: 'join_group 已停用',
    );

    // ---- 立刻报数 ----
    final today = DateTime.now();
    final localDate =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final globalType = (await a
        .from('practice_types')
        .select('id')
        .isFilter('group_id', null)
        .eq('active', true)
        .limit(1)
        .single())['id'] as String;

    final myLog = await a
        .from('practice_logs')
        .insert({
          'group_id': gid,
          'reporter_id': aId,
          'practice_type_id': globalType,
          'quantity': 3,
          'local_date': localDate,
        })
        .select('id, unit')
        .single();
    expect(myLog['id'], isNotNull, reason: '注册后第一次报数即可成功');

    // B 看得到 A 的记录(共修流水全体可见,PRD §3.2)
    final seenByB =
        await b.from('practice_logs').select('id').eq('id', myLog['id'] as String);
    expect(seenByB.length, 1);

    // ---- 自定义功课项:仅创建者可选(设计 Q8)----
    final customId = (await a
        .from('practice_types')
        .insert({
          'group_id': gid,
          'name_hant': 'A 的自訂功課 $ts',
          'name_hans': 'A 的自定功课 $ts',
          'category': 'other',
          'unit': 'count',
          'is_custom': true,
        })
        .select('id, created_by')
        .single());
    expect(customId['created_by'], aId, reason: 'created_by 由触发器落当前用户');

    // A 的「可选」清单里有,B 的没有
    final aSelectable = await a
        .from('practice_types')
        .select('id')
        .eq('active', true)
        .or('group_id.is.null,created_by.eq.$aId');
    final bSelectable = await b
        .from('practice_types')
        .select('id')
        .eq('active', true)
        .or('group_id.is.null,created_by.eq.$bId');
    expect(aSelectable.any((t) => t['id'] == customId['id']), isTrue);
    expect(bSelectable.any((t) => t['id'] == customId['id']), isFalse);

    // 但名称对 B 可读(否则 A 用它报的记录在共修流水里会是无名条目)
    final readableByB = await b
        .from('practice_types')
        .select('name_hant')
        .eq('id', customId['id'] as String)
        .single();
    expect(readableByB['name_hant'], 'A 的自訂功課 $ts');

    // B 不能拿 A 的自定义项去报数(DB 层拦截,不只是 UI 过滤)
    await expectLater(
      b.from('practice_logs').insert({
        'group_id': gid,
        'reporter_id': bId,
        'practice_type_id': customId['id'],
        'quantity': 1,
        'local_date': localDate,
      }),
      throwsA(isA<PostgrestException>()),
      reason: '不得用他人的自定义功课项报数',
    );
  });
}
