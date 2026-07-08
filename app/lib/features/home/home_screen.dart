import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../../core/units.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';

/// 全局功课项(主清单),匿名即可读(RLS:group_id is null 公开)
class PracticeType {
  const PracticeType({
    required this.id,
    required this.nameHant,
    required this.nameHans,
    required this.category,
    required this.unit,
  });

  final String id;
  final String nameHant;
  final String nameHans;
  final String category;
  final String unit;

  factory PracticeType.fromJson(Map<String, dynamic> json) => PracticeType(
        id: json['id'] as String,
        nameHant: json['name_hant'] as String,
        nameHans: json['name_hans'] as String,
        category: json['category'] as String,
        unit: json['unit'] as String,
      );

  String nameFor(Locale locale) => locale.scriptCode == 'Hans' ? nameHans : nameHant;
}

final globalPracticeTypesProvider = FutureProvider<List<PracticeType>>((ref) async {
  final rows = await Supabase.instance.client
      .from('practice_types')
      .select('id, name_hant, name_hans, category, unit')
      .isFilter('group_id', null)
      .order('sort_order', ascending: true);
  return rows.map(PracticeType.fromJson).toList();
});

/// 骨架期首页:展示全局功课清单,验证「App 启动并匿名读到公开表数据」(PLAN P0.6 验收)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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
            // 按分类分组:經/咒/懺/念佛/靜坐(PRD v0.5.2)
            : ListView(
                children: [
                  for (final cat in practiceCategories)
                    if (items.any((t) => t.category == cat)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          categoryLabel(l10n, cat),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      for (final item in items.where((t) => t.category == cat))
                        ListTile(
                          dense: true,
                          title: Text(item.nameFor(locale)),
                          trailing: Text(
                            unitLabel(l10n, item.unit),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                    ],
                ],
              ),
    );
  }
}
