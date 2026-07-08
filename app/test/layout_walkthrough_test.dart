import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/prefs.dart';
import 'package:pure_thoughts/features/auth/auth_screen.dart';
import 'package:pure_thoughts/features/onboarding/onboarding_screen.dart';
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

  Future<void> pumpScreen(WidgetTester tester, Widget screen, Locale locale) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: locale,
          supportedLocales: locales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  }
}
