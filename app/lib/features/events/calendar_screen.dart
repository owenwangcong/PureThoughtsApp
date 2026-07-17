import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/almanac/almanac.dart';
import '../../core/almanac/lunar_format.dart';
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

    // 佛历层(PRD v0.5.15 §5.2):当前月可能溢出到相邻年,三年数据都备着(懒加载+缓存)
    final hans = ref.watch(localeProvider).scriptCode == 'Hans';
    final almanacYears = {
      for (final y in {_focused.year - 1, _focused.year, _focused.year + 1})
        y: ref.watch(almanacYearProvider(y)).value,
    };
    AlmanacDayInfo? infoOf(DateTime d) => almanacYears[d.year]?.infoFor(d);
    final selectedInfo = infoOf(selected);

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
              onPressed: () async {
                final startAt = await showEventEditor(context, ref);
                // 新建成功 → 日历跳到活动那一天,当日列表立刻可见
                // (默认建在明天、时区可能非本地,不跳的话像"没加上")
                if (startAt != null && mounted) {
                  setState(() {
                    _selected = startAt;
                    _focused = startAt;
                  });
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _invalidateAll(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            // 日历格子有农历副标签,给格子内文字设缩放上限,超大字号下不破格
            // (下方列表与佛历卡不受限,仍完整跟随用户字号)
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: MediaQuery.of(context)
                    .textScaler
                    .clamp(maxScaleFactor: 1.3),
              ),
              child: TableCalendar<Occurrence>(
                locale: Localizations.localeOf(context).toString(),
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focused,
                rowHeight: 62, // 容纳日号 + 农历副标签 + 底部活动图标
                daysOfWeekHeight: 30,
                selectedDayPredicate: (d) => isSameDay(d, _selected),
                eventLoader: (day) => byDay[dateKeyOf(day)] ?? const [],
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                // 卡片式格子(2026-07-17 用户选定 B 方案):邻月日期不显示,减少杂讯
                calendarStyle: const CalendarStyle(outsideDaysVisible: false),
                // 星期表头:浅底色条 + 周末区分色
                daysOfWeekStyle: DaysOfWeekStyle(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                calendarBuilders: CalendarBuilders<Occurrence>(
                  dowBuilder: (context, day) => Center(
                    child: Text(
                      DateFormat.EEEEE(
                              Localizations.localeOf(context).toString())
                          .format(day),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _weekendColor(context, day.weekday) ??
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // 日格:日号 + 农历/节日短名副标签 + 十斋日角点(PRD v0.5.15 §5.2)
                  defaultBuilder: (context, day, _) =>
                      _dayCell(context, day, infoOf(day), hans: hans),
                  todayBuilder: (context, day, _) =>
                      _dayCell(context, day, infoOf(day), hans: hans, today: true),
                  selectedBuilder: (context, day, _) => _dayCell(
                      context, day, infoOf(day), hans: hans, selected: true),
                  // 格子标记:用活动类型图标代替圆点(PRD §5)
                  markerBuilder: (context, day, occs) {
                    final keys = dayMarkerIconKeys(occs, _typeById);
                    if (keys.isEmpty) return null;
                    // 单场活动的日子放大些更醒目;多场则缩小以并排容纳
                    final size = keys.length == 1 ? 16.0 : 13.0;
                    final scheme = Theme.of(context).colorScheme;
                    // 选中格底色为主色,图标转反色以保持可见
                    final color = isSameDay(day, _selected)
                        ? scheme.onPrimary
                        : scheme.primary;
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
            ),

            // 图例:金字=节日 · 金点=十斋日 · 图标=活动(2026-07-17 用户选定)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Wrap(
                alignment: WrapAlignment.center, // 图例整行居中
                spacing: 14,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.legendFestival,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      )),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(l10n.almanacZhaiTen, style: _legendStyle(context)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.event, size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(l10n.legendEvent, style: _legendStyle(context)),
                  ]),
                ],
              ),
            ),
            const Divider(),

            // ---- 当日佛历(农历 + 节日 + 十斋日;PRD v0.5.15 §5.2) ----
            if (selectedInfo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: selectedInfo.isSpecial
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.spa_outlined,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lunarFullText(
                                          selectedInfo.lunarMonth,
                                          selectedInfo.lunarDay,
                                          selectedInfo.isLeapMonth,
                                          hans: hans),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      [
                                        for (final f in selectedInfo.festivals)
                                          f.name(hans: hans),
                                        if (selectedInfo.isZhaiTen)
                                          l10n.almanacZhaiTen,
                                      ].join('、'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Text(
                        lunarFullText(selectedInfo.lunarMonth,
                            selectedInfo.lunarDay, selectedInfo.isLeapMonth,
                            hans: hans),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
              ),
            if (dayList.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                // 明确说「没有活动」,不用笼统的「暂无资料」(2026-07-17 用户反馈)
                child: Center(child: Text(l10n.noEventsThisDay)),
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

  /// 周末区分色(纸质日历惯例,2026-07-17 用户选定):周日暗红棕、周六青灰;
  /// 深色主题取亮化变体。工作日返回 null(用默认色)。
  Color? _weekendColor(BuildContext context, int weekday) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (weekday) {
      DateTime.sunday => dark ? const Color(0xFFE5A899) : const Color(0xFF9A4A3B),
      DateTime.saturday =>
        dark ? const Color(0xFFA9C7C4) : const Color(0xFF4E6E6A),
      _ => null,
    };
  }

  TextStyle _legendStyle(BuildContext context) => TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  /// 日格(卡片式,2026-07-17 用户选定 B 方案):浅底色瓷砖分隔天与天;
  /// 今日=淡金填充+粗体,选中=深金实心;周末日号用区分色;
  /// 副标签(平日=农历,节日=金色短名)+ 十斋日角点。
  /// 内容整体 FittedBox 收缩,配合外层 1.3 倍缩放上限,大字号下不破格。
  Widget _dayCell(BuildContext context, DateTime day, AlmanacDayInfo? info,
      {bool hans = false, bool today = false, bool selected = false}) {
    final scheme = Theme.of(context).colorScheme;
    final festival = info != null && info.festivals.isNotEmpty;
    final sub = info == null
        ? null
        : festival
            ? info.festivals.first.shortName(hans: hans)
            : lunarCellLabel(info.lunarMonth, info.lunarDay, info.isLeapMonth,
                hans: hans);
    final numColor = selected
        ? scheme.onPrimary
        : today
            ? scheme.onPrimaryContainer
            : _weekendColor(context, day.weekday) ?? scheme.onSurface;
    final subColor = selected
        ? scheme.onPrimary
        : festival
            ? scheme.primary
            : today
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.all(1.5), // 瓷砖间 3px 空隙
      decoration: BoxDecoration(
        // Highest 档:浅色主题里 surfaceContainer 与宣纸底几乎同色,瓷砖会隐形
        color: selected
            ? scheme.primary
            : today
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Center(
            // 整体 scaleDown:无论字号多大,格子内容都收缩适配、绝不溢出
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${day.day}',
                      style: TextStyle(
                        color: numColor,
                        fontWeight: today || selected ? FontWeight.bold : null,
                      )),
                  if (sub != null)
                    Text(sub,
                        maxLines: 1,
                        style: TextStyle(fontSize: 10, color: subColor)),
                  const SizedBox(height: 6), // 底部活动图标 marker 的呼吸空间
                ],
              ),
            ),
          ),
          if (info?.isZhaiTen == true)
            Positioned(
              top: 4,
              right: 6,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.onPrimary : scheme.primary,
                ),
              ),
            ),
        ],
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
