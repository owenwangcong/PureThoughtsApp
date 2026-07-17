import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/channels.dart';
import '../../core/error_text.dart';
import '../../core/settings.dart';
import '../../l10n/gen/app_localizations.dart';
import 'event_icons.dart';
import 'events_providers.dart';

/// 活动相关 provider 统一失效(新增/编辑/删除后刷新日历)。
void invalidateEvents(WidgetRef ref) {
  ref.invalidate(eventsProvider);
  ref.invalidate(eventOverridesProvider);
  ref.invalidate(eventTypesProvider);
}

/// 事件类型名(按当前语言取简繁)。
String eventTypeName(Map<String, dynamic>? t, Locale locale) => t == null
    ? ''
    : (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant']) as String;

/// 管理员新增/编辑活动(existing 非空 = 编辑)。
/// 从日历页与活动详情页共用(P2.4c 抽出,原在 CalendarScreen)。
Future<void> showEventEditor(BuildContext context, WidgetRef ref,
    {Map<String, dynamic>? existing}) async {
  final l10n = AppLocalizations.of(context);
  final locale = ref.read(localeProvider);
  final types = (ref.read(eventTypesProvider).value ?? const [])
      .where((t) => t['active'] == true || t['id'] == existing?['event_type_id'])
      .toList();
  if (types.isEmpty) return;

  final title = TextEditingController(text: existing?['title'] as String? ?? '');
  final content =
      TextEditingController(text: existing?['content'] as String? ?? '');
  final youtube = TextEditingController(
      text: existing == null
          ? Channels.youtubeLiveUrl
          : (existing['youtube_url'] as String? ?? ''));
  final webex = TextEditingController(
      text: existing == null
          ? Channels.webexJoinUrl
          : (existing['webex_url'] as String? ?? ''));
  var typeId =
      existing?['event_type_id'] as String? ?? types.first['id'] as String;
  var weekly = existing == null
      ? false
      : (existing['recurrence_rule'] as String?)?.isNotEmpty == true;
  var when = existing == null
      ? DateTime.now().add(const Duration(days: 1))
      : DateTime.parse(existing['start_at'] as String).toLocal();
  final duration = existing?['duration_minutes'] as int? ?? 90;

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? l10n.createEvent : l10n.editEvent),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: title,
                decoration: InputDecoration(labelText: l10n.eventTitleLabel),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: typeId,
                decoration: InputDecoration(labelText: l10n.categoryTitle),
                items: [
                  for (final t in types)
                    DropdownMenuItem(
                      value: t['id'] as String,
                      child: Row(
                        children: [
                          Icon(eventIcon(t['icon'] as String?), size: 20),
                          const SizedBox(width: 8),
                          Text(eventTypeName(t, locale)),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => typeId = v!),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(DateFormat('yyyy-MM-dd HH:mm').format(when)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: when,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d == null || !context.mounted) return;
                  final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(when));
                  if (t == null) return;
                  setState(() =>
                      when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.weeklyRepeat),
                value: weekly,
                onChanged: (v) => setState(() => weekly = v),
              ),
              TextField(
                controller: youtube,
                decoration: const InputDecoration(labelText: 'YouTube URL'),
              ),
              TextField(
                controller: webex,
                decoration: const InputDecoration(labelText: 'Webex URL'),
              ),
              TextField(
                controller: content,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.noteLabel),
              ),
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
  if (ok != true || title.text.trim().isEmpty || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final payload = {
    'title': title.text.trim(),
    'event_type_id': typeId,
    'start_at': when.toUtc().toIso8601String(),
    'duration_minutes': duration,
    'recurrence_rule': weekly ? 'FREQ=WEEKLY' : null,
    'youtube_url': youtube.text.trim().isEmpty ? null : youtube.text.trim(),
    'webex_url': webex.text.trim().isEmpty ? null : webex.text.trim(),
    'content': content.text.trim().isEmpty ? null : content.text.trim(),
  };
  try {
    if (existing == null) {
      await Supabase.instance.client.from('events').insert({
        ...payload,
        'created_by': Supabase.instance.client.auth.currentUser!.id,
      });
    } else {
      await Supabase.instance.client
          .from('events')
          .update(payload)
          .eq('id', existing['id'] as String);
    }
    invalidateEvents(ref);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errText(l10n, e))));
  }
}
