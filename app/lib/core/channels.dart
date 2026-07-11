/// 固定直播频道(PRD v0.5.6 §6 定案;与 supabase/functions/live-probe 保持一致)
abstract final class Channels {
  static const youtubeChannelUrl = 'https://www.youtube.com/@善護念';
  static const youtubeLiveUrl = 'https://www.youtube.com/@善護念/live';
  static const webexJoinUrl = 'https://purethoughts.my.webex.com/join/Shanhunian';

  /// Webex 網頁客戶端訪客直達入口(免 App 下載頁,應用內加入用):
  /// uuid = 固定個人會議室的會議 UUID(取自 join 鏈接跳轉頁);房間更換時需同步更新
  static const webexWebClientUrl =
      'https://purethoughts.my.webex.com/webappng/sites/purethoughts.my/dashboard/landing'
      '?siteurl=purethoughts.my&type=Attendee&uuid=82acaa3f02a24c34ac261094bd05654a';
  static const scripturesUrl = 'https://qldazangjing.com/'; // 乾隆大藏經(E9)
}
