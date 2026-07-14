import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/prefs.dart';
import '../../core/settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../dashboard/dashboard_providers.dart';
import '../groups/groups_providers.dart';
import '../logs/offline_queue.dart';

/// 工具 → 报数桥(PRD §9):计时/计数结果一键转为报数。
/// 弹窗选群(默认上次报数的群)与功课(默认给定分类的全局项),确认即写入。
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
  final groups = (ref.read(myGroupsProvider).value ?? const [])
      .where((m) => m['status'] == 'approved')
      .map((m) => m['groups'] as Map<String, dynamic>)
      .toList();
  if (groups.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.emptyList)));
    return;
  }
  final locale = ref.read(localeProvider);
  final types = (ref.read(allPracticeTypesMapProvider).value ?? {})
      .values
      .where((t) => t['active'] == true)
      .toList()
    ..sort((a, b) =>
        (a['sort_order'] as int? ?? 0).compareTo(b['sort_order'] as int? ?? 0));
  if (types.isEmpty) return;

  final prefs = ref.read(sharedPrefsProvider);
  final lastGroup = prefs.getString(PrefKeys.lastReportGroup);
  var groupId = groups
          .map((g) => g['id'] as String)
          .contains(lastGroup)
      ? lastGroup!
      : groups.first['id'] as String;
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
            if (groups.length > 1)
              DropdownButtonFormField<String>(
                value: groupId,
                decoration: InputDecoration(labelText: l10n.chooseGroup),
                items: [
                  for (final g in groups)
                    DropdownMenuItem(
                        value: g['id'] as String, child: Text(g['name'] as String)),
                ],
                onChanged: (v) => setState(() => groupId = v!),
              ),
            const SizedBox(height: 8),
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
