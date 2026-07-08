import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'善護念'**
  String get appTitle;

  /// No description provided for @practiceListTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'功課清單'**
  String get practiceListTitle;

  /// No description provided for @loadFailed.
  ///
  /// In zh_Hant, this message translates to:
  /// **'載入失敗,請重試'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In zh_Hant, this message translates to:
  /// **'重試'**
  String get retry;

  /// No description provided for @emptyList.
  ///
  /// In zh_Hant, this message translates to:
  /// **'暫無資料'**
  String get emptyList;

  /// No description provided for @unitVolume.
  ///
  /// In zh_Hant, this message translates to:
  /// **'部'**
  String get unitVolume;

  /// No description provided for @unitRecitation.
  ///
  /// In zh_Hant, this message translates to:
  /// **'遍'**
  String get unitRecitation;

  /// No description provided for @unitCount.
  ///
  /// In zh_Hant, this message translates to:
  /// **'次'**
  String get unitCount;

  /// No description provided for @unitMinute.
  ///
  /// In zh_Hant, this message translates to:
  /// **'分鐘'**
  String get unitMinute;

  /// No description provided for @authSignIn.
  ///
  /// In zh_Hant, this message translates to:
  /// **'登入'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In zh_Hant, this message translates to:
  /// **'註冊'**
  String get authSignUp;

  /// No description provided for @authSignOut.
  ///
  /// In zh_Hant, this message translates to:
  /// **'登出'**
  String get authSignOut;

  /// No description provided for @authEmail.
  ///
  /// In zh_Hant, this message translates to:
  /// **'電子郵箱'**
  String get authEmail;

  /// No description provided for @authEmailInvalid.
  ///
  /// In zh_Hant, this message translates to:
  /// **'請輸入有效的電子郵箱'**
  String get authEmailInvalid;

  /// No description provided for @authPassword.
  ///
  /// In zh_Hant, this message translates to:
  /// **'密碼'**
  String get authPassword;

  /// No description provided for @authPasswordMin.
  ///
  /// In zh_Hant, this message translates to:
  /// **'密碼至少 6 位'**
  String get authPasswordMin;

  /// No description provided for @authForgot.
  ///
  /// In zh_Hant, this message translates to:
  /// **'忘記密碼?'**
  String get authForgot;

  /// No description provided for @authResetSent.
  ///
  /// In zh_Hant, this message translates to:
  /// **'重設密碼郵件已發送,請查收'**
  String get authResetSent;

  /// No description provided for @authToSignUp.
  ///
  /// In zh_Hant, this message translates to:
  /// **'沒有帳號?註冊'**
  String get authToSignUp;

  /// No description provided for @authToSignIn.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已有帳號?登入'**
  String get authToSignIn;

  /// No description provided for @authFailed.
  ///
  /// In zh_Hant, this message translates to:
  /// **'操作失敗:'**
  String get authFailed;

  /// No description provided for @next.
  ///
  /// In zh_Hant, this message translates to:
  /// **'下一步'**
  String get next;

  /// No description provided for @done.
  ///
  /// In zh_Hant, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @onboardingLanguage.
  ///
  /// In zh_Hant, this message translates to:
  /// **'選擇語言'**
  String get onboardingLanguage;

  /// No description provided for @onboardingFont.
  ///
  /// In zh_Hant, this message translates to:
  /// **'選擇字號'**
  String get onboardingFont;

  /// No description provided for @onboardingFontPreview.
  ///
  /// In zh_Hant, this message translates to:
  /// **'諸惡莫作,眾善奉行'**
  String get onboardingFontPreview;

  /// No description provided for @onboardingRegion.
  ///
  /// In zh_Hant, this message translates to:
  /// **'所在地區'**
  String get onboardingRegion;

  /// No description provided for @onboardingRegionHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'用於選擇通知送達方式(大陸地區以應用內通知與郵件為主)'**
  String get onboardingRegionHint;

  /// No description provided for @regionCn.
  ///
  /// In zh_Hant, this message translates to:
  /// **'中國大陸'**
  String get regionCn;

  /// No description provided for @regionOther.
  ///
  /// In zh_Hant, this message translates to:
  /// **'其他地區'**
  String get regionOther;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
