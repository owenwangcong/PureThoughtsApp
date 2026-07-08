import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../l10n/gen/app_localizations.dart';
import '../groups/groups_providers.dart';
import '../logs/logs_providers.dart';
import 'dashboard_providers.dart';

String _fmtNum(Object? n) {
  final d = double.tryParse('$n') ?? 0;
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

/// 快捷报数(PRD §4.2,P1.7):首页展示最近报过的(群 × 功课)组合,
/// 一键弹窗确认(默认上次数量,可改)即完成报数,减少老年用户输入。
class QuickReportSection extends ConsumerWidget {
  const QuickReportSection({super.key});

  Future<void> _quickReport(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
    String typeName,
    String unit,
  ) async {
    final l10n = AppLocalizations.of(context);
    final qty = TextEditingController(text: _fmtNum(item['quantity']));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(typeName),
        content: TextField(
          controller: qty,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: InputDecoration(
            labelText: l10n.quantityTitle,
            suffixText: unitLabel(l10n, unit),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.submitLog)),
        ],
      ),
    );
    final q = double.tryParse(qty.text.trim());
    if (ok != true || q == null || q <= 0 || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.from('practice_logs').insert({
        'group_id': item['group_id'],
        'reporter_id': Supabase.instance.client.auth.currentUser!.id,
        'practice_type_id': item['practice_type_id'],
        'quantity': q,
        'local_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      ref.invalidate(myRecentSelfLogsProvider);
      ref.invalidate(myDailyStatsProvider);
      ref.invalidate(myTotalsProvider);
      ref.invalidate(groupLogsProvider(item['group_id'] as String));
      messenger.showSnackBar(SnackBar(content: Text(l10n.logSubmitted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final recent = ref.watch(myRecentSelfLogsProvider);
    final myGroups = ref.watch(myGroupsProvider);

    return recent.maybeWhen(
      data: (rows) {
        // 去重:每个(群 × 功课)取最近一条,最多 6 个
        final seen = <String>{};
        final items = <Map<String, dynamic>>[];
        for (final r in rows) {
          final key = '${r['group_id']}|${r['practice_type_id']}';
          if (seen.add(key)) items.add(r);
          if (items.length >= 6) break;
        }
        if (items.isEmpty) return const SizedBox.shrink();

        final typeIds =
            items.map((r) => r['practice_type_id'] as String).toSet().toList();
        final names = ref.watch(practiceTypeNamesProvider(typeIds));
        final groupNames = <String, String>{
          for (final m in myGroups.value ?? const [])
            (m['groups'] as Map)['id'] as String: (m['groups'] as Map)['name'] as String,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l10n.quickReport,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in items)
                    Builder(builder: (context) {
                      final t = names.value?[item['practice_type_id']];
                      if (t == null) return const SizedBox.shrink();
                      final typeName = (locale.scriptCode == 'Hans'
                          ? t['name_hans']
                          : t['name_hant']) as String;
                      final unit = t['unit'] as String;
                      return Padding(
                        padding: const EdgeInsets.all(4),
                        child: ActionChip(
                          padding: const EdgeInsets.all(10),
                          label: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(typeName,
                                  style: Theme.of(context).textTheme.titleSmall),
                              Text(
                                '${_fmtNum(item['quantity'])} ${unitLabel(l10n, unit)} · ${groupNames[item['group_id']] ?? ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          onPressed: () =>
                              _quickReport(context, ref, item, typeName, unit),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
