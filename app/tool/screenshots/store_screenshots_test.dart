import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/prefs.dart';
import 'package:pure_thoughts/core/theme/app_theme.dart';
import 'package:pure_thoughts/features/auth/auth_providers.dart';
import 'package:pure_thoughts/features/community/community_providers.dart';
import 'package:pure_thoughts/features/community/community_screen.dart';
import 'package:pure_thoughts/features/dashboard/dashboard_providers.dart';
import 'package:pure_thoughts/features/dashboard/my_dashboard_screen.dart';
import 'package:pure_thoughts/features/events/calendar_screen.dart';
import 'package:pure_thoughts/features/events/events_providers.dart';
import 'package:pure_thoughts/features/home/home_screen.dart';
import 'package:pure_thoughts/features/live/live_providers.dart';
import 'package:pure_thoughts/features/logs/logs_providers.dart';
import 'package:pure_thoughts/features/logs/report_log_screen.dart';
import 'package:pure_thoughts/features/notifications/notifications_providers.dart';
import 'package:pure_thoughts/features/study_qa/study_qa_list_screen.dart';
import 'package:pure_thoughts/features/study_qa/study_qa_providers.dart';
import 'package:pure_thoughts/features/tools/timer_screen.dart';
import 'package:pure_thoughts/features/vows/vows_providers.dart';
import 'package:pure_thoughts/features/vows/vows_screen.dart';
import 'package:pure_thoughts/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 商店截图生成器(不随 `flutter test` 跑——本文件在 tool/ 下,不在 test/ 下)。
///
/// 跑法(Windows):
///   cd app
///   flutter test tool/screenshots/store_screenshots_test.dart --update-goldens
///
/// 产物:release/screenshots/<平台>/<尺寸档>/{zh-Hant|zh-Hans}/NN-页面.png
///   apple/6.9-1290x2796         iPhone 6.9" 槽(8 张)
///   apple/6.5-1284x2778         iPhone 6.5" 槽(8 张,ASC 常默认展示这档)
///   google-play/phone-1440x2560 Play 手机(8 张)
///   google-play/tablet-7-1080x1920 与 tablet-10-1800x3200(各 4 张,Play 平板槽必填)
///
/// ⚠️ Play 的尺寸校验:必须 16:9 或 9:16,且**长边 ≤ 短边 × 2**
///    (1080×2400 = 2.22 倍会被拒),手机 320–3840px、平板 1080–7680px。
///    Apple 不受这条约束,用 Apple 自己的机型尺寸。
///
/// 说明:渲染的是**真实 App 界面**(同一套 Widget 与主题),数据为演示数据,
/// 不含任何真实用户信息。中文字体从系统 SimHei 加载(测试环境不自带 CJK 字体)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 中文字体:测试环境无 CJK 字体,不加载会渲染成方块。
    // 注册两个家族名:'PTCjk' 供主题显式指定;'Roboto' 覆盖默认家族,
    // 这样代码里 const TextStyle(...) 这类不继承主题的样式也能出中文。
    final bytes = File(_cjkFontPath).readAsBytesSync().buffer.asByteData();
    for (final family in ['PTCjk', 'Roboto']) {
      final loader = FontLoader(family)..addFont(Future.value(bytes));
      await loader.load();
    }
    // Material 图标字体:随 Flutter SDK 分发,测试环境同样需手动加载
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(
          File(_iconFontPath).readAsBytesSync().buffer.asByteData()));
    await icons.load();
  });

  // ---- 01 首页(功能宫格;匿名与登录同一套界面,PRD v0.5.8) ----
  _page('01-home', () => const HomeScreen(), (l) => [
        currentUserProvider.overrideWith((ref) => null),
        myProfileProvider.overrideWith((ref) async => null),
        hasLiveNowProvider.overrideWith((ref) async => true),
        unreadCountProvider.overrideWithValue(3),
      ]);

  // ---- 02 共修報數(我的 / 全體 双栏 + 趋势 + 公告) ----
  _page('02-community', () => const CommunityScreen(), (l) => [
        currentUserProvider.overrideWith((ref) => null),
        communityProvider.overrideWith((ref) async => {
              'id': 'c1',
              'name': l.hans ? '共修报数' : '共修報數',
              'announcement': l.hans
                  ? '本周六共修改为线上,请提前十分钟进入会议室,阿弥陀佛。'
                  : '本週六共修改為線上,請提前十分鐘進入會議室,阿彌陀佛。',
            }),
        myDailyStatsProvider.overrideWith((ref) async => _myDaily()),
        communityDailyStatsProvider.overrideWith((ref) async => _communityDaily()),
        myTotalsProvider.overrideWith((ref) async => [
              _row('t1', 108, 36),
              _row('t2', 1080, 54),
              _row('t3', 640, 32),
            ]),
        communityTotalsProvider.overrideWith((ref) async => [
              _row('t1', 12608, 3260),
              _row('t2', 98450, 5120),
              _row('t3', 43870, 2180),
            ]),
        communityTodayReportersProvider.overrideWith((ref) async => 136),
        allPracticeTypesMapProvider.overrideWith((ref) async => _typesMap()),
        myCustomPracticeTypesProvider.overrideWith((ref) async => const []),
        communityLogsRealtimeProvider.overrideWithValue(null),
      ]);

  // ---- 03 個人統計(连续用功天数 + 趋势 + 累计) ----
  _page('03-dashboard', () => const MyDashboardScreen(), (l) => [
        currentUserProvider.overrideWith((ref) => null),
        myDailyStatsProvider.overrideWith((ref) async => _myDaily()),
        myTotalsProvider.overrideWith((ref) async => [
              _row('t1', 108, 36),
              _row('t2', 1080, 54),
              _row('t3', 640, 32),
            ]),
        allPracticeTypesMapProvider.overrideWith((ref) async => _typesMap()),
        myVowsProvider.overrideWith((ref) async => [_vow()]),
        vowProgressProvider('v1').overrideWith((ref) async => 68),
        myLogsOnDateProvider(_dayKey(0)).overrideWith((ref) async => _todayLogs()),
      ]);

  // ---- 04 報數(功课项 + 数量 + 代报) ----
  _page('04-report', () => const ReportLogScreen(), (l) => [
        currentUserProvider.overrideWith((ref) => null),
        reportablePracticeTypesProvider.overrideWith((ref) async => _typesList()),
        proxyNamesProvider.overrideWith((ref) async => const ['李師姐', '陳居士']),
        myRecentSelfLogsProvider.overrideWith((ref) async => _todayLogs()),
        allPracticeTypesMapProvider.overrideWith((ref) async => _typesMap()),
      ], tablets: false, after: (tester) async {
        // 选中一项功课 → 露出数量步进器,截图不至于大片留白
        await tester.tap(find.byType(FilterChip).first);
      });

  // ---- 05 活動日曆(佛历 + 活动) ----
  _page('05-calendar', () => const CalendarScreen(), (l) => [
        currentUserProvider.overrideWith((ref) => null),
        myProfileProvider.overrideWith((ref) async => null),
        eventsProvider.overrideWith((ref) async => _events(l)),
        eventOverridesProvider.overrideWith((ref) async => const []),
        eventTypesProvider.overrideWith((ref) async => _eventTypes(l)),
      ], tablets: false);

  // ---- 06 打坐計時(自訂任意时长,P2.18) ----
  _page('06-timer', () => const TimerScreen(), (l) => const [],
      prefs: {'timer_minutes': 75});

  // ---- 07 學修問答 ----
  _page('07-study-qa', () => const StudyQaListScreen(), (l) => [
        currentUserProvider.overrideWith((ref) => null),
        myProfileProvider.overrideWith((ref) async => {'is_app_admin': false}),
        qaThreadsProvider.overrideWith((ref) async => _threads(l)),
      ], tablets: false);

  // ---- Play 必需的商店图形:1024×500 宣传图 + 512×512 图标 ----
  _brandAssets();

  // ---- 08 發願 ----
  _page('08-vows', () => const VowsScreen(), (l) => [
        currentUserProvider.overrideWith((ref) => null),
        myVowsProvider.overrideWith((ref) async => [_vow(), _vow2()]),
        vowProgressProvider('v1').overrideWith((ref) async => 68),
        vowProgressProvider('v2').overrideWith((ref) async => 21),
        allPracticeTypesMapProvider.overrideWith((ref) async => _typesMap()),
      ], tablets: false);
}

// ============================ 基础设施 ============================

const _cjkFontPath = r'C:\Windows\Fonts\simhei.ttf';
const _iconFontPath =
    r'D:\Apps\Flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';

class _Device {
  const _Device(this.dir, this.width, this.height, this.dpr);
  final String dir;
  final double width; // 物理像素
  final double height;
  final double dpr;
}

const _devices = [
  // App Store Connect 的 iPhone 槽位按显示尺寸分组,尺寸不符会被直接判错。
  // 两档都出:6.9" 是当前主槽,6.5" 是 ASC 默认展示的那一档(1284×2778)。
  _Device('apple/6.9-1290x2796', 1290, 2796, 3.0), // iPhone 6.9"(430×932 @3)
  _Device('apple/6.5-1284x2778', 1284, 2778, 3.0), // iPhone 6.5"(428×926 @3)
  // iPad 档已移除:App 改为仅 iPhone(TARGETED_DEVICE_FAMILY = "1")。
  // 若日后恢复 iPad 支持,加回:_Device('apple/ipad-13-2048x2732', 2048, 2732, 2.0)

  // Play 的三档都必须是 16:9 / 9:16,且**长边不得超过短边的 2 倍**
  //(1080×2400 = 2.22 倍会被拒),尺寸范围:手机 320–3840px、平板 1080–7680px。
  _Device('google-play/phone-1440x2560', 1440, 2560, 3.0), // 480×853 @3
  _Device('google-play/tablet-7-1080x1920', 1080, 1920, 2.0), // 540×960 @2
  // 10" 档用 @3:逻辑尺寸 600×1067,内容占比合适;@2(900×1600)下半屏会大片留白
  _Device('google-play/tablet-10-1800x3200', 1800, 3200, 3.0), // 600×1067 @3
];

class _Loc {
  const _Loc(this.dir, this.hans);
  final String dir;
  final bool hans;
  Locale get locale => hans
      ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')
      : const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
}

const _locales = [_Loc('zh-Hant', false), _Loc('zh-Hans', true)];

/// 为一个页面生成 2 端 × 2 语言 = 4 张图
void _page(
  String name,
  Widget Function() screen,
  List<dynamic> Function(_Loc) overrides, {
  Map<String, Object> prefs = const {},
  Future<void> Function(WidgetTester)? after,
  bool tablets = true, // Play 平板槽只需 4 张,次要页面不出平板档以免仓库堆图
}) {
  for (final device in _devices) {
    if (!tablets && device.dir.contains('tablet')) continue;
    for (final loc in _locales) {
      testWidgets('${device.dir}/${loc.dir}/$name', (tester) async {
        tester.view.physicalSize = Size(device.width, device.height);
        tester.view.devicePixelRatio = device.dpr;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({
          'locale': loc.hans ? 'zh_Hans' : 'zh_Hant',
          ...prefs,
        });
        final sp = await SharedPreferences.getInstance();

        // 视口尺寸在各档之间变化时,旧帧像素会残留在新画布未覆盖的区域
        // (表现为页面底部凭空多出一条 AppBar)。setSurfaceSize 让测试 binding
        // 按逻辑尺寸重建 surface,再铺一帧不透明底色清干净。
        await tester.binding.setSurfaceSize(
            Size(device.width / device.dpr, device.height / device.dpr));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        // 两帧:第一帧让新 surface 尺寸生效,第二帧才真正把底色铺满整块新画布
        await tester.pumpWidget(const ColoredBox(color: Color(0xFFF6F1E4)));
        await tester.pump();
        await tester.pumpWidget(const ColoredBox(color: Color(0xFFF6F1E4)));
        await tester.pump();

        final base = AppTheme.light;
        await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(sp),
            ...overrides(loc),
          ],
          child: MaterialApp(
            locale: loc.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            debugShowCheckedModeBanner: false,
            theme: base.copyWith(
              textTheme: base.textTheme.apply(fontFamily: 'PTCjk'),
              primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'PTCjk'),
              appBarTheme: base.appBarTheme.copyWith(
                titleTextStyle:
                    base.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'PTCjk'),
              ),
            ),
            home: screen(),
          ),
        ));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        if (after != null) {
          await after(tester);
          await tester.pumpAndSettle();
        }

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
              '../../../release/screenshots/${device.dir}/${loc.dir}/$name.png'),
        );
      });
    }
  }
}

/// Google Play 的两件必需图形素材:
///   feature-graphic.png 1024×500(横幅,不能有透明通道)
///   app-icon-512.png    512×512(商店图标,由 iOS 1024 母版缩放)
void _brandAssets() {
  const paper = Color(0xFFF6F1E4); // 宣纸暖白(PRD §11 视觉基调)
  const bronze = Color(0xFF8A6D3B); // 古铜金
  const ink = Color(0xFF3E3325);

  testWidgets('google-play/feature-graphic', (tester) async {
    tester.view.physicalSize = const Size(1024, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final logo = File('assets/images/logo_mark.png').readAsBytesSync();
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: paper,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64),
            child: Row(
              // 整体居中:Play 在不同位置会按不同比例裁切两侧,重要内容留在中间更安全
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.memory(logo, width: 250, height: 250, fit: BoxFit.contain),
                const SizedBox(width: 48),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('善護念',
                        style: TextStyle(
                            fontFamily: 'PTCjk',
                            fontSize: 84,
                            height: 1.15,
                            color: ink,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 6)),
                    SizedBox(height: 12),
                    Text('每日功課記錄 · 共修統計',
                        style: TextStyle(
                            fontFamily: 'PTCjk',
                            fontSize: 34,
                            height: 1.3,
                            color: bronze,
                            letterSpacing: 2)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('../../../release/screenshots/google-play/feature-graphic.png'));
  });

  testWidgets('google-play/app-icon-512', (tester) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final icon = File(
            'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')
        .readAsBytesSync();
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Image.memory(icon, width: 512, height: 512, fit: BoxFit.cover),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('../../../release/screenshots/google-play/app-icon-512.png'));
  });
}

// ============================ 演示数据 ============================

String _dayKey(int daysAgo) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _row(String typeId, num total, int entries,
        {int daysAgo = 0, String unit = 'volume'}) =>
    {
      'group_id': 'c1',
      'practice_type_id': typeId,
      'unit': unit,
      'local_date': _dayKey(daysAgo),
      'total': total,
      'entries': entries,
    };

/// 我的近 14 天(连续用功;笔数逐日起伏,趋势条才有高低)
const _myEntries = [3, 2, 4, 2, 3, 1, 4, 3, 2, 4, 1, 3, 2, 4];
const _communityEntries = [96, 74, 112, 88, 130, 68, 104, 92, 120, 78, 110, 86, 128, 98];

List<Map<String, dynamic>> _myDaily() => [
      for (var i = 0; i < 14; i++) ...[
        _row('t1', 1 + (i % 3), _myEntries[i], daysAgo: i),
        _row('t2', 21 + (i % 5) * 3, _myEntries[i], daysAgo: i, unit: 'recitation'),
      ],
    ];

List<Map<String, dynamic>> _communityDaily() => [
      for (var i = 0; i < 14; i++) ...[
        _row('t1', 120 + i * 7, _communityEntries[i], daysAgo: i),
        _row('t2', 860 + i * 23, _communityEntries[i] * 2, daysAgo: i, unit: 'recitation'),
      ],
    ];

Map<String, Map<String, dynamic>> _typesMap() => {
      for (final t in _typesList()) t['id'] as String: t,
    };

List<Map<String, dynamic>> _typesList() => [
      {
        'id': 't1',
        'name_hant': '佛說阿彌陀經',
        'name_hans': '佛说阿弥陀经',
        'category': 'sutra',
        'unit': 'volume',
        'group_id': null,
        'sort_order': 1,
        'active': true,
      },
      {
        'id': 't2',
        'name_hant': '大悲咒',
        'name_hans': '大悲咒',
        'category': 'mantra',
        'unit': 'recitation',
        'group_id': null,
        'sort_order': 2,
        'active': true,
      },
      {
        'id': 't3',
        'name_hant': '八十八佛大懺悔文',
        'name_hans': '八十八佛大忏悔文',
        'category': 'repentance',
        'unit': 'recitation',
        'group_id': null,
        'sort_order': 3,
        'active': true,
      },
      {
        'id': 't4',
        'name_hant': '南無阿彌陀佛',
        'name_hans': '南无阿弥陀佛',
        'category': 'buddha_name',
        'unit': 'count',
        'group_id': null,
        'sort_order': 4,
        'active': true,
      },
      {
        'id': 't5',
        'name_hant': '打坐',
        'name_hans': '打坐',
        'category': 'meditation',
        'unit': 'minute',
        'group_id': null,
        'sort_order': 5,
        'active': true,
      },
    ];

List<Map<String, dynamic>> _todayLogs() => [
      {
        'group_id': 'c1',
        'practice_type_id': 't1',
        'quantity': 2,
        'unit': 'volume',
        'note': null,
        'subject_user_id': null,
        'subject_name': null,
        'reporter_id': 'u1',
        'local_date': _dayKey(0),
        'created_at': DateTime.now()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
      },
      {
        'group_id': 'c1',
        'practice_type_id': 't2',
        'quantity': 21,
        'unit': 'recitation',
        'note': null,
        'subject_user_id': null,
        'subject_name': null,
        'reporter_id': 'u1',
        'local_date': _dayKey(0),
        'created_at': DateTime.now()
            .subtract(const Duration(hours: 5))
            .toIso8601String(),
      },
      {
        'group_id': 'c1',
        'practice_type_id': 't5',
        'quantity': 75,
        'unit': 'minute',
        'note': null,
        'subject_user_id': null,
        'subject_name': null,
        'reporter_id': 'u1',
        'local_date': _dayKey(1),
        'created_at': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      },
    ];

Map<String, dynamic> _vow() => {
      'id': 'v1',
      'group_id': null,
      'practice_type_id': 't1',
      'target_qty': 100,
      'start_date': _dayKey(32),
      'end_date': _dayKey(-68),
      'status': 'active',
    };

Map<String, dynamic> _vow2() => {
      'id': 'v2',
      'group_id': null,
      'practice_type_id': 't3',
      'target_qty': 49,
      'start_date': _dayKey(7),
      'end_date': _dayKey(-42),
      'status': 'active',
    };

List<Map<String, dynamic>> _events(_Loc l) {
  final now = DateTime.now();
  DateTime at(int addDays, int hour) =>
      DateTime(now.year, now.month, now.day, hour).add(Duration(days: addDays));
  // 让「週六共修 / 週三打坐」落在真实的周六 / 周三,标题与日期不打架
  final toSat = (DateTime.saturday - now.weekday + 7) % 7;
  final toWed = (DateTime.wednesday - now.weekday + 7) % 7;
  return [
    {
      'id': 'e1',
      'title': l.hans ? '周六共修' : '週六共修',
      'start_at': at(toSat, 9).toUtc().toIso8601String(),
      'duration_minutes': 120,
      'content': l.hans ? '线上共修,提前十分钟进入。' : '線上共修,提前十分鐘進入。',
      'recurrence_rule': 'FREQ=WEEKLY;BYDAY=SA',
      'event_type_id': 'et1',
      'youtube_url': 'https://www.youtube.com/@善護念/live',
      'webex_url': null,
      'timezone': 'Asia/Hong_Kong',
    },
    {
      'id': 'e2',
      'title': l.hans ? '周三打坐' : '週三打坐',
      'start_at': at(toWed, 20).toUtc().toIso8601String(),
      'duration_minutes': 60,
      'content': l.hans ? '共同打坐一小时。' : '共同打坐一小時。',
      'recurrence_rule': 'FREQ=WEEKLY;BYDAY=WE',
      'event_type_id': 'et2',
      'youtube_url': null,
      'webex_url': null,
      'timezone': 'Asia/Hong_Kong',
    },
    {
      'id': 'e3',
      'title': l.hans ? '地藏法会' : '地藏法會',
      'start_at': at(0, 8).toUtc().toIso8601String(), // 今天:当日活动列表不空
      'duration_minutes': 240,
      'content': l.hans ? '一年一度地藏法会。' : '一年一度地藏法會。',
      'recurrence_rule': null,
      'event_type_id': 'et3',
      'youtube_url': null,
      'webex_url': null,
      'timezone': 'Asia/Hong_Kong',
    },
  ];
}

List<Map<String, dynamic>> _eventTypes(_Loc l) => [
      {
        'id': 'et1',
        'name_hant': '共修',
        'name_hans': '共修',
        'icon': 'groups',
        'color': '#8A6D3B',
        'sort_order': 1,
        'active': true,
      },
      {
        'id': 'et2',
        'name_hant': '打坐',
        'name_hans': '打坐',
        'icon': 'self_improvement',
        'color': '#6B7F5B',
        'sort_order': 2,
        'active': true,
      },
      {
        'id': 'et3',
        'name_hant': '法會',
        'name_hans': '法会',
        'icon': 'temple_buddhist',
        'color': '#A65E3B',
        'sort_order': 3,
        'active': true,
      },
    ];

List<Map<String, dynamic>> _threads(_Loc l) => [
      {
        'id': 'th1',
        'user_id': 'u1',
        'last_sender_role': 'admin',
        'last_message_at':
            DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        'first_message_preview': l.hans
            ? '打坐时妄念很多,无法安住,请问应如何对治?'
            : '打坐時妄念很多,無法安住,請問應如何對治?',
        'last_message_preview': l.hans ? '不必与妄念对抗…' : '不必與妄念對抗…',
        'user_last_read_at':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'created_at':
            DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'profiles': {'display_name': l.hans ? '王师姐' : '王師姐'},
      },
      {
        'id': 'th2',
        'user_id': 'u1',
        'last_sender_role': 'user',
        'last_message_at':
            DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        'first_message_preview': l.hans
            ? '每日功课时间不固定,应如何安排比较好?'
            : '每日功課時間不固定,應如何安排比較好?',
        'last_message_preview': l.hans ? '同上' : '同上',
        'user_last_read_at': DateTime.now().toIso8601String(),
        'created_at':
            DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'profiles': {'display_name': l.hans ? '王师姐' : '王師姐'},
      },
    ];
