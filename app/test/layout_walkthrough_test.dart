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
import 'package:pure_thoughts/features/events/event_detail_screen.dart';
import 'package:pure_thoughts/features/events/events_providers.dart';
import 'package:pure_thoughts/features/events/occurrence_utils.dart';
import 'package:pure_thoughts/features/onboarding/onboarding_screen.dart';
import 'package:pure_thoughts/features/qa/qa_detail_screen.dart';
import 'package:pure_thoughts/features/qa/qa_models.dart';
import 'package:pure_thoughts/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
