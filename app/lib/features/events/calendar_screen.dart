import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/settings.dart';
import '../../core/widgets/async_states.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_providers.dart';
import 'event_detail_models.dart';
import 'event_edit.dart';
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
              onPressed: () => showEventEditor(context, ref),
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
              calendarBuilders: CalendarBuilders<Occurrence>(
                // 格子标记:用活动类型图标代替圆点(PRD §5)
                markerBuilder: (context, day, occs) {
                  final keys = dayMarkerIconKeys(occs, _typeById);
                  if (keys.isEmpty) return null;
                  // 单场活动的日子放大些更醒目;多场则缩小以并排容纳
                  final size = keys.length == 1 ? 16.0 : 13.0;
                  final color = Theme.of(context).colorScheme.primary;
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final k in keys)
                            Icon(eventIcon(k), size: size, color: color),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
              for (final o in dayList) _occurrenceTile(context, o),

            // ---- 未來活動 ----
            if (upcoming.isNotEmpty) ...[
              SectionHeader(l10n.upcomingTitle),
              for (final o in upcoming)
                _occurrenceTile(context, o, showDate: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _occurrenceTile(BuildContext context, Occurrence o,
      {bool showDate = false}) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final t = _typeById[o.event['event_type_id']];
    final time = showDate
        ? DateFormat('MM-dd (E) HH:mm', Localizations.localeOf(context).toString())
            .format(o.startAt)
        : DateFormat('HH:mm').format(o.startAt);
    // 内含资源标记:有时间表 / PDF 资料 / 链接时,在列表项上各挂一个小图标,
    // 让用户不点开也知道里面有内容(PRD v0.5.12)。
    final flags = EventResourceFlags.fromEvent(o.event);
    final muted = o.cancelled
        ? Theme.of(context).disabledColor
        : Theme.of(context).colorScheme.onSurfaceVariant;
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
      trailing: flags.any
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (flags.agenda)
                  _resIcon(Icons.schedule, l10n.eventAgendaTitle, muted),
                if (flags.attachment)
                  _resIcon(Icons.picture_as_pdf_outlined,
                      l10n.eventAttachmentsTitle, muted),
                if (flags.link) _resIcon(Icons.link, 'YouTube / Webex', muted),
              ],
            )
          : null,
      onTap: () => context.push('/calendar/event', extra: o),
    );
  }

  Widget _resIcon(IconData icon, String tooltip, Color color) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Tooltip(
          message: tooltip,
          child: Icon(icon, size: 18, color: color),
        ),
      );
}
