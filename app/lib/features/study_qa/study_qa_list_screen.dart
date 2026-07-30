import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import 'study_qa_providers.dart';

/// 学修问答列表(设计 §4.2/§4.3):
/// 普通用户 =「我的提問」单列表;管理员 = 待回覆/全部两个 tab + 提问人名。
/// RLS 保证两者用同一查询(qaThreadsProvider)。
class StudyQaListScreen extends ConsumerWidget {
  const StudyQaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isAdmin =
        ref.watch(myProfileProvider).value?['is_app_admin'] == true;
    final threads = ref.watch(qaThreadsProvider);

    Widget listOf(List<Map<String, dynamic>> rows) {
      if (rows.isEmpty) {
        return EmptyState(
          icon: Icons.question_answer_outlined,
          title: l10n.studyQaEmpty,
          action: isAdmin
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
              _ThreadTile(thread: rows[i], showAsker: isAdmin),
        ),
      );
    }

    final body = threads.when(
      loading: () => const SkeletonList(),
      error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(qaThreadsProvider)),
      data: (rows) {
        if (!isAdmin) return listOf(rows);
        return TabBarView(children: [
          listOf(rows.where(qaThreadPending).toList()),
          listOf(rows),
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
              ])
            : null,
      ),
      body: body,
    );

    return isAdmin ? DefaultTabController(length: 2, child: scaffold) : scaffold;
  }
}

class _ThreadTile extends ConsumerWidget {
  const _ThreadTile({required this.thread, required this.showAsker});

  final Map<String, dynamic> thread;
  final bool showAsker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pending = qaThreadPending(thread);
    // 未读红点是「提问人视角」的信号,管理员列表用「待回覆」章即可
    final unread = !showAsker && qaThreadUnread(thread);
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
            if (showAsker && asker.isNotEmpty) Text(asker),
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
      onTap: () => context.push('/study-qa/${thread['id']}'),
    );
  }
}
