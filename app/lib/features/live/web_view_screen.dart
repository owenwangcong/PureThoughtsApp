import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/settings.dart';

/// 应用内浏览器(PRD §6/§7):YouTube 频道页、Webex 加入、经本等
/// 尽量不离开 App;右上角保留外部打开兜底(Webex 深度功能可能需要)。
/// [applyFontScale] = true 时把 App 字号设置透传为网页缩放(经本阅读)。
class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({
    super.key,
    required this.url,
    this.title,
    this.applyFontScale = false,
  });

  final String url;
  final String? title;
  final bool applyFontScale;

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen> {
  late final WebViewController _controller;
  var _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageFinished: (_) {
          if (!widget.applyFontScale) return;
          final scale = ref.read(fontScaleProvider);
          // 字号透传:整页缩放,适老阅读(PRD §7)
          _controller.runJavaScript(
              "document.body.style.zoom='${scale.toStringAsFixed(2)}'");
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.title != null ? Text(widget.title!) : null,
        actions: [
          IconButton(
            tooltip: 'Browser',
            icon: const Icon(Icons.open_in_new),
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
