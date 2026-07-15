import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/settings.dart';
import '../../core/units.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../groups/groups_providers.dart';
import '../moderation/moderation_providers.dart';
import '../moderation/report_dialog.dart';
import 'logs_providers.dart';

/// 本群报数记录:成员可见全部(PRD §12.3);
/// 修改(quantity/note)限报数人;删除限报数人 / 被代报人 / 群主(走 RPC 软删)。
class GroupLogsScreen extends ConsumerWidget {
  const GroupLogsScreen({super.key, required this.groupId});

  final String groupId;

  Future<void> _edit(BuildContext context, WidgetRef ref, Map<String, dynamic> log) async {
    final l10n = AppLocalizations.of(context);
    final qty = TextEditingController(text: '${log['quantity']}');
    final note = TextEditingController(text: log['note'] as String? ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.edit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.quantityTitle),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              decoration: InputDecoration(labelText: l10n.noteLabel),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.save)),
        ],
      ),
    );
    final newQty = double.tryParse(qty.text.trim());
    if (ok != true || newQty == null || newQty <= 0 || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.from('practice_logs').update({
        'quantity': newQty,
        'note': note.text.trim().isEmpty ? null : note.text.trim(),
      }).eq('id', log['id'] as String);
      ref.invalidate(groupLogsProvider(groupId));
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String logId) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.confirmDeleteLog),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.submit)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .rpc('delete_practice_log', params: {'p_log_id': logId});
      ref.invalidate(groupLogsProvider(groupId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final user = ref.watch(currentUserProvider);
    final logs = ref.watch(groupLogsProvider(groupId));
    final group = ref.watch(groupProvider(groupId));
    final members = ref.watch(groupMembersProvider(groupId));
    final types = ref.watch(reportablePracticeTypesProvider(groupId));

    final nameOf = <String, String>{
      for (final m in members.value ?? const [])
        m['user_id'] as String: m['display_name'] as String? ?? '',
    };
    final typeOf = <String, Map<String, dynamic>>{
      for (final t in types.value ?? const []) t['id'] as String: t,
    };
    final isOwner = group.value?['owner_id'] == user?.id;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.logsTitle)),
      body: logs.when(
        loading: () => const SkeletonList(),
        error: (_, _) =>
            ErrorRetry(onRetry: () => ref.invalidate(groupLogsProvider(groupId))),
        data: (raw) {
          // 已拉黑用户的报数不展示(PRD §10.2)
          final blocks = ref.watch(myBlocksProvider).value ?? const <String>{};
          final list = raw
              .where((log) =>
                  !blocks.contains(log['reporter_id']) &&
                  !blocks.contains(log['subject_user_id']))
              .toList();
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.emptyList,
              hint: l10n.logsEmptyHint,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(groupLogsProvider(groupId)),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final log = list[i];
                final t = typeOf[log['practice_type_id']];
                final typeName = t == null
                    ? ''
                    : (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant'])
                        as String;
                final subject = (log['subject_name'] as String?) ??
                    nameOf[(log['subject_user_id'] ?? log['reporter_id']) as String?] ??
                    l10n.fellowPractitioner;
                final reporter =
                    nameOf[log['reporter_id'] as String?] ?? l10n.fellowPractitioner;
                final isProxy = log['subject_user_id'] != null || log['subject_name'] != null;
                final qty = log['quantity'];
                final canEdit = log['reporter_id'] == user?.id;
                final canDelete = canEdit ||
                    log['subject_user_id'] == user?.id ||
                    isOwner;

                return ListTile(
                  title: Text(
                      '$subject · $typeName ${_fmtQty(qty)} ${unitLabel(l10n, log['unit'] as String)}'),
                  subtitle: Text([
                    log['local_date'] as String,
                    if (isProxy) '$reporter ${l10n.proxyBy}',
                    if (log['note'] != null) log['note'] as String,
                  ].join(' · ')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _edit(context, ref, log);
                      if (v == 'delete') _delete(context, ref, log['id'] as String);
                      if (v == 'report') {
                        showReportDialog(context,
                            targetType: 'log', targetId: log['id'] as String);
                      }
                    },
                    itemBuilder: (context) => [
                      if (canEdit)
                        PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                      if (canDelete)
                        PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                      if (!canEdit)
                        PopupMenuItem(value: 'report', child: Text(l10n.reportAction)),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static String _fmtQty(Object? qty) {
    final d = double.tryParse('$qty') ?? 0;
    return d == d.roundToDouble() ? '${d.round()}' : '$d';
  }
}
