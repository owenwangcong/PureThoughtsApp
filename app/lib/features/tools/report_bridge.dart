import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../community/community_providers.dart';
import '../dashboard/dashboard_providers.dart';
import '../logs/logs_providers.dart';
import '../logs/offline_queue.dart';

/// 工具 → 报数桥(PRD §9):计时/计数结果一键转为报数。
/// v0.6.0 去群化:不再选群,弹窗只选功课(默认给定分类的项),确认即写入。
Future<void> toolResultToLog(
  BuildContext context,
  WidgetRef ref, {
  required double quantity,
  required String preferredCategory, // meditation / buddha_name ...
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.authSignIn)));
    return;
  }
  final groupId = ref.read(communityIdProvider);
  if (groupId == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.loadFailed)));
    return;
  }
  final locale = ref.read(localeProvider);
  // 「可选」清单:全局主清单 + 我自己的自定义项(不能是别人的,设计 Q8)
  final types = (ref.read(reportablePracticeTypesProvider).value ?? const [])
      .toList()
    ..sort((a, b) =>
        (a['sort_order'] as int? ?? 0).compareTo(b['sort_order'] as int? ?? 0));
  if (types.isEmpty) return;

  var typeId = (types.firstWhere(
    (t) => t['category'] == preferredCategory,
    orElse: () => types.first,
  ))['id'] as String;

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.toReport),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: typeId,
              decoration: InputDecoration(labelText: l10n.selectPracticeType),
              items: [
                for (final t in types)
                  DropdownMenuItem(
                    value: t['id'] as String,
                    child: Text((locale.scriptCode == 'Hans'
                        ? t['name_hans']
                        : t['name_hant']) as String),
                  ),
              ],
              onChanged: (v) => setState(() => typeId = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true), child: Text(l10n.submitLog)),
        ],
      ),
    ),
  );
  if (ok != true) return;

  try {
    final result = await submitPracticeLogs(ref, [
      {
        'group_id': groupId,
        'reporter_id': user.id,
        'practice_type_id': typeId,
        'quantity': quantity,
        'local_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      }
    ]);
    if (result == SubmitResult.queued) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.offlineQueued)));
      return;
    }
    ref.invalidate(myRecentSelfLogsProvider);
    ref.invalidate(myDailyStatsProvider);
    ref.invalidate(myTotalsProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.logSubmitted)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
  }
}
