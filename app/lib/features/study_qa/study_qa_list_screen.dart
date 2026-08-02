import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import 'study_qa_providers.dart';

/// 学修问答列表(设计 §4.2/§4.3/§9):
/// 普通用户 =「我的提問」单列表;
/// 管理员 = 待回覆/全部/我的提問三个 tab(P8.6)——前两个是管理语境
/// (显示提问人名,进会话以管理员身份回复),「我的提問」是提问人语境
/// (未读红点,进会话以提问人身份追问)。
/// RLS 保证同一查询(qaThreadsProvider)。
class StudyQaListScreen extends ConsumerWidget {
  const StudyQaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(myProfileProvider).value;
    final isAdmin = profile?['is_app_admin'] == true;
    final myId = profile?['id'] as String?;
    final threads = ref.watch(qaThreadsProvider);

    Widget listOf(List<Map<String, dynamic>> rows, {required bool adminView}) {
      if (rows.isEmpty) {
        return EmptyState(
          icon: Icons.question_answer_outlined,
          title: l10n.studyQaEmpty,
          action: adminView
              ? null
              : FilledButton.tonal(
                  onPressed: () => context.push('/study-qa/new'),
                  child: Text(l10n.studyQaAsk),
                ),
        );
      }
      return RefreshIndicator(
        onRefresh: () async => ref.invalidate(qaThreadsProvider),
        child: ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) =>
              _ThreadTile(thread: rows[i], adminView: adminView),
        ),
      );
    }

    final body = threads.when(
      loading: () => const SkeletonList(),
      error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(qaThreadsProvider)),
      data: (rows) {
        if (!isAdmin) return listOf(rows, adminView: false);
        return TabBarView(children: [
          listOf(rows.where(qaThreadPending).toList(), adminView: true),
          listOf(rows, adminView: true),
          listOf(rows.where((t) => t['user_id'] == myId).toList(),
              adminView: false),
        ]);
      },
    );

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyQaTitle),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/study-qa/new'),
            icon: const Icon(Icons.add),
            label: Text(l10n.studyQaAsk),
          ),
        ],
        bottom: isAdmin
            ? TabBar(tabs: [
                Tab(text: l10n.studyQaPending),
                Tab(text: l10n.studyQaTabAll),
                Tab(text: l10n.studyQaMine),
              ])
            : null,
      ),
      body: body,
    );

    return isAdmin ? DefaultTabController(length: 3, child: scaffold) : scaffold;
  }
}

class _ThreadTile extends ConsumerWidget {
  const _ThreadTile({required this.thread, required this.adminView});

  final Map<String, dynamic> thread;

  /// 管理语境行:显示提问人名、进会话带 ?as=admin;提问人语境行:未读红点
  final bool adminView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pending = qaThreadPending(thread);
    // 未读红点是「提问人视角」的信号,管理语境用「待回覆」章即可
    final unread = !adminView && qaThreadUnread(thread);
    final asker =
        (thread['profiles'] as Map?)?['display_name'] as String? ?? '';
    final time = (thread['last_message_at'] as String? ?? '')
        .replaceFirst('T', ' ')
        .split('.')
        .first;
    final timeShort = time.length >= 16 ? time.substring(5, 16) : time;

    return ListTile(
      title: Text(
        thread['first_message_preview'] as String? ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: unread ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: pending
                    ? scheme.surfaceContainerHigh
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pending ? l10n.studyQaPending : l10n.studyQaAnswered,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            if (adminView && asker.isNotEmpty) Text(asker),
            Text(timeShort,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
      trailing: unread
          ? Icon(Icons.circle, size: 10, color: scheme.error)
          : const Icon(Icons.chevron_right),
      onTap: () async {
        // 管理语境带 ?as=admin(P8.6);返回后刷新列表(状态章/红点即时更新)
        await context.push(
            '/study-qa/${thread['id']}${adminView ? '?as=admin' : ''}');
        if (context.mounted) ref.invalidate(qaThreadsProvider);
      },
    );
  }
}
