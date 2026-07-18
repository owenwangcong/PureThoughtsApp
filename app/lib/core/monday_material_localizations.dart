import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

/// 让系统日期选择器(showDatePicker 等)以**周一**开头(2026-07-18 用户需求)。
///
/// zh 语系的 CLDR 周起始日是周日,与主日历(TableCalendar,周一开头)不一致;
/// SDK 未暴露参数,选择器读的是 `MaterialLocalizations.firstDayOfWeekIndex`,
/// 故覆写 zh 系本地化类的该 getter。用法:main.dart 的 localizationsDelegates
/// 里把 [MondayFirstMaterialLocalizationsDelegate] 放在默认委托**之前**
/// (Localizations 取首个支持该 locale 的委托)。
class MondayFirstMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const MondayFirstMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zh';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // 先走官方委托:确保 intl 的日期数据按 flutter_localizations 的方式初始化,
    // 之后用同名 locale 构造的 DateFormat 与官方完全一致
    await GlobalMaterialLocalizations.delegate.load(locale);
    final localeName = intl.Intl.canonicalizedLocale(locale.toString());
    // 与官方委托同一套格式选择逻辑(localeExists 回退链)
    final String dateLocale = intl.DateFormat.localeExists(localeName)
        ? localeName
        : (intl.DateFormat.localeExists(locale.languageCode)
            ? locale.languageCode
            : intl.Intl.defaultLocale ?? 'zh');
    final String numLocale = intl.NumberFormat.localeExists(localeName)
        ? localeName
        : (intl.NumberFormat.localeExists(locale.languageCode)
            ? locale.languageCode
            : intl.Intl.defaultLocale ?? 'zh');

    final fullYearFormat = intl.DateFormat.y(dateLocale);
    final compactDateFormat = intl.DateFormat.yMd(dateLocale);
    final shortDateFormat = intl.DateFormat.yMMMd(dateLocale);
    final mediumDateFormat = intl.DateFormat.MMMEd(dateLocale);
    final longDateFormat = intl.DateFormat.yMMMMEEEEd(dateLocale);
    final yearMonthFormat = intl.DateFormat.yMMMM(dateLocale);
    final shortMonthDayFormat = intl.DateFormat.MMMd(dateLocale);
    final decimalFormat = intl.NumberFormat.decimalPattern(numLocale);
    final twoDigitZeroPaddedFormat = intl.NumberFormat('00', numLocale);

    return switch (locale.scriptCode) {
      'Hant' => _MondayZhHant(
          fullYearFormat: fullYearFormat,
          compactDateFormat: compactDateFormat,
          shortDateFormat: shortDateFormat,
          mediumDateFormat: mediumDateFormat,
          longDateFormat: longDateFormat,
          yearMonthFormat: yearMonthFormat,
          shortMonthDayFormat: shortMonthDayFormat,
          decimalFormat: decimalFormat,
          twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
        ),
      'Hans' => _MondayZhHans(
          fullYearFormat: fullYearFormat,
          compactDateFormat: compactDateFormat,
          shortDateFormat: shortDateFormat,
          mediumDateFormat: mediumDateFormat,
          longDateFormat: longDateFormat,
          yearMonthFormat: yearMonthFormat,
          shortMonthDayFormat: shortMonthDayFormat,
          decimalFormat: decimalFormat,
          twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
        ),
      _ => _MondayZh(
          fullYearFormat: fullYearFormat,
          compactDateFormat: compactDateFormat,
          shortDateFormat: shortDateFormat,
          mediumDateFormat: mediumDateFormat,
          longDateFormat: longDateFormat,
          yearMonthFormat: yearMonthFormat,
          shortMonthDayFormat: shortMonthDayFormat,
          decimalFormat: decimalFormat,
          twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
        ),
    };
  }

  @override
  bool shouldReload(MondayFirstMaterialLocalizationsDelegate old) => false;
}

const int _monday = DateTime.monday % DateTime.daysPerWeek; // 1(0=周日)

class _MondayZh extends MaterialLocalizationZh {
  const _MondayZh({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  int get firstDayOfWeekIndex => _monday;
}

class _MondayZhHans extends MaterialLocalizationZhHans {
  const _MondayZhHans({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  int get firstDayOfWeekIndex => _monday;
}

class _MondayZhHant extends MaterialLocalizationZhHant {
  const _MondayZhHant({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  int get firstDayOfWeekIndex => _monday;
}
