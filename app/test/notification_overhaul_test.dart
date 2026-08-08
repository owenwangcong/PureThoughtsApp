// 通知系统改造(P2.12–P2.17,PRD v0.5.21)客户端测试。
// 用例编号见 docs/design/notification-overhaul.md §12.3(T-APP-01…13)。
// 佛历开关迁移(T-APP-01)另在 almanac_test.dart 覆盖。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_thoughts/core/prefs.dart';
import 'package:pure_thoughts/core/theme/app_theme.dart';
import 'package:pure_thoughts/features/auth/auth_providers.dart';
import 'package:pure_thoughts/features/dashboard/dashboard_providers.dart';
import 'package:pure_thoughts/features/events/event_reminder_options.dart';
import 'package:pure_thoughts/features/events/occurrence_utils.dart';
import 'package:pure_thoughts/features/groups/groups_providers.dart';
import 'package:pure_thoughts/features/notifications/notification_prefs.dart';
import 'package:pure_thoughts/features/notifications/notifications_providers.dart';
import 'package:pure_thoughts/features/notifications/notifications_screen.dart';
import 'package:pure_thoughts/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

  // ---------------------------------------------------------------- 深链路由
  group('T-APP-02 通知深链 routeOfNotification', () {
    Map<String, dynamic> n(String type,
            {Map<String, dynamic>? payload, String? targetId, String? eventId}) =>
        {
          'type': type,
          'payload': payload ?? const {},
          'target_id': ?targetId,
          'event_id': ?eventId,
        };

    test('活动提醒带场次 → 该场活动详情', () {
      expect(
        routeOfNotification(n('event_reminder', payload: {
          'event_id': 'e1',
          'occurrence_date': '2026-08-15',
        })),
        '/calendar/event/e1?date=2026-08-15',
      );
    });

    test('活动变更单次改动用 payload.date', () {
      expect(
        routeOfNotification(
            n('event_changed', payload: {'event_id': 'e2', 'date': '2026-09-01'})),
        '/calendar/event/e2?date=2026-09-01',
      );
    });

    test('活动变更无场次信息 → 活动详情(取最近一场)', () {
      expect(
        routeOfNotification(n('event_changed', payload: {'event_id': 'e3'})),
        '/calendar/event/e3',
      );
    });

    test('活动已删(无 event_id)→ 退化到日历,不深链到空态', () {
      expect(
        routeOfNotification(n('event_changed', payload: {'action': 'deleted'})),
        '/calendar',
      );
    });

    test('其余类型', () {
      expect(routeOfNotification(n('almanac', payload: {'kind': 'zhai'})),
          '/calendar');
      expect(routeOfNotification(n('live_started')), '/live');
      expect(
          routeOfNotification(n('qa_reply', payload: {'thread_id': 't1'})),
          '/study-qa/t1');
      expect(routeOfNotification(n('qa_question', payload: {'thread_id': 't1'})),
          '/study-qa/t1?as=admin');
      expect(routeOfNotification(n('announcement', targetId: 'g1')), '/groups/g1');
      expect(routeOfNotification(n('proxy_log')), '/dashboard');
      expect(routeOfNotification(n('general')), isNull);
    });

    test('event_id 在列上而不在 payload 里也能用', () {
      expect(routeOfNotification(n('event_reminder', eventId: 'e9')),
          '/calendar/event/e9');
    });
  });

  // ---------------------------------------------------------------- 提醒档位
  group('T-APP-03 提醒档位', () {
    test('默认三档与 DB 触发器一致', () {
      expect(defaultReminderOffsets, [1440, 30, 0]);
      // 三档都必须在可选档位里,否则编辑器回显不出来
      for (final m in defaultReminderOffsets) {
        expect(reminderOffsetOptions, contains(m));
      }
    });

    test('diffReminders 求增删差集', () {
      final d = diffReminders(current: [1440, 30, 0], wanted: [1440, 0, 60]);
      expect(d.toAdd, [60]);
      expect(d.toRemove, [30]);
    });

    test('diffReminders 无变化时两侧都空', () {
      final d = diffReminders(current: [0, 30], wanted: [30, 0]);
      expect(d.toAdd, isEmpty);
      expect(d.toRemove, isEmpty);
    });
  });

  // ---------------------------------------------------------------- 通知偏好
  group('通知偏好模型', () {
    test('Postgres time 解析与回写', () {
      expect(parseDbTime('22:00:00', 0), const TimeOfDay(hour: 22, minute: 0));
      expect(parseDbTime('07:30', 0), const TimeOfDay(hour: 7, minute: 30));
      expect(parseDbTime(null, 22), const TimeOfDay(hour: 22, minute: 0));
      expect(parseDbTime('乱码', 7), const TimeOfDay(hour: 7, minute: 0));
      expect(formatDbTime(const TimeOfDay(hour: 7, minute: 5)), '07:05');
    });

    test('默认值:免打扰开、22:00-07:00、不静音任何类别', () {
      const p = NotificationPrefs();
      expect(p.quietEnabled, true);
      expect(formatDbTime(p.quietStart), '22:00');
      expect(formatDbTime(p.quietEnd), '07:00');
      for (final c in NotifyCategory.values) {
        expect(p.enabledFor(c), true);
      }
    });

    test('关闭一个类别 → 其全部 muted key 进列表,其它类别不受影响', () {
      const p = NotificationPrefs();
      final muted = p.toggled(NotifyCategory.almanacFestival, false);
      expect(muted, ['almanac:festival', 'almanac:festival_eve']);
      final p2 = p.copyWith(mutedTypes: muted);
      expect(p2.enabledFor(NotifyCategory.almanacFestival), false);
      expect(p2.enabledFor(NotifyCategory.almanacZhai), true);
      expect(p2.enabledFor(NotifyCategory.eventReminder), true);
    });

    test('重新打开 → muted key 被移除', () {
      const p = NotificationPrefs(mutedTypes: ['event_reminder', 'almanac:zhai']);
      final muted = p.toggled(NotifyCategory.eventReminder, true);
      expect(muted, ['almanac:zhai']);
    });

    test('fromRow 容错:缺列时回落默认值', () {
      final p = NotificationPrefs.fromRow({});
      expect(p.quietEnabled, true);
      expect(p.mutedTypes, isEmpty);
      expect(NotificationPrefs.fromRow(null).quietEnabled, true);
    });
  });

  // ---------------------------------------------------------------- 深链定位
  group('T-APP-09 resolveOccurrence(深链按 id + 场次定位)', () {
    Map<String, dynamic> weekly(String id, String startUtc) => {
          'id': id,
          'title': 'e$id',
          'start_at': startUtc,
          'recurrence_rule': 'FREQ=WEEKLY',
          'timezone': 'Asia/Shanghai',
        };

    test('按 dateKey 命中指定场次', () {
      final events = [weekly('e1', '2026-08-01T02:00:00Z')];
      // 先展开一次拿到真实 dateKey(避免手写日期与时区口径不一致)
      final all = expandOccurrences(
        events: events,
        overrides: const [],
        rangeStart: DateTime(2026, 8, 1),
        rangeEnd: DateTime(2026, 8, 31),
      );
      final target = all[2];
      final got = resolveOccurrence(
        events: events,
        overrides: const [],
        eventId: 'e1',
        dateKey: target.dateKey,
      );
      expect(got, isNotNull);
      expect(got!.dateKey, target.dateKey);
      expect(got.startAt, target.startAt);
    });

    test('活动不存在 → null', () {
      expect(
        resolveOccurrence(
            events: [weekly('e1', '2026-08-01T02:00:00Z')],
            overrides: const [],
            eventId: 'nope',
            dateKey: '2026-08-01'),
        isNull,
      );
    });

    test('场次已不存在(dateKey 对不上)→ null,不静默落到别的场次', () {
      expect(
        resolveOccurrence(
            events: [weekly('e1', '2026-08-01T02:00:00Z')],
            overrides: const [],
            eventId: 'e1',
            dateKey: '2026-08-03'),
        isNull,
      );
    });

    test('无 dateKey → 取未来最近的一场', () {
      final events = [weekly('e1', '2026-08-01T02:00:00Z')];
      final got = resolveOccurrence(
        events: events,
        overrides: const [],
        eventId: 'e1',
        dateKey: null,
        now: DateTime.utc(2026, 8, 12),
      );
      expect(got, isNotNull);
      expect(got!.startAt.isAfter(DateTime.utc(2026, 8, 12)), true);
    });

    test('非法 dateKey → null 而不是抛异常', () {
      expect(
        resolveOccurrence(
            events: [weekly('e1', '2026-08-01T02:00:00Z')],
            overrides: const [],
            eventId: 'e1',
            dateKey: 'not-a-date'),
        isNull,
      );
    });
  });

  // ---------------------------------------------------------------- 通知中心
  group('通知中心(widget)', () {
    Future<void> pump(WidgetTester tester,
        {required List<Map<String, dynamic>> rows}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const NotificationsScreen()),
        GoRoute(
          path: '/calendar/event/:id',
          builder: (context, state) => Scaffold(
            body: Text('event:${state.pathParameters['id']}'
                ':${state.uri.queryParameters['date'] ?? '-'}'),
          ),
        ),
      ]);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWith((ref) => null),
          allPracticeTypesMapProvider.overrideWith((ref) async => {}),
          myGroupsProvider.overrideWith((ref) async => []),
          notificationFeedProvider.overrideWith(() => StubNotificationFeed(rows)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: hant,
          supportedLocales: const [hant],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.light,
        ),
      ));
      await tester.pumpAndSettle();
    }

    Map<String, dynamic> reminder(int offset, {String? title}) => {
          'id': 'r$offset',
          'scope': 'all',
          'target_id': null,
          'title': '',
          'body': null,
          'type': 'event_reminder',
          'event_id': 'e1',
          'payload': {
            'event_id': 'e1',
            'occurrence_date': '2026-08-15',
            'offset_minutes': offset,
            'title': title ?? '週六共修',
            'start_at': '2026-08-15T11:30:00Z',
            'timezone': 'Asia/Shanghai',
            'has_youtube': true,
          },
          'created_at': '2026-08-14T10:00:00Z',
          'notification_reads': const [],
        };

    testWidgets('T-APP-07 活动提醒四档文案', (tester) async {
      await pump(tester, rows: [
        reminder(1440),
        reminder(180),
        reminder(30),
        reminder(0),
      ]);
      expect(find.text('活動預告'), findsOneWidget);
      expect(find.text('活動即將開始'), findsNWidgets(2)); // 180 与 30 两档
      expect(find.text('活動開始了'), findsOneWidget);
      // 预告带活动当地时间(11:30 UTC = 19:30 Asia/Shanghai)
      expect(find.textContaining('08-15 19:30'), findsOneWidget);
      expect(find.textContaining('3 小時後開始'), findsOneWidget);
      expect(find.textContaining('30 分鐘後開始'), findsOneWidget);
      // 有链接的开始档提示可点进
      expect(find.textContaining('點擊進入'), findsOneWidget);
    });

    testWidgets('T-APP-08 單次恢復渲染(缺陷 F 的客户端侧)', (tester) async {
      await pump(tester, rows: [
        {
          'id': 'c1',
          'scope': 'all',
          'target_id': null,
          'title': '',
          'body': null,
          'type': 'event_changed',
          'event_id': 'e1',
          'payload': {
            'action': 'occurrence_restored',
            'title': '週六共修',
            'event_id': 'e1',
            'date': '2026-08-15',
          },
          'created_at': '2026-08-10T10:00:00Z',
          'notification_reads': const [],
        }
      ]);
      expect(find.text('活動異動'), findsOneWidget);
      expect(find.textContaining('單次恢復'), findsOneWidget);
    });

    testWidgets('T-APP-05 未读时显示「全部已讀」,全已读时不显示', (tester) async {
      await pump(tester, rows: [reminder(0)]);
      expect(find.text('全部已讀'), findsOneWidget);

      final read = reminder(0);
      read['notification_reads'] = [
        {'read_at': '2026-08-14T11:00:00Z'}
      ];
      await pump(tester, rows: [read]);
      expect(find.text('全部已讀'), findsNothing);
    });

    testWidgets('T-APP-06 点击提醒深链到该场活动', (tester) async {
      await pump(tester, rows: [reminder(1440)]);
      await tester.tap(find.text('活動預告'));
      await tester.pumpAndSettle();
      expect(find.text('event:e1:2026-08-15'), findsOneWidget);
    });

    testWidgets('空态', (tester) async {
      await pump(tester, rows: const []);
      expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
    });
  });
}
