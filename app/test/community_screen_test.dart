import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_thoughts/core/prefs.dart';
import 'package:pure_thoughts/core/settings.dart';
import 'package:pure_thoughts/core/theme/app_theme.dart';
import 'package:pure_thoughts/core/widgets/async_states.dart';
import 'package:pure_thoughts/features/community/community_providers.dart';
import 'package:pure_thoughts/features/community/community_screen.dart';
import 'package:pure_thoughts/features/dashboard/dashboard_providers.dart';
import 'package:pure_thoughts/l10n/gen/app_localizations.dart';
import 'package:pure_thoughts/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// P9.2 去群化客户端测试(设计 §12.2 T-APP-01 / 03 / 04 / 08)。
/// T-APP-02 在 batch_utils_test;T-APP-05 在 layout_walkthrough_test;
/// T-APP-06/07(可选 vs 可读两层)在 community_flow_smoke_test 对真库验证。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

  Map<String, dynamic> daily(String date, String typeId, num total, int entries) =>
      {
        'practice_type_id': typeId,
        'unit': 'volume',
        'local_date': date,
        'total': total,
        'entries': entries,
      };

  Future<SharedPreferences> mockPrefs() async {
    SharedPreferences.setMockInitialValues({PrefKeys.onboardingDone: true});
    return SharedPreferences.getInstance();
  }

  Future<void> pump(WidgetTester tester, Widget screen,
      {List<dynamic> overrides = const []}) async {
    final prefs = await mockPrefs();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [sharedPrefsProvider.overrideWithValue(prefs), ...overrides],
        child: MaterialApp(
          locale: hant,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.light,
          home: screen,
        ),
      ),
    );
  }

  testWidgets('T-APP-01 共修体未就绪时显示骨架屏而不是崩溃/空白', (tester) async {
    await pump(
      tester,
      const CommunityScreen(),
      overrides: [
        // 永不完成的 Future = 加载中
        communityProvider
            .overrideWith((ref) => Completer<Map<String, dynamic>?>().future),
        myDailyStatsProvider.overrideWith((ref) async => const []),
        communityDailyStatsProvider.overrideWith((ref) async => const []),
        myTotalsProvider.overrideWith((ref) async => const []),
        communityTotalsProvider.overrideWith((ref) async => const []),
        communityTodayReportersProvider.overrideWith((ref) async => 0),
        allPracticeTypesMapProvider.overrideWith((ref) async => const {}),
        myCustomPracticeTypesProvider.overrideWith((ref) async => const []),
      ],
    );
    await tester.pump();
    expect(find.byType(SkeletonList), findsOneWidget);
  });

  testWidgets('T-APP-08 今日双栏:我的与全體各自成列,数字互不串台', (tester) async {
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await pump(
      tester,
      const CommunityScreen(),
      overrides: [
        communityProvider.overrideWith(
            (ref) async => {'id': 'c1', 'name': '共修報數', 'announcement': null}),
        myDailyStatsProvider.overrideWith((ref) async => [daily(key, 't1', 3, 1)]),
        communityDailyStatsProvider
            .overrideWith((ref) async => [daily(key, 't1', 42, 9)]),
        myTotalsProvider.overrideWith((ref) async => const []),
        communityTotalsProvider.overrideWith((ref) async => const []),
        communityTodayReportersProvider.overrideWith((ref) async => 7),
        allPracticeTypesMapProvider.overrideWith((ref) async => {
              't1': {
                'id': 't1',
                'name_hant': '金剛經',
                'name_hans': '金刚经',
                'unit': 'volume',
                'category': 'sutra',
                'sort_order': 1,
                'active': true,
              }
            }),
        myCustomPracticeTypesProvider.overrideWith((ref) async => const []),
        communityLogsRealtimeProvider.overrideWithValue(null),
      ],
    );
    await tester.pumpAndSettle();

    // 「我的 / 全體」在今日卡、趋势图例、累计卡三处各出现一次
    expect(find.text('我的'), findsNWidgets(3));
    expect(find.text('全體'), findsNWidgets(3));
    // 我的 3 部 / 全體 42 部,两个数字都在,且没有互相覆盖
    expect(find.text('金剛經 3 部'), findsOneWidget);
    expect(find.text('金剛經 42 部'), findsOneWidget);
    // 「今日已報人數」只挂在全體卡上
    expect(find.textContaining('7'), findsWidgets);
  });

  testWidgets('T-APP-03/04 新路由存在 + 旧「群」路由留着 redirect(旧版报文与收藏兼容)',
      (tester) async {
    final prefs = await mockPrefs();
    final container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    GoRoute routeOf(String location) =>
        router.configuration.findMatch(Uri.parse(location)).routes.last
            as GoRoute;

    // T-APP-03:報數是独立路由,不带任何 groupId,首页可直达
    for (final p in ['/report', '/community', '/community/logs']) {
      expect(routeOf(p).builder, isNotNull, reason: '$p 应是可直接渲染的页面');
    }

    // T-APP-04:5 条旧路由仍在路由表里,且都是重定向(不是渲染页面)
    for (final p in [
      '/groups',
      '/groups/abc',
      '/groups/abc/report',
      '/groups/abc/logs',
      '/groups/abc/stats',
    ]) {
      final r = routeOf(p);
      expect(r.redirect, isNotNull, reason: '$p 必须保留兼容重定向(设计 §5.9)');
      expect(r.builder, isNull, reason: '$p 不应再渲染任何页面');
    }
  });
}
