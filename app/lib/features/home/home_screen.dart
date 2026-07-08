import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';

/// 全局功课项(主清单),匿名即可读(RLS:group_id is null 公开)
class PracticeType {
  const PracticeType({
    required this.id,
    required this.nameHant,
    required this.nameHans,
    required this.unit,
  });

  final String id;
  final String nameHant;
  final String nameHans;
  final String unit;

  factory PracticeType.fromJson(Map<String, dynamic> json) => PracticeType(
        id: json['id'] as String,
        nameHant: json['name_hant'] as String,
        nameHans: json['name_hans'] as String,
        unit: json['unit'] as String,
      );

  String nameFor(Locale locale) => locale.scriptCode == 'Hans' ? nameHans : nameHant;
}

final globalPracticeTypesProvider = FutureProvider<List<PracticeType>>((ref) async {
  final rows = await Supabase.instance.client
      .from('practice_types')
      .select('id, name_hant, name_hans, unit')
      .isFilter('group_id', null)
      .order('sort_order', ascending: true);
  return rows.map(PracticeType.fromJson).toList();
});

/// 骨架期首页:展示全局功课清单,验证「App 启动并匿名读到公开表数据」(PLAN P0.6 验收)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _unitLabel(AppLocalizations l10n, String unit) => switch (unit) {
        'volume' => l10n.unitVolume,
        'recitation' => l10n.unitRecitation,
        'count' => l10n.unitCount,
        'minute' => l10n.unitMinute,
        _ => unit,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final types = ref.watch(globalPracticeTypesProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.practiceListTitle),
        actions: [
          if (user == null)
            TextButton(
              onPressed: () => context.push('/auth'),
              child: Text(l10n.authSignIn),
            ),
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (user != null)
            ListTile(
              leading: const Icon(Icons.groups),
              title: Text(l10n.groupsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/groups'),
            ),
          if (user != null) const Divider(height: 1),
          Expanded(child: _buildPracticeList(context, ref, l10n, locale, types)),
        ],
      ),
    );
  }

  Widget _buildPracticeList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Locale locale,
    AsyncValue<List<PracticeType>> types,
  ) {
    return types.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.loadFailed),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(globalPracticeTypesProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.emptyList))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item.nameFor(locale)),
                    trailing: Text(
                      _unitLabel(l10n, item.unit),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                },
              ),
    );
  }
}
