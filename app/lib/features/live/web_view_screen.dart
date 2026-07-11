import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../core/channels.dart';
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
    this.prefillEmail,
    this.externalUrl,
  });

  final String url;
  final String? title;
  final bool applyFontScale;
  final String? prefillName;
  final String? prefillEmail;

  /// 右上角"外部打開"用的链接(默认同 [url];Webex 用 join 链接以唤起 App)
  final String? externalUrl;

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
          _scheduleWebexAutomation();
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

  String _jsEsc(String s) =>
      s.replaceAll('\\', r'\\').replaceAll("'", r"\'");

  /// Webex 网页客户端全自动加入(2026-07-11 在真实会议上全链路验证):
  /// web.webex.com/join-meeting 是顶层页面(无跨域 iframe),流程为
  /// ① 填会议链接 → 点 Next(Webex 用 momentum 组件,按钮在关闭 shadow root
  ///    里,querySelector 不可达 → 深度遍历开放 shadow root 找宿主元素,
  ///    派发 pointer+click 合成事件,实测有效);
  /// ② 访客表单(第 1/2 个 text 输入 = 名字/邮箱,都是 type=text)填后点
  ///    "Join meeting";名字邮箱齐全才自动加入,缺则留给用户手填。
  /// 页面结构变化时静默失效(用户手动操作,Remember me 会记住)。
  void _scheduleWebexAutomation() {
    if (!_isWebex) return;
    final name = _jsEsc(widget.prefillName ?? '');
    final mail = _jsEsc(widget.prefillEmail ?? '');
    const link = Channels.webexJoinUrl;
    final js = """
(function() {
  function deepAll(root, sel, out) {
    root.querySelectorAll(sel).forEach(function(e) { out.push(e); });
    root.querySelectorAll('*').forEach(function(el) {
      if (el.shadowRoot) deepAll(el.shadowRoot, sel, out);
    });
    return out;
  }
  function fire(el) {
    ['pointerdown', 'pointerup', 'click'].forEach(function(t) {
      el.dispatchEvent(new MouseEvent(t, {bubbles: true, composed: true, cancelable: true}));
    });
  }
  function clickByText(texts) {
    deepAll(document, '*', []).forEach(function(e) {
      var t = (e.textContent || '').trim();
      if (texts.indexOf(t) !== -1 && e.children.length <= 2) fire(e);
    });
  }
  function setVal(inp, v) {
    if (!inp || !v || inp.value) return;
    var s = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
    s.call(inp, v);
    inp.dispatchEvent(new Event('input', {bubbles: true, composed: true}));
    inp.dispatchEvent(new Event('change', {bubbles: true, composed: true}));
  }
  // 兜底:若落在旧下载页(*.my.webex.com),自动点"从浏览器加入"
  document.querySelectorAll('button').forEach(function(b) {
    var t = (b.textContent || '').trim().toLowerCase();
    if (t.indexOf('browser') !== -1 || t.indexOf('瀏覽器') !== -1 || t.indexOf('浏览器') !== -1) b.click();
  });
  if (location.host !== 'web.webex.com') return;
  var texts = deepAll(document, 'input', []).filter(function(i) { return i.type === 'text'; });
  if (location.pathname.indexOf('join-meeting') !== -1) {
    if (texts[0] && !texts[0].value) {
      setVal(texts[0], '$link');
      setTimeout(function() { clickByText(['Next', '下一步']); }, 600);
    }
  } else {
    setVal(texts[0], '$name');
    setVal(texts[1], '$mail');
    setTimeout(function() {
      clickByText(['Use microphone and camera', '使用麥克風和攝影機', '使用麦克风和摄像头']);
      if ('$name' && '$mail' && texts[0] && texts[0].value && texts[1] && texts[1].value) {
        clickByText(['Join meeting', '加入會議', '加入会议']);
      }
    }, 800);
  }
})();
""";
    for (final delay in const [
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 7),
      Duration(seconds: 11),
      Duration(seconds: 15),
    ]) {
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
            onPressed: () => launchUrl(
                Uri.parse(widget.externalUrl ?? widget.url),
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
