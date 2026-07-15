import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_text.dart';
import '../../core/settings.dart';
import '../../core/units.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../dashboard/dashboard_providers.dart';
import '../groups/groups_providers.dart';
import 'vows_providers.dart';

String _fmtNum(Object? n) {
  final d = double.tryParse('$n') ?? 0;
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

/// 我的發願(PRD §4.4):进度条 + 剩余天数;达成显示随喜 + 回向偈;
/// 到期不提示"失败",仅温和显示进度;仅本人可见。
class VowsScreen extends ConsumerStatefulWidget {
  const VowsScreen({super.key});

  @override
  ConsumerState<VowsScreen> createState() => _VowsScreenState();
}

class _VowsScreenState extends ConsumerState<VowsScreen> {
  final _celebrated = <String>{};

  /// 达成检测:进度 ≥ 目标且仍 active → 标记 completed + 随喜弹层(一次)
  Future<void> _maybeComplete(
      Map<String, dynamic> vow, double progress, AppLocalizations l10n) async {
    final id = vow['id'] as String;
    if (vow['status'] != 'active' ||
        progress < (double.tryParse('${vow['target_qty']}') ?? double.infinity) ||
        !_celebrated.add(id)) {
      return;
    }
    await Supabase.instance.client
        .from('vows')
        .update({'status': 'completed'}).eq('id', id);
    ref.invalidate(myVowsProvider);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.spa_outlined, size: 40),
        title: Text(l10n.vowCongrats),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dedicationTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(l10n.dedicationText),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context), child: Text(l10n.done)),
        ],
      ),
    );
  }

  /// 到期检测:静默转 expired(无"失败"文案,PRD §4.4)
  Future<void> _maybeExpire(Map<String, dynamic> vow) async {
    if (vow['status'] != 'active' ||
        vowDaysLeft(vow, DateTime.now()) >= 0) {
      return;
    }
    await Supabase.instance.client
        .from('vows')
        .update({'status': 'expired'}).eq('id', vow['id'] as String);
    ref.invalidate(myVowsProvider);
  }

  Future<void> _createVow() async {
    final l10n = AppLocalizations.of(context);
    final locale = ref.read(localeProvider);
    final types = (ref.read(allPracticeTypesMapProvider).value ?? {})
        .values
        .where((t) => t['active'] == true)
        .toList()
      ..sort((a, b) => (a['sort_order'] as int? ?? 0)
          .compareTo(b['sort_order'] as int? ?? 0));
    final groups = (ref.read(myGroupsProvider).value ?? const [])
        .where((m) => m['status'] == 'approved')
        .map((m) => m['groups'] as Map<String, dynamic>)
        .toList();
    if (types.isEmpty) return;

    String? typeId;
    String? groupId; // null = 全部群
    var days = 49;
    final target = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.createVow),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: typeId,
                  hint: Text(l10n.selectPracticeType),
                  items: [
                    for (final t in types)
                      DropdownMenuItem(
                        value: t['id'] as String,
                        child: Text((locale.scriptCode == 'Hans'
                            ? t['name_hans']
                            : t['name_hant']) as String),
                      ),
                  ],
                  onChanged: (v) => setState(() => typeId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.vowTarget),
                ),
                const SizedBox(height: 12),
                Text(l10n.vowPeriod, style: Theme.of(context).textTheme.labelLarge),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in const [7, 21, 49, 100, 365])
                      ChoiceChip(
                        label: Text('$d ${l10n.daysUnit}'),
                        selected: days == d,
                        onSelected: (_) => setState(() => days = d),
                      ),
                  ],
                ),
                if (groups.length > 1) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: groupId,
                    decoration: InputDecoration(labelText: l10n.vowScope),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.scopeAllGroups)),
                      for (final g in groups)
                        DropdownMenuItem(
                            value: g['id'] as String,
                            child: Text(g['name'] as String)),
                    ],
                    onChanged: (v) => setState(() => groupId = v),
                  ),
                ],
              ],
            ),
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
      ),
    );
    final qty = double.tryParse(target.text.trim());
    if (ok != true || typeId == null || qty == null || qty <= 0 || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final today = DateTime.now();
      await Supabase.instance.client.from('vows').insert({
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'practice_type_id': typeId,
        'group_id': groupId,
        'target_qty': qty,
        'start_date': DateFormat('yyyy-MM-dd').format(today),
        'end_date':
            DateFormat('yyyy-MM-dd').format(today.add(Duration(days: days))),
      });
      ref.invalidate(myVowsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final vows = ref.watch(myVowsProvider);
    final types = ref.watch(allPracticeTypesMapProvider).value ?? const {};

    String nameOf(String id) {
      final t = types[id];
      if (t == null) return '…';
      return (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant']) as String;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vowsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createVow,
        icon: const Icon(Icons.volunteer_activism),
        label: Text(l10n.createVow),
      ),
      body: vows.when(
        loading: () => const SkeletonList(rows: 3, rowHeight: 96),
        error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(myVowsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.volunteer_activism_outlined,
              title: l10n.emptyList,
              hint: l10n.vowsEmptyHint,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myVowsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final vow in list)
                  _VowCard(
                    vow: vow,
                    typeName: nameOf(vow['practice_type_id'] as String),
                    unit: types[vow['practice_type_id']]?['unit'] as String? ?? '',
                    onProgress: (p) {
                      _maybeComplete(vow, p, l10n);
                      _maybeExpire(vow);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VowCard extends ConsumerWidget {
  const _VowCard({
    required this.vow,
    required this.typeName,
    required this.unit,
    required this.onProgress,
  });

  final Map<String, dynamic> vow;
  final String typeName;
  final String unit;
  final void Function(double progress) onProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(vowProgressProvider(vow['id'] as String));
    final target = double.tryParse('${vow['target_qty']}') ?? 1;
    final status = vow['status'] as String;
    final days = vowDaysLeft(vow, DateTime.now());

    return progress.when(
      loading: () => const Card(child: LinearProgressIndicator()),
      error: (_, _) => Card(child: ListTile(title: Text(l10n.loadFailed))),
      data: (p) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onProgress(p));
        final ratio = (p / target).clamp(0.0, 1.0);
        final statusText = switch (status) {
          'completed' => l10n.vowCompleted,
          'expired' => l10n.vowExpired,
          _ => days >= 0 ? l10n.daysLeft(days) : l10n.vowExpired,
        };
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(typeName,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (status == 'completed')
                      const Icon(Icons.spa, color: Colors.green)
                    else
                      Text(statusText,
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: ratio, minHeight: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_fmtNum(p)} / ${_fmtNum(target)} ${unitLabel(l10n, unit)}'
                  '${status == 'completed' ? ' · ${l10n.vowCompleted}' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
