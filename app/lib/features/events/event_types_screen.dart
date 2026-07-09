import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import 'event_icons.dart';
import 'events_providers.dart';

/// 事件類型管理(管理员;PRD v0.5.7 §5):
/// 名称简繁 + 预置图标 + 启用状态;被活动引用的类型不可删(FK),提示改为停用。
class EventTypesScreen extends ConsumerWidget {
  const EventTypesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) async {
    final l10n = AppLocalizations.of(context);
    final hant = TextEditingController(text: existing?['name_hant'] as String? ?? '');
    final hans = TextEditingController(text: existing?['name_hans'] as String? ?? '');
    var icon = existing?['icon'] as String? ?? 'event';
    var active = existing?['active'] as bool? ?? true;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? l10n.addPracticeType : l10n.edit),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hant,
                decoration: InputDecoration(labelText: l10n.typeNameHant),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: hans,
                decoration: InputDecoration(labelText: l10n.typeNameHans),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: icon,
                decoration: InputDecoration(labelText: l10n.iconLabel),
                items: [
                  for (final e in eventIconOptions.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Icon(e.value, size: 24),
                    ),
                ],
                onChanged: (v) => setState(() => icon = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.activeLabel),
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(context, 'delete'),
                child: Text(l10n.delete),
              ),
            TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(context, 'save'),
                child: Text(l10n.save)),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (action == 'delete') {
        await Supabase.instance.client
            .from('event_types')
            .delete()
            .eq('id', existing!['id'] as String);
      } else {
        if (hant.text.trim().isEmpty || hans.text.trim().isEmpty) return;
        final payload = {
          'name_hant': hant.text.trim(),
          'name_hans': hans.text.trim(),
          'icon': icon,
          'active': active,
        };
        if (existing == null) {
          await Supabase.instance.client.from('event_types').insert({
            ...payload,
            'sort_order': 50,
          });
        } else {
          await Supabase.instance.client
              .from('event_types')
              .update(payload)
              .eq('id', existing['id'] as String);
        }
      }
      ref.invalidate(eventTypesProvider);
      ref.invalidate(eventsProvider);
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.code == '23503'
            ? l10n.deleteTypeBlocked
            : '${l10n.authFailed}${e.message}'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final types = ref.watch(eventTypesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manageEventTypes)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
      body: types.when(
        loading: () => const SkeletonList(rows: 5),
        error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(eventTypesProvider)),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final t = list[i];
            final inactive = t['active'] == false;
            return ListTile(
              leading: Icon(
                eventIcon(t['icon'] as String?),
                color: inactive
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant'])
                    as String,
                style: inactive
                    ? TextStyle(color: Theme.of(context).disabledColor)
                    : null,
              ),
              subtitle: Text('${t['name_hant']} · ${t['name_hans']}'),
              trailing: inactive
                  ? Chip(label: Text(l10n.offLabel))
                  : const Icon(Icons.edit_outlined),
              onTap: () => _edit(context, ref, existing: t),
            );
          },
        ),
      ),
    );
  }
}
