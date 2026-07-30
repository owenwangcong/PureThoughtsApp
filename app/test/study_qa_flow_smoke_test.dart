import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// P8.2/P8.3 端到端冒烟:学修问答全链路(客户端查询模式与 PostgREST 层验证;
/// 深层 RLS/触发器行为由 pgTAP study_qa.test.sql 覆盖)。依赖本地栈;未运行则跳过。
/// 管理员用 seed 账号 admin@test.local(is_app_admin)。
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

  test('提问 → 隔离 → 管理员回复 → 通知 → 追问 → 上限 → 删除', () async {
    if (!await stackReachable()) {
      markTestSkipped('本地 Supabase 栈未运行,跳过(npx supabase start 后重跑)');
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final asker = newClient();
    final other = newClient();
    final admin = newClient();
    addTearDown(() {
      asker.dispose();
      other.dispose();
      admin.dispose();
    });

    await asker.auth
        .signUp(email: 'sqa_a_$ts@test.local', password: 'secret-123456');
    await other.auth
        .signUp(email: 'sqa_b_$ts@test.local', password: 'secret-123456');
    await admin.auth.signInWithPassword(
        email: 'admin@test.local', password: 'test1234');
    final askerId = asker.auth.currentUser!.id;
    final adminId = admin.auth.currentUser!.id;

    // 提问(原子 RPC)
    final tid = await asker
        .rpc('create_qa_thread', params: {'p_body': '冒煙提問 $ts'}) as String;

    // 列表查询模式(客户端同款):asker 见 1 条,other 完全不可见,管理员可见
    final mine = await asker
        .from('qa_threads')
        .select('id, last_sender_role, first_message_preview, profiles(display_name)')
        .order('last_message_at', ascending: false);
    expect(mine.map((t) => t['id']), contains(tid));
    expect(mine.first['last_sender_role'], 'user');

    final others = await other.from('qa_threads').select('id');
    expect(others.where((t) => t['id'] == tid), isEmpty);
    final otherMsgs =
        await other.from('qa_messages').select('id').eq('thread_id', tid);
    expect(otherMsgs, isEmpty);

    final adminView = await admin
        .from('qa_threads')
        .select('id, profiles(display_name)')
        .eq('id', tid)
        .single();
    expect(adminView['id'], tid);

    // 管理员回复(客户端同款 insert)→ 冗余列翻转 + asker 收到 qa_reply 通知
    await admin.from('qa_messages').insert({
      'thread_id': tid,
      'sender_id': adminId,
      'sender_role': 'admin',
      'body': '冒煙回覆',
    });
    final after = await asker
        .from('qa_threads')
        .select('last_sender_role, last_message_preview, user_last_read_at, last_message_at')
        .eq('id', tid)
        .single();
    expect(after['last_sender_role'], 'admin');
    expect(after['last_message_preview'], '冒煙回覆');
    // 未读:last_message_at > user_last_read_at
    expect(
        DateTime.parse(after['last_message_at'] as String)
            .isAfter(DateTime.parse(after['user_last_read_at'] as String)),
        isTrue);

    final notif = await asker
        .from('notifications')
        .select('type, title, body, payload')
        .eq('type', 'qa_reply')
        .eq('target_id', askerId);
    expect(notif, hasLength(1));
    expect(notif.first['payload']['thread_id'], tid);
    expect((notif.first['title'] as String?) ?? '', isEmpty); // 无正文
    expect(notif.first['body'], isNull);

    // 已读 RPC → 红点消除
    await asker.rpc('mark_qa_thread_read', params: {'p_thread_id': tid});
    final read = await asker
        .from('qa_threads')
        .select('user_last_read_at, last_message_at')
        .eq('id', tid)
        .single();
    expect(
        DateTime.parse(read['user_last_read_at'] as String)
            .isBefore(DateTime.parse(read['last_message_at'] as String)),
        isFalse);

    // 追问 → 管理员收到 qa_question 通知
    await asker.from('qa_messages').insert({
      'thread_id': tid,
      'sender_id': askerId,
      'sender_role': 'user',
      'body': '追問 $ts',
    });
    final adminNotif = await admin
        .from('notifications')
        .select('id')
        .eq('type', 'qa_question')
        .eq('target_id', adminId)
        .filter('payload->>thread_id', 'eq', tid);
    // 首问 + 追问各通知一次(每条用户消息都通知管理员,设计 §3.3)
    expect(adminNotif, hasLength(2));

    // 待回覆上限:当前 1 个待回覆,再建 2 个到 3,第 4 个报 QA_PENDING_LIMIT
    await asker.rpc('create_qa_thread', params: {'p_body': '第二問 $ts'});
    await asker.rpc('create_qa_thread', params: {'p_body': '第三問 $ts'});
    await expectLater(
      asker.rpc('create_qa_thread', params: {'p_body': '第四問 $ts'}),
      throwsA(predicate(
          (e) => e is PostgrestException && e.message.contains('QA_PENDING_LIMIT'))),
    );

    // 删除:本人删第一线程(消息级联);管理员删其余
    await asker.from('qa_threads').delete().eq('id', tid);
    final goneMsgs =
        await admin.from('qa_messages').select('id').eq('thread_id', tid);
    expect(goneMsgs, isEmpty);
    await admin.from('qa_threads').delete().eq('user_id', askerId);
    final left = await asker.from('qa_threads').select('id');
    expect(left, isEmpty);
  });
}
