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

  /// No description provided for @eventTypePractice.
  ///
  /// In zh_Hant, this message translates to:
  /// **'共修'**
  String get eventTypePractice;

  /// No description provided for @eventTypeMeditation.
  ///
  /// In zh_Hant, this message translates to:
  /// **'打坐'**
  String get eventTypeMeditation;

  /// No description provided for @eventTypeTalk.
  ///
  /// In zh_Hant, this message translates to:
  /// **'講法'**
  String get eventTypeTalk;

  /// No description provided for @eventTypeAssembly.
  ///
  /// In zh_Hant, this message translates to:
  /// **'法會'**
  String get eventTypeAssembly;

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
