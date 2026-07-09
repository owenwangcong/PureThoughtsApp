import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/channels.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import 'events_providers.dart';
import 'occurrence_utils.dart';

/// 活動日曆(PRD §5):循环活动展开 + 单次修改;时间按用户本地时区显示;
/// 匿名可浏览;管理员可建活动/取消单次。
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  var _focused = DateTime.now();
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(eventsProvider);
    final overrides = ref.watch(eventOverridesProvider);
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _editEvent,
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(eventsProvider);
          ref.invalidate(eventOverridesProvider);
        },
        child: ListView(
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
              onDaySelected: (sel, foc) => setState(() {
                _selected = sel;
                _focused = foc;
              }),
              onPageChanged: (foc) => setState(() => _focused = foc),
            ),
            const Divider(),
            if (dayList.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(l10n.emptyList)),
              )
            else
              for (final o in dayList) _occurrenceTile(context, o, isAdmin),
          ],
        ),
      ),
    );
  }

  Widget _occurrenceTile(BuildContext context, Occurrence o, bool isAdmin) {
    final l10n = AppLocalizations.of(context);
    final time = DateFormat('HH:mm').format(o.startAt);
    return ListTile(
      leading: Icon(
        switch (o.event['type']) {
          'group_practice' => Icons.groups,
          'meditation' => Icons.self_improvement,
          'dharma_talk' => Icons.record_voice_over,
          'dharma_assembly' => Icons.temple_buddhist,
          _ => Icons.event,
        },
        color: o.cancelled ? Theme.of(context).disabledColor : null,
      ),
      title: Text(
        o.event['title'] as String,
        style: o.cancelled
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).disabledColor)
            : null,
      ),
      subtitle: Text(o.cancelled ? l10n.eventCancelled : time),
      onTap: () => _showDetail(context, o, isAdmin),
    );
  }

  void _showDetail(BuildContext context, Occurrence o, bool isAdmin) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
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
                  // App 内观看:watch 链接进内嵌播放器,其余进应用内浏览器
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
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Webex'),
                  onPressed: () => context.push(Uri(
                    path: '/webview',
                    queryParameters: {
                      'url': o.event['webex_url'] as String,
                      'title': 'Webex',
                    },
                  ).toString()),
                ),
              ],
              if (isAdmin && !o.cancelled) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    await Supabase.instance.client.from('event_overrides').upsert({
                      'event_id': o.event['id'],
                      'occurrence_date': o.dateKey,
                      'patch': {'cancelled': true},
                    }, onConflict: 'event_id,occurrence_date');
                    ref.invalidate(eventOverridesProvider);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(l10n.cancelOccurrence),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 管理员创建活动(标题/类型/时间/时长/每周循环/连接/说明)
  Future<void> _editEvent() async {
    final l10n = AppLocalizations.of(context);
    final title = TextEditingController();
    final content = TextEditingController();
    // 默认预填固定频道(PRD v0.5.6 §6),不需要时清空即可
    final youtube = TextEditingController(text: Channels.youtubeLiveUrl);
    final webex = TextEditingController(text: Channels.webexJoinUrl);
    var type = 'group_practice';
    var weekly = true;
    var duration = 90;
    var when = DateTime.now().add(const Duration(days: 1));

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.createEvent),
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
                  value: type,
                  decoration: InputDecoration(labelText: l10n.categoryTitle),
                  items: [
                    for (final t in const [
                      'group_practice',
                      'meditation',
                      'dharma_talk',
                      'dharma_assembly',
                      'other'
                    ])
                      DropdownMenuItem(value: t, child: Text(_eventTypeLabel(l10n, t))),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(DateFormat('yyyy-MM-dd HH:mm').format(when)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: when,
                      firstDate: DateTime.now(),
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
    try {
      await Supabase.instance.client.from('events').insert({
        'title': title.text.trim(),
        'type': type,
        'start_at': when.toUtc().toIso8601String(),
        'duration_minutes': duration,
        if (weekly) 'recurrence_rule': 'FREQ=WEEKLY',
        if (youtube.text.trim().isNotEmpty) 'youtube_url': youtube.text.trim(),
        if (webex.text.trim().isNotEmpty) 'webex_url': webex.text.trim(),
        if (content.text.trim().isNotEmpty) 'content': content.text.trim(),
        'created_by': Supabase.instance.client.auth.currentUser!.id,
      });
      ref.invalidate(eventsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.authFailed}$e')));
    }
  }
}

String _eventTypeLabel(AppLocalizations l10n, String type) => switch (type) {
      'group_practice' => l10n.eventTypePractice,
      'meditation' => l10n.eventTypeMeditation,
      'dharma_talk' => l10n.eventTypeTalk,
      'dharma_assembly' => l10n.eventTypeAssembly,
      _ => l10n.categoryOther,
    };
