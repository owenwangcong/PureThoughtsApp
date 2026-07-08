import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/gen/app_localizations.dart';
import 'moderation_providers.dart';

/// 管理员举报处置(最简版,PRD §10.2):列表 → 标记已处理 / 封禁用户
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  Future<void> _resolve(WidgetRef ref, String reportId) async {
    await Supabase.instance.client.from('reports').update({
      'status': 'resolved',
      'handled_by': Supabase.instance.client.auth.currentUser!.id,
    }).eq('id', reportId);
    ref.invalidate(openReportsProvider);
  }

  Future<void> _ban(WidgetRef ref, String reportId, String userId) async {
    await Supabase.instance.client
        .from('profiles')
        .update({'banned_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', userId);
    await _resolve(ref, reportId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reports = ref.watch(openReportsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminReports)),
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.loadFailed)),
        data: (list) => list.isEmpty
            ? Center(child: Text(l10n.emptyList))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(openReportsProvider),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(r['reason'] as String),
                      subtitle: Text(
                          '${r['target_type']} · ${(r['created_at'] as String).substring(0, 10)}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'resolve') _resolve(ref, r['id'] as String);
                          if (v == 'ban') {
                            _ban(ref, r['id'] as String, r['target_id'] as String);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                              value: 'resolve', child: Text(l10n.markResolved)),
                          if (r['target_type'] == 'user')
                            PopupMenuItem(value: 'ban', child: Text(l10n.banUser)),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
