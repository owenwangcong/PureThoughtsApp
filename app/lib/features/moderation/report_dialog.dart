import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../l10n/gen/app_localizations.dart';

/// 通用举报对话框(user / group / log;PRD §10.2 UGC 合规)
Future<void> showReportDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) async {
  final l10n = AppLocalizations.of(context);
  final reason = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.reportAction),
      content: TextField(
        controller: reason,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: l10n.reportReasonLabel),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.submit)),
      ],
    ),
  );
  if (ok != true || reason.text.trim().isEmpty || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await Supabase.instance.client.from('reports').insert({
      'reporter_id': Supabase.instance.client.auth.currentUser!.id,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason.text.trim(),
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.reportSubmitted)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
  }
}
