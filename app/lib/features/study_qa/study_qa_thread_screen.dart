import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import 'study_qa_providers.dart';

/// 学修问答会话页(设计 §4.2):聊天气泡流 + 底部输入框 + 删除。
/// 本人消息右侧主色;对方左侧,管理员统一署名「管理員」(不暴露具体身份)。
/// 线程查无(已删/无权限)→ 空态「該提問已刪除」。
class StudyQaThreadScreen extends ConsumerStatefulWidget {
  const StudyQaThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<StudyQaThreadScreen> createState() => _StudyQaThreadScreenState();
}

class _StudyQaThreadScreenState extends ConsumerState<StudyQaThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _sending = false;
  var _markedRead = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(Map<String, dynamic> thread) async {
    final l10n = AppLocalizations.of(context);
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final myId = ref.read(currentUserProvider)!.id;
      await sendQaMessage(widget.threadId,
          qaSenderRole(thread['user_id'] as String, myId), text);
      _input.clear();
      ref.invalidate(qaMessagesProvider(widget.threadId));
      ref.invalidate(qaThreadsProvider);
    } catch (e) {
      // 发送失败:文字保留在输入框(设计 §3.4,不做离线暂存)
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(qaErrorText(l10n, e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.studyQaDelete),
        content: Text(l10n.studyQaDeleteConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.studyQaDelete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final l10n2 = AppLocalizations.of(context);
    try {
      await deleteQaThread(widget.threadId);
      ref.invalidate(qaThreadsProvider);
      if (mounted && context.canPop()) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(qaErrorText(l10n2, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final thread = ref.watch(qaThreadProvider(widget.threadId));
    final messages = ref.watch(qaMessagesProvider(widget.threadId));
    final myId = ref.watch(currentUserProvider)?.id;

    // 进入即标已读(RPC 仅 owner 生效;线程数据到位后一次)
    final t = thread.value;
    if (t != null && !_markedRead && myId != null && t['user_id'] == myId) {
      _markedRead = true;
      Future.microtask(() async {
        await markQaThreadRead(widget.threadId);
        ref.invalidate(qaThreadsProvider);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyQaTitle),
        actions: [
          if (t != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _delete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.studyQaDelete),
                ),
              ],
            ),
        ],
      ),
      body: thread.when(
        loading: () => const SkeletonList(),
        error: (_, _) => ErrorRetry(
            onRetry: () => ref.invalidate(qaThreadProvider(widget.threadId))),
        data: (t) {
          if (t == null) {
            // 已删除的旧通知深链落点(设计 §3.4)
            return EmptyState(
              icon: Icons.delete_outline,
              title: l10n.studyQaDeleted,
              action: context.canPop()
                  ? FilledButton.tonal(
                      onPressed: () => context.pop(),
                      child: Text(l10n.back))
                  : null,
            );
          }
          return Column(
            children: [
              Expanded(
                child: messages.when(
                  loading: () => const SkeletonList(),
                  error: (_, _) => ErrorRetry(
                      onRetry: () =>
                          ref.invalidate(qaMessagesProvider(widget.threadId))),
                  data: (rows) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(qaMessagesProvider(widget.threadId));
                      ref.invalidate(qaThreadProvider(widget.threadId));
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => _Bubble(
                        message: rows[rows.length - 1 - i],
                        myId: myId,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 2000,
                          // 不常驻占位计数行,接近上限才显示
                          buildCounter: (context,
                                  {required currentLength,
                                  required isFocused,
                                  maxLength}) =>
                              currentLength > 1800
                                  ? Text('$currentLength/$maxLength')
                                  : null,
                          decoration: InputDecoration(
                            hintText: l10n.studyQaNewHint,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: l10n.studyQaSend,
                        onPressed: _sending ? null : () => _send(t),
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.myId});

  final Map<String, dynamic> message;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mine = message['sender_id'] == myId;
    final isAdminMsg = message['sender_role'] == 'admin';
    final time = (message['created_at'] as String? ?? '')
        .replaceFirst('T', ' ')
        .split('.')
        .first;
    final timeShort = time.length >= 16 ? time.substring(5, 16) : time;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 2),
            bottomRight: Radius.circular(mine ? 2 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // 对方是管理员时统一署名「管理員」;本人消息不署名
            if (!mine && isAdminMsg)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  l10n.studyQaAdminLabel,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.primary),
                ),
              ),
            Text(message['body'] as String? ?? ''),
            const SizedBox(height: 2),
            Text(
              timeShort,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
