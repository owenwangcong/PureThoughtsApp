/// 固定直播频道(PRD v0.5.6 §6 定案;与 supabase/functions/live-probe 保持一致)
abstract final class Channels {
  static const youtubeChannelUrl = 'https://www.youtube.com/@善護念';
  static const youtubeLiveUrl = 'https://www.youtube.com/@善護念/live';
  // 应用内加入也用 join 链接:桌面 UA 下它给出"从浏览器加入"入口,由
  // WebViewScreen 自动点击直达访客表单(2026-07-11 实测;webappng landing
  // 直链没有会话上下文会被弹回营销页,不可用)
  static const webexJoinUrl = 'https://purethoughts.my.webex.com/join/Shanhunian';
  static const scripturesUrl = 'https://qldazangjing.com/'; // 乾隆大藏經(E9)
}
