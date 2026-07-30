import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';

/// 学修问答(PRD §16,设计 docs/design/study-qa.md):
/// RLS 已保证可见性——普通用户只取回自己的线程,管理员取回全部;
/// 客户端不需要也不允许再做权限判断,查询是同一条。

/// 线程列表(按最后消息倒序;profiles 内嵌供管理员视图显示提问人)
final qaThreadsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return Supabase.instance.client
      .from('qa_threads')
      .select('id, user_id, last_sender_role, last_message_at, '
          'first_message_preview, last_message_preview, user_last_read_at, '
          'created_at, profiles(display_name)')
      .order('last_message_at', ascending: false);
});

/// 单线程(会话页头部;null = 已删除或无权限 → 空态「該提問已刪除」)
final qaThreadProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, threadId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return Supabase.instance.client
      .from('qa_threads')
      .select('id, user_id, last_sender_role, user_last_read_at')
      .eq('id', threadId)
      .maybeSingle();
});

/// 线程消息(升序,聊天式渲染)
final qaMessagesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
    (ref, threadId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return Supabase.instance.client
      .from('qa_messages')
      .select('id, sender_id, sender_role, body, created_at')
      .eq('thread_id', threadId)
      .order('created_at', ascending: true);
});

// ---------------------------------------------------------------- 纯逻辑(可单测)

/// 未读红点:管理员已回覆且回覆晚于我的已读位点(设计 §4.2)
bool qaThreadUnread(Map<String, dynamic> t) {
  if (t['last_sender_role'] != 'admin') return false;
  final last = DateTime.tryParse(t['last_message_at'] as String? ?? '');
  final read = DateTime.tryParse(t['user_last_read_at'] as String? ?? '');
  if (last == null || read == null) return false;
  return last.isAfter(read);
}

/// 待回覆 = 最后发言方是用户
bool qaThreadPending(Map<String, dynamic> t) => t['last_sender_role'] == 'user';

/// 发消息用的角色:线程主人以 user 身份发言(管理员自问也算),其余为管理员回复
String qaSenderRole(String threadOwnerId, String myId) =>
    threadOwnerId == myId ? 'user' : 'admin';

/// 学修问答错误文案:待回覆上限(触发器 QA_PENDING_LIMIT)给专属提示,其余走 errText
String qaErrorText(AppLocalizations l10n, Object e) {
  if (e.toString().contains('QA_PENDING_LIMIT')) return l10n.studyQaLimitHit;
  return errText(l10n, e);
}

// ---------------------------------------------------------------- 操作

/// 建线程 + 首问(原子 RPC);返回新线程 id
Future<String> createQaThread(String body) async {
  final res = await Supabase.instance.client
      .rpc('create_qa_thread', params: {'p_body': body.trim()});
  return res as String;
}

/// 发消息(追问 / 管理员回复;冗余列与通知由 DB 触发器维护)
Future<void> sendQaMessage(String threadId, String role, String body) async {
  await Supabase.instance.client.from('qa_messages').insert({
    'thread_id': threadId,
    'sender_id': Supabase.instance.client.auth.currentUser!.id,
    'sender_role': role,
    'body': body.trim(),
  });
}

/// 硬删线程(消息级联;RLS 限本人或管理员)
Future<void> deleteQaThread(String threadId) async {
  await Supabase.instance.client.from('qa_threads').delete().eq('id', threadId);
}

/// 标记已读(RPC 内自校验仅 owner 生效,可放心调用)
Future<void> markQaThreadRead(String threadId) async {
  await Supabase.instance.client
      .rpc('mark_qa_thread_read', params: {'p_thread_id': threadId});
}
