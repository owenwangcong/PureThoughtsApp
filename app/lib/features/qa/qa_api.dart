import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/channels.dart';
import 'qa_models.dart';

/// 往期问答 API 客户端(PRD §6 / design/qa-search.md §3、§6)。
///
/// 客户端**直连**上游 FastAPI(不走 Edge Function 代理):接口完全公开、无认证、
/// CORS 全开,代理无可隐藏、无鉴权可统一。基址常量在 core/channels.dart,
/// 日后若需保护再引代理只改一处。
///
/// message 仅作诊断/上报,**不直接展示**;UI 一律用 async_states 的 ErrorRetry。
class QaApiException implements Exception {
  QaApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => 'QaApiException($statusCode): $message';
}

class QaApi {
  QaApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final Uri _base = Uri.parse(Channels.qaApiBase);

  /// 搜索问答片段。所有参数可选;不传 query/tags = 按日期倒序列出全部。
  /// [script] = 'hans' | 'hant',按 App 当前语言取字形(上游未支持时会静默忽略,
  /// 返回默认字形——客户端可先行,不会因此 422)。
  Future<QaSearchResponse> search({
    String? query,
    List<String>? tags,
    String script = 'hans',
    String sort = 'desc',
    int page = 1,
    int perPage = 20,
  }) async {
    // 在客户端就夹紧,从根上不产生 422(上游对越界会 422)
    final params = <String, String>{
      'page': '${page < 1 ? 1 : page}',
      'per_page': '${perPage.clamp(1, 100)}',
      'sort': sort,
      'script': script,
    };
    final q = query?.trim();
    if (q != null && q.isNotEmpty) params['query'] = q;
    if (tags != null && tags.isNotEmpty) params['tags'] = tags.join(',');

    return _getJson(
      _base.replace(path: '${_base.path}/search', queryParameters: params),
      QaSearchResponse.fromJson,
    );
  }

  /// 全部标签(已归一化去重、按 script 输出字形)。给标签选择器做本地过滤。
  Future<List<String>> tags({String script = 'hans'}) {
    return _getJson(
      _base.replace(path: '${_base.path}/tags', queryParameters: {'script': script}),
      (json) => (json['tags'] as List<dynamic>).cast<String>(),
    );
  }

  Future<T> _getJson<T>(Uri uri, T Function(Map<String, dynamic>) parse) async {
    http.Response res;
    try {
      res = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw QaApiException('network timeout');
    } on SocketException {
      throw QaApiException('network unreachable');
    } on http.ClientException catch (e) {
      throw QaApiException('client error: ${e.message}');
    }

    // 上游返回 UTF-8 中文;必须 utf8.decode(bodyBytes),res.body 在缺 charset 时会乱码
    final decoded = utf8.decode(res.bodyBytes);
    if (res.statusCode == 200) {
      return parse(jsonDecode(decoded) as Map<String, dynamic>);
    }
    // 422 的 detail 是数组不是字符串,绝不外泄;clamp 后本不该出现,出现即客户端 bug
    if (res.statusCode == 422) throw QaApiException('invalid params', 422);
    throw QaApiException('server error', res.statusCode);
  }

  void dispose() => _client.close();
}
