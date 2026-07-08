import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/prefs.dart';
import 'package:pure_thoughts/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('设置 providers', () {
    test('语言默认繁体 zh_Hant(PRD §11)', () async {
      final container = await makeContainer();
      final locale = container.read(localeProvider);
      expect(locale.languageCode, 'zh');
      expect(locale.scriptCode, 'Hant');
    });

    test('可切换到简体,且持久化到本地(重启后仍生效)', () async {
      final c1 = await makeContainer();
      c1.read(localeProvider.notifier).set(LocaleController.zhHans);
      expect(c1.read(localeProvider).scriptCode, 'Hans');

      // 模拟重启:新容器从同一份存储读取
      final c2 = await makeContainer();
      expect(c2.read(localeProvider).scriptCode, 'Hans');
    });

    test('字号默认 1.0,超界收敛到 [0.8, 2.0] 并持久化', () async {
      final c1 = await makeContainer();
      expect(c1.read(fontScaleProvider), 1.0);
      c1.read(fontScaleProvider.notifier).set(5.0);
      expect(c1.read(fontScaleProvider), FontScaleController.max);

      final c2 = await makeContainer();
      expect(c2.read(fontScaleProvider), FontScaleController.max);
    });

    test('地区默认 other,可设为 cn;首启引导标记持久化', () async {
      final c1 = await makeContainer();
      expect(c1.read(regionProvider), 'other');
      c1.read(regionProvider.notifier).set('cn');
      expect(c1.read(onboardingDoneProvider), false);
      c1.read(onboardingDoneProvider.notifier).markDone();

      final c2 = await makeContainer();
      expect(c2.read(regionProvider), 'cn');
      expect(c2.read(onboardingDoneProvider), true);
    });
  });
}
