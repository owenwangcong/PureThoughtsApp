import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/channels.dart';
import '../../core/settings.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../live/webex.dart';
import 'event_icons.dart';
import 'events_providers.dart';
import 'occurrence_utils.dart';

/// 活動日曆(PRD v0.5.7 §5):月视图 + 当日列表 + **未來活動列表**;
/// 动态事件类型(不同图标);管理员增删改活动/取消单次/管理类型;
/// 任何变更由 DB 触发器自动生成全员通知;时间按本地时区显示;匿名可浏览。
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  var _focused = DateTime.now();
  DateTime? _selected;

  Map<String, Map<String, dynamic>> get _typeById => {
        for (final t in ref.read(eventTypesProvider).value ?? const [])
          t['id'] as String: t,
      };

  String _typeName(Map<String, dynamic>? t, Locale locale) => t == null
      ? ''
      : (locale.scriptCode == 'Hans' ? t['name_hans'] : t['name_hant']) as String;

  void _invalidateAll() {
    ref.invalidate(eventsProvider);
    ref.invalidate(eventOverridesProvider);
    ref.invalidate(eventTypesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(eventsProvider);
    final overrides = ref.watch(eventOverridesProvider);
    ref.watch(eventTypesProvider);
    final profile = ref.watch(myProfileProvider);
    final isAdmin = profile.value?['is_app_admin'] == true;

    final monthStart = DateTime(_focused.year, _focused.month - 1, 1);
    final monthEnd = DateTime(_focused.year, _focused.month + 2, 0);
    final occurrences = expandOccurrences(
      events: events.value ?? const [],
      overrides: overrides.value ?? const [],
      rangeStart: monthStart,
      rangeEnd: monthEnd,
    );
    final byDay = <String, List<Occurrence>>{};
    for (final o in occurrences) {
      byDay.putIfAbsent(dateKeyOf(o.startAt), () => []).add(o);
    }
    final selected = _selected ?? DateTime.now();
    final dayList = byDay[dateKeyOf(selected)] ?? const [];

    // 未來活動:自今日起 90 天内的前 10 场(不含已取消)
    final now = DateTime.now();
    final upcoming = expandOccurrences(
      events: events.value ?? const [],
      overrides: overrides.value ?? const [],
      rangeStart: now,
      rangeEnd: now.add(const Duration(days: 90)),
    ).where((o) => !o.cancelled && o.startAt.isAfter(now)).take(10).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendarTitle),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: l10n.manageEventTypes,
              icon: const Icon(Icons.category_outlined),
              onPressed: () => context.push('/calendar/types'),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _editEvent(),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _invalidateAll(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            TableCalendar<Occurrence>(
              locale: Localizations.localeOf(context).toString(),
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focused,
              selectedDayPredicate: (d) => isSameDay(d, _selected),
              eventLoader: (day) => byDay[dateKeyOf(day)] ?? const [],
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              calendarStyle: const CalendarStyle(markersMaxCount: 4),
              onDaySelected: (sel, foc) => setState(() {
                _selected = sel;
                _focused = foc;
              }),
              onPageChanged: (foc) => setState(() => _focused = foc),
            ),
            const Divider(),
            if (dayList.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text(l10n.emptyList)),
              )
            else
              for (final o in dayList) _occurrenceTile(context, o, isAdmin),

            // ---- 未來活動 ----
            if (upcoming.isNotEmpty) ...[
              SectionHeader(l10n.upcomingTitle),
              for (final o in upcoming)
                _occurrenceTile(context, o, isAdmin, showDate: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _occurrenceTile(BuildContext context, Occurrence o, bool isAdmin,
      {bool showDate = false}) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final t = _typeById[o.event['event_type_id']];
    final time = showDate
        ? DateFormat('MM-dd (E) HH:mm', Localizations.localeOf(context).toString())
            .format(o.startAt)
        : DateFormat('HH:mm').format(o.startAt);
    return ListTile(
      leading: Icon(
        eventIcon(t?['icon'] as String?),
        color: o.cancelled
            ? Theme.of(context).disabledColor
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        o.event['title'] as String,
        style: o.cancelled
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).disabledColor)
            : null,
      ),
      subtitle: Text(
        '${_typeName(t, locale)} · ${o.cancelled ? l10n.eventCancelled : time}',
      ),
      onTap: () => _showDetail(context, o, isAdmin),
    );
  }

  void _showDetail(BuildContext context, Occurrence o, bool isAdmin) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(o.event['title'] as String,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(o.startAt) +
                    (o.event['duration_minutes'] != null
                        ? ' · ${o.event['duration_minutes']} ${l10n.unitMinute}'
                        : ''),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (o.event['content'] != null) ...[
                const SizedBox(height: 12),
                Text(o.event['content'] as String),
              ],
              const SizedBox(height: 16),
              if (o.event['youtube_url'] != null)
                FilledButton.icon(
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('YouTube'),
                  onPressed: () {
                    final url = o.event['youtube_url'] as String;
                    final id = RegExp(r'(?:v=|youtu\.be/|/live/)([\w-]{11})')
                        .firstMatch(url)
                        ?.group(1);
                    context.push(id != null
                        ? '/watch/$id'
                        : Uri(path: '/webview', queryParameters: {
                            'url': url,
                            'title': 'YouTube',
                          }).toString());
                  },
                ),
              if (o.event['webex_url'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('Webex'),
                        onPressed: () => openWebexInApp(context, ref,
                            url: o.event['webex_url'] as String),
                      ),
                    ),
                    // 永远保留 Webex App 选项(用户定案)
                    IconButton(
                      tooltip: l10n.webexOpenApp,
                      icon: const Icon(Icons.exit_to_app),
                      onPressed: () => launchUrl(
                          Uri.parse(o.event['webex_url'] as String),
                          mode: LaunchMode.externalApplication),
                    ),
                  ],
                ),
              ],
              if (isAdmin) ...[
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _editEvent(existing: o.event);
                        },
                        child: Text(l10n.editEvent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!o.cancelled)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await Supabase.instance.client
                                .from('event_overrides')
                                .upsert({
                              'event_id': o.event['id'],
                              'occurrence_date': o.dateKey,
                              'patch': {'cancelled': true},
                            }, onConflict: 'event_id,occurrence_date');
                            _invalidateAll();
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          },
                          child: Text(l10n.cancelOccurrence),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        content: Text(l10n.confirmDeleteEvent),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dctx, false),
                              child: Text(l10n.cancel)),
                          FilledButton(
                              onPressed: () => Navigator.pop(dctx, true),
                              child: Text(l10n.submit)),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await Supabase.instance.client
                        .from('events')
                        .delete()
                        .eq('id', o.event['id'] as String);
                    _invalidateAll();
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  child: Text(l10n.deleteEvent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 管理员新增/编辑活动(existing 非空 = 编辑)
  Future<void> _editEvent({Map<String, dynamic>? existing}) async {
    final l10n = AppLocalizations.of(context);
    final locale = ref.read(localeProvider);
    final types = (ref.read(eventTypesProvider).value ?? const [])
        .where((t) =>
            t['active'] == true || t['id'] == existing?['event_type_id'])
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
    var typeId = existing?['event_type_id'] as String? ?? types.first['id'] as String;
    var weekly = existing == null
        ? true
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
                            Text(_typeName(t, locale)),
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
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
    if (ok != true || title.text.trim().isEmpty || !mounted) return;

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
      _invalidateAll();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    }
  }
}
