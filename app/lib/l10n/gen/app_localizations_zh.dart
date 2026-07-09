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
  String get groupsTitle => '我的群組';

  @override
  String get createGroup => '建立群組';

  @override
  String get joinGroup => '申請入群';

  @override
  String get groupName => '群組名稱';

  @override
  String get groupDescription => '群組簡介';

  @override
  String get joinCodeLabel => '群 ID';

  @override
  String get applyMessageLabel => '申請說明';

  @override
  String get submit => '提交';

  @override
  String get cancel => '取消';

  @override
  String get statusPending => '審核中';

  @override
  String get roleOwner => '群主';

  @override
  String get members => '成員';

  @override
  String get pendingApplications => '入群審核';

  @override
  String get approve => '通過';

  @override
  String get reject => '拒絕';

  @override
  String get copied => '已複製';

  @override
  String get joinRequested => '已提交申請,等待群主審核';

  @override
  String get groupCreated => '群組已建立';

  @override
  String get announcement => '公告';

  @override
  String get editAnnouncement => '編輯公告';

  @override
  String get leaveGroup => '退出群組';

  @override
  String get removeMember => '移除成員';

  @override
  String get transferOwner => '轉讓群主';

  @override
  String get dissolveGroup => '解散群組';

  @override
  String get resetJoinCode => '重置群 ID';

  @override
  String get confirmLeave => '確定退出此群組?歷史報數將保留。';

  @override
  String get confirmRemove => '確定移除該成員?其歷史報數將保留。';

  @override
  String get confirmTransfer => '確定將群主轉讓給此成員?轉讓後您將成為普通成員。';

  @override
  String get confirmDissolve => '解散後群組對所有成員不可見,且無法恢復。確定解散?';

  @override
  String get confirmResetCode => '舊群 ID 將立即失效,確定重置?';

  @override
  String get groupPracticeTypes => '本群功課項';

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
  String get subjectMember => '群成員';

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
  String get groupStats => '群統計';

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
  String get reportGroup => '檢舉群組';

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
  String get deleteAccountWarn => '帳號與個人資料將被永久刪除,無法恢復;您的歷史報數將匿名保留於群統計中。確定刪除?';

  @override
  String get deleteOwnerBlocked => '您仍是群組群主,請先轉讓或解散群組,再刪除帳號。';

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
  String get chooseGroup => '選擇群組';

  @override
  String get notificationsTitle => '通知';

  @override
  String get notifProxyLog => '有同修為您代報';

  @override
  String get notifAnnouncement => '群公告更新';

  @override
  String get vowsTitle => '我的發願';

  @override
  String get createVow => '發願';

  @override
  String get vowTarget => '目標數量';

  @override
  String get vowPeriod => '期限';

  @override
  String get vowScope => '範圍';

  @override
  String get scopeAllGroups => '全部群組';

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
  String get groupsEmptyHint => '輸入群 ID 申請加入,或建立新群組,與同修一起精進。';

  @override
  String get logsEmptyHint => '本群還沒有報數,點右下角「報數」開始。';

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
  String get groupsTitle => '我的群组';

  @override
  String get createGroup => '创建群组';

  @override
  String get joinGroup => '申请入群';

  @override
  String get groupName => '群组名称';

  @override
  String get groupDescription => '群组简介';

  @override
  String get joinCodeLabel => '群 ID';

  @override
  String get applyMessageLabel => '申请说明';

  @override
  String get submit => '提交';

  @override
  String get cancel => '取消';

  @override
  String get statusPending => '审核中';

  @override
  String get roleOwner => '群主';

  @override
  String get members => '成员';

  @override
  String get pendingApplications => '入群审核';

  @override
  String get approve => '通过';

  @override
  String get reject => '拒绝';

  @override
  String get copied => '已复制';

  @override
  String get joinRequested => '已提交申请,等待群主审核';

  @override
  String get groupCreated => '群组已创建';

  @override
  String get announcement => '公告';

  @override
  String get editAnnouncement => '编辑公告';

  @override
  String get leaveGroup => '退出群组';

  @override
  String get removeMember => '移除成员';

  @override
  String get transferOwner => '转让群主';

  @override
  String get dissolveGroup => '解散群组';

  @override
  String get resetJoinCode => '重置群 ID';

  @override
  String get confirmLeave => '确定退出此群组?历史报数将保留。';

  @override
  String get confirmRemove => '确定移除该成员?其历史报数将保留。';

  @override
  String get confirmTransfer => '确定将群主转让给此成员?转让后您将成为普通成员。';

  @override
  String get confirmDissolve => '解散后群组对所有成员不可见,且无法恢复。确定解散?';

  @override
  String get confirmResetCode => '旧群 ID 将立即失效,确定重置?';

  @override
  String get groupPracticeTypes => '本群功课项';

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
  String get subjectMember => '群成员';

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
  String get groupStats => '群统计';

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
  String get reportGroup => '举报群组';

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
  String get deleteAccountWarn => '账号与个人资料将被永久删除,无法恢复;您的历史报数将匿名保留于群统计中。确定删除?';

  @override
  String get deleteOwnerBlocked => '您仍是群组群主,请先转让或解散群组,再删除账号。';

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
  String get chooseGroup => '选择群组';

  @override
  String get notificationsTitle => '通知';

  @override
  String get notifProxyLog => '有同修为您代报';

  @override
  String get notifAnnouncement => '群公告更新';

  @override
  String get vowsTitle => '我的发愿';

  @override
  String get createVow => '发愿';

  @override
  String get vowTarget => '目标数量';

  @override
  String get vowPeriod => '期限';

  @override
  String get vowScope => '范围';

  @override
  String get scopeAllGroups => '全部群组';

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
  String get groupsEmptyHint => '输入群 ID 申请加入,或创建新群组,与同修一起精进。';

  @override
  String get logsEmptyHint => '本群还没有报数,点右下角「报数」开始。';

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
  String get groupsTitle => '我的群組';

  @override
  String get createGroup => '建立群組';

  @override
  String get joinGroup => '申請入群';

  @override
  String get groupName => '群組名稱';

  @override
  String get groupDescription => '群組簡介';

  @override
  String get joinCodeLabel => '群 ID';

  @override
  String get applyMessageLabel => '申請說明';

  @override
  String get submit => '提交';

  @override
  String get cancel => '取消';

  @override
  String get statusPending => '審核中';

  @override
  String get roleOwner => '群主';

  @override
  String get members => '成員';

  @override
  String get pendingApplications => '入群審核';

  @override
  String get approve => '通過';

  @override
  String get reject => '拒絕';

  @override
  String get copied => '已複製';

  @override
  String get joinRequested => '已提交申請,等待群主審核';

  @override
  String get groupCreated => '群組已建立';

  @override
  String get announcement => '公告';

  @override
  String get editAnnouncement => '編輯公告';

  @override
  String get leaveGroup => '退出群組';

  @override
  String get removeMember => '移除成員';

  @override
  String get transferOwner => '轉讓群主';

  @override
  String get dissolveGroup => '解散群組';

  @override
  String get resetJoinCode => '重置群 ID';

  @override
  String get confirmLeave => '確定退出此群組?歷史報數將保留。';

  @override
  String get confirmRemove => '確定移除該成員?其歷史報數將保留。';

  @override
  String get confirmTransfer => '確定將群主轉讓給此成員?轉讓後您將成為普通成員。';

  @override
  String get confirmDissolve => '解散後群組對所有成員不可見,且無法恢復。確定解散?';

  @override
  String get confirmResetCode => '舊群 ID 將立即失效,確定重置?';

  @override
  String get groupPracticeTypes => '本群功課項';

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
  String get subjectMember => '群成員';

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
  String get groupStats => '群統計';

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
  String get reportGroup => '檢舉群組';

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
  String get deleteAccountWarn => '帳號與個人資料將被永久刪除,無法恢復;您的歷史報數將匿名保留於群統計中。確定刪除?';

  @override
  String get deleteOwnerBlocked => '您仍是群組群主,請先轉讓或解散群組,再刪除帳號。';

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
  String get chooseGroup => '選擇群組';

  @override
  String get notificationsTitle => '通知';

  @override
  String get notifProxyLog => '有同修為您代報';

  @override
  String get notifAnnouncement => '群公告更新';

  @override
  String get vowsTitle => '我的發願';

  @override
  String get createVow => '發願';

  @override
  String get vowTarget => '目標數量';

  @override
  String get vowPeriod => '期限';

  @override
  String get vowScope => '範圍';

  @override
  String get scopeAllGroups => '全部群組';

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
  String get groupsEmptyHint => '輸入群 ID 申請加入,或建立新群組,與同修一起精進。';

  @override
  String get logsEmptyHint => '本群還沒有報數,點右下角「報數」開始。';

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
}
