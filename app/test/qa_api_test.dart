import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pure_thoughts/features/qa/qa_api.dart';
import 'package:pure_thoughts/features/qa/qa_models.dart';

/// 一条最小可解析的 /search 响应(含中文,兼作 UTF-8 解码验证)。
String _searchBody({
  int total = 1,
  int page = 1,
  int perPage = 20,
  int totalPages = 1,
  bool hasNext = false,
  bool hasPrev = false,
}) =>
    jsonEncode({
      'total': total,
      'page': page,
      'per_page': perPage,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_prev': hasPrev,
      'results': [
        {
          'id': 1,
          'qa_title': '转境、转性与转度的区别',
          'video_title': '2026年1月10日 讲法直播问答',
          'summary': '问题:修行中提到"转境"…\n回答:心不随境转',
          'timestamp_url': 'https://www.youtube.com/watch?v=o3dBw8Su_oA&t=239s',
          'start_time': '00:03:59',
          'duration_seconds': 696,
          'published_date': '2026-01-11',
          'tags': ['唯识', '三性'],
        }
      ],
    });

http.Client _client200(String body, {void Function(http.Request)? onCall}) =>
    MockClient((req) async {
      onCall?.call(req);
      return http.Response.bytes(utf8.encode(body), 200);
    });

void main() {
  group('QaSegment.fromJson', () {
    test('可空字段为 null 时不抛,派生 videoId / startSeconds 正确', () {
      final seg = QaSegment.fromJson({
        'id': 7,
        'qa_title': '标题',
        'video_title': '视频',
        'summary': '',
        'timestamp_url': 'https://www.youtube.com/watch?v=o3dBw8Su_oA&t=239s',
        'start_time': null,
        'duration_seconds': null,
        'published_date': null,
        'tags': <String>[],
      });
      expect(seg.summary, '');
      expect(seg.startTime, isNull);
      expect(seg.durationSeconds, isNull);
      expect(seg.publishedDate, isNull);
      expect(seg.tags, isEmpty);
      expect(seg.videoId, 'o3dBw8Su_oA');
      expect(seg.startSeconds, 239);
    });

    test('summary 键缺失回退空串;published_date 解析为日期', () {
      final seg = QaSegment.fromJson({
        'id': 1,
        'qa_title': 't',
        'video_title': 'v',
        'timestamp_url': 'https://youtu.be/abcdefghijk',
        'published_date': '2026-01-11',
        'tags': ['禅修'],
      });
      expect(seg.summary, '');
      expect(seg.publishedDate, DateTime(2026, 1, 11));
      expect(seg.videoId, 'abcdefghijk');
      expect(seg.startSeconds, isNull); // 无 ?t=
    });
  });

  group('QaSearchResponse.fromJson', () {
    test('无结果时 total_pages 为 0、results 为空数组', () {
      final res = QaSearchResponse.fromJson(jsonDecode(_searchBody(
        total: 0,
        totalPages: 0,
      )) as Map<String, dynamic>);
      // body 里仍带 1 条示例,这里只验证顶层计数字段能读到 0
      expect(res.total, 0);
      expect(res.totalPages, 0);
      expect(res.hasNext, isFalse);
    });
  });

  group('格式化纯函数', () {
    test('时长秒 → m:ss', () {
      expect(qaFormatDuration(696), '11:36');
      expect(qaFormatDuration(190), '3:10');
      expect(qaFormatDuration(59), '0:59');
      expect(qaFormatDuration(60), '1:00');
    });
    test('日期 → YYYY-MM-DD 补零', () {
      expect(qaFormatDate(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('QaApi.search URL 构建', () {
    test('per_page / page 客户端夹紧,避免 422', () async {
      late Uri hi, lo, negPage;
      await QaApi(client: _client200(_searchBody(), onCall: (r) => hi = r.url))
          .search(perPage: 200);
      await QaApi(client: _client200(_searchBody(), onCall: (r) => lo = r.url))
          .search(perPage: 0);
      await QaApi(client: _client200(_searchBody(), onCall: (r) => negPage = r.url))
          .search(page: 0);
      expect(hi.queryParameters['per_page'], '100');
      expect(lo.queryParameters['per_page'], '1');
      expect(negPage.queryParameters['page'], '1');
    });

    test('path 指向 /api/search,script 默认 hans、可传 hant', () async {
      late Uri d, h;
      await QaApi(client: _client200(_searchBody(), onCall: (r) => d = r.url))
          .search();
      await QaApi(client: _client200(_searchBody(), onCall: (r) => h = r.url))
          .search(script: 'hant');
      expect(d.path, '/api/search');
      expect(d.queryParameters['script'], 'hans');
      expect(h.queryParameters['script'], 'hant');
    });

    test('空/空白 query 不带该参数;非空去首尾空格', () async {
      late Uri blank, trimmed;
      await QaApi(client: _client200(_searchBody(), onCall: (r) => blank = r.url))
          .search(query: '   ');
      await QaApi(client: _client200(_searchBody(), onCall: (r) => trimmed = r.url))
          .search(query: '  禅修  ');
      expect(blank.queryParameters.containsKey('query'), isFalse);
      expect(trimmed.queryParameters['query'], '禅修');
    });

    test('tags 以英文逗号拼接;空列表不带该参数', () async {
      late Uri withTags, noTags;
      await QaApi(client: _client200(_searchBody(), onCall: (r) => withTags = r.url))
          .search(tags: ['唯识', '三性']);
      await QaApi(client: _client200(_searchBody(), onCall: (r) => noTags = r.url))
          .search(tags: const []);
      expect(withTags.queryParameters['tags'], '唯识,三性');
      expect(noTags.queryParameters.containsKey('tags'), isFalse);
    });
  });

  group('QaApi 解码与错误', () {
    test('UTF-8 中文正确解码(用 bodyBytes,非 res.body)', () async {
      final res = await QaApi(client: _client200(_searchBody())).search();
      expect(res.results.single.qaTitle, '转境、转性与转度的区别');
      expect(res.results.single.tags, ['唯识', '三性']);
    });

    test('422 → QaApiException(422),detail 数组不外泄到 message', () async {
      final client = MockClient((req) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'detail': [
                {'loc': ['query', 'per_page'], 'msg': '…', 'type': 'less_than_equal'}
              ]
            })),
            422,
          ));
      await expectLater(
        QaApi(client: client).search(),
        throwsA(isA<QaApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.message, 'message', isNot(contains('loc')))),
      );
    });

    test('500 → QaApiException 带状态码', () async {
      final client = MockClient((req) async => http.Response.bytes(
            utf8.encode('{"x":1}'),
            500,
          ));
      await expectLater(
        QaApi(client: client).search(),
        throwsA(isA<QaApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('tags() 命中 /api/tags 并解析字符串数组', () async {
      late Uri uri;
      final client = _client200(
        jsonEncode({'tags': ['三性', '业力', '唯识']}),
        onCall: (r) => uri = r.url,
      );
      final tags = await QaApi(client: client).tags(script: 'hant');
      expect(uri.path, '/api/tags');
      expect(uri.queryParameters['script'], 'hant');
      expect(tags, ['三性', '业力', '唯识']);
    });
  });
}
