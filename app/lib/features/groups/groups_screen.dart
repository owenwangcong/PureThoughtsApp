import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import 'groups_providers.dart';

/// 我的群列表 + 建群 / 申请入群
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createGroup),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: l10n.groupName),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: desc,
              decoration: InputDecoration(labelText: l10n.groupDescription),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.submit)),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final row = await Supabase.instance.client
          .from('groups')
          .insert({
            'name': name.text.trim(),
            'description': desc.text.trim().isEmpty ? null : desc.text.trim(),
            'owner_id': Supabase.instance.client.auth.currentUser!.id,
          })
          .select('id')
          .single();
      ref.invalidate(myGroupsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.groupCreated)));
      if (context.mounted) context.push('/groups/${row['id']}');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    }
  }

  Future<void> _joinGroup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final code = TextEditingController();
    final message = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.joinGroup),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l10n.joinCodeLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: message,
              decoration: InputDecoration(labelText: l10n.applyMessageLabel),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.submit)),
        ],
      ),
    );
    if (ok != true || code.text.trim().isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.rpc('join_group', params: {
        'p_code': code.text.trim().toUpperCase(),
        'p_message': message.text.trim(),
      });
      ref.invalidate(myGroupsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.joinRequested)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final groups = ref.watch(myGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupsTitle)),
      body: groups.when(
        loading: () => const SkeletonList(),
        error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(myGroupsProvider)),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myGroupsProvider),
          child: items.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 48),
                  EmptyState(
                    icon: Icons.groups_outlined,
                    title: l10n.emptyList,
                    hint: l10n.groupsEmptyHint,
                  ),
                ])
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final m = items[i];
                    final g = m['groups'] as Map<String, dynamic>;
                    final pending = m['status'] == 'pending';
                    final owner = m['role'] == 'owner';
                    return ListTile(
                      title: Text(g['name'] as String),
                      subtitle: g['description'] != null ? Text(g['description'] as String) : null,
                      trailing: pending
                          ? Chip(label: Text(l10n.statusPending))
                          : owner
                              ? Chip(label: Text(l10n.roleOwner))
                              : const Icon(Icons.chevron_right),
                      onTap: pending ? null : () => context.push('/groups/${g['id']}'),
                    );
                  },
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _joinGroup(context, ref),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: Text(l10n.joinGroup),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _createGroup(context, ref),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: Text(l10n.createGroup),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
