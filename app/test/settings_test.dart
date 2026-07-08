import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/settings.dart';

void main() {
  group('设置 providers', () {
    test('语言默认繁体 zh_Hant(PRD §11)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final locale = container.read(localeProvider);
      expect(locale.languageCode, 'zh');
      expect(locale.scriptCode, 'Hant');
    });

    test('可切换到简体', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(localeProvider.notifier).set(LocaleController.zhHans);
      expect(container.read(localeProvider).scriptCode, 'Hans');
    });

    test('字号默认 1.0,设置超界时收敛到 [0.8, 2.0]', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(fontScaleProvider), 1.0);
      container.read(fontScaleProvider.notifier).set(5.0);
      expect(container.read(fontScaleProvider), FontScaleController.max);
      container.read(fontScaleProvider.notifier).set(0.1);
      expect(container.read(fontScaleProvider), FontScaleController.min);
    });
  });
}
