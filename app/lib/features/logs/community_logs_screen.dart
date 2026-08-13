import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/settings.dart';
import '../../core/units.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../dashboard/dashboard_providers.dart';
import '../moderation/moderation_providers.dart';
import '../moderation/report_dialog.dart';
import 'batch_utils.dart';
import 'logs_providers.dart';

/// 共修报数记录(PRD v0.6.0 §3.2):全体注册用户可见的流水,随喜而非排名。
/// 修改(quantity/note)限报数人;删除限报数人 / 被代报人 / App 管理员(走 RPC 软删)。
class CommunityLogsScreen extends ConsumerWidget {
  const CommunityLogsScreen({super.key});

  Future<void> _edit(
      BuildContext context, WidgetRef ref, Map<String, dynamic> log) async {
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save)),
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
      ref.invalidate(communityLogsProvider);
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.submit)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .rpc('delete_practice_log', params: {'p_log_id': logId});
      ref.invalidate(communityLogsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    }
  }

  /// 拉黑发布者(去群化后成员列表没了,拉黑入口移到记录条目;PRD §10.2)
  Future<void> _block(BuildContext context, WidgetRef ref, String userId) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.blockUser),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.submit)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await toggleBlock(userId, true);
      ref.invalidate(myBlocksProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final user = ref.watch(currentUserProvider);
    final logs = ref.watch(communityLogsProvider);
    final names = ref.watch(logDisplayNamesProvider).value ?? const {};
    // 名称映射必须用**不过滤**的全量表:他人的自定义功课项也要能显示名字,
    // 否则那条记录会变成无名条目(设计 §5.2 可读 / 可选两层)。
    final types = ref.watch(allPracticeTypesMapProvider).value ?? const {};
    final isAdmin =
        ref.watch(myProfileProvider).value?['is_app_admin'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityLogs)),
      body: logs.when(
        loading: () => const SkeletonList(),
        error: (_, _) =>
            ErrorRetry(onRetry: () => ref.invalidate(communityLogsProvider)),
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
          // 同一次提交的多条报数分组为一张卡片一起显示(PRD v0.5.10)
          final batches = groupByBatch(list.cast<Map<String, dynamic>>());
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(communityLogsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: batches.length,
              itemBuilder: (context, i) {
                final batch = batches[i];
                final head = batch.first;
                final reporterId = head['reporter_id'] as String?;
                final subject = (head['subject_name'] as String?) ??
                    names[(head['subject_user_id'] ?? reporterId) as String?] ??
                    l10n.fellowPractitioner;
                final reporter =
                    names[reporterId] ?? l10n.fellowPractitioner;
                final isProxy =
                    head['subject_user_id'] != null || head['subject_name'] != null;
                final note = head['note'] as String?;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 批次头:对象 · 日期 ·(代报人)·(备注)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subject,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              [
                                head['local_date'] as String,
                                if (isProxy) '$reporter ${l10n.proxyBy}',
                                ?note,
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      // 批内每条功课:名称 · 数量单位 + 独立菜单(改/删/举报/拉黑按 log 生效)
                      for (final log in batch)
                        _LogItemRow(
                          typeName: types[log['practice_type_id']] == null
                              ? ''
                              : (locale.scriptCode == 'Hans'
                                      ? types[log['practice_type_id']]!['name_hans']
                                      : types[log['practice_type_id']]!['name_hant'])
                                  as String,
                          qty: _fmtQty(log['quantity']),
                          unit: unitLabel(l10n, log['unit'] as String),
                          canEdit: log['reporter_id'] == user?.id,
                          canDelete: log['reporter_id'] == user?.id ||
                              log['subject_user_id'] == user?.id ||
                              isAdmin,
                          onEdit: () => _edit(context, ref, log),
                          onDelete: () => _delete(context, ref, log['id'] as String),
                          onReport: () => showReportDialog(context,
                              targetType: 'log', targetId: log['id'] as String),
                          onBlock: reporterId == null || reporterId == user?.id
                              ? null
                              : () => _block(context, ref, reporterId),
                        ),
                      const SizedBox(height: 6),
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

/// 批次卡片内的单条功课行:名称 + 数量单位 + 独立操作菜单。
class _LogItemRow extends StatelessWidget {
  const _LogItemRow({
    required this.typeName,
    required this.qty,
    required this.unit,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
    required this.onBlock,
  });

  final String typeName;
  final String qty;
  final String unit;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  /// 为空表示不显示「封鎖此人」(自己的记录 / 已注销用户)
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: Text('$typeName · $qty $unit',
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
              if (v == 'report') onReport();
              if (v == 'block') onBlock?.call();
            },
            itemBuilder: (context) => [
              if (canEdit) PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
              if (canDelete) PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              if (!canEdit) PopupMenuItem(value: 'report', child: Text(l10n.reportAction)),
              if (!canEdit && onBlock != null)
                PopupMenuItem(value: 'block', child: Text(l10n.blockUser)),
            ],
          ),
        ],
      ),
    );
  }
}
