import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../l10n/gen/app_localizations.dart';

/// App 内 YouTube 播放(直播与回看共用;PRD §6 YouTube 内嵌播放)。
/// 注:受 YouTube ToS 限制不做后台/息屏播放(PRD §8)。
/// 频道未开"允许嵌入"等情况 iframe 会拒播(错误 101/150),
/// 此时给出网页观看 / YouTube App 两个备用入口。
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
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
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
