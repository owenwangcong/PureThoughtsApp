import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/core/monday_material_localizations.dart';

void main() {
  const delegate = MondayFirstMaterialLocalizationsDelegate();

  const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  const hans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  test('仅支持 zh 语系', () {
    expect(delegate.isSupported(hant), true);
    expect(delegate.isSupported(hans), true);
    expect(delegate.isSupported(const Locale('en')), false);
  });

  test('繁/简日期选择器均以周一开头,其余文案不受影响', () async {
    for (final locale in [hant, hans]) {
      final l = await delegate.load(locale);
      expect(l.firstDayOfWeekIndex, DateTime.monday % 7,
          reason: '$locale 应为周一开头(1),与主日历一致');
      expect(l.okButtonLabel, isNotEmpty, reason: '常规文案应正常加载');
      expect(l.narrowWeekdays.length, 7);
      // narrowWeekdays 以周日起始存储,配合 index=1 时选择器首列应渲染「一」
      expect(l.narrowWeekdays[l.firstDayOfWeekIndex], '一');
    }
  });
}
