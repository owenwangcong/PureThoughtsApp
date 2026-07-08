import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import 'groups_providers.dart';

/// 群详情:公告、群主区(群 ID 分享、入群审核)、成员列表。
/// 退群/移除/转让/解散在 P1.4 加入。
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    String userId,
    bool approve,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .from('group_members')
          .update(approve
              ? {'status': 'approved', 'approved_at': DateTime.now().toUtc().toIso8601String()}
              : {'status': 'rejected'})
          .eq('group_id', groupId)
          .eq('user_id', userId);
      ref.invalidate(pendingApplicationsProvider(groupId));
      ref.invalidate(groupMembersProvider(groupId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final group = ref.watch(groupProvider(groupId));
    final members = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: group.maybeWhen(
          data: (g) => Text(g?['name'] as String? ?? ''),
          orElse: () => const Text(''),
        ),
      ),
      body: group.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.loadFailed)),
        data: (g) {
          if (g == null) return Center(child: Text(l10n.loadFailed));
          final isOwner = g['owner_id'] == user?.id;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupProvider(groupId));
              ref.invalidate(groupMembersProvider(groupId));
              ref.invalidate(pendingApplicationsProvider(groupId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (g['description'] != null) ...[
                  Text(g['description'] as String),
                  const SizedBox(height: 8),
                ],
                if (g['announcement'] != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.announcement,
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(g['announcement'] as String),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (isOwner) ...[
                  _JoinCodeTile(groupId: groupId),
                  _PendingSection(groupId: groupId, onReview: (uid, ok) => _review(context, ref, uid, ok)),
                  const Divider(height: 32),
                ],
                Text(l10n.members, style: Theme.of(context).textTheme.titleMedium),
                members.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text(l10n.loadFailed),
                  data: (list) => Column(
                    children: [
                      for (final m in list)
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(m['display_name'] as String? ?? ''),
                          trailing: m['role'] == 'owner' ? Chip(label: Text(l10n.roleOwner)) : null,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _JoinCodeTile extends ConsumerWidget {
  const _JoinCodeTile({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final code = ref.watch(joinCodeProvider(groupId));
    return code.maybeWhen(
      data: (c) => c == null
          ? const SizedBox.shrink()
          : ListTile(
              leading: const Icon(Icons.key),
              title: Text(l10n.joinCodeLabel),
              subtitle: Text(c, style: const TextStyle(fontSize: 20, letterSpacing: 2)),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: c));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l10n.copied)));
                  }
                },
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _PendingSection extends ConsumerWidget {
  const _PendingSection({required this.groupId, required this.onReview});
  final String groupId;
  final void Function(String userId, bool approve) onReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = ref.watch(pendingApplicationsProvider(groupId));
    return pending.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(l10n.pendingApplications,
                    style: Theme.of(context).textTheme.titleMedium),
                for (final p in list)
                  ListTile(
                    leading: const Icon(Icons.hourglass_top),
                    title: Text(p['apply_message'] as String? ?? ''),
                    subtitle: Text((p['created_at'] as String).substring(0, 10)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.approve,
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => onReview(p['user_id'] as String, true),
                        ),
                        IconButton(
                          tooltip: l10n.reject,
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: () => onReview(p['user_id'] as String, false),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
