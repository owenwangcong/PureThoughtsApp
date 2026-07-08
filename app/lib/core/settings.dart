import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';

/// 本地偏好键名(云端对应 profiles 表,登录后经 profile_sync 同步)
abstract final class PrefKeys {
  static const locale = 'locale'; // 'zh_Hant' | 'zh_Hans'
  static const fontScale = 'font_scale';
  static const region = 'region'; // 'cn' | 'other'
  static const onboardingDone = 'onboarding_done';
}

/// UI 语言,默认繁体(PRD §11)
class LocaleController extends Notifier<Locale> {
  static const zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  static const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  @override
  Locale build() =>
      ref.watch(sharedPrefsProvider).getString(PrefKeys.locale) == 'zh_Hans' ? zhHans : zhHant;

  void set(Locale locale) {
    state = locale;
    ref
        .read(sharedPrefsProvider)
        .setString(PrefKeys.locale, locale.scriptCode == 'Hans' ? 'zh_Hans' : 'zh_Hant');
  }

  /// 云端 profiles.locale 的取值
  String get dbValue => state.scriptCode == 'Hans' ? 'zh_Hans' : 'zh_Hant';
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// 全局字号缩放(可访问性:大字体适老)
class FontScaleController extends Notifier<double> {
  static const min = 0.8;
  static const max = 2.0;

  @override
  double build() =>
      (ref.watch(sharedPrefsProvider).getDouble(PrefKeys.fontScale) ?? 1.0).clamp(min, max);

  void set(double scale) {
    state = scale.clamp(min, max);
    ref.read(sharedPrefsProvider).setDouble(PrefKeys.fontScale, state);
  }
}

final fontScaleProvider = NotifierProvider<FontScaleController, double>(FontScaleController.new);

/// 所在地区:决定通知送达方式(PRD §5.1,大陆以 App 内通知 + 邮件为主)
class RegionController extends Notifier<String> {
  @override
  String build() => ref.watch(sharedPrefsProvider).getString(PrefKeys.region) ?? 'other';

  void set(String region) {
    assert(region == 'cn' || region == 'other');
    state = region;
    ref.read(sharedPrefsProvider).setString(PrefKeys.region, region);
  }
}

final regionProvider = NotifierProvider<RegionController, String>(RegionController.new);

/// 首启引导是否完成(语言 → 字号 → 地区,PRD §11)
class OnboardingDoneController extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPrefsProvider).getBool(PrefKeys.onboardingDone) ?? false;

  void markDone() {
    state = true;
    ref.read(sharedPrefsProvider).setBool(PrefKeys.onboardingDone, true);
  }
}

final onboardingDoneProvider =
    NotifierProvider<OnboardingDoneController, bool>(OnboardingDoneController.new);
