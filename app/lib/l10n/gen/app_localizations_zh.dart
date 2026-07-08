// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '善護念';

  @override
  String get practiceListTitle => '功課清單';

  @override
  String get loadFailed => '載入失敗,請重試';

  @override
  String get retry => '重試';

  @override
  String get emptyList => '暫無資料';

  @override
  String get unitVolume => '部';

  @override
  String get unitRecitation => '遍';

  @override
  String get unitCount => '次';

  @override
  String get unitMinute => '分鐘';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get appTitle => '善护念';

  @override
  String get practiceListTitle => '功课清单';

  @override
  String get loadFailed => '加载失败,请重试';

  @override
  String get retry => '重试';

  @override
  String get emptyList => '暂无资料';

  @override
  String get unitVolume => '部';

  @override
  String get unitRecitation => '遍';

  @override
  String get unitCount => '次';

  @override
  String get unitMinute => '分钟';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => '善護念';

  @override
  String get practiceListTitle => '功課清單';

  @override
  String get loadFailed => '載入失敗,請重試';

  @override
  String get retry => '重試';

  @override
  String get emptyList => '暫無資料';

  @override
  String get unitVolume => '部';

  @override
  String get unitRecitation => '遍';

  @override
  String get unitCount => '次';

  @override
  String get unitMinute => '分鐘';
}
