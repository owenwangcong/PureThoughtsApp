import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';

/// 在线经本条目(匿名可读,管理员维护;PRD §7)
final scripturesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return Supabase.instance.client
      .from('scriptures')
      .select('id, title, web_url')
      .order('sort_order', ascending: true);
});

/// 在線經本(PRD §7):列表 → 应用内 WebView(App 字号透传网页缩放)
class ScripturesScreen extends ConsumerWidget {
  const ScripturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scriptures = ref.watch(scripturesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scripturesTitle)),
      body: scriptures.when(
        loading: () => const SkeletonList(rows: 4),
        error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(scripturesProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.menu_book_outlined, title: l10n.emptyList)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(scripturesProvider),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(s['title'] as String,
                          style: Theme.of(context).textTheme.titleMedium),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(Uri(
                        path: '/webview',
                        queryParameters: {
                          'url': s['web_url'] as String,
                          'title': s['title'] as String,
                          'zoom': '1', // 阅读页透传 App 字号
                        },
                      ).toString()),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
