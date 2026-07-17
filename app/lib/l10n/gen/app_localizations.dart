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

  /// No description provided for @authUsername.
  ///
  /// In zh_Hant, this message translates to:
  /// **'用戶名或郵箱'**
  String get authUsername;

  /// No description provided for @authUsernameHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'3–30 位小寫字母、數字或 . _ -;也可直接用郵箱'**
  String get authUsernameHint;

  /// No description provided for @authUsernameInvalid.
  ///
  /// In zh_Hant, this message translates to:
  /// **'用戶名需 3–30 位字母、數字或 . _ -(或有效郵箱)'**
  String get authUsernameInvalid;

  /// No description provided for @authRecoveryEmail.
  ///
  /// In zh_Hant, this message translates to:
  /// **'電郵(選填)'**
  String get authRecoveryEmail;

  /// No description provided for @authRecoveryEmailHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'僅用於忘記密碼時找回,可不填'**
  String get authRecoveryEmailHint;

  /// No description provided for @authResetNeedAdmin.
  ///
  /// In zh_Hant, this message translates to:
  /// **'此帳號未綁定郵箱,請聯繫群主或管理員重置密碼'**
  String get authResetNeedAdmin;

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

  /// No description provided for @settingsTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'設定'**
  String get settingsTitle;

  /// No description provided for @displayName.
  ///
  /// In zh_Hant, this message translates to:
  /// **'顯示名稱'**
  String get displayName;

  /// No description provided for @save.
  ///
  /// In zh_Hant, this message translates to:
  /// **'儲存'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已儲存'**
  String get saved;

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

  /// No description provided for @groupsTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'我的群組'**
  String get groupsTitle;

  /// No description provided for @createGroup.
  ///
  /// In zh_Hant, this message translates to:
  /// **'建立群組'**
  String get createGroup;

  /// No description provided for @joinGroup.
  ///
  /// In zh_Hant, this message translates to:
  /// **'申請入群'**
  String get joinGroup;

  /// No description provided for @groupName.
  ///
  /// In zh_Hant, this message translates to:
  /// **'群組名稱'**
  String get groupName;

  /// No description provided for @groupDescription.
  ///
  /// In zh_Hant, this message translates to:
  /// **'群組簡介'**
  String get groupDescription;

  /// No description provided for @joinCodeLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'群 ID'**
  String get joinCodeLabel;

  /// No description provided for @applyMessageLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'申請說明'**
  String get applyMessageLabel;

  /// No description provided for @submit.
  ///
  /// In zh_Hant, this message translates to:
  /// **'提交'**
  String get submit;

  /// No description provided for @cancel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @statusPending.
  ///
  /// In zh_Hant, this message translates to:
  /// **'審核中'**
  String get statusPending;

  /// No description provided for @roleOwner.
  ///
  /// In zh_Hant, this message translates to:
  /// **'群主'**
  String get roleOwner;

  /// No description provided for @members.
  ///
  /// In zh_Hant, this message translates to:
  /// **'成員'**
  String get members;

  /// No description provided for @pendingApplications.
  ///
  /// In zh_Hant, this message translates to:
  /// **'入群審核'**
  String get pendingApplications;

  /// No description provided for @approve.
  ///
  /// In zh_Hant, this message translates to:
  /// **'通過'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In zh_Hant, this message translates to:
  /// **'拒絕'**
  String get reject;

  /// No description provided for @copied.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已複製'**
  String get copied;

  /// No description provided for @joinRequested.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已提交申請,等待群主審核'**
  String get joinRequested;

  /// No description provided for @groupCreated.
  ///
  /// In zh_Hant, this message translates to:
  /// **'群組已建立'**
  String get groupCreated;

  /// No description provided for @announcement.
  ///
  /// In zh_Hant, this message translates to:
  /// **'公告'**
  String get announcement;

  /// No description provided for @editAnnouncement.
  ///
  /// In zh_Hant, this message translates to:
  /// **'編輯公告'**
  String get editAnnouncement;

  /// No description provided for @leaveGroup.
  ///
  /// In zh_Hant, this message translates to:
  /// **'退出群組'**
  String get leaveGroup;

  /// No description provided for @removeMember.
  ///
  /// In zh_Hant, this message translates to:
  /// **'移除成員'**
  String get removeMember;

  /// No description provided for @transferOwner.
  ///
  /// In zh_Hant, this message translates to:
  /// **'轉讓群主'**
  String get transferOwner;

  /// No description provided for @dissolveGroup.
  ///
  /// In zh_Hant, this message translates to:
  /// **'解散群組'**
  String get dissolveGroup;

  /// No description provided for @resetJoinCode.
  ///
  /// In zh_Hant, this message translates to:
  /// **'重置群 ID'**
  String get resetJoinCode;

  /// No description provided for @confirmLeave.
  ///
  /// In zh_Hant, this message translates to:
  /// **'確定退出此群組?歷史報數將保留。'**
  String get confirmLeave;

  /// No description provided for @confirmRemove.
  ///
  /// In zh_Hant, this message translates to:
  /// **'確定移除該成員?其歷史報數將保留。'**
  String get confirmRemove;

  /// No description provided for @confirmTransfer.
  ///
  /// In zh_Hant, this message translates to:
  /// **'確定將群主轉讓給此成員?轉讓後您將成為普通成員。'**
  String get confirmTransfer;

  /// No description provided for @confirmDissolve.
  ///
  /// In zh_Hant, this message translates to:
  /// **'解散後群組對所有成員不可見,且無法恢復。確定解散?'**
  String get confirmDissolve;

  /// No description provided for @confirmResetCode.
  ///
  /// In zh_Hant, this message translates to:
  /// **'舊群 ID 將立即失效,確定重置?'**
  String get confirmResetCode;

  /// No description provided for @groupPracticeTypes.
  ///
  /// In zh_Hant, this message translates to:
  /// **'本群功課項'**
  String get groupPracticeTypes;

  /// No description provided for @addPracticeType.
  ///
  /// In zh_Hant, this message translates to:
  /// **'新增功課項'**
  String get addPracticeType;

  /// No description provided for @practiceTypeName.
  ///
  /// In zh_Hant, this message translates to:
  /// **'名稱'**
  String get practiceTypeName;

  /// No description provided for @unitTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'單位'**
  String get unitTitle;

  /// No description provided for @reportLog.
  ///
  /// In zh_Hant, this message translates to:
  /// **'報數'**
  String get reportLog;

  /// No description provided for @logsTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'報數記錄'**
  String get logsTitle;

  /// No description provided for @selectPracticeType.
  ///
  /// In zh_Hant, this message translates to:
  /// **'選擇功課'**
  String get selectPracticeType;

  /// No description provided for @subjectTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'為誰報數'**
  String get subjectTitle;

  /// No description provided for @subjectSelf.
  ///
  /// In zh_Hant, this message translates to:
  /// **'自己'**
  String get subjectSelf;

  /// No description provided for @subjectMember.
  ///
  /// In zh_Hant, this message translates to:
  /// **'群成員'**
  String get subjectMember;

  /// No description provided for @subjectName.
  ///
  /// In zh_Hant, this message translates to:
  /// **'其他名字'**
  String get subjectName;

  /// No description provided for @quantityTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'數量'**
  String get quantityTitle;

  /// No description provided for @noteLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'備註(選填;補報可註明實際日期)'**
  String get noteLabel;

  /// No description provided for @submitLog.
  ///
  /// In zh_Hant, this message translates to:
  /// **'提交報數'**
  String get submitLog;

  /// No description provided for @logSubmitted.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已報數,隨喜讚歎!'**
  String get logSubmitted;

  /// No description provided for @offlineQueued.
  ///
  /// In zh_Hant, this message translates to:
  /// **'網絡不通,已離線暫存,連網後自動補傳'**
  String get offlineQueued;

  /// No description provided for @offlineFlushed.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已補傳離線報數'**
  String get offlineFlushed;

  /// No description provided for @quantityInvalid.
  ///
  /// In zh_Hant, this message translates to:
  /// **'請輸入正確的數量'**
  String get quantityInvalid;

  /// No description provided for @edit.
  ///
  /// In zh_Hant, this message translates to:
  /// **'編輯'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In zh_Hant, this message translates to:
  /// **'刪除'**
  String get delete;

  /// No description provided for @confirmDeleteLog.
  ///
  /// In zh_Hant, this message translates to:
  /// **'確定刪除這條報數?統計將即時扣減。'**
  String get confirmDeleteLog;

  /// No description provided for @proxyBy.
  ///
  /// In zh_Hant, this message translates to:
  /// **'代報'**
  String get proxyBy;

  /// No description provided for @fellowPractitioner.
  ///
  /// In zh_Hant, this message translates to:
  /// **'同修'**
  String get fellowPractitioner;

  /// No description provided for @categoryTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'分類'**
  String get categoryTitle;

  /// No description provided for @categorySutra.
  ///
  /// In zh_Hant, this message translates to:
  /// **'經'**
  String get categorySutra;

  /// No description provided for @categoryMantra.
  ///
  /// In zh_Hant, this message translates to:
  /// **'咒'**
  String get categoryMantra;

  /// No description provided for @categoryRepentance.
  ///
  /// In zh_Hant, this message translates to:
  /// **'懺'**
  String get categoryRepentance;

  /// No description provided for @categoryBuddhaName.
  ///
  /// In zh_Hant, this message translates to:
  /// **'念佛'**
  String get categoryBuddhaName;

  /// No description provided for @categoryMeditation.
  ///
  /// In zh_Hant, this message translates to:
  /// **'靜坐'**
  String get categoryMeditation;

  /// No description provided for @categoryOther.
  ///
  /// In zh_Hant, this message translates to:
  /// **'其他'**
  String get categoryOther;

  /// No description provided for @quickReport.
  ///
  /// In zh_Hant, this message translates to:
  /// **'快捷報數'**
  String get quickReport;

  /// No description provided for @myStats.
  ///
  /// In zh_Hant, this message translates to:
  /// **'個人統計'**
  String get myStats;

  /// No description provided for @groupStats.
  ///
  /// In zh_Hant, this message translates to:
  /// **'群統計'**
  String get groupStats;

  /// No description provided for @todayTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'今日'**
  String get todayTitle;

  /// No description provided for @totalTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'累計'**
  String get totalTitle;

  /// No description provided for @streakLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'連續用功天數'**
  String get streakLabel;

  /// No description provided for @trend14.
  ///
  /// In zh_Hant, this message translates to:
  /// **'近 14 天趨勢(筆數)'**
  String get trend14;

  /// No description provided for @historyTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'歷史查看'**
  String get historyTitle;

  /// No description provided for @pickDate.
  ///
  /// In zh_Hant, this message translates to:
  /// **'選擇日期'**
  String get pickDate;

  /// No description provided for @noDataToday.
  ///
  /// In zh_Hant, this message translates to:
  /// **'今日尚未報數'**
  String get noDataToday;

  /// No description provided for @reportedToday.
  ///
  /// In zh_Hant, this message translates to:
  /// **'今日已報人數'**
  String get reportedToday;

  /// No description provided for @reportAction.
  ///
  /// In zh_Hant, this message translates to:
  /// **'檢舉'**
  String get reportAction;

  /// No description provided for @reportGroup.
  ///
  /// In zh_Hant, this message translates to:
  /// **'檢舉群組'**
  String get reportGroup;

  /// No description provided for @reportReasonLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'原因'**
  String get reportReasonLabel;

  /// No description provided for @reportSubmitted.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已提交檢舉,管理員會盡快處理'**
  String get reportSubmitted;

  /// No description provided for @blockUser.
  ///
  /// In zh_Hant, this message translates to:
  /// **'封鎖此用戶'**
  String get blockUser;

  /// No description provided for @unblockUser.
  ///
  /// In zh_Hant, this message translates to:
  /// **'解除封鎖'**
  String get unblockUser;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh_Hant, this message translates to:
  /// **'隱私政策'**
  String get privacyPolicy;

  /// No description provided for @communityGuidelines.
  ///
  /// In zh_Hant, this message translates to:
  /// **'社區規範'**
  String get communityGuidelines;

  /// No description provided for @eulaAgreeFinish.
  ///
  /// In zh_Hant, this message translates to:
  /// **'同意並完成'**
  String get eulaAgreeFinish;

  /// No description provided for @deleteAccount.
  ///
  /// In zh_Hant, this message translates to:
  /// **'刪除帳號'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarn.
  ///
  /// In zh_Hant, this message translates to:
  /// **'帳號與個人資料將被永久刪除,無法恢復;您的歷史報數將匿名保留於群統計中。確定刪除?'**
  String get deleteAccountWarn;

  /// No description provided for @deleteOwnerBlocked.
  ///
  /// In zh_Hant, this message translates to:
  /// **'您仍是群組群主,請先轉讓或解散群組,再刪除帳號。'**
  String get deleteOwnerBlocked;

  /// No description provided for @adminReports.
  ///
  /// In zh_Hant, this message translates to:
  /// **'檢舉處理'**
  String get adminReports;

  /// No description provided for @markResolved.
  ///
  /// In zh_Hant, this message translates to:
  /// **'標記已處理'**
  String get markResolved;

  /// No description provided for @banUser.
  ///
  /// In zh_Hant, this message translates to:
  /// **'封禁該用戶'**
  String get banUser;

  /// No description provided for @repeatLast.
  ///
  /// In zh_Hant, this message translates to:
  /// **'重複上次'**
  String get repeatLast;

  /// No description provided for @forOthers.
  ///
  /// In zh_Hant, this message translates to:
  /// **'替他人報數'**
  String get forOthers;

  /// No description provided for @frequentGroup.
  ///
  /// In zh_Hant, this message translates to:
  /// **'常用'**
  String get frequentGroup;

  /// No description provided for @chooseGroup.
  ///
  /// In zh_Hant, this message translates to:
  /// **'選擇群組'**
  String get chooseGroup;

  /// No description provided for @notificationsTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'通知'**
  String get notificationsTitle;

  /// No description provided for @notifProxyLog.
  ///
  /// In zh_Hant, this message translates to:
  /// **'有同修為您代報'**
  String get notifProxyLog;

  /// No description provided for @notifAnnouncement.
  ///
  /// In zh_Hant, this message translates to:
  /// **'群公告更新'**
  String get notifAnnouncement;

  /// No description provided for @vowsTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'我的發願'**
  String get vowsTitle;

  /// No description provided for @createVow.
  ///
  /// In zh_Hant, this message translates to:
  /// **'發願'**
  String get createVow;

  /// No description provided for @vowTarget.
  ///
  /// In zh_Hant, this message translates to:
  /// **'目標數量'**
  String get vowTarget;

  /// No description provided for @vowPeriod.
  ///
  /// In zh_Hant, this message translates to:
  /// **'期限'**
  String get vowPeriod;

  /// No description provided for @vowScope.
  ///
  /// In zh_Hant, this message translates to:
  /// **'範圍'**
  String get vowScope;

  /// No description provided for @scopeAllGroups.
  ///
  /// In zh_Hant, this message translates to:
  /// **'全部群組'**
  String get scopeAllGroups;

  /// No description provided for @daysUnit.
  ///
  /// In zh_Hant, this message translates to:
  /// **'天'**
  String get daysUnit;

  /// No description provided for @daysLeft.
  ///
  /// In zh_Hant, this message translates to:
  /// **'剩餘 {days} 天'**
  String daysLeft(int days);

  /// No description provided for @vowCompleted.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已圓滿'**
  String get vowCompleted;

  /// No description provided for @vowExpired.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已到期'**
  String get vowExpired;

  /// No description provided for @vowCongrats.
  ///
  /// In zh_Hant, this message translates to:
  /// **'隨喜讚歎!發願圓滿'**
  String get vowCongrats;

  /// No description provided for @quickReportTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'快捷報數'**
  String get quickReportTitle;

  /// No description provided for @quickEmptyHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'還沒有常用組合,先報一次數,下次就能一鍵重複。'**
  String get quickEmptyHint;

  /// No description provided for @sectionDaily.
  ///
  /// In zh_Hant, this message translates to:
  /// **'日課'**
  String get sectionDaily;

  /// No description provided for @sectionSangha.
  ///
  /// In zh_Hant, this message translates to:
  /// **'共修'**
  String get sectionSangha;

  /// No description provided for @sectionSelf.
  ///
  /// In zh_Hant, this message translates to:
  /// **'修行'**
  String get sectionSelf;

  /// No description provided for @sectionGeneral.
  ///
  /// In zh_Hant, this message translates to:
  /// **'通用'**
  String get sectionGeneral;

  /// No description provided for @themeTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'外觀'**
  String get themeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In zh_Hant, this message translates to:
  /// **'跟隨系統'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh_Hant, this message translates to:
  /// **'淺色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh_Hant, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @groupsEmptyHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'輸入群 ID 申請加入,或建立新群組,與同修一起精進。'**
  String get groupsEmptyHint;

  /// No description provided for @logsEmptyHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'本群還沒有報數,點右下角「報數」開始。'**
  String get logsEmptyHint;

  /// No description provided for @vowsEmptyHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'發一個願,讓精進有方向。'**
  String get vowsEmptyHint;

  /// No description provided for @scripturesTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'在線經本'**
  String get scripturesTitle;

  /// No description provided for @liveTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'直播'**
  String get liveTitle;

  /// No description provided for @liveNow.
  ///
  /// In zh_Hant, this message translates to:
  /// **'直播中'**
  String get liveNow;

  /// No description provided for @notLive.
  ///
  /// In zh_Hant, this message translates to:
  /// **'目前未直播'**
  String get notLive;

  /// No description provided for @enterLive.
  ///
  /// In zh_Hant, this message translates to:
  /// **'進入直播'**
  String get enterLive;

  /// No description provided for @openChannel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'打開頻道'**
  String get openChannel;

  /// No description provided for @joinWebex.
  ///
  /// In zh_Hant, this message translates to:
  /// **'加入 Webex 共修'**
  String get joinWebex;

  /// No description provided for @webexOpenApp.
  ///
  /// In zh_Hant, this message translates to:
  /// **'用 Webex App 開啟'**
  String get webexOpenApp;

  /// No description provided for @webexHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'固定共修房間,開始時間見活動日曆'**
  String get webexHint;

  /// No description provided for @replaysTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'往期回看'**
  String get replaysTitle;

  /// No description provided for @notifLiveStarted.
  ///
  /// In zh_Hant, this message translates to:
  /// **'直播開始了'**
  String get notifLiveStarted;

  /// No description provided for @calendarTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'活動日曆'**
  String get calendarTitle;

  /// No description provided for @createEvent.
  ///
  /// In zh_Hant, this message translates to:
  /// **'新增活動'**
  String get createEvent;

  /// No description provided for @eventTitleLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'活動名稱'**
  String get eventTitleLabel;

  /// No description provided for @weeklyRepeat.
  ///
  /// In zh_Hant, this message translates to:
  /// **'每週重複'**
  String get weeklyRepeat;

  /// No description provided for @eventCancelled.
  ///
  /// In zh_Hant, this message translates to:
  /// **'本次取消'**
  String get eventCancelled;

  /// No description provided for @cancelOccurrence.
  ///
  /// In zh_Hant, this message translates to:
  /// **'取消本次活動'**
  String get cancelOccurrence;

  /// No description provided for @upcomingTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'未來活動'**
  String get upcomingTitle;

  /// No description provided for @manageEventTypes.
  ///
  /// In zh_Hant, this message translates to:
  /// **'事件類型管理'**
  String get manageEventTypes;

  /// No description provided for @editEvent.
  ///
  /// In zh_Hant, this message translates to:
  /// **'編輯活動'**
  String get editEvent;

  /// No description provided for @deleteEvent.
  ///
  /// In zh_Hant, this message translates to:
  /// **'刪除活動'**
  String get deleteEvent;

  /// No description provided for @confirmDeleteEvent.
  ///
  /// In zh_Hant, this message translates to:
  /// **'確定刪除此活動?所有重複場次將一併移除,並通知全體用戶。'**
  String get confirmDeleteEvent;

  /// No description provided for @typeNameHant.
  ///
  /// In zh_Hant, this message translates to:
  /// **'名稱(繁體)'**
  String get typeNameHant;

  /// No description provided for @typeNameHans.
  ///
  /// In zh_Hant, this message translates to:
  /// **'名稱(簡體)'**
  String get typeNameHans;

  /// No description provided for @iconLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'圖標'**
  String get iconLabel;

  /// No description provided for @activeLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'啟用'**
  String get activeLabel;

  /// No description provided for @deleteTypeBlocked.
  ///
  /// In zh_Hant, this message translates to:
  /// **'該類型已被活動使用,無法刪除;可改為停用。'**
  String get deleteTypeBlocked;

  /// No description provided for @notifEventChanged.
  ///
  /// In zh_Hant, this message translates to:
  /// **'活動異動'**
  String get notifEventChanged;

  /// No description provided for @actCreated.
  ///
  /// In zh_Hant, this message translates to:
  /// **'新增'**
  String get actCreated;

  /// No description provided for @actUpdated.
  ///
  /// In zh_Hant, this message translates to:
  /// **'更新'**
  String get actUpdated;

  /// No description provided for @actDeleted.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已取消'**
  String get actDeleted;

  /// No description provided for @actOccCancelled.
  ///
  /// In zh_Hant, this message translates to:
  /// **'單次取消'**
  String get actOccCancelled;

  /// No description provided for @actOccChanged.
  ///
  /// In zh_Hant, this message translates to:
  /// **'單次改期'**
  String get actOccChanged;

  /// No description provided for @toolsTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'工具'**
  String get toolsTitle;

  /// No description provided for @timerTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'打坐計時'**
  String get timerTitle;

  /// No description provided for @counterTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'念珠計數'**
  String get counterTitle;

  /// No description provided for @startTimer.
  ///
  /// In zh_Hant, this message translates to:
  /// **'開始'**
  String get startTimer;

  /// No description provided for @stopTimer.
  ///
  /// In zh_Hant, this message translates to:
  /// **'結束'**
  String get stopTimer;

  /// No description provided for @timeUp.
  ///
  /// In zh_Hant, this message translates to:
  /// **'時間到'**
  String get timeUp;

  /// No description provided for @intervalBell.
  ///
  /// In zh_Hant, this message translates to:
  /// **'中途鈴(正念提醒)'**
  String get intervalBell;

  /// No description provided for @prepBell.
  ///
  /// In zh_Hant, this message translates to:
  /// **'預備鈴'**
  String get prepBell;

  /// No description provided for @offLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'關閉'**
  String get offLabel;

  /// No description provided for @keepAwake.
  ///
  /// In zh_Hant, this message translates to:
  /// **'螢幕常亮'**
  String get keepAwake;

  /// No description provided for @keepForeground.
  ///
  /// In zh_Hant, this message translates to:
  /// **'計時期間請保持 App 開啟,螢幕會自動常亮'**
  String get keepForeground;

  /// No description provided for @tapToCount.
  ///
  /// In zh_Hant, this message translates to:
  /// **'點擊螢幕任意處計數'**
  String get tapToCount;

  /// No description provided for @roundsLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'串數'**
  String get roundsLabel;

  /// No description provided for @beadsTarget.
  ///
  /// In zh_Hant, this message translates to:
  /// **'一串'**
  String get beadsTarget;

  /// No description provided for @resetCount.
  ///
  /// In zh_Hant, this message translates to:
  /// **'清零'**
  String get resetCount;

  /// No description provided for @confirmReset.
  ///
  /// In zh_Hant, this message translates to:
  /// **'確定清零?'**
  String get confirmReset;

  /// No description provided for @soundToggle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'鈴聲'**
  String get soundToggle;

  /// No description provided for @toReport.
  ///
  /// In zh_Hant, this message translates to:
  /// **'轉為報數'**
  String get toReport;

  /// No description provided for @dedicationTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'迴向'**
  String get dedicationTitle;

  /// No description provided for @dedicationText.
  ///
  /// In zh_Hant, this message translates to:
  /// **'願以此功德,莊嚴佛淨土。\n上報四重恩,下濟三途苦。\n若有見聞者,悉發菩提心。\n盡此一報身,同生極樂國。'**
  String get dedicationText;

  /// No description provided for @errNetwork.
  ///
  /// In zh_Hant, this message translates to:
  /// **'網絡連接失敗,請檢查網絡後重試'**
  String get errNetwork;

  /// No description provided for @errGeneric.
  ///
  /// In zh_Hant, this message translates to:
  /// **'操作失敗,請稍後再試'**
  String get errGeneric;

  /// No description provided for @errAuthInvalidCredentials.
  ///
  /// In zh_Hant, this message translates to:
  /// **'用戶名或密碼錯誤'**
  String get errAuthInvalidCredentials;

  /// No description provided for @errAuthAlreadyRegistered.
  ///
  /// In zh_Hant, this message translates to:
  /// **'該帳號已被註冊,請直接登入'**
  String get errAuthAlreadyRegistered;

  /// No description provided for @errAuthWeakPassword.
  ///
  /// In zh_Hant, this message translates to:
  /// **'密碼至少 6 位'**
  String get errAuthWeakPassword;

  /// No description provided for @errAuthNotActivated.
  ///
  /// In zh_Hant, this message translates to:
  /// **'帳號尚未啟用,請聯繫管理員'**
  String get errAuthNotActivated;

  /// No description provided for @errAuthRateLimited.
  ///
  /// In zh_Hant, this message translates to:
  /// **'操作過於頻繁,請稍後再試'**
  String get errAuthRateLimited;

  /// No description provided for @errAuthSignupDisabled.
  ///
  /// In zh_Hant, this message translates to:
  /// **'暫未開放註冊'**
  String get errAuthSignupDisabled;

  /// No description provided for @errAuthBanned.
  ///
  /// In zh_Hant, this message translates to:
  /// **'帳號已被停用,請聯繫管理員'**
  String get errAuthBanned;

  /// No description provided for @errNoPermission.
  ///
  /// In zh_Hant, this message translates to:
  /// **'沒有權限執行此操作'**
  String get errNoPermission;

  /// No description provided for @errDuplicate.
  ///
  /// In zh_Hant, this message translates to:
  /// **'資料重複,請勿重複提交'**
  String get errDuplicate;

  /// No description provided for @errSessionExpired.
  ///
  /// In zh_Hant, this message translates to:
  /// **'登入已過期,請重新登入'**
  String get errSessionExpired;

  /// No description provided for @mrTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'正念提醒'**
  String get mrTitle;

  /// No description provided for @mrEnable.
  ///
  /// In zh_Hant, this message translates to:
  /// **'開啟正念提醒'**
  String get mrEnable;

  /// No description provided for @mrEnableHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'在設定的時段內定時響磬,提醒回到當下'**
  String get mrEnableHint;

  /// No description provided for @mrWeekdays.
  ///
  /// In zh_Hant, this message translates to:
  /// **'提醒日'**
  String get mrWeekdays;

  /// No description provided for @mrDay1.
  ///
  /// In zh_Hant, this message translates to:
  /// **'一'**
  String get mrDay1;

  /// No description provided for @mrDay2.
  ///
  /// In zh_Hant, this message translates to:
  /// **'二'**
  String get mrDay2;

  /// No description provided for @mrDay3.
  ///
  /// In zh_Hant, this message translates to:
  /// **'三'**
  String get mrDay3;

  /// No description provided for @mrDay4.
  ///
  /// In zh_Hant, this message translates to:
  /// **'四'**
  String get mrDay4;

  /// No description provided for @mrDay5.
  ///
  /// In zh_Hant, this message translates to:
  /// **'五'**
  String get mrDay5;

  /// No description provided for @mrDay6.
  ///
  /// In zh_Hant, this message translates to:
  /// **'六'**
  String get mrDay6;

  /// No description provided for @mrDay7.
  ///
  /// In zh_Hant, this message translates to:
  /// **'日'**
  String get mrDay7;

  /// No description provided for @mrStart.
  ///
  /// In zh_Hant, this message translates to:
  /// **'開始時間'**
  String get mrStart;

  /// No description provided for @mrEnd.
  ///
  /// In zh_Hant, this message translates to:
  /// **'結束時間'**
  String get mrEnd;

  /// No description provided for @mrWindowInvalid.
  ///
  /// In zh_Hant, this message translates to:
  /// **'結束時間需晚於開始時間'**
  String get mrWindowInvalid;

  /// No description provided for @mrInterval.
  ///
  /// In zh_Hant, this message translates to:
  /// **'間隔'**
  String get mrInterval;

  /// No description provided for @mrSound.
  ///
  /// In zh_Hant, this message translates to:
  /// **'提示音'**
  String get mrSound;

  /// No description provided for @mrSoundBell.
  ///
  /// In zh_Hant, this message translates to:
  /// **'磬聲'**
  String get mrSoundBell;

  /// No description provided for @mrSoundSilent.
  ///
  /// In zh_Hant, this message translates to:
  /// **'靜音'**
  String get mrSoundSilent;

  /// No description provided for @mrVibrate.
  ///
  /// In zh_Hant, this message translates to:
  /// **'震動'**
  String get mrVibrate;

  /// No description provided for @mrPreviewSound.
  ///
  /// In zh_Hant, this message translates to:
  /// **'試聽'**
  String get mrPreviewSound;

  /// No description provided for @mrMessage.
  ///
  /// In zh_Hant, this message translates to:
  /// **'提醒文案'**
  String get mrMessage;

  /// No description provided for @mrMessageDefault.
  ///
  /// In zh_Hant, this message translates to:
  /// **'該正念了 · 回到當下'**
  String get mrMessageDefault;

  /// No description provided for @mrMessageHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'留空則用預設文案'**
  String get mrMessageHint;

  /// No description provided for @mrCountSummary.
  ///
  /// In zh_Hant, this message translates to:
  /// **'每天 {daily} 次 · 本週共 {total} 次'**
  String mrCountSummary(int daily, int total);

  /// No description provided for @mrIosCapWarning.
  ///
  /// In zh_Hant, this message translates to:
  /// **'iOS 最多 {cap} 條通知,目前 {total} 條會被截斷;請增大間隔或縮短時段'**
  String mrIosCapWarning(int cap, int total);

  /// No description provided for @mrTest.
  ///
  /// In zh_Hant, this message translates to:
  /// **'立即測試'**
  String get mrTest;

  /// No description provided for @mrTestSent.
  ///
  /// In zh_Hant, this message translates to:
  /// **'測試通知已發送'**
  String get mrTestSent;

  /// No description provided for @mrHelp.
  ///
  /// In zh_Hant, this message translates to:
  /// **'讓提醒準時響起'**
  String get mrHelp;

  /// No description provided for @mrHelpSubtitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'iOS 與 Android 設定指引'**
  String get mrHelpSubtitle;

  /// No description provided for @mrPermDenied.
  ///
  /// In zh_Hant, this message translates to:
  /// **'通知權限未開啟,提醒無法響起'**
  String get mrPermDenied;

  /// No description provided for @mrGrant.
  ///
  /// In zh_Hant, this message translates to:
  /// **'去開啟'**
  String get mrGrant;

  /// No description provided for @mrRespectSilent.
  ///
  /// In zh_Hant, this message translates to:
  /// **'手機靜音或勿擾時不會出聲,僅顯示橫幅(尊重系統設定)'**
  String get mrRespectSilent;

  /// No description provided for @mrHelpIntro.
  ///
  /// In zh_Hant, this message translates to:
  /// **'提醒靠系統在預定時刻觸發。請按下面步驟放行,確保 App 關閉或息屏時也能響。'**
  String get mrHelpIntro;

  /// No description provided for @mrSelfCheck.
  ///
  /// In zh_Hant, this message translates to:
  /// **'響鈴自檢'**
  String get mrSelfCheck;

  /// No description provided for @mrSelfCheckHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'點一下發一條測試通知,看是否真的響了。'**
  String get mrSelfCheckHint;

  /// No description provided for @mrHelpIosTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'iOS 設定'**
  String get mrHelpIosTitle;

  /// No description provided for @mrHelpIosStep1.
  ///
  /// In zh_Hant, this message translates to:
  /// **'允許通知:首次開啟會彈窗;若曾拒絕,前往「設定 > 善護念 > 通知」開啟允許通知、聲音、鎖屏顯示。'**
  String get mrHelpIosStep1;

  /// No description provided for @mrHelpIosStep2.
  ///
  /// In zh_Hant, this message translates to:
  /// **'靜音/勿擾:處於靜音檔或勿擾時不會出聲(系統限制,非故障);需要出聲請退出靜音。'**
  String get mrHelpIosStep2;

  /// No description provided for @mrHelpIosStep3.
  ///
  /// In zh_Hant, this message translates to:
  /// **'專注模式:若開啟了工作/睡眠等專注,可能攔截通知,請把善護念加入允許清單。'**
  String get mrHelpIosStep3;

  /// No description provided for @mrHelpAndroidTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'Android 設定'**
  String get mrHelpAndroidTitle;

  /// No description provided for @mrHelpAndroidStep1.
  ///
  /// In zh_Hant, this message translates to:
  /// **'允許通知:在系統彈窗或「應用資訊 > 通知」中允許。'**
  String get mrHelpAndroidStep1;

  /// No description provided for @mrHelpAndroidStep2.
  ///
  /// In zh_Hant, this message translates to:
  /// **'電池不受限:關閉對本 App 的電池最佳化,否則後台可能被限制。'**
  String get mrHelpAndroidStep2;

  /// No description provided for @mrHelpAndroidStep3.
  ///
  /// In zh_Hant, this message translates to:
  /// **'勿擾說明:系統勿擾時不會出聲,僅顯示橫幅。'**
  String get mrHelpAndroidStep3;

  /// No description provided for @mrHelpOemTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'國產手機額外設定(小米/華為/OPPO/vivo 等)'**
  String get mrHelpOemTitle;

  /// No description provided for @mrHelpOemBody.
  ///
  /// In zh_Hant, this message translates to:
  /// **'這些手機預設會清理後台,可能延遲或漏掉提醒。請手動開啟:自啟動/自動啟動、允許後台活動(不受限制)、鎖定在最近任務、允許後台彈通知。即便全部放行,個別機型仍可能延遲——這是系統限制,非本 App 故障。'**
  String get mrHelpOemBody;

  /// No description provided for @mrOpenSettings.
  ///
  /// In zh_Hant, this message translates to:
  /// **'去應用設定'**
  String get mrOpenSettings;

  /// No description provided for @qaTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'往期問答'**
  String get qaTitle;

  /// No description provided for @qaEntryTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'往期問答檢索'**
  String get qaEntryTitle;

  /// No description provided for @qaEntrySubtitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'搜尋歷次講法問答片段'**
  String get qaEntrySubtitle;

  /// No description provided for @qaSearchHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'搜尋關鍵詞(2 字以上)'**
  String get qaSearchHint;

  /// No description provided for @qaTooShort.
  ///
  /// In zh_Hant, this message translates to:
  /// **'請輸入 2 個字以上'**
  String get qaTooShort;

  /// No description provided for @qaResultCount.
  ///
  /// In zh_Hant, this message translates to:
  /// **'共 {n} 條'**
  String qaResultCount(int n);

  /// No description provided for @qaEmpty.
  ///
  /// In zh_Hant, this message translates to:
  /// **'未找到相關內容'**
  String get qaEmpty;

  /// No description provided for @qaEmptyHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'試試其他關鍵詞,或清除標籤篩選'**
  String get qaEmptyHint;

  /// No description provided for @qaBackToList.
  ///
  /// In zh_Hant, this message translates to:
  /// **'返回列表'**
  String get qaBackToList;

  /// No description provided for @qaTagsAdd.
  ///
  /// In zh_Hant, this message translates to:
  /// **'標籤'**
  String get qaTagsAdd;

  /// No description provided for @qaTagPickerTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'選擇標籤'**
  String get qaTagPickerTitle;

  /// No description provided for @qaTagPickerHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'搜尋標籤'**
  String get qaTagPickerHint;

  /// No description provided for @qaTagPickerOr.
  ///
  /// In zh_Hant, this message translates to:
  /// **'選多個標籤時,符合任一即顯示'**
  String get qaTagPickerOr;

  /// No description provided for @qaTagPickerDone.
  ///
  /// In zh_Hant, this message translates to:
  /// **'完成({n})'**
  String qaTagPickerDone(int n);

  /// No description provided for @qaOpenExternal.
  ///
  /// In zh_Hant, this message translates to:
  /// **'用 YouTube App 開啟'**
  String get qaOpenExternal;

  /// No description provided for @qaFromVideo.
  ///
  /// In zh_Hant, this message translates to:
  /// **'出自「{title}」'**
  String qaFromVideo(String title);

  /// No description provided for @eventShare.
  ///
  /// In zh_Hant, this message translates to:
  /// **'分享'**
  String get eventShare;

  /// No description provided for @eventAgendaTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'時間表'**
  String get eventAgendaTitle;

  /// No description provided for @eventAttachmentsTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'相關資料'**
  String get eventAttachmentsTitle;

  /// No description provided for @eventCopy.
  ///
  /// In zh_Hant, this message translates to:
  /// **'複製'**
  String get eventCopy;

  /// No description provided for @eventCopied.
  ///
  /// In zh_Hant, this message translates to:
  /// **'已複製時間表'**
  String get eventCopied;

  /// No description provided for @eventLinkLabelDefault.
  ///
  /// In zh_Hant, this message translates to:
  /// **'查看'**
  String get eventLinkLabelDefault;

  /// No description provided for @eventAdminTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'管理員'**
  String get eventAdminTitle;

  /// No description provided for @eventEditAgenda.
  ///
  /// In zh_Hant, this message translates to:
  /// **'編輯時間表/資料'**
  String get eventEditAgenda;

  /// No description provided for @eventAddAgendaRow.
  ///
  /// In zh_Hant, this message translates to:
  /// **'新增一行'**
  String get eventAddAgendaRow;

  /// No description provided for @eventUploadPdf.
  ///
  /// In zh_Hant, this message translates to:
  /// **'上傳 PDF'**
  String get eventUploadPdf;

  /// No description provided for @eventUploading.
  ///
  /// In zh_Hant, this message translates to:
  /// **'上傳中…'**
  String get eventUploading;

  /// No description provided for @eventNoAgenda.
  ///
  /// In zh_Hant, this message translates to:
  /// **'尚未安排時間表,點「新增一行」開始'**
  String get eventNoAgenda;

  /// No description provided for @eventAttachmentName.
  ///
  /// In zh_Hant, this message translates to:
  /// **'資料名稱'**
  String get eventAttachmentName;

  /// No description provided for @eventAgendaSaved.
  ///
  /// In zh_Hant, this message translates to:
  /// **'時間表已儲存'**
  String get eventAgendaSaved;

  /// No description provided for @confirmDeleteAttachment.
  ///
  /// In zh_Hant, this message translates to:
  /// **'確定刪除此資料?檔案將從伺服器移除。'**
  String get confirmDeleteAttachment;

  /// No description provided for @agendaDay.
  ///
  /// In zh_Hant, this message translates to:
  /// **'第幾天'**
  String get agendaDay;

  /// No description provided for @agendaStart.
  ///
  /// In zh_Hant, this message translates to:
  /// **'開始時間'**
  String get agendaStart;

  /// No description provided for @agendaEnd.
  ///
  /// In zh_Hant, this message translates to:
  /// **'結束時間(選填)'**
  String get agendaEnd;

  /// No description provided for @agendaActivity.
  ///
  /// In zh_Hant, this message translates to:
  /// **'活動內容'**
  String get agendaActivity;

  /// No description provided for @agendaLinkUrl.
  ///
  /// In zh_Hant, this message translates to:
  /// **'連結網址(選填)'**
  String get agendaLinkUrl;

  /// No description provided for @agendaLinkLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'連結文字(選填)'**
  String get agendaLinkLabel;

  /// No description provided for @almanacToday.
  ///
  /// In zh_Hant, this message translates to:
  /// **'今日'**
  String get almanacToday;

  /// No description provided for @almanacZhaiTen.
  ///
  /// In zh_Hant, this message translates to:
  /// **'十齋日'**
  String get almanacZhaiTen;

  /// No description provided for @notifAlmanacFestival.
  ///
  /// In zh_Hant, this message translates to:
  /// **'今日佛教節日'**
  String get notifAlmanacFestival;

  /// No description provided for @notifAlmanacEve.
  ///
  /// In zh_Hant, this message translates to:
  /// **'明日佛教節日'**
  String get notifAlmanacEve;

  /// No description provided for @notifAlmanacZhai.
  ///
  /// In zh_Hant, this message translates to:
  /// **'今日十齋日'**
  String get notifAlmanacZhai;

  /// No description provided for @almanacSection.
  ///
  /// In zh_Hant, this message translates to:
  /// **'佛曆提醒'**
  String get almanacSection;

  /// No description provided for @almanacFestivalToggle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'佛教節日提醒'**
  String get almanacFestivalToggle;

  /// No description provided for @almanacZhaiToggle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'十齋日提醒'**
  String get almanacZhaiToggle;

  /// No description provided for @eventTimezoneLabel.
  ///
  /// In zh_Hant, this message translates to:
  /// **'時區'**
  String get eventTimezoneLabel;

  /// No description provided for @eventLocalTime.
  ///
  /// In zh_Hant, this message translates to:
  /// **'活動當地時間'**
  String get eventLocalTime;

  /// No description provided for @defaultEventTimezone.
  ///
  /// In zh_Hant, this message translates to:
  /// **'預設活動時區'**
  String get defaultEventTimezone;

  /// No description provided for @tzPickerTitle.
  ///
  /// In zh_Hant, this message translates to:
  /// **'選擇時區'**
  String get tzPickerTitle;

  /// No description provided for @tzSearchHint.
  ///
  /// In zh_Hant, this message translates to:
  /// **'輸入城市或時區名稱搜尋'**
  String get tzSearchHint;

  /// No description provided for @legendFestival.
  ///
  /// In zh_Hant, this message translates to:
  /// **'節日'**
  String get legendFestival;

  /// No description provided for @legendEvent.
  ///
  /// In zh_Hant, this message translates to:
  /// **'活動'**
  String get legendEvent;

  /// No description provided for @tzMore.
  ///
  /// In zh_Hant, this message translates to:
  /// **'其他時區…'**
  String get tzMore;
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
