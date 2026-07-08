import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI 语言,默认繁体(PRD §11 NFR);后续接 profiles.locale 云端同步
class LocaleController extends Notifier<Locale> {
  static const zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  static const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  @override
  Locale build() => zhHant;

  void set(Locale locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// 全局字号缩放(可访问性:大字体适老);后续接 profiles.font_scale 云端同步
class FontScaleController extends Notifier<double> {
  static const min = 0.8;
  static const max = 2.0;

  @override
  double build() => 1.0;

  void set(double scale) => state = scale.clamp(min, max);
}

final fontScaleProvider = NotifierProvider<FontScaleController, double>(FontScaleController.new);
