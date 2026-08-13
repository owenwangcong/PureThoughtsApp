import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/prefs.dart';
import 'package:pure_thoughts/core/theme/app_theme.dart';
import 'package:pure_thoughts/features/auth/auth_providers.dart';
import 'package:pure_thoughts/features/auth/auth_screen.dart';
import 'package:pure_thoughts/features/events/calendar_screen.dart';
import 'package:pure_thoughts/features/moderation/admin_notify_screen.dart';
import 'package:pure_thoughts/features/events/event_agenda_editor.dart';
import 'package:pure_thoughts/features/events/event_detail_models.dart';
import 'package:pure_thoughts/features/community/community_providers.dart';
import 'package:pure_thoughts/features/community/community_screen.dart';
import 'package:pure_thoughts/features/dashboard/dashboard_providers.dart';
import 'package:pure_thoughts/features/events/event_detail_screen.dart';
import 'package:pure_thoughts/features/events/events_providers.dart';
import 'package:pure_thoughts/features/events/occurrence_utils.dart';
import 'package:pure_thoughts/features/notifications/notification_prefs.dart';
import 'package:pure_thoughts/features/notifications/notifications_providers.dart';
import 'package:pure_thoughts/features/notifications/notifications_screen.dart';
import 'package:pure_thoughts/features/onboarding/onboarding_screen.dart';
import 'package:pure_thoughts/features/qa/qa_detail_screen.dart';
import 'package:pure_thoughts/features/qa/qa_models.dart';
import 'package:pure_thoughts/features/study_qa/study_qa_list_screen.dart';
import 'package:pure_thoughts/features/study_qa/study_qa_providers.dart';
import 'package:pure_thoughts/features/settings/settings_screen.dart';
import 'package:pure_thoughts/features/study_qa/study_qa_thread_screen.dart';
import 'package:pure_thoughts/features/tools/timer_screen.dart';
import 'package:pure_thoughts/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

/// P1.10 布局走查(自动化部分):关键无网络界面在
/// 简/繁 × 最大字号(2.0)下渲染不溢出(RenderFlex overflow 在测试中即失败)。
/// 依赖网络的页面(首页/群/统计)由真机人工走查覆盖。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const locales = [
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ];

  Future<void> pumpScreen(WidgetTester tester, Widget screen, Locale locale,
      {List<dynamic> overrides = const []}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          ...overrides,
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: locales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in locales) {
    final tag = locale.scriptCode;

    testWidgets('首启引导四步 · $tag · 字号 2.0 不溢出', (tester) async {
      // 大字号下小屏更容易溢出,用偏小逻辑尺寸检验
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpScreen(tester, const OnboardingScreen(), locale);
      // 逐步走完四步(最后一步不点,避免 context.go 无路由)
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    // 共修報數(P9.2):今日/累计双栏 + 双系列趋势 + 我的自訂功課,
    // 双栏在大字号下须自动堆叠(设计 §5.7),否则两列会被挤爆
    testWidgets('共修報數 · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final now = DateTime.now();
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      Map<String, dynamic> row(num total, int entries) => {
            'practice_type_id': 't1',
            'unit': 'volume',
            'local_date': day,
            'total': total,
            'entries': entries,
          };

      await pumpScreen(tester, const CommunityScreen(), locale, overrides: [
        communityProvider.overrideWith((ref) async => {
              'id': 'c1',
              'name': '共修報數',
              'announcement': '本週六共修改為線上,請提前十分鐘進入會議室,阿彌陀佛。',
            }),
        myDailyStatsProvider.overrideWith((ref) async => [row(3, 1)]),
        communityDailyStatsProvider.overrideWith((ref) async => [row(1204, 96)]),
        myTotalsProvider.overrideWith((ref) async => [row(128, 40)]),
        communityTotalsProvider.overrideWith((ref) async => [row(98765, 3210)]),
        communityTodayReportersProvider.overrideWith((ref) async => 128),
        allPracticeTypesMapProvider.overrideWith((ref) async => {
              't1': {
                'id': 't1',
                'name_hant': '八十八佛大懺悔文',
                'name_hans': '八十八佛大忏悔文',
                'unit': 'volume',
                'category': 'repentance',
                'sort_order': 1,
                'active': true,
              }
            }),
        myCustomPracticeTypesProvider.overrideWith((ref) async => [
              {
                'id': 'c9',
                'name_hant': '我自己加的長名稱功課項',
                'name_hans': '我自己加的长名称功课项',
                'category': 'other',
                'unit': 'count',
                'active': true,
                'sort_order': 900,
              }
            ]),
        communityLogsRealtimeProvider.overrideWithValue(null),
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('登录/注册/找回密码 · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpScreen(tester, const AuthScreen(), locale);
      // 切到注册
      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // 问答详情:传固定片段(build 不触网),验长摘要 + 标签在大字号下不溢出
    testWidgets('问答详情 · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      const seg = QaSegment(
        id: 1,
        qaTitle: '转境、转性与转度的区别',
        videoTitle: '2026年1月10日 讲法直播问答',
        summary: '问题:修行中提到"转境、转性、转度"…\n回答:\n1. 转境:心不随境转;\n'
            '2. 转性:见性起用;\n3. 转度:自度度他。此段摘要用于验证大字号下的换行与滚动。',
        timestampUrl: 'https://www.youtube.com/watch?v=o3dBw8Su_oA&t=239s',
        startTime: '00:03:59',
        durationSeconds: 696,
        tags: ['唯识', '三性', '转依', '修行次第'],
      );
      await pumpScreen(tester, const QaDetailScreen(segment: seg), locale);
      expect(tester.takeException(), isNull);
    });

    // 活动详情:多日时间表 + PDF 资料 + 管理员操作,大字号下不溢出(build 不触网,provider 覆写)
    testWidgets('活动详情(时间表/资料)· $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final event = <String, dynamic>{
        'id': 'ev-test',
        'title': '地藏法會',
        'start_at': DateTime(2026, 8, 1, 9).toUtc().toIso8601String(),
        'duration_minutes': 90,
        'content': '一年一度地藏法會,歡迎共修同霑法益。',
        'youtube_url': 'https://youtube.com/watch?v=abcdef12345',
        'webex_url': null,
        'event_type_id': 't1',
      };
      final occ = Occurrence(
        event: event,
        startAt: DateTime(2026, 8, 1, 9),
        dateKey: '2026-08-01',
        cancelled: false,
      );
      await pumpScreen(
        tester,
        EventDetailScreen(occ: occ),
        locale,
        overrides: [
          myProfileProvider.overrideWith((ref) => {'is_app_admin': true}),
          agendaItemsProvider('ev-test').overrideWith((ref) => _demoAgenda),
          attachmentsProvider('ev-test').overrideWith((ref) => _demoAtts),
        ],
      );
      expect(tester.takeException(), isNull);
    });

    // 管理员时间表编辑器:行列表 + 资料 + 上传按钮,大字号下不溢出
    testWidgets('时间表编辑器 · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final event = <String, dynamic>{
        'id': 'ev-test',
        'title': '禪七',
        'recurrence_rule': null,
      };
      await pumpScreen(
        tester,
        EventAgendaEditorScreen(event: event),
        locale,
        overrides: [
          agendaItemsProvider('ev-test').overrideWith((ref) => _demoAgenda),
          attachmentsProvider('ev-test').overrideWith((ref) => _demoAtts),
        ],
      );
      expect(tester.takeException(), isNull);
    });

    // 活動日曆:佛历格子(农历副标签/节日短名/斋日角点)+ 当日佛历卡,
    // 大字号下不溢出(格内文字有 1.3 倍缩放上限 + FittedBox;P2.9)
    testWidgets('活動日曆佛历格子 · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpScreen(
        tester,
        const CalendarScreen(),
        locale,
        overrides: [
          myProfileProvider.overrideWith((ref) => null),
          eventsProvider.overrideWith((ref) async => []),
          eventOverridesProvider.overrideWith((ref) async => []),
          eventTypesProvider.overrideWith((ref) async => []),
        ],
      );
      expect(tester.takeException(), isNull);
    });

    // 学修问答列表(管理员视图含 tab + 提问人名,信息密度最高)· 大字号不溢出(P8.2)
    testWidgets('學修問答列表 · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpScreen(
        tester,
        const StudyQaListScreen(),
        locale,
        overrides: [
          myProfileProvider.overrideWith((ref) => {'is_app_admin': true}),
          qaThreadsProvider.overrideWith((ref) async => [
                {
                  'id': 'th-1',
                  'user_id': 'u1',
                  'last_sender_role': 'user',
                  'last_message_at': '2026-07-30T10:00:00',
                  'first_message_preview':
                      '打坐時妄念很多,無法安住,請問應如何對治?是否應該改為經行或誦經?',
                  'last_message_preview': '同上',
                  'user_last_read_at': '2026-07-30T09:00:00',
                  'created_at': '2026-07-29T08:00:00',
                  'profiles': {'display_name': '王師姐'},
                },
              ]),
        ],
      );
      expect(tester.takeException(), isNull);
    });

    // 学修问答会话页:长气泡 + 署名 + 输入框,大字号不溢出(P8.2)
    testWidgets('學修問答會話 · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final viewer = User(
        id: 'admin-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-07-30T00:00:00Z',
      );
      await pumpScreen(
        tester,
        const StudyQaThreadScreen(threadId: 'th-1'),
        locale,
        overrides: [
          currentUserProvider.overrideWith((ref) => viewer),
          qaThreadProvider('th-1').overrideWith((ref) async => {
                'id': 'th-1',
                'user_id': 'u1',
                'last_sender_role': 'admin',
                'user_last_read_at': '2026-07-30T09:00:00',
              }),
          qaMessagesProvider('th-1').overrideWith((ref) async => [
                {
                  'id': 'm1',
                  'sender_id': 'u1',
                  'sender_role': 'user',
                  'body': '打坐時妄念很多,無法安住,請問應如何對治?'
                      '是否應該改為經行或誦經?懇請開示。',
                  'created_at': '2026-07-30T09:00:00',
                },
                {
                  'id': 'm2',
                  'sender_id': 'admin-2',
                  'sender_role': 'admin',
                  'body': '妄念來去不隨,不迎不拒。安住呼吸,念起即覺,覺之即無。'
                      '功夫在平常,不必求速效。',
                  'created_at': '2026-07-30T10:00:00',
                },
              ]),
        ],
      );
      expect(tester.takeException(), isNull);
    });

    // 管理员發布通知:表单 + 排程/已发送列表,大字号不溢出(P2.11)
    testWidgets('發布通知(管理員) · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpScreen(
        tester,
        const AdminNotifyScreen(),
        locale,
        overrides: [
          adminGeneralNotificationsProvider.overrideWith((ref) async => [
                {
                  'id': 'n1',
                  'title': '週六共修調整為線上進行,請各位同修留意時間安排',
                  'body': '因場地整修,本週共修改為 Webex 線上進行。',
                  'scheduled_at': '2099-01-01T00:00:00Z',
                  'sent_at': null,
                  'created_at': '2026-07-18T00:00:00Z',
                },
                {
                  'id': 'n2',
                  'title': '已發送的公告',
                  'body': null,
                  'scheduled_at': null,
                  'sent_at': '2026-07-18T00:01:00Z',
                  'created_at': '2026-07-18T00:00:00Z',
                },
              ]),
        ],
      );
      expect(tester.takeException(), isNull);
    });

    // 通知中心(P2.17 改造:三档提醒文案 + 全部已讀按钮 + 本地时间行)
    testWidgets('通知中心 · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      Map<String, dynamic> row(String id, String type,
              Map<String, dynamic> payload) =>
          {
            'id': id,
            'scope': 'all',
            'target_id': null,
            'title': '',
            'body': null,
            'type': type,
            'event_id': 'e1',
            'payload': payload,
            'created_at': '2026-08-14T10:00:00Z',
            'notification_reads': const [],
          };

      await pumpScreen(
        tester,
        const NotificationsScreen(),
        locale,
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          allPracticeTypesMapProvider.overrideWith((ref) async => {}),
          notificationFeedProvider.overrideWith(() => StubNotificationFeed([
                row('n1', 'event_reminder', {
                  'event_id': 'e1',
                  'occurrence_date': '2026-08-15',
                  'offset_minutes': 1440,
                  'title': '週六共修迴向法會',
                  'start_at': '2026-08-15T11:30:00Z',
                  'timezone': 'Asia/Shanghai',
                  'has_youtube': true,
                }),
                row('n2', 'event_reminder', {
                  'event_id': 'e1',
                  'occurrence_date': '2026-08-15',
                  'offset_minutes': 30,
                  'title': '週六共修迴向法會',
                  'start_at': '2026-08-15T11:30:00Z',
                  'timezone': 'Asia/Shanghai',
                }),
                row('n3', 'event_changed', {
                  'action': 'occurrence_restored',
                  'title': '週六共修迴向法會',
                  'event_id': 'e1',
                  'date': '2026-08-15',
                }),
              ])),
        ],
      );
      expect(tester.takeException(), isNull);
    });

    // 设置页「通知」分组(免打扰起讫 + 5 个分类开关)
    testWidgets('设置页通知分组 · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpScreen(
        tester,
        const SettingsScreen(),
        locale,
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          myProfileProvider.overrideWith((ref) async => null),
          notificationPrefsProvider
              .overrideWith((ref) async => const NotificationPrefs()),
        ],
      );
      expect(tester.takeException(), isNull);
    });

    // P2.18:自訂时长对话框内是两列滚轮,大字号下最易挤爆
    testWidgets('打坐計時自訂时长 · $tag · 字号 2.0 不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpScreen(tester, const TimerScreen(), locale);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(ChoiceChip).last); // 自訂
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}

const _demoAgenda = <AgendaItem>[
  AgendaItem(dayIndex: 1, startTime: '06:00', endTime: '07:00', activity: '早課'),
  AgendaItem(
      dayIndex: 1,
      startTime: '07:00',
      endTime: '08:30',
      activity: '誦地藏經',
      linkUrl: 'https://qldazangjing.com/',
      linkLabel: '經文'),
  AgendaItem(dayIndex: 2, startTime: '06:00', activity: '早課'),
];

const _demoAtts = <EventAttachment>[
  EventAttachment(
    id: 'a1',
    title: '地藏經 經本',
    storagePath: 'ev-test/x.pdf',
    publicUrl:
        'https://api.pure-thoughts.com/storage/v1/object/public/event-files/ev-test/x.pdf',
    sizeBytes: 1258291,
  ),
];
