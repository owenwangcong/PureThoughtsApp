import 'package:flutter/material.dart';

import 'web_view_screen.dart';

/// App 内 YouTube 播放(直播与回看共用;PRD §6)。
/// 2026-07-11 改为直接加载移动版 watch 页:YouTube 拒绝无真实 Referer 的
/// iframe 嵌入(错误 153),而 Android WebView 的 loadHtmlString(baseUrl)
/// 不会随请求发真实 Referer,内嵌播放器路线在真机上不可行;
/// watch 网页无嵌入限制,直播/回看皆可播,全屏按钮自带。
/// 注:受 YouTube ToS 限制不做后台/息屏播放(PRD §8)。
class VideoPlayerScreen extends StatelessWidget {
  const VideoPlayerScreen({super.key, required this.videoId, this.startSeconds});

  final String videoId;

  /// 起播秒数(往期问答 timestamp_url 的 ?t=;直播/回看不传)。
  final int? startSeconds;

  @override
  Widget build(BuildContext context) {
    final url = 'https://m.youtube.com/watch?v=$videoId'
        '${startSeconds != null ? '&t=${startSeconds}s' : ''}';
    return WebViewScreen(url: url, title: 'YouTube', externalUrl: url);
  }
}
