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

  @override
  String get unitHour => '小時';

  @override
  String get authSignIn => '登入';

  @override
  String get authSignUp => '註冊';

  @override
  String get authSignOut => '登出';

  @override
  String get authEmail => '電子郵箱';

  @override
  String get authEmailInvalid => '請輸入有效的電子郵箱';

  @override
  String get authPassword => '密碼';

  @override
  String get authPasswordMin => '密碼至少 6 位';

  @override
  String get authForgot => '忘記密碼?';

  @override
  String get authResetSent => '重設密碼郵件已發送,請查收';

  @override
  String get authUsername => '用戶名或郵箱';

  @override
  String get authUsernameHint => '3–30 位小寫字母、數字或 . _ -;也可直接用郵箱';

  @override
  String get authUsernameInvalid => '用戶名需 3–30 位字母、數字或 . _ -(或有效郵箱)';

  @override
  String get authRecoveryEmail => '電郵(選填)';

  @override
  String get authRecoveryEmailHint => '僅用於忘記密碼時找回,可不填';

  @override
  String get authResetNeedAdmin => '此帳號未綁定郵箱,請聯繫管理員重置密碼';

  @override
  String get authToSignUp => '沒有帳號?註冊';

  @override
  String get authToSignIn => '已有帳號?登入';

  @override
  String get authFailed => '操作失敗:';

  @override
  String get settingsTitle => '設定';

  @override
  String get displayName => '顯示名稱';

  @override
  String get save => '儲存';

  @override
  String get saved => '已儲存';

  @override
  String get next => '下一步';

  @override
  String get done => '完成';

  @override
  String get onboardingLanguage => '選擇語言';

  @override
  String get onboardingFont => '選擇字號';

  @override
  String get onboardingFontPreview => '諸惡莫作,眾善奉行';

  @override
  String get onboardingRegion => '所在地區';

  @override
  String get onboardingRegionHint => '用於選擇通知送達方式(大陸地區以應用內通知與郵件為主)';

  @override
  String get regionCn => '中國大陸';

  @override
  String get regionOther => '其他地區';

  @override
  String get submit => '提交';

  @override
  String get cancel => '取消';

  @override
  String get copied => '已複製';

  @override
  String get addPracticeType => '新增功課項';

  @override
  String get practiceTypeName => '名稱';

  @override
  String get unitTitle => '單位';

  @override
  String get reportLog => '報數';

  @override
  String get logsTitle => '報數記錄';

  @override
  String get selectPracticeType => '選擇功課';

  @override
  String get subjectTitle => '為誰報數';

  @override
  String get subjectSelf => '自己';

  @override
  String get subjectMember => '同修';

  @override
  String get subjectName => '其他名字';

  @override
  String get quantityTitle => '數量';

  @override
  String get noteLabel => '備註(選填;補報可註明實際日期)';

  @override
  String get submitLog => '提交報數';

  @override
  String get logSubmitted => '已報數,隨喜讚歎!';

  @override
  String get offlineQueued => '網絡不通,已離線暫存,連網後自動補傳';

  @override
  String get offlineFlushed => '已補傳離線報數';

  @override
  String get quantityInvalid => '請輸入正確的數量';

  @override
  String get edit => '編輯';

  @override
  String get delete => '刪除';

  @override
  String get confirmDeleteLog => '確定刪除這條報數?統計將即時扣減。';

  @override
  String get proxyBy => '代報';

  @override
  String get fellowPractitioner => '同修';

  @override
  String get categoryTitle => '分類';

  @override
  String get categorySutra => '經';

  @override
  String get categoryMantra => '咒';

  @override
  String get categoryRepentance => '懺';

  @override
  String get categoryBuddhaName => '念佛';

  @override
  String get categoryMeditation => '靜坐';

  @override
  String get categoryOther => '其他';

  @override
  String get quickReport => '快捷報數';

  @override
  String get myStats => '個人統計';

  @override
  String get todayTitle => '今日';

  @override
  String get totalTitle => '累計';

  @override
  String get streakLabel => '連續用功天數';

  @override
  String get trend14 => '近 14 天趨勢(筆數)';

  @override
  String get historyTitle => '歷史查看';

  @override
  String get pickDate => '選擇日期';

  @override
  String get noDataToday => '今日尚未報數';

  @override
  String get reportedToday => '今日已報人數';

  @override
  String get reportAction => '檢舉';

  @override
  String get reportReasonLabel => '原因';

  @override
  String get reportSubmitted => '已提交檢舉,管理員會盡快處理';

  @override
  String get blockUser => '封鎖此用戶';

  @override
  String get unblockUser => '解除封鎖';

  @override
  String get privacyPolicy => '隱私政策';

  @override
  String get communityGuidelines => '社區規範';

  @override
  String get eulaAgreeFinish => '同意並完成';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get deleteAccountWarn => '帳號與個人資料將被永久刪除,無法恢復;您的歷史報數將匿名保留於共修統計中。確定刪除?';

  @override
  String get adminReports => '檢舉處理';

  @override
  String get markResolved => '標記已處理';

  @override
  String get banUser => '封禁該用戶';

  @override
  String get repeatLast => '重複上次';

  @override
  String get forOthers => '替他人報數';

  @override
  String get frequentGroup => '常用';

  @override
  String get notificationsTitle => '通知';

  @override
  String get notifProxyLog => '有同修為您代報';

  @override
  String get notifAnnouncement => '共修公告更新';

  @override
  String get vowsTitle => '我的發願';

  @override
  String get createVow => '發願';

  @override
  String get vowTarget => '目標數量';

  @override
  String get vowPeriod => '期限';

  @override
  String get daysUnit => '天';

  @override
  String daysLeft(int days) {
    return '剩餘 $days 天';
  }

  @override
  String get vowCompleted => '已圓滿';

  @override
  String get vowExpired => '已到期';

  @override
  String get vowCongrats => '隨喜讚歎!發願圓滿';

  @override
  String get quickReportTitle => '快捷報數';

  @override
  String get quickEmptyHint => '還沒有常用組合,先報一次數,下次就能一鍵重複。';

  @override
  String get sectionDaily => '日課';

  @override
  String get sectionSangha => '共修';

  @override
  String get sectionSelf => '修行';

  @override
  String get sectionGeneral => '通用';

  @override
  String get themeTitle => '外觀';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get logsEmptyHint => '還沒有人報數,從首頁「報數」開始吧。';

  @override
  String get vowsEmptyHint => '發一個願,讓精進有方向。';

  @override
  String get scripturesTitle => '在線經本';

  @override
  String get liveTitle => '直播';

  @override
  String get liveNow => '直播中';

  @override
  String get notLive => '目前未直播';

  @override
  String get enterLive => '進入直播';

  @override
  String get openChannel => '打開頻道';

  @override
  String get joinWebex => '加入 Webex 共修';

  @override
  String get webexOpenApp => '用 Webex App 開啟';

  @override
  String get webexHint => '固定共修房間,開始時間見活動日曆';

  @override
  String get replaysTitle => '往期回看';

  @override
  String get notifLiveStarted => '直播開始了';

  @override
  String get calendarTitle => '活動日曆';

  @override
  String get createEvent => '新增活動';

  @override
  String get eventTitleLabel => '活動名稱';

  @override
  String get weeklyRepeat => '每週重複';

  @override
  String get eventCancelled => '本次取消';

  @override
  String get cancelOccurrence => '取消本次活動';

  @override
  String get upcomingTitle => '未來活動';

  @override
  String get manageEventTypes => '事件類型管理';

  @override
  String get editEvent => '編輯活動';

  @override
  String get deleteEvent => '刪除活動';

  @override
  String get confirmDeleteEvent => '確定刪除此活動?所有重複場次將一併移除,並通知全體用戶。';

  @override
  String get typeNameHant => '名稱(繁體)';

  @override
  String get typeNameHans => '名稱(簡體)';

  @override
  String get iconLabel => '圖標';

  @override
  String get activeLabel => '啟用';

  @override
  String get deleteTypeBlocked => '該類型已被活動使用,無法刪除;可改為停用。';

  @override
  String get notifEventChanged => '活動異動';

  @override
  String get actCreated => '新增';

  @override
  String get actUpdated => '更新';

  @override
  String get actDeleted => '已取消';

  @override
  String get actOccCancelled => '單次取消';

  @override
  String get actOccChanged => '單次改期';

  @override
  String get toolsTitle => '工具';

  @override
  String get timerTitle => '打坐計時';

  @override
  String get timerDuration => '時長';

  @override
  String get customDuration => '自訂';

  @override
  String get customDurationTitle => '自訂時長';

  @override
  String get counterTitle => '念珠計數';

  @override
  String get startTimer => '開始';

  @override
  String get stopTimer => '結束';

  @override
  String get timeUp => '時間到';

  @override
  String get intervalBell => '中途鈴(正念提醒)';

  @override
  String get prepBell => '預備鈴';

  @override
  String get offLabel => '關閉';

  @override
  String get keepAwake => '螢幕常亮';

  @override
  String get keepForeground => '計時期間請保持 App 開啟,螢幕會自動常亮';

  @override
  String get tapToCount => '點擊螢幕任意處計數';

  @override
  String get roundsLabel => '串數';

  @override
  String get beadsTarget => '一串';

  @override
  String get resetCount => '清零';

  @override
  String get confirmReset => '確定清零?';

  @override
  String get soundToggle => '鈴聲';

  @override
  String get toReport => '轉為報數';

  @override
  String get dedicationTitle => '迴向';

  @override
  String get dedicationText =>
      '願以此功德,莊嚴佛淨土。\n上報四重恩,下濟三途苦。\n若有見聞者,悉發菩提心。\n盡此一報身,同生極樂國。';

  @override
  String get errNetwork => '網絡連接失敗,請檢查網絡後重試';

  @override
  String get errGeneric => '操作失敗,請稍後再試';

  @override
  String get errAuthInvalidCredentials => '用戶名或密碼錯誤';

  @override
  String get errAuthAlreadyRegistered => '該帳號已被註冊,請直接登入';

  @override
  String get errAuthWeakPassword => '密碼至少 6 位';

  @override
  String get errAuthNotActivated => '帳號尚未啟用,請聯繫管理員';

  @override
  String get errAuthRateLimited => '操作過於頻繁,請稍後再試';

  @override
  String get errAuthSignupDisabled => '暫未開放註冊';

  @override
  String get errAuthBanned => '帳號已被停用,請聯繫管理員';

  @override
  String get errNoPermission => '沒有權限執行此操作';

  @override
  String get errDuplicate => '資料重複,請勿重複提交';

  @override
  String get errSessionExpired => '登入已過期,請重新登入';

  @override
  String get mrTitle => '正念提醒';

  @override
  String get mrEnable => '開啟正念提醒';

  @override
  String get mrEnableHint => '在設定的時段內定時響磬,提醒回到當下';

  @override
  String get mrWeekdays => '提醒日';

  @override
  String get mrDay1 => '一';

  @override
  String get mrDay2 => '二';

  @override
  String get mrDay3 => '三';

  @override
  String get mrDay4 => '四';

  @override
  String get mrDay5 => '五';

  @override
  String get mrDay6 => '六';

  @override
  String get mrDay7 => '日';

  @override
  String get mrStart => '開始時間';

  @override
  String get mrEnd => '結束時間';

  @override
  String get mrWindowInvalid => '結束時間需晚於開始時間';

  @override
  String get mrInterval => '間隔';

  @override
  String get mrSound => '提示音';

  @override
  String get mrSoundBell => '磬聲';

  @override
  String get mrSoundSilent => '靜音';

  @override
  String get mrVibrate => '震動';

  @override
  String get mrPreviewSound => '試聽';

  @override
  String get mrMessage => '提醒文案';

  @override
  String get mrMessageDefault => '該正念了 · 回到當下';

  @override
  String get mrMessageHint => '留空則用預設文案';

  @override
  String mrCountSummary(int daily, int total) {
    return '每天 $daily 次 · 本週共 $total 次';
  }

  @override
  String mrIosCapWarning(int cap, int total) {
    return 'iOS 最多 $cap 條通知,目前 $total 條會被截斷;請增大間隔或縮短時段';
  }

  @override
  String get mrTest => '立即測試';

  @override
  String get mrTestSent => '測試通知已發送';

  @override
  String get mrHelp => '讓提醒準時響起';

  @override
  String get mrHelpSubtitle => 'iOS 與 Android 設定指引';

  @override
  String get mrPermDenied => '通知權限未開啟,提醒無法響起';

  @override
  String get mrGrant => '去開啟';

  @override
  String get mrRespectSilent => '手機靜音或勿擾時不會出聲,僅顯示橫幅(尊重系統設定)';

  @override
  String get mrHelpIntro => '提醒靠系統在預定時刻觸發。請按下面步驟放行,確保 App 關閉或息屏時也能響。';

  @override
  String get mrSelfCheck => '響鈴自檢';

  @override
  String get mrSelfCheckHint => '點一下發一條測試通知,看是否真的響了。';

  @override
  String get mrHelpIosTitle => 'iOS 設定';

  @override
  String get mrHelpIosStep1 =>
      '允許通知:首次開啟會彈窗;若曾拒絕,前往「設定 > 善護念 > 通知」開啟允許通知、聲音、鎖屏顯示。';

  @override
  String get mrHelpIosStep2 => '靜音/勿擾:處於靜音檔或勿擾時不會出聲(系統限制,非故障);需要出聲請退出靜音。';

  @override
  String get mrHelpIosStep3 => '專注模式:若開啟了工作/睡眠等專注,可能攔截通知,請把善護念加入允許清單。';

  @override
  String get mrHelpAndroidTitle => 'Android 設定';

  @override
  String get mrHelpAndroidStep1 => '允許通知:在系統彈窗或「應用資訊 > 通知」中允許。';

  @override
  String get mrHelpAndroidStep2 => '電池不受限:關閉對本 App 的電池最佳化,否則後台可能被限制。';

  @override
  String get mrHelpAndroidStep3 => '勿擾說明:系統勿擾時不會出聲,僅顯示橫幅。';

  @override
  String get mrHelpOemTitle => '國產手機額外設定(小米/華為/OPPO/vivo 等)';

  @override
  String get mrHelpOemBody =>
      '這些手機預設會清理後台,可能延遲或漏掉提醒。請手動開啟:自啟動/自動啟動、允許後台活動(不受限制)、鎖定在最近任務、允許後台彈通知。即便全部放行,個別機型仍可能延遲——這是系統限制,非本 App 故障。';

  @override
  String get mrOpenSettings => '去應用設定';

  @override
  String get qaTitle => '往期問答';

  @override
  String get qaEntryTitle => '往期問答檢索';

  @override
  String get qaEntrySubtitle => '搜尋歷次講法問答片段';

  @override
  String get qaSearchHint => '搜尋關鍵詞(2 字以上)';

  @override
  String get qaTooShort => '請輸入 2 個字以上';

  @override
  String qaResultCount(int n) {
    return '共 $n 條';
  }

  @override
  String get qaEmpty => '未找到相關內容';

  @override
  String get qaEmptyHint => '試試其他關鍵詞,或清除標籤篩選';

  @override
  String get qaBackToList => '返回列表';

  @override
  String get qaTagsAdd => '標籤';

  @override
  String get qaTagPickerTitle => '選擇標籤';

  @override
  String get qaTagPickerHint => '搜尋標籤';

  @override
  String get qaTagPickerOr => '選多個標籤時,符合任一即顯示';

  @override
  String qaTagPickerDone(int n) {
    return '完成($n)';
  }

  @override
  String get qaOpenExternal => '用 YouTube App 開啟';

  @override
  String qaFromVideo(String title) {
    return '出自「$title」';
  }

  @override
  String get eventShare => '分享';

  @override
  String get eventAgendaTitle => '時間表';

  @override
  String get eventAttachmentsTitle => '相關資料';

  @override
  String get eventCopy => '複製';

  @override
  String get eventCopied => '已複製時間表';

  @override
  String get eventLinkLabelDefault => '查看';

  @override
  String get eventAdminTitle => '管理員';

  @override
  String get eventEditAgenda => '編輯時間表/資料';

  @override
  String get eventAddAgendaRow => '新增一行';

  @override
  String get eventUploadPdf => '上傳 PDF';

  @override
  String get eventUploading => '上傳中…';

  @override
  String get eventNoAgenda => '尚未安排時間表,點「新增一行」開始';

  @override
  String get eventAttachmentName => '資料名稱';

  @override
  String get eventAgendaSaved => '時間表已儲存';

  @override
  String get confirmDeleteAttachment => '確定刪除此資料?檔案將從伺服器移除。';

  @override
  String get agendaDay => '第幾天';

  @override
  String get agendaStart => '開始時間';

  @override
  String get agendaEnd => '結束時間(選填)';

  @override
  String get agendaActivity => '活動內容';

  @override
  String get agendaLinkUrl => '連結網址(選填)';

  @override
  String get agendaLinkLabel => '連結文字(選填)';

  @override
  String get almanacToday => '今日';

  @override
  String get almanacZhaiTen => '十齋日';

  @override
  String get notifAlmanacFestival => '今日佛教節日';

  @override
  String get notifAlmanacEve => '明日佛教節日';

  @override
  String get notifAlmanacZhai => '今日十齋日';

  @override
  String get almanacSection => '佛曆提醒';

  @override
  String get almanacFestivalToggle => '佛教節日提醒';

  @override
  String get almanacZhaiToggle => '十齋日提醒';

  @override
  String get eventTimezoneLabel => '時區';

  @override
  String get eventLocalTime => '活動當地時間';

  @override
  String get defaultEventTimezone => '預設活動時區';

  @override
  String get tzPickerTitle => '選擇時區';

  @override
  String get tzSearchHint => '輸入城市或時區名稱搜尋';

  @override
  String get noEventsThisDay => '沒有活動';

  @override
  String get legendFestival => '節日';

  @override
  String get legendEvent => '活動';

  @override
  String get yourLocalTime => '您的時間';

  @override
  String get sectionAdmin => '管理';

  @override
  String get publishNotify => '發布通知';

  @override
  String get titleLabel => '標題';

  @override
  String get contentLabel => '內容(選填)';

  @override
  String get scheduleSend => '定時發送';

  @override
  String get sendTimeLabel => '發送時間(您的時間)';

  @override
  String get confirmPublishTitle => '確認發布';

  @override
  String get confirmPublishAll => '將發送給全體用戶';

  @override
  String get sendNow => '立即發送';

  @override
  String get publishedOk => '已發布';

  @override
  String get scheduledOk => '已排程';

  @override
  String get pendingScheduled => '已排程(未發送)';

  @override
  String get sentRecentTitle => '近期已發送';

  @override
  String get cancelSchedule => '取消排程';

  @override
  String get recallAction => '撤回';

  @override
  String get recallWarn => '撤回後所有用戶的通知中心將不再顯示此通知;已彈出的手機推送無法收回。確定?';

  @override
  String get tzMore => '其他時區…';

  @override
  String get back => '返回';

  @override
  String get studyQaTitle => '學修問答';

  @override
  String get studyQaMine => '我的提問';

  @override
  String get studyQaAsk => '提問';

  @override
  String get studyQaNewHint => '請寫下您的學修問題…';

  @override
  String get studyQaPending => '待回覆';

  @override
  String get studyQaAnswered => '已回覆';

  @override
  String get studyQaTabAll => '全部';

  @override
  String get studyQaAdminLabel => '管理員';

  @override
  String get studyQaAskerLabel => '提問人';

  @override
  String get studyQaDelete => '刪除提問';

  @override
  String get studyQaDeleteConfirm => '刪除後問答內容將永久消失,無法恢復。確定刪除?';

  @override
  String get studyQaDeleted => '該提問已刪除';

  @override
  String get studyQaEmpty => '還沒有提問。';

  @override
  String get studyQaLimitHit => '您已有 3 個提問待回覆,請耐心等待回覆後再提問。';

  @override
  String get studyQaSend => '發送';

  @override
  String get notifQaReply => '您的提問有新回覆';

  @override
  String get notifQaQuestion => '有新的學修提問';

  @override
  String get notifySection => '通知';

  @override
  String get notifyQuietTitle => '免打擾時段';

  @override
  String get notifyQuietHint => '此時段內不發手機推送,順延到結束後發送;活動開始前的提醒不受限。';

  @override
  String get notifyQuietStart => '開始';

  @override
  String get notifyQuietEnd => '結束';

  @override
  String get notifySubscribeHeader => '接收以下通知';

  @override
  String get notifyTypeEventReminder => '活動提醒';

  @override
  String get notifyTypeEventChanged => '活動變動';

  @override
  String get notifyTypeQaReply => '學修問答回覆';

  @override
  String get notifyMarkAllRead => '全部已讀';

  @override
  String get notifyOnChangeSwitch => '通知所有人';

  @override
  String get notifEventReminderEve => '活動預告';

  @override
  String get notifEventReminderSoon => '活動即將開始';

  @override
  String get notifEventReminderNow => '活動開始了';

  @override
  String notifEventReminderInHours(int n) {
    return '$n 小時後開始';
  }

  @override
  String notifEventReminderInMinutes(int n) {
    return '$n 分鐘後開始';
  }

  @override
  String get notifEventReminderEnter => '點擊進入';

  @override
  String get actOccRestored => '單次恢復';

  @override
  String get reminderSectionTitle => '提醒';

  @override
  String get reminderAddButton => '新增提醒';

  @override
  String get reminderListLabel => '已設提醒';

  @override
  String get reminderOffsetAtStart => '活動開始時';

  @override
  String get reminderOffsetOneDay => '提前一天';

  @override
  String get reminderOffsetTwoDays => '提前兩天';

  @override
  String reminderOffsetMinutes(int n) {
    return '提前 $n 分鐘';
  }

  @override
  String reminderOffsetHours(int n) {
    return '提前 $n 小時';
  }

  @override
  String get communityTitle => '共修報數';

  @override
  String get communityLogs => '共修報數紀錄';

  @override
  String get communityAnnouncement => '共修公告';

  @override
  String get communityEmptyToday => '今日還沒有人報數 · 隨喜您先行';

  @override
  String get myCustomTypes => '我的自訂功課';

  @override
  String get statsMine => '我的';

  @override
  String get statsAll => '全體';

  @override
  String get statsScaledNote => '各自比例';

  @override
  String get searchMemberHint => '輸入姓名搜尋同修';

  @override
  String get searchMemberEmpty => '找不到這位同修,可改用「任意名字」代報';

  @override
  String get customTypePrivateHint => '自訂功課僅自己可見,別的同修看不到你的清單。';
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

  @override
  String get unitHour => '小时';

  @override
  String get authSignIn => '登录';

  @override
  String get authSignUp => '注册';

  @override
  String get authSignOut => '退出登录';

  @override
  String get authEmail => '电子邮箱';

  @override
  String get authEmailInvalid => '请输入有效的电子邮箱';

  @override
  String get authPassword => '密码';

  @override
  String get authPasswordMin => '密码至少 6 位';

  @override
  String get authForgot => '忘记密码?';

  @override
  String get authResetSent => '重置密码邮件已发送,请查收';

  @override
  String get authUsername => '用户名或邮箱';

  @override
  String get authUsernameHint => '3–30 位小写字母、数字或 . _ -;也可直接用邮箱';

  @override
  String get authUsernameInvalid => '用户名需 3–30 位字母、数字或 . _ -(或有效邮箱)';

  @override
  String get authRecoveryEmail => '邮箱(选填)';

  @override
  String get authRecoveryEmailHint => '仅用于忘记密码时找回,可不填';

  @override
  String get authResetNeedAdmin => '此账号未绑定邮箱,请联系管理员重置密码';

  @override
  String get authToSignUp => '没有账号?注册';

  @override
  String get authToSignIn => '已有账号?登录';

  @override
  String get authFailed => '操作失败:';

  @override
  String get settingsTitle => '设置';

  @override
  String get displayName => '显示名称';

  @override
  String get save => '保存';

  @override
  String get saved => '已保存';

  @override
  String get next => '下一步';

  @override
  String get done => '完成';

  @override
  String get onboardingLanguage => '选择语言';

  @override
  String get onboardingFont => '选择字号';

  @override
  String get onboardingFontPreview => '诸恶莫作,众善奉行';

  @override
  String get onboardingRegion => '所在地区';

  @override
  String get onboardingRegionHint => '用于选择通知送达方式(大陆地区以应用内通知与邮件为主)';

  @override
  String get regionCn => '中国大陆';

  @override
  String get regionOther => '其他地区';

  @override
  String get submit => '提交';

  @override
  String get cancel => '取消';

  @override
  String get copied => '已复制';

  @override
  String get addPracticeType => '新增功课项';

  @override
  String get practiceTypeName => '名称';

  @override
  String get unitTitle => '单位';

  @override
  String get reportLog => '报数';

  @override
  String get logsTitle => '报数记录';

  @override
  String get selectPracticeType => '选择功课';

  @override
  String get subjectTitle => '为谁报数';

  @override
  String get subjectSelf => '自己';

  @override
  String get subjectMember => '同修';

  @override
  String get subjectName => '其他名字';

  @override
  String get quantityTitle => '数量';

  @override
  String get noteLabel => '备注(选填;补报可注明实际日期)';

  @override
  String get submitLog => '提交报数';

  @override
  String get logSubmitted => '已报数,随喜赞叹!';

  @override
  String get offlineQueued => '网络不通,已离线暂存,联网后自动补传';

  @override
  String get offlineFlushed => '已补传离线报数';

  @override
  String get quantityInvalid => '请输入正确的数量';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get confirmDeleteLog => '确定删除这条报数?统计将即时扣减。';

  @override
  String get proxyBy => '代报';

  @override
  String get fellowPractitioner => '同修';

  @override
  String get categoryTitle => '分类';

  @override
  String get categorySutra => '经';

  @override
  String get categoryMantra => '咒';

  @override
  String get categoryRepentance => '忏';

  @override
  String get categoryBuddhaName => '念佛';

  @override
  String get categoryMeditation => '静坐';

  @override
  String get categoryOther => '其他';

  @override
  String get quickReport => '快捷报数';

  @override
  String get myStats => '个人统计';

  @override
  String get todayTitle => '今日';

  @override
  String get totalTitle => '累计';

  @override
  String get streakLabel => '连续用功天数';

  @override
  String get trend14 => '近 14 天趋势(笔数)';

  @override
  String get historyTitle => '历史查看';

  @override
  String get pickDate => '选择日期';

  @override
  String get noDataToday => '今日尚未报数';

  @override
  String get reportedToday => '今日已报人数';

  @override
  String get reportAction => '举报';

  @override
  String get reportReasonLabel => '原因';

  @override
  String get reportSubmitted => '已提交举报,管理员会尽快处理';

  @override
  String get blockUser => '拉黑此用户';

  @override
  String get unblockUser => '取消拉黑';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get communityGuidelines => '社区规范';

  @override
  String get eulaAgreeFinish => '同意并完成';

  @override
  String get deleteAccount => '删除账号';

  @override
  String get deleteAccountWarn => '账号与个人资料将被永久删除,无法恢复;您的历史报数将匿名保留于共修统计中。确定删除?';

  @override
  String get adminReports => '举报处理';

  @override
  String get markResolved => '标记已处理';

  @override
  String get banUser => '封禁该用户';

  @override
  String get repeatLast => '重复上次';

  @override
  String get forOthers => '替他人报数';

  @override
  String get frequentGroup => '常用';

  @override
  String get notificationsTitle => '通知';

  @override
  String get notifProxyLog => '有同修为您代报';

  @override
  String get notifAnnouncement => '共修公告更新';

  @override
  String get vowsTitle => '我的发愿';

  @override
  String get createVow => '发愿';

  @override
  String get vowTarget => '目标数量';

  @override
  String get vowPeriod => '期限';

  @override
  String get daysUnit => '天';

  @override
  String daysLeft(int days) {
    return '剩余 $days 天';
  }

  @override
  String get vowCompleted => '已圆满';

  @override
  String get vowExpired => '已到期';

  @override
  String get vowCongrats => '随喜赞叹!发愿圆满';

  @override
  String get quickReportTitle => '快捷报数';

  @override
  String get quickEmptyHint => '还没有常用组合,先报一次数,下次就能一键重复。';

  @override
  String get sectionDaily => '日课';

  @override
  String get sectionSangha => '共修';

  @override
  String get sectionSelf => '修行';

  @override
  String get sectionGeneral => '通用';

  @override
  String get themeTitle => '外观';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get logsEmptyHint => '还没有人报数,从首页「报数」开始吧。';

  @override
  String get vowsEmptyHint => '发一个愿,让精进有方向。';

  @override
  String get scripturesTitle => '在线经本';

  @override
  String get liveTitle => '直播';

  @override
  String get liveNow => '直播中';

  @override
  String get notLive => '当前未直播';

  @override
  String get enterLive => '进入直播';

  @override
  String get openChannel => '打开频道';

  @override
  String get joinWebex => '加入 Webex 共修';

  @override
  String get webexOpenApp => '用 Webex App 打开';

  @override
  String get webexHint => '固定共修房间,开始时间见活动日历';

  @override
  String get replaysTitle => '往期回看';

  @override
  String get notifLiveStarted => '直播开始了';

  @override
  String get calendarTitle => '活动日历';

  @override
  String get createEvent => '新增活动';

  @override
  String get eventTitleLabel => '活动名称';

  @override
  String get weeklyRepeat => '每周重复';

  @override
  String get eventCancelled => '本次取消';

  @override
  String get cancelOccurrence => '取消本次活动';

  @override
  String get upcomingTitle => '未来活动';

  @override
  String get manageEventTypes => '事件类型管理';

  @override
  String get editEvent => '编辑活动';

  @override
  String get deleteEvent => '删除活动';

  @override
  String get confirmDeleteEvent => '确定删除此活动?所有重复场次将一并移除,并通知全体用户。';

  @override
  String get typeNameHant => '名称(繁体)';

  @override
  String get typeNameHans => '名称(简体)';

  @override
  String get iconLabel => '图标';

  @override
  String get activeLabel => '启用';

  @override
  String get deleteTypeBlocked => '该类型已被活动使用,无法删除;可改为停用。';

  @override
  String get notifEventChanged => '活动变动';

  @override
  String get actCreated => '新增';

  @override
  String get actUpdated => '更新';

  @override
  String get actDeleted => '已取消';

  @override
  String get actOccCancelled => '单次取消';

  @override
  String get actOccChanged => '单次改期';

  @override
  String get toolsTitle => '工具';

  @override
  String get timerTitle => '打坐计时';

  @override
  String get timerDuration => '时长';

  @override
  String get customDuration => '自定';

  @override
  String get customDurationTitle => '自定义时长';

  @override
  String get counterTitle => '念珠计数';

  @override
  String get startTimer => '开始';

  @override
  String get stopTimer => '结束';

  @override
  String get timeUp => '时间到';

  @override
  String get intervalBell => '中途铃(正念提醒)';

  @override
  String get prepBell => '预备铃';

  @override
  String get offLabel => '关闭';

  @override
  String get keepAwake => '屏幕常亮';

  @override
  String get keepForeground => '计时期间请保持 App 打开,屏幕会自动常亮';

  @override
  String get tapToCount => '点击屏幕任意处计数';

  @override
  String get roundsLabel => '串数';

  @override
  String get beadsTarget => '一串';

  @override
  String get resetCount => '清零';

  @override
  String get confirmReset => '确定清零?';

  @override
  String get soundToggle => '铃声';

  @override
  String get toReport => '转为报数';

  @override
  String get dedicationTitle => '回向';

  @override
  String get dedicationText =>
      '愿以此功德,庄严佛净土。\n上报四重恩,下济三途苦。\n若有见闻者,悉发菩提心。\n尽此一报身,同生极乐国。';

  @override
  String get errNetwork => '网络连接失败,请检查网络后重试';

  @override
  String get errGeneric => '操作失败,请稍后再试';

  @override
  String get errAuthInvalidCredentials => '用户名或密码错误';

  @override
  String get errAuthAlreadyRegistered => '该账号已被注册,请直接登录';

  @override
  String get errAuthWeakPassword => '密码至少 6 位';

  @override
  String get errAuthNotActivated => '账号尚未启用,请联系管理员';

  @override
  String get errAuthRateLimited => '操作过于频繁,请稍后再试';

  @override
  String get errAuthSignupDisabled => '暂未开放注册';

  @override
  String get errAuthBanned => '账号已被停用,请联系管理员';

  @override
  String get errNoPermission => '没有权限执行此操作';

  @override
  String get errDuplicate => '数据重复,请勿重复提交';

  @override
  String get errSessionExpired => '登录已过期,请重新登录';

  @override
  String get mrTitle => '正念提醒';

  @override
  String get mrEnable => '开启正念提醒';

  @override
  String get mrEnableHint => '在设定的时段内定时响磬,提醒回到当下';

  @override
  String get mrWeekdays => '提醒日';

  @override
  String get mrDay1 => '一';

  @override
  String get mrDay2 => '二';

  @override
  String get mrDay3 => '三';

  @override
  String get mrDay4 => '四';

  @override
  String get mrDay5 => '五';

  @override
  String get mrDay6 => '六';

  @override
  String get mrDay7 => '日';

  @override
  String get mrStart => '开始时间';

  @override
  String get mrEnd => '结束时间';

  @override
  String get mrWindowInvalid => '结束时间需晚于开始时间';

  @override
  String get mrInterval => '间隔';

  @override
  String get mrSound => '提示音';

  @override
  String get mrSoundBell => '磬声';

  @override
  String get mrSoundSilent => '静音';

  @override
  String get mrVibrate => '震动';

  @override
  String get mrPreviewSound => '试听';

  @override
  String get mrMessage => '提醒文案';

  @override
  String get mrMessageDefault => '该正念了 · 回到当下';

  @override
  String get mrMessageHint => '留空则用默认文案';

  @override
  String mrCountSummary(int daily, int total) {
    return '每天 $daily 次 · 本周共 $total 次';
  }

  @override
  String mrIosCapWarning(int cap, int total) {
    return 'iOS 最多 $cap 条通知,当前 $total 条会被截断;请增大间隔或缩短时段';
  }

  @override
  String get mrTest => '立即测试';

  @override
  String get mrTestSent => '测试通知已发送';

  @override
  String get mrHelp => '让提醒准时响起';

  @override
  String get mrHelpSubtitle => 'iOS 与 Android 设置指引';

  @override
  String get mrPermDenied => '通知权限未开启,提醒无法响起';

  @override
  String get mrGrant => '去开启';

  @override
  String get mrRespectSilent => '手机静音或勿扰时不会出声,仅显示横幅(尊重系统设置)';

  @override
  String get mrHelpIntro => '提醒靠系统在预定时刻触发。请按下面步骤放行,确保 App 关闭或息屏时也能响。';

  @override
  String get mrSelfCheck => '响铃自检';

  @override
  String get mrSelfCheckHint => '点一下发一条测试通知,看是否真的响了。';

  @override
  String get mrHelpIosTitle => 'iOS 设置';

  @override
  String get mrHelpIosStep1 =>
      '允许通知:首次开启会弹窗;若曾拒绝,前往「设置 > 善护念 > 通知」开启允许通知、声音、锁屏显示。';

  @override
  String get mrHelpIosStep2 => '静音/勿扰:处于静音档或勿扰时不会出声(系统限制,非故障);需要出声请退出静音。';

  @override
  String get mrHelpIosStep3 => '专注模式:若开启了工作/睡眠等专注,可能拦截通知,请把善护念加入允许列表。';

  @override
  String get mrHelpAndroidTitle => 'Android 设置';

  @override
  String get mrHelpAndroidStep1 => '允许通知:在系统弹窗或「应用信息 > 通知」中允许。';

  @override
  String get mrHelpAndroidStep2 => '电池不受限:关闭对本 App 的电池优化,否则后台可能被限制。';

  @override
  String get mrHelpAndroidStep3 => '勿扰说明:系统勿扰时不会出声,仅显示横幅。';

  @override
  String get mrHelpOemTitle => '国产手机额外设置(小米/华为/OPPO/vivo 等)';

  @override
  String get mrHelpOemBody =>
      '这些手机默认会清理后台,可能延迟或漏掉提醒。请手动开启:自启动/自动启动、允许后台活动(不受限制)、锁定在最近任务、允许后台弹通知。即便全部放行,个别机型仍可能延迟——这是系统限制,非本 App 故障。';

  @override
  String get mrOpenSettings => '去应用设置';

  @override
  String get qaTitle => '往期问答';

  @override
  String get qaEntryTitle => '往期问答检索';

  @override
  String get qaEntrySubtitle => '搜索历次讲法问答片段';

  @override
  String get qaSearchHint => '搜索关键词(2 字以上)';

  @override
  String get qaTooShort => '请输入 2 个字以上';

  @override
  String qaResultCount(int n) {
    return '共 $n 条';
  }

  @override
  String get qaEmpty => '未找到相关内容';

  @override
  String get qaEmptyHint => '试试其他关键词,或清除标签筛选';

  @override
  String get qaBackToList => '返回列表';

  @override
  String get qaTagsAdd => '标签';

  @override
  String get qaTagPickerTitle => '选择标签';

  @override
  String get qaTagPickerHint => '搜索标签';

  @override
  String get qaTagPickerOr => '选多个标签时,符合任一即显示';

  @override
  String qaTagPickerDone(int n) {
    return '完成($n)';
  }

  @override
  String get qaOpenExternal => '用 YouTube App 打开';

  @override
  String qaFromVideo(String title) {
    return '出自「$title」';
  }

  @override
  String get eventShare => '分享';

  @override
  String get eventAgendaTitle => '时间表';

  @override
  String get eventAttachmentsTitle => '相关资料';

  @override
  String get eventCopy => '复制';

  @override
  String get eventCopied => '已复制时间表';

  @override
  String get eventLinkLabelDefault => '查看';

  @override
  String get eventAdminTitle => '管理员';

  @override
  String get eventEditAgenda => '编辑时间表/资料';

  @override
  String get eventAddAgendaRow => '新增一行';

  @override
  String get eventUploadPdf => '上传 PDF';

  @override
  String get eventUploading => '上传中…';

  @override
  String get eventNoAgenda => '尚未安排时间表,点「新增一行」开始';

  @override
  String get eventAttachmentName => '资料名称';

  @override
  String get eventAgendaSaved => '时间表已保存';

  @override
  String get confirmDeleteAttachment => '确定删除此资料?文件将从服务器移除。';

  @override
  String get agendaDay => '第几天';

  @override
  String get agendaStart => '开始时间';

  @override
  String get agendaEnd => '结束时间(选填)';

  @override
  String get agendaActivity => '活动内容';

  @override
  String get agendaLinkUrl => '链接网址(选填)';

  @override
  String get agendaLinkLabel => '链接文字(选填)';

  @override
  String get almanacToday => '今日';

  @override
  String get almanacZhaiTen => '十斋日';

  @override
  String get notifAlmanacFestival => '今日佛教节日';

  @override
  String get notifAlmanacEve => '明日佛教节日';

  @override
  String get notifAlmanacZhai => '今日十斋日';

  @override
  String get almanacSection => '佛历提醒';

  @override
  String get almanacFestivalToggle => '佛教节日提醒';

  @override
  String get almanacZhaiToggle => '十斋日提醒';

  @override
  String get eventTimezoneLabel => '时区';

  @override
  String get eventLocalTime => '活动当地时间';

  @override
  String get defaultEventTimezone => '预设活动时区';

  @override
  String get tzPickerTitle => '选择时区';

  @override
  String get tzSearchHint => '输入城市或时区名称搜索';

  @override
  String get noEventsThisDay => '没有活动';

  @override
  String get legendFestival => '节日';

  @override
  String get legendEvent => '活动';

  @override
  String get yourLocalTime => '您的时间';

  @override
  String get sectionAdmin => '管理';

  @override
  String get publishNotify => '发布通知';

  @override
  String get titleLabel => '标题';

  @override
  String get contentLabel => '内容(选填)';

  @override
  String get scheduleSend => '定时发送';

  @override
  String get sendTimeLabel => '发送时间(您的时间)';

  @override
  String get confirmPublishTitle => '确认发布';

  @override
  String get confirmPublishAll => '将发送给全体用户';

  @override
  String get sendNow => '立即发送';

  @override
  String get publishedOk => '已发布';

  @override
  String get scheduledOk => '已排程';

  @override
  String get pendingScheduled => '已排程(未发送)';

  @override
  String get sentRecentTitle => '近期已发送';

  @override
  String get cancelSchedule => '取消排程';

  @override
  String get recallAction => '撤回';

  @override
  String get recallWarn => '撤回后所有用户的通知中心将不再显示此通知;已弹出的手机推送无法收回。确定?';

  @override
  String get tzMore => '其他时区…';

  @override
  String get back => '返回';

  @override
  String get studyQaTitle => '学修问答';

  @override
  String get studyQaMine => '我的提问';

  @override
  String get studyQaAsk => '提问';

  @override
  String get studyQaNewHint => '请写下您的学修问题…';

  @override
  String get studyQaPending => '待回复';

  @override
  String get studyQaAnswered => '已回复';

  @override
  String get studyQaTabAll => '全部';

  @override
  String get studyQaAdminLabel => '管理员';

  @override
  String get studyQaAskerLabel => '提问人';

  @override
  String get studyQaDelete => '删除提问';

  @override
  String get studyQaDeleteConfirm => '删除后问答内容将永久消失,无法恢复。确定删除?';

  @override
  String get studyQaDeleted => '该提问已删除';

  @override
  String get studyQaEmpty => '还没有提问。';

  @override
  String get studyQaLimitHit => '您已有 3 个提问待回复,请耐心等待回复后再提问。';

  @override
  String get studyQaSend => '发送';

  @override
  String get notifQaReply => '您的提问有新回复';

  @override
  String get notifQaQuestion => '有新的学修提问';

  @override
  String get notifySection => '通知';

  @override
  String get notifyQuietTitle => '免打扰时段';

  @override
  String get notifyQuietHint => '此时段内不发手机推送,顺延到结束后发送;活动开始前的提醒不受限。';

  @override
  String get notifyQuietStart => '开始';

  @override
  String get notifyQuietEnd => '结束';

  @override
  String get notifySubscribeHeader => '接收以下通知';

  @override
  String get notifyTypeEventReminder => '活动提醒';

  @override
  String get notifyTypeEventChanged => '活动变动';

  @override
  String get notifyTypeQaReply => '学修问答回复';

  @override
  String get notifyMarkAllRead => '全部已读';

  @override
  String get notifyOnChangeSwitch => '通知所有人';

  @override
  String get notifEventReminderEve => '活动预告';

  @override
  String get notifEventReminderSoon => '活动即将开始';

  @override
  String get notifEventReminderNow => '活动开始了';

  @override
  String notifEventReminderInHours(int n) {
    return '$n 小时后开始';
  }

  @override
  String notifEventReminderInMinutes(int n) {
    return '$n 分钟后开始';
  }

  @override
  String get notifEventReminderEnter => '点击进入';

  @override
  String get actOccRestored => '单次恢复';

  @override
  String get reminderSectionTitle => '提醒';

  @override
  String get reminderAddButton => '新增提醒';

  @override
  String get reminderListLabel => '已设提醒';

  @override
  String get reminderOffsetAtStart => '活动开始时';

  @override
  String get reminderOffsetOneDay => '提前一天';

  @override
  String get reminderOffsetTwoDays => '提前两天';

  @override
  String reminderOffsetMinutes(int n) {
    return '提前 $n 分钟';
  }

  @override
  String reminderOffsetHours(int n) {
    return '提前 $n 小时';
  }

  @override
  String get communityTitle => '共修报数';

  @override
  String get communityLogs => '共修报数记录';

  @override
  String get communityAnnouncement => '共修公告';

  @override
  String get communityEmptyToday => '今日还没有人报数 · 随喜您先行';

  @override
  String get myCustomTypes => '我的自定功课';

  @override
  String get statsMine => '我的';

  @override
  String get statsAll => '全体';

  @override
  String get statsScaledNote => '各自比例';

  @override
  String get searchMemberHint => '输入姓名搜索同修';

  @override
  String get searchMemberEmpty => '找不到这位同修,可改用「任意名字」代报';

  @override
  String get customTypePrivateHint => '自定功课仅自己可见,别的同修看不到你的清单。';
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

  @override
  String get unitHour => '小時';

  @override
  String get authSignIn => '登入';

  @override
  String get authSignUp => '註冊';

  @override
  String get authSignOut => '登出';

  @override
  String get authEmail => '電子郵箱';

  @override
  String get authEmailInvalid => '請輸入有效的電子郵箱';

  @override
  String get authPassword => '密碼';

  @override
  String get authPasswordMin => '密碼至少 6 位';

  @override
  String get authForgot => '忘記密碼?';

  @override
  String get authResetSent => '重設密碼郵件已發送,請查收';

  @override
  String get authUsername => '用戶名或郵箱';

  @override
  String get authUsernameHint => '3–30 位小寫字母、數字或 . _ -;也可直接用郵箱';

  @override
  String get authUsernameInvalid => '用戶名需 3–30 位字母、數字或 . _ -(或有效郵箱)';

  @override
  String get authRecoveryEmail => '電郵(選填)';

  @override
  String get authRecoveryEmailHint => '僅用於忘記密碼時找回,可不填';

  @override
  String get authResetNeedAdmin => '此帳號未綁定郵箱,請聯繫管理員重置密碼';

  @override
  String get authToSignUp => '沒有帳號?註冊';

  @override
  String get authToSignIn => '已有帳號?登入';

  @override
  String get authFailed => '操作失敗:';

  @override
  String get settingsTitle => '設定';

  @override
  String get displayName => '顯示名稱';

  @override
  String get save => '儲存';

  @override
  String get saved => '已儲存';

  @override
  String get next => '下一步';

  @override
  String get done => '完成';

  @override
  String get onboardingLanguage => '選擇語言';

  @override
  String get onboardingFont => '選擇字號';

  @override
  String get onboardingFontPreview => '諸惡莫作,眾善奉行';

  @override
  String get onboardingRegion => '所在地區';

  @override
  String get onboardingRegionHint => '用於選擇通知送達方式(大陸地區以應用內通知與郵件為主)';

  @override
  String get regionCn => '中國大陸';

  @override
  String get regionOther => '其他地區';

  @override
  String get submit => '提交';

  @override
  String get cancel => '取消';

  @override
  String get copied => '已複製';

  @override
  String get addPracticeType => '新增功課項';

  @override
  String get practiceTypeName => '名稱';

  @override
  String get unitTitle => '單位';

  @override
  String get reportLog => '報數';

  @override
  String get logsTitle => '報數記錄';

  @override
  String get selectPracticeType => '選擇功課';

  @override
  String get subjectTitle => '為誰報數';

  @override
  String get subjectSelf => '自己';

  @override
  String get subjectMember => '同修';

  @override
  String get subjectName => '其他名字';

  @override
  String get quantityTitle => '數量';

  @override
  String get noteLabel => '備註(選填;補報可註明實際日期)';

  @override
  String get submitLog => '提交報數';

  @override
  String get logSubmitted => '已報數,隨喜讚歎!';

  @override
  String get offlineQueued => '網絡不通,已離線暫存,連網後自動補傳';

  @override
  String get offlineFlushed => '已補傳離線報數';

  @override
  String get quantityInvalid => '請輸入正確的數量';

  @override
  String get edit => '編輯';

  @override
  String get delete => '刪除';

  @override
  String get confirmDeleteLog => '確定刪除這條報數?統計將即時扣減。';

  @override
  String get proxyBy => '代報';

  @override
  String get fellowPractitioner => '同修';

  @override
  String get categoryTitle => '分類';

  @override
  String get categorySutra => '經';

  @override
  String get categoryMantra => '咒';

  @override
  String get categoryRepentance => '懺';

  @override
  String get categoryBuddhaName => '念佛';

  @override
  String get categoryMeditation => '靜坐';

  @override
  String get categoryOther => '其他';

  @override
  String get quickReport => '快捷報數';

  @override
  String get myStats => '個人統計';

  @override
  String get todayTitle => '今日';

  @override
  String get totalTitle => '累計';

  @override
  String get streakLabel => '連續用功天數';

  @override
  String get trend14 => '近 14 天趨勢(筆數)';

  @override
  String get historyTitle => '歷史查看';

  @override
  String get pickDate => '選擇日期';

  @override
  String get noDataToday => '今日尚未報數';

  @override
  String get reportedToday => '今日已報人數';

  @override
  String get reportAction => '檢舉';

  @override
  String get reportReasonLabel => '原因';

  @override
  String get reportSubmitted => '已提交檢舉,管理員會盡快處理';

  @override
  String get blockUser => '封鎖此用戶';

  @override
  String get unblockUser => '解除封鎖';

  @override
  String get privacyPolicy => '隱私政策';

  @override
  String get communityGuidelines => '社區規範';

  @override
  String get eulaAgreeFinish => '同意並完成';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get deleteAccountWarn => '帳號與個人資料將被永久刪除,無法恢復;您的歷史報數將匿名保留於共修統計中。確定刪除?';

  @override
  String get adminReports => '檢舉處理';

  @override
  String get markResolved => '標記已處理';

  @override
  String get banUser => '封禁該用戶';

  @override
  String get repeatLast => '重複上次';

  @override
  String get forOthers => '替他人報數';

  @override
  String get frequentGroup => '常用';

  @override
  String get notificationsTitle => '通知';

  @override
  String get notifProxyLog => '有同修為您代報';

  @override
  String get notifAnnouncement => '共修公告更新';

  @override
  String get vowsTitle => '我的發願';

  @override
  String get createVow => '發願';

  @override
  String get vowTarget => '目標數量';

  @override
  String get vowPeriod => '期限';

  @override
  String get daysUnit => '天';

  @override
  String daysLeft(int days) {
    return '剩餘 $days 天';
  }

  @override
  String get vowCompleted => '已圓滿';

  @override
  String get vowExpired => '已到期';

  @override
  String get vowCongrats => '隨喜讚歎!發願圓滿';

  @override
  String get quickReportTitle => '快捷報數';

  @override
  String get quickEmptyHint => '還沒有常用組合,先報一次數,下次就能一鍵重複。';

  @override
  String get sectionDaily => '日課';

  @override
  String get sectionSangha => '共修';

  @override
  String get sectionSelf => '修行';

  @override
  String get sectionGeneral => '通用';

  @override
  String get themeTitle => '外觀';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get logsEmptyHint => '還沒有人報數,從首頁「報數」開始吧。';

  @override
  String get vowsEmptyHint => '發一個願,讓精進有方向。';

  @override
  String get scripturesTitle => '在線經本';

  @override
  String get liveTitle => '直播';

  @override
  String get liveNow => '直播中';

  @override
  String get notLive => '目前未直播';

  @override
  String get enterLive => '進入直播';

  @override
  String get openChannel => '打開頻道';

  @override
  String get joinWebex => '加入 Webex 共修';

  @override
  String get webexOpenApp => '用 Webex App 開啟';

  @override
  String get webexHint => '固定共修房間,開始時間見活動日曆';

  @override
  String get replaysTitle => '往期回看';

  @override
  String get notifLiveStarted => '直播開始了';

  @override
  String get calendarTitle => '活動日曆';

  @override
  String get createEvent => '新增活動';

  @override
  String get eventTitleLabel => '活動名稱';

  @override
  String get weeklyRepeat => '每週重複';

  @override
  String get eventCancelled => '本次取消';

  @override
  String get cancelOccurrence => '取消本次活動';

  @override
  String get upcomingTitle => '未來活動';

  @override
  String get manageEventTypes => '事件類型管理';

  @override
  String get editEvent => '編輯活動';

  @override
  String get deleteEvent => '刪除活動';

  @override
  String get confirmDeleteEvent => '確定刪除此活動?所有重複場次將一併移除,並通知全體用戶。';

  @override
  String get typeNameHant => '名稱(繁體)';

  @override
  String get typeNameHans => '名稱(簡體)';

  @override
  String get iconLabel => '圖標';

  @override
  String get activeLabel => '啟用';

  @override
  String get deleteTypeBlocked => '該類型已被活動使用,無法刪除;可改為停用。';

  @override
  String get notifEventChanged => '活動異動';

  @override
  String get actCreated => '新增';

  @override
  String get actUpdated => '更新';

  @override
  String get actDeleted => '已取消';

  @override
  String get actOccCancelled => '單次取消';

  @override
  String get actOccChanged => '單次改期';

  @override
  String get toolsTitle => '工具';

  @override
  String get timerTitle => '打坐計時';

  @override
  String get timerDuration => '時長';

  @override
  String get customDuration => '自訂';

  @override
  String get customDurationTitle => '自訂時長';

  @override
  String get counterTitle => '念珠計數';

  @override
  String get startTimer => '開始';

  @override
  String get stopTimer => '結束';

  @override
  String get timeUp => '時間到';

  @override
  String get intervalBell => '中途鈴(正念提醒)';

  @override
  String get prepBell => '預備鈴';

  @override
  String get offLabel => '關閉';

  @override
  String get keepAwake => '螢幕常亮';

  @override
  String get keepForeground => '計時期間請保持 App 開啟,螢幕會自動常亮';

  @override
  String get tapToCount => '點擊螢幕任意處計數';

  @override
  String get roundsLabel => '串數';

  @override
  String get beadsTarget => '一串';

  @override
  String get resetCount => '清零';

  @override
  String get confirmReset => '確定清零?';

  @override
  String get soundToggle => '鈴聲';

  @override
  String get toReport => '轉為報數';

  @override
  String get dedicationTitle => '迴向';

  @override
  String get dedicationText =>
      '願以此功德,莊嚴佛淨土。\n上報四重恩,下濟三途苦。\n若有見聞者,悉發菩提心。\n盡此一報身,同生極樂國。';

  @override
  String get errNetwork => '網絡連接失敗,請檢查網絡後重試';

  @override
  String get errGeneric => '操作失敗,請稍後再試';

  @override
  String get errAuthInvalidCredentials => '用戶名或密碼錯誤';

  @override
  String get errAuthAlreadyRegistered => '該帳號已被註冊,請直接登入';

  @override
  String get errAuthWeakPassword => '密碼至少 6 位';

  @override
  String get errAuthNotActivated => '帳號尚未啟用,請聯繫管理員';

  @override
  String get errAuthRateLimited => '操作過於頻繁,請稍後再試';

  @override
  String get errAuthSignupDisabled => '暫未開放註冊';

  @override
  String get errAuthBanned => '帳號已被停用,請聯繫管理員';

  @override
  String get errNoPermission => '沒有權限執行此操作';

  @override
  String get errDuplicate => '資料重複,請勿重複提交';

  @override
  String get errSessionExpired => '登入已過期,請重新登入';

  @override
  String get mrTitle => '正念提醒';

  @override
  String get mrEnable => '開啟正念提醒';

  @override
  String get mrEnableHint => '在設定的時段內定時響磬,提醒回到當下';

  @override
  String get mrWeekdays => '提醒日';

  @override
  String get mrDay1 => '一';

  @override
  String get mrDay2 => '二';

  @override
  String get mrDay3 => '三';

  @override
  String get mrDay4 => '四';

  @override
  String get mrDay5 => '五';

  @override
  String get mrDay6 => '六';

  @override
  String get mrDay7 => '日';

  @override
  String get mrStart => '開始時間';

  @override
  String get mrEnd => '結束時間';

  @override
  String get mrWindowInvalid => '結束時間需晚於開始時間';

  @override
  String get mrInterval => '間隔';

  @override
  String get mrSound => '提示音';

  @override
  String get mrSoundBell => '磬聲';

  @override
  String get mrSoundSilent => '靜音';

  @override
  String get mrVibrate => '震動';

  @override
  String get mrPreviewSound => '試聽';

  @override
  String get mrMessage => '提醒文案';

  @override
  String get mrMessageDefault => '該正念了 · 回到當下';

  @override
  String get mrMessageHint => '留空則用預設文案';

  @override
  String mrCountSummary(int daily, int total) {
    return '每天 $daily 次 · 本週共 $total 次';
  }

  @override
  String mrIosCapWarning(int cap, int total) {
    return 'iOS 最多 $cap 條通知,目前 $total 條會被截斷;請增大間隔或縮短時段';
  }

  @override
  String get mrTest => '立即測試';

  @override
  String get mrTestSent => '測試通知已發送';

  @override
  String get mrHelp => '讓提醒準時響起';

  @override
  String get mrHelpSubtitle => 'iOS 與 Android 設定指引';

  @override
  String get mrPermDenied => '通知權限未開啟,提醒無法響起';

  @override
  String get mrGrant => '去開啟';

  @override
  String get mrRespectSilent => '手機靜音或勿擾時不會出聲,僅顯示橫幅(尊重系統設定)';

  @override
  String get mrHelpIntro => '提醒靠系統在預定時刻觸發。請按下面步驟放行,確保 App 關閉或息屏時也能響。';

  @override
  String get mrSelfCheck => '響鈴自檢';

  @override
  String get mrSelfCheckHint => '點一下發一條測試通知,看是否真的響了。';

  @override
  String get mrHelpIosTitle => 'iOS 設定';

  @override
  String get mrHelpIosStep1 =>
      '允許通知:首次開啟會彈窗;若曾拒絕,前往「設定 > 善護念 > 通知」開啟允許通知、聲音、鎖屏顯示。';

  @override
  String get mrHelpIosStep2 => '靜音/勿擾:處於靜音檔或勿擾時不會出聲(系統限制,非故障);需要出聲請退出靜音。';

  @override
  String get mrHelpIosStep3 => '專注模式:若開啟了工作/睡眠等專注,可能攔截通知,請把善護念加入允許清單。';

  @override
  String get mrHelpAndroidTitle => 'Android 設定';

  @override
  String get mrHelpAndroidStep1 => '允許通知:在系統彈窗或「應用資訊 > 通知」中允許。';

  @override
  String get mrHelpAndroidStep2 => '電池不受限:關閉對本 App 的電池最佳化,否則後台可能被限制。';

  @override
  String get mrHelpAndroidStep3 => '勿擾說明:系統勿擾時不會出聲,僅顯示橫幅。';

  @override
  String get mrHelpOemTitle => '國產手機額外設定(小米/華為/OPPO/vivo 等)';

  @override
  String get mrHelpOemBody =>
      '這些手機預設會清理後台,可能延遲或漏掉提醒。請手動開啟:自啟動/自動啟動、允許後台活動(不受限制)、鎖定在最近任務、允許後台彈通知。即便全部放行,個別機型仍可能延遲——這是系統限制,非本 App 故障。';

  @override
  String get mrOpenSettings => '去應用設定';

  @override
  String get qaTitle => '往期問答';

  @override
  String get qaEntryTitle => '往期問答檢索';

  @override
  String get qaEntrySubtitle => '搜尋歷次講法問答片段';

  @override
  String get qaSearchHint => '搜尋關鍵詞(2 字以上)';

  @override
  String get qaTooShort => '請輸入 2 個字以上';

  @override
  String qaResultCount(int n) {
    return '共 $n 條';
  }

  @override
  String get qaEmpty => '未找到相關內容';

  @override
  String get qaEmptyHint => '試試其他關鍵詞,或清除標籤篩選';

  @override
  String get qaBackToList => '返回列表';

  @override
  String get qaTagsAdd => '標籤';

  @override
  String get qaTagPickerTitle => '選擇標籤';

  @override
  String get qaTagPickerHint => '搜尋標籤';

  @override
  String get qaTagPickerOr => '選多個標籤時,符合任一即顯示';

  @override
  String qaTagPickerDone(int n) {
    return '完成($n)';
  }

  @override
  String get qaOpenExternal => '用 YouTube App 開啟';

  @override
  String qaFromVideo(String title) {
    return '出自「$title」';
  }

  @override
  String get eventShare => '分享';

  @override
  String get eventAgendaTitle => '時間表';

  @override
  String get eventAttachmentsTitle => '相關資料';

  @override
  String get eventCopy => '複製';

  @override
  String get eventCopied => '已複製時間表';

  @override
  String get eventLinkLabelDefault => '查看';

  @override
  String get eventAdminTitle => '管理員';

  @override
  String get eventEditAgenda => '編輯時間表/資料';

  @override
  String get eventAddAgendaRow => '新增一行';

  @override
  String get eventUploadPdf => '上傳 PDF';

  @override
  String get eventUploading => '上傳中…';

  @override
  String get eventNoAgenda => '尚未安排時間表,點「新增一行」開始';

  @override
  String get eventAttachmentName => '資料名稱';

  @override
  String get eventAgendaSaved => '時間表已儲存';

  @override
  String get confirmDeleteAttachment => '確定刪除此資料?檔案將從伺服器移除。';

  @override
  String get agendaDay => '第幾天';

  @override
  String get agendaStart => '開始時間';

  @override
  String get agendaEnd => '結束時間(選填)';

  @override
  String get agendaActivity => '活動內容';

  @override
  String get agendaLinkUrl => '連結網址(選填)';

  @override
  String get agendaLinkLabel => '連結文字(選填)';

  @override
  String get almanacToday => '今日';

  @override
  String get almanacZhaiTen => '十齋日';

  @override
  String get notifAlmanacFestival => '今日佛教節日';

  @override
  String get notifAlmanacEve => '明日佛教節日';

  @override
  String get notifAlmanacZhai => '今日十齋日';

  @override
  String get almanacSection => '佛曆提醒';

  @override
  String get almanacFestivalToggle => '佛教節日提醒';

  @override
  String get almanacZhaiToggle => '十齋日提醒';

  @override
  String get eventTimezoneLabel => '時區';

  @override
  String get eventLocalTime => '活動當地時間';

  @override
  String get defaultEventTimezone => '預設活動時區';

  @override
  String get tzPickerTitle => '選擇時區';

  @override
  String get tzSearchHint => '輸入城市或時區名稱搜尋';

  @override
  String get noEventsThisDay => '沒有活動';

  @override
  String get legendFestival => '節日';

  @override
  String get legendEvent => '活動';

  @override
  String get yourLocalTime => '您的時間';

  @override
  String get sectionAdmin => '管理';

  @override
  String get publishNotify => '發布通知';

  @override
  String get titleLabel => '標題';

  @override
  String get contentLabel => '內容(選填)';

  @override
  String get scheduleSend => '定時發送';

  @override
  String get sendTimeLabel => '發送時間(您的時間)';

  @override
  String get confirmPublishTitle => '確認發布';

  @override
  String get confirmPublishAll => '將發送給全體用戶';

  @override
  String get sendNow => '立即發送';

  @override
  String get publishedOk => '已發布';

  @override
  String get scheduledOk => '已排程';

  @override
  String get pendingScheduled => '已排程(未發送)';

  @override
  String get sentRecentTitle => '近期已發送';

  @override
  String get cancelSchedule => '取消排程';

  @override
  String get recallAction => '撤回';

  @override
  String get recallWarn => '撤回後所有用戶的通知中心將不再顯示此通知;已彈出的手機推送無法收回。確定?';

  @override
  String get tzMore => '其他時區…';

  @override
  String get back => '返回';

  @override
  String get studyQaTitle => '學修問答';

  @override
  String get studyQaMine => '我的提問';

  @override
  String get studyQaAsk => '提問';

  @override
  String get studyQaNewHint => '請寫下您的學修問題…';

  @override
  String get studyQaPending => '待回覆';

  @override
  String get studyQaAnswered => '已回覆';

  @override
  String get studyQaTabAll => '全部';

  @override
  String get studyQaAdminLabel => '管理員';

  @override
  String get studyQaAskerLabel => '提問人';

  @override
  String get studyQaDelete => '刪除提問';

  @override
  String get studyQaDeleteConfirm => '刪除後問答內容將永久消失,無法恢復。確定刪除?';

  @override
  String get studyQaDeleted => '該提問已刪除';

  @override
  String get studyQaEmpty => '還沒有提問。';

  @override
  String get studyQaLimitHit => '您已有 3 個提問待回覆,請耐心等待回覆後再提問。';

  @override
  String get studyQaSend => '發送';

  @override
  String get notifQaReply => '您的提問有新回覆';

  @override
  String get notifQaQuestion => '有新的學修提問';

  @override
  String get notifySection => '通知';

  @override
  String get notifyQuietTitle => '免打擾時段';

  @override
  String get notifyQuietHint => '此時段內不發手機推送,順延到結束後發送;活動開始前的提醒不受限。';

  @override
  String get notifyQuietStart => '開始';

  @override
  String get notifyQuietEnd => '結束';

  @override
  String get notifySubscribeHeader => '接收以下通知';

  @override
  String get notifyTypeEventReminder => '活動提醒';

  @override
  String get notifyTypeEventChanged => '活動變動';

  @override
  String get notifyTypeQaReply => '學修問答回覆';

  @override
  String get notifyMarkAllRead => '全部已讀';

  @override
  String get notifyOnChangeSwitch => '通知所有人';

  @override
  String get notifEventReminderEve => '活動預告';

  @override
  String get notifEventReminderSoon => '活動即將開始';

  @override
  String get notifEventReminderNow => '活動開始了';

  @override
  String notifEventReminderInHours(int n) {
    return '$n 小時後開始';
  }

  @override
  String notifEventReminderInMinutes(int n) {
    return '$n 分鐘後開始';
  }

  @override
  String get notifEventReminderEnter => '點擊進入';

  @override
  String get actOccRestored => '單次恢復';

  @override
  String get reminderSectionTitle => '提醒';

  @override
  String get reminderAddButton => '新增提醒';

  @override
  String get reminderListLabel => '已設提醒';

  @override
  String get reminderOffsetAtStart => '活動開始時';

  @override
  String get reminderOffsetOneDay => '提前一天';

  @override
  String get reminderOffsetTwoDays => '提前兩天';

  @override
  String reminderOffsetMinutes(int n) {
    return '提前 $n 分鐘';
  }

  @override
  String reminderOffsetHours(int n) {
    return '提前 $n 小時';
  }

  @override
  String get communityTitle => '共修報數';

  @override
  String get communityLogs => '共修報數紀錄';

  @override
  String get communityAnnouncement => '共修公告';

  @override
  String get communityEmptyToday => '今日還沒有人報數 · 隨喜您先行';

  @override
  String get myCustomTypes => '我的自訂功課';

  @override
  String get statsMine => '我的';

  @override
  String get statsAll => '全體';

  @override
  String get statsScaledNote => '各自比例';

  @override
  String get searchMemberHint => '輸入姓名搜尋同修';

  @override
  String get searchMemberEmpty => '找不到這位同修,可改用「任意名字」代報';

  @override
  String get customTypePrivateHint => '自訂功課僅自己可見,別的同修看不到你的清單。';
}
