import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../core/settings.dart';

/// 应用内浏览器(PRD §6/§7):YouTube 频道页、Webex 会议、经本等。
/// - [applyFontScale]:App 字号透传网页缩放(经本阅读)
/// - [prefillName]:Webex 访客名预填(尽力而为的 JS 注入;WebView 存储持久,
///   填过一次后 Webex 自己也会记住)
/// - 媒体权限桥接:网页申请麦克风/摄像头时放行(Webex 网页版通话)
/// - 右上角始终保留外部打开(Webex App / 浏览器)兜底
class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({
    super.key,
    required this.url,
    this.title,
    this.applyFontScale = false,
    this.prefillName,
  });

  final String url;
  final String? title;
  final bool applyFontScale;
  final String? prefillName;

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen> {
  late final WebViewController _controller;
  final _timers = <Timer>[];
  var _progress = 0;

  bool get _isWebex => widget.url.contains('webex.com');

  @override
  void initState() {
    super.initState();
    // iOS:允许内联播放,媒体不需用户手势(网页版会议必需)
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          // wbx:// intent:// market:// 等应用协议 WebView 打不开,
          // 会整页显示 ERR_UNKNOWN_URL_SCHEME;拦下来交给系统
          //(装了 Webex App 就顺势唤起,没装则静默忽略)
          if (uri != null && uri.scheme != 'http' && uri.scheme != 'https') {
            launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication)
                .catchError((_) => false);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (_) {
          _applyZoom();
          _schedulePrefill();
        },
      ));
    if (_isWebex) {
      // Webex 对移动端 UA 一律推 App 下载页(不给浏览器加入入口);
      // 用桌面 Chrome UA 才有"从浏览器加入"。效果不佳时右上角 Webex App 兜底。
      _controller.setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36');
    }
    _controller.loadRequest(Uri.parse(widget.url));

    // Android:网页的麦克风/摄像头申请直接放行(系统层权限已由入口预请求)
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setOnPlatformPermissionRequest((request) => request.grant());
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _applyZoom() {
    if (!widget.applyFontScale) return;
    final scale = ref.read(fontScaleProvider);
    _controller.runJavaScript(
        "document.body.style.zoom='${scale.toStringAsFixed(2)}'");
  }

  /// Webex 访客名预填:SPA 渲染较晚,页面完成后多次尝试注入。
  /// 页面结构变化时静默失效(用户手动填,WebView 会记住)。
  void _schedulePrefill() {
    final name = widget.prefillName;
    if (!_isWebex || name == null || name.isEmpty) return;
    final safe = name.replaceAll('\\', r'\\').replaceAll("'", r"\'");
    final js = """
(function() {
  var inp = document.querySelector('input#guest_name')
    || document.querySelector('input[name="guestName"]')
    || document.querySelector('input[data-test="guest-name-input"]')
    || document.querySelector('input[type="text"]');
  if (inp && !inp.value) {
    var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
    setter.call(inp, '$safe');
    inp.dispatchEvent(new Event('input', {bubbles: true}));
    inp.dispatchEvent(new Event('change', {bubbles: true}));
  }
})();
""";
    for (final delay in const [Duration.zero, Duration(seconds: 2), Duration(seconds: 5)]) {
      _timers.add(Timer(delay, () {
        if (mounted) _controller.runJavaScript(js).ignore();
      }));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.title != null ? Text(widget.title!) : null,
        actions: [
          // 永远保留外部打开:Webex 链接会唤起 Webex App(用户定案)
          IconButton(
            tooltip: _isWebex ? 'Webex App' : 'Browser',
            icon: Icon(_isWebex ? Icons.exit_to_app : Icons.open_in_new),
            onPressed: () => launchUrl(Uri.parse(widget.url),
                mode: LaunchMode.externalApplication),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
