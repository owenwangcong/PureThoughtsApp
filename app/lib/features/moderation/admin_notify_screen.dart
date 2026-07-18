import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../notifications/notifications_providers.dart';

/// 管理员发布的通用通知(近 30 条,含未发送的排程行;PRD v0.5.16 §5.3)
final adminGeneralNotificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('notifications')
      .select('id, title, body, scheduled_at, sent_at, created_at')
      .eq('type', 'general')
      .eq('scope', 'all')
      .order('created_at', ascending: false)
      .limit(30);
});

/// 拆分为「已排程(未发送)」与「近期已发送」(纯函数,便于单测)
({List<Map<String, dynamic>> pending, List<Map<String, dynamic>> sent})
    splitAdminNotifications(List<Map<String, dynamic>> rows, DateTime now) {
  final pending = <Map<String, dynamic>>[];
  final sent = <Map<String, dynamic>>[];
  for (final r in rows) {
    final scheduled = r['scheduled_at'] as String?;
    final isPending = r['sent_at'] == null &&
        scheduled != null &&
        DateTime.parse(scheduled).isAfter(now.toUtc());
    (isPending ? pending : sent).add(r);
  }
  return (pending: pending, sent: sent);
}

/// 發布通知(PRD v0.5.16 §5.3,设计 admin-notifications.md):
/// 标题+内容+定时;预览确认后经 RPC 发布;下方管理已排程(取消)与已发送(撤回)。
class AdminNotifyScreen extends ConsumerStatefulWidget {
  const AdminNotifyScreen({super.key});

  @override
  ConsumerState<AdminNotifyScreen> createState() => _AdminNotifyScreenState();
}

class _AdminNotifyScreenState extends ConsumerState<AdminNotifyScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  var _schedule = false;
  DateTime? _when; // 设备本地时间
  var _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final init = _when ?? now.add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(init));
    if (t == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final title = _title.text.trim();
    if (title.isEmpty) return;
    if (_schedule && _when == null) {
      await _pickWhen();
      if (_when == null) return;
    }
    if (!mounted) return;

    final whenText = _schedule && _when != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(_when!)
        : l10n.sendNow;
    // 预览确认:全员通知,误发代价高
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmPublishTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (_body.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_body.text.trim()),
            ],
            const SizedBox(height: 12),
            Text('${l10n.confirmPublishAll} · $whenText',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
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
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.rpc('admin_publish_notification', params: {
        'p_title': title,
        'p_body': _body.text.trim().isEmpty ? null : _body.text.trim(),
        'p_scheduled_at':
            _schedule ? _when!.toUtc().toIso8601String() : null,
      });
      messenger.showSnackBar(SnackBar(
          content: Text(_schedule ? l10n.scheduledOk : l10n.publishedOk)));
      _title.clear();
      _body.clear();
      setState(() {
        _schedule = false;
        _when = null;
      });
      ref.invalidate(adminGeneralNotificationsProvider);
      ref.invalidate(myNotificationsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> row, {required bool sent}) async {
    final l10n = AppLocalizations.of(context);
    if (sent) {
      // 撤回已发:说明推送收不回
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.recallAction),
          content: Text(l10n.recallWarn),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel)),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.recallAction)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.rpc('admin_cancel_notification',
          params: {'p_id': row['id']});
      ref.invalidate(adminGeneralNotificationsProvider);
      ref.invalidate(myNotificationsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final listAsync = ref.watch(adminGeneralNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.publishNotify)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminGeneralNotificationsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: l10n.titleLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.contentLabel),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.scheduleSend),
              value: _schedule,
              onChanged: (v) => setState(() => _schedule = v),
            ),
            if (_schedule)
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(_when == null
                    ? l10n.sendTimeLabel
                    : '${l10n.sendTimeLabel}:'
                        '${DateFormat('yyyy-MM-dd HH:mm').format(_when!)}'),
                onPressed: _pickWhen,
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(l10n.publishNotify),
            ),

            // ---- 已排程 / 近期已发送 ----
            listAsync.when(
              // SkeletonList 本身是 ListView,嵌套在外层 ListView 里须给定高
              loading: () => const SizedBox(
                  height: 200, child: SkeletonList(rows: 3)),
              error: (_, _) => ErrorRetry(
                  onRetry: () =>
                      ref.invalidate(adminGeneralNotificationsProvider)),
              data: (rows) {
                final split = splitAdminNotifications(rows, DateTime.now());
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (split.pending.isNotEmpty) ...[
                      SectionHeader(l10n.pendingScheduled,
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 4)),
                      for (final r in split.pending)
                        _tile(context, r,
                            action: l10n.cancelSchedule,
                            onAction: () => _cancel(r, sent: false)),
                    ],
                    if (split.sent.isNotEmpty) ...[
                      SectionHeader(l10n.sentRecentTitle,
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 4)),
                      for (final r in split.sent)
                        _tile(context, r,
                            action: l10n.recallAction,
                            onAction: () => _cancel(r, sent: true)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> r,
      {required String action, required VoidCallback onAction}) {
    final scheduled = r['scheduled_at'] as String?;
    final timeText = DateFormat('MM-dd HH:mm').format(
        DateTime.parse((scheduled ?? r['created_at']) as String).toLocal());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(r['title'] as String? ?? ''),
      subtitle: Text(
        [timeText, if ((r['body'] as String?)?.isNotEmpty == true) r['body']]
            .join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: TextButton(onPressed: onAction, child: Text(action)),
    );
  }
}
