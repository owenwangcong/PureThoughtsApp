/// 固定直播频道(PRD v0.5.6 §6 定案;与 supabase/functions/live-probe 保持一致)
abstract final class Channels {
  static const youtubeChannelUrl = 'https://www.youtube.com/@善護念';
  static const youtubeLiveUrl = 'https://www.youtube.com/@善護念/live';
  static const webexJoinUrl = 'https://purethoughts.my.webex.com/join/Shanhunian';

  /// 应用内加入的入口(2026-07-11 实测定案):web.webex.com 的通用加入页是
  /// **顶层页面**(无跨域 iframe),WebViewScreen 可全程 JS 自动化——
  /// 填会议链接→Next→访客表单填名字/邮箱→加入。
  /// (join 链接的下载页会把访客表单套在跨域 iframe 里,注入触不到,弃用;
  /// webappng landing 直链无会话上下文会弹回营销页,不可用。)
  static const webexBrowserJoinUrl = 'https://web.webex.com/join-meeting';
  static const scripturesUrl = 'https://qldazangjing.com/'; // 乾隆大藏經(E9)
}
