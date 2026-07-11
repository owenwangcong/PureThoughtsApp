import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../l10n/gen/app_localizations.dart';

/// App 内 YouTube 播放(直播与回看共用;PRD §6 YouTube 内嵌播放)。
/// 注:受 YouTube ToS 限制不做后台/息屏播放(PRD §8)。
/// 播放器被拒(101/150 嵌入受限、153 无有效 Referer 等)时,
/// 给出网页观看 / YouTube App 两个备用入口。
class _RefererFixedController extends YoutubePlayerController {
  // YouTube 2025 起拒绝无 Referer / 冒充 youtube.com 来源的嵌入(错误 153,
  // 实测浏览器直开 /embed 同样报 153,带真实站点 Referer 的 iframe 则正常播)。
  // 包 5.2.2 的 origin 参数同时充当 baseUrl(Referer)与 YT.Player host,无法分开:
  // origin=null 让 playerVars 不带 origin、host 落默认 youtube.com,
  // 再覆写 load() 把 baseUrl 固定为本项目域名,构成"真实 Referer + 官方 host"组合。
  _RefererFixedController()
      : super(
          params: const YoutubePlayerParams(
            origin: null,
            showFullscreenButton: true,
            strictRelatedVideos: true,
          ),
        );

  @override
  Future<void> load({
    required YoutubePlayerParams params,
    String? baseUrl,
    String id = 'player',
  }) {
    return super.load(
        params: params, baseUrl: 'https://pure-thoughts.com', id: id);
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.videoId});

  final String videoId;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _sub;
  var _error = YoutubeError.none;

  String get _watchUrl => 'https://www.youtube.com/watch?v=${widget.videoId}';

  @override
  void initState() {
    super.initState();
    _controller = _RefererFixedController();
    _controller.loadVideoById(videoId: widget.videoId);
    _sub = _controller.stream.listen((v) {
      if (v.error != YoutubeError.none && v.error != _error && mounted) {
        setState(() => _error = v.error);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: _error == YoutubeError.none
            ? YoutubePlayer(
                controller: _controller,
                aspectRatio: 16 / 9,
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off, size: 48, color: scheme.outline),
                    const SizedBox(height: 12),
                    Text(l10n.videoFallbackHint, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      icon: const Icon(Icons.public),
                      label: Text(l10n.watchOnWeb),
                      onPressed: () => context.pushReplacement(Uri(
                        path: '/webview',
                        queryParameters: {'url': _watchUrl, 'title': 'YouTube'},
                      ).toString()),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.openInYoutube),
                      onPressed: () => launchUrl(Uri.parse(_watchUrl),
                          mode: LaunchMode.externalApplication),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
