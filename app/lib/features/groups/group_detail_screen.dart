import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import 'groups_providers.dart';

/// 群详情:公告、群主区(群 ID 分享/重置、入群审核、成员管理)、成员列表、
/// 退群 / 转让 / 解散(PRD §3.2 群生命周期)。
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  Future<bool> _confirm(BuildContext context, String message) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true), child: Text(l10n.submit)),
            ],
          ),
        ) ==
        true;
  }

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(groupProvider(groupId));
    ref.invalidate(groupMembersProvider(groupId));
    ref.invalidate(pendingApplicationsProvider(groupId));
    ref.invalidate(joinCodeProvider(groupId));
    ref.invalidate(myGroupsProvider);
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action, {
    bool popAfter = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      _invalidateAll(ref);
      if (popAfter && context.mounted) context.go('/groups');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    }
  }

  Future<void> _review(
      BuildContext context, WidgetRef ref, String userId, bool approve) async {
    await _run(context, ref, () async {
      await Supabase.instance.client
          .from('group_members')
          .update(approve
              ? {'status': 'approved', 'approved_at': DateTime.now().toUtc().toIso8601String()}
              : {'status': 'rejected'})
          .eq('group_id', groupId)
          .eq('user_id', userId);
    });
  }

  Future<void> _editAnnouncement(
      BuildContext context, WidgetRef ref, String? current) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: current ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editAnnouncement),
        content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.save)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, ref, () async {
      final text = ctrl.text.trim();
      await Supabase.instance.client
          .from('groups')
          .update({'announcement': text.isEmpty ? null : text}).eq('id', groupId);
    });
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
        actions: [
          group.maybeWhen(
            data: (g) {
              if (g == null) return const SizedBox.shrink();
              final isOwner = g['owner_id'] == user?.id;
              return PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'announcement':
                      await _editAnnouncement(context, ref, g['announcement'] as String?);
                    case 'reset_code':
                      if (await _confirm(context, l10n.confirmResetCode) && context.mounted) {
                        await _run(context, ref, () async {
                          await Supabase.instance.client.rpc('reset_group_join_code',
                              params: {'p_group_id': groupId});
                        });
                      }
                    case 'dissolve':
                      if (await _confirm(context, l10n.confirmDissolve) && context.mounted) {
                        await _run(context, ref, () async {
                          await Supabase.instance.client
                              .rpc('dissolve_group', params: {'p_group_id': groupId});
                        }, popAfter: true);
                      }
                    case 'leave':
                      if (await _confirm(context, l10n.confirmLeave) && context.mounted) {
                        await _run(context, ref, () async {
                          await Supabase.instance.client
                              .from('group_members')
                              .update({'status': 'left'})
                              .eq('group_id', groupId)
                              .eq('user_id', user!.id);
                        }, popAfter: true);
                      }
                  }
                },
                itemBuilder: (context) => [
                  if (isOwner) ...[
                    PopupMenuItem(
                        value: 'announcement', child: Text(l10n.editAnnouncement)),
                    PopupMenuItem(value: 'reset_code', child: Text(l10n.resetJoinCode)),
                    PopupMenuItem(value: 'dissolve', child: Text(l10n.dissolveGroup)),
                  ] else
                    PopupMenuItem(value: 'leave', child: Text(l10n.leaveGroup)),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: group.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.loadFailed)),
        data: (g) {
          if (g == null) return Center(child: Text(l10n.loadFailed));
          final isOwner = g['owner_id'] == user?.id;
          return RefreshIndicator(
            onRefresh: () async => _invalidateAll(ref),
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
                  _PendingSection(
                      groupId: groupId,
                      onReview: (uid, ok) => _review(context, ref, uid, ok)),
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
                          trailing: m['role'] == 'owner'
                              ? Chip(label: Text(l10n.roleOwner))
                              : (isOwner
                                  ? PopupMenuButton<String>(
                                      onSelected: (v) async {
                                        final uid = m['user_id'] as String;
                                        if (v == 'remove') {
                                          if (await _confirm(context, l10n.confirmRemove) &&
                                              context.mounted) {
                                            await _run(context, ref, () async {
                                              await Supabase.instance.client
                                                  .from('group_members')
                                                  .update({'status': 'removed'})
                                                  .eq('group_id', groupId)
                                                  .eq('user_id', uid);
                                            });
                                          }
                                        } else if (v == 'transfer') {
                                          if (await _confirm(context, l10n.confirmTransfer) &&
                                              context.mounted) {
                                            await _run(context, ref, () async {
                                              await Supabase.instance.client.rpc(
                                                  'transfer_group_ownership',
                                                  params: {
                                                    'p_group_id': groupId,
                                                    'p_new_owner': uid,
                                                  });
                                            });
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                            value: 'transfer',
                                            child: Text(l10n.transferOwner)),
                                        PopupMenuItem(
                                            value: 'remove',
                                            child: Text(l10n.removeMember)),
                                      ],
                                    )
                                  : null),
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
