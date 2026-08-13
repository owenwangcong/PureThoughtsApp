import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/prefs.dart';
import 'package:pure_thoughts/features/tools/bell.dart';
import 'package:pure_thoughts/features/tools/timer_screen.dart';
import 'package:pure_thoughts/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('计时显示 formatMmSs', () {
    test('整分与秒位补零', () {
      expect(formatMmSs(const Duration(minutes: 20)), '20:00');
      expect(formatMmSs(const Duration(minutes: 5, seconds: 7)), '05:07');
      expect(formatMmSs(const Duration(seconds: 59)), '00:59');
      expect(formatMmSs(Duration.zero), '00:00');
    });

    test('超过一小时以分钟累计显示', () {
      expect(formatMmSs(const Duration(minutes: 90, seconds: 3)), '90:03');
    });
  });

  group('计时显示 formatHms(自订长时长)', () {
    test('不足一小时回退 mm:ss', () {
      expect(formatHms(const Duration(minutes: 59, seconds: 59)), '59:59');
      expect(formatHms(Duration.zero), '00:00');
    });

    test('满一小时起用 h:mm:ss', () {
      expect(formatHms(const Duration(hours: 1)), '1:00:00');
      expect(formatHms(const Duration(minutes: 90, seconds: 3)), '1:30:03');
      expect(formatHms(const Duration(hours: 12)), '12:00:00');
    });
  });

  group('时长标签 formatMinutesLabel', () {
    String label(int m) =>
        formatMinutesLabel(m, hourUnit: '小時', minuteUnit: '分鐘');

    test('不足一小时只显示分钟', () {
      expect(label(1), '1 分鐘');
      expect(label(45), '45 分鐘');
    });

    test('整小时省略分钟', () {
      expect(label(60), '1 小時');
      expect(label(120), '2 小時');
    });

    test('时分并列', () {
      expect(label(75), '1 小時 15 分鐘');
      expect(label(720), '12 小時');
    });
  });

  group('打坐計時 自訂时长(PRD §9.1)', () {
    Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    Widget wrap(SharedPreferences prefs) => ProviderScope(
          overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TimerScreen(),
          ),
        );

    testWidgets('已存的非预设时长显示在自訂 chip 上', (tester) async {
      final prefs = await prefsWith({'timer_minutes': 75});
      await tester.pumpWidget(wrap(prefs));
      await tester.pumpAndSettle();

      expect(find.text('1 小時 15 分鐘'), findsOneWidget);
      expect(find.text('自訂'), findsNothing); // 已有自订值时直接显示该值
    });

    testWidgets('点自訂打开时 / 分滚轮,确认后写回并持久化', (tester) async {
      final prefs = await prefsWith(<String, Object>{});
      await tester.pumpWidget(wrap(prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, '自訂'));
      await tester.pumpAndSettle();

      expect(find.text('自訂時長'), findsOneWidget);
      expect(find.byType(CupertinoPicker), findsNWidgets(2)); // 小时 + 分钟
      expect(find.text('20 分鐘'), findsWidgets); // 默认 20 分钟带入滚轮

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.text('自訂時長'), findsNothing);
      expect(prefs.getInt('timer_minutes'), 20);
    });

    testWidgets('滚轮可选到超过一小时的时长', (tester) async {
      final prefs = await prefsWith(<String, Object>{});
      await tester.pumpWidget(wrap(prefs));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, '自訂'));
      await tester.pumpAndSettle();

      // 小时列向上拖一格 → 1 小時
      await tester.drag(find.byType(CupertinoPicker).first, const Offset(0, -44),
          touchSlopY: 0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      final saved = prefs.getInt('timer_minutes')!;
      expect(saved, greaterThanOrEqualTo(60)); // 至少一小时,证明不再受 60 分钟预设上限约束
      expect(find.text(formatMinutesLabel(saved, hourUnit: '小時', minuteUnit: '分鐘')),
          findsOneWidget);
    });
  });
}
