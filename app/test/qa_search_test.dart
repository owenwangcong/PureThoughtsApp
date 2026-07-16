import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pure_thoughts/core/prefs.dart';
import 'package:pure_thoughts/features/qa/qa_api.dart';
import 'package:pure_thoughts/features/qa/qa_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _item(int id) => {
      'id': id,
      'qa_title': '标题$id',
      'video_title': '视频',
      'summary': '摘要',
      'timestamp_url': 'https://www.youtube.com/watch?v=o3dBw8Su_oA&t=1s',
      'start_time': '00:00:01',
      'duration_seconds': 60,
      'published_date': '2026-01-11',
      'tags': <String>[],
    };

/// 分页:第 1 页 20 条 has_next,第 2 页 5 条到底;共 25 条。
String _pageBody(int page) {
  final first = page == 1;
  final count = first ? 20 : 5;
  final startId = first ? 1 : 21;
  return jsonEncode({
    'total': 25,
    'page': page,
    'per_page': 20,
    'total_pages': 2,
    'has_next': first,
    'has_prev': !first,
    'results': [for (var i = 0; i < count; i++) _item(startId + i)],
  });
}

http.Client _paging({bool failPage2 = false}) => MockClient((req) async {
      final page = int.parse(req.url.queryParameters['page']!);
      if (failPage2 && page == 2) {
        return http.Response.bytes(utf8.encode('{}'), 500);
      }
      return http.Response.bytes(utf8.encode(_pageBody(page)), 200);
    });

Future<ProviderContainer> _makeContainer(http.Client client) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    qaApiProvider.overrideWithValue(QaApi(client: client)),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// 等到不在 loading / loadingMore(有上限,避免卡死)。
Future<void> _settle(ProviderContainer c) async {
  for (var i = 0; i < 100; i++) {
    final s = c.read(qaSearchProvider);
    if (!s.loading && !s.loadingMore) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('未在预期时间内结束加载');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('初始加载:无 query 即全部,首页 20 条 has_next', () async {
    final c = await _makeContainer(_paging());
    c.read(qaSearchProvider.notifier);
    await _settle(c);
    final s = c.read(qaSearchProvider);
    expect(s.items.length, 20);
    expect(s.total, 25);
    expect(s.hasNext, isTrue);
    expect(s.error, isFalse);
  });

  test('loadMore 追加下一页,到底后 has_next=false 不再请求', () async {
    final c = await _makeContainer(_paging());
    final ctrl = c.read(qaSearchProvider.notifier);
    await _settle(c);

    await ctrl.loadMore();
    var s = c.read(qaSearchProvider);
    expect(s.items.length, 25);
    expect(s.page, 2);
    expect(s.hasNext, isFalse);

    // 已到底:再调用直接返回,条数不变
    await ctrl.loadMore();
    s = c.read(qaSearchProvider);
    expect(s.items.length, 25);
  });

  test('追加失败:页码回退、条数不变、不卡 loadingMore', () async {
    final c = await _makeContainer(_paging(failPage2: true));
    final ctrl = c.read(qaSearchProvider.notifier);
    await _settle(c);

    await ctrl.loadMore(); // 第 2 页 500
    final s = c.read(qaSearchProvider);
    expect(s.items.length, 20); // 未追加
    expect(s.page, 1); // 未前进
    expect(s.hasNext, isTrue); // 仍可重试
    expect(s.loadingMore, isFalse);
  });

  test('短词保护:非强制且不足 2 字 → 不请求、tooShort', () async {
    final c = await _makeContainer(_paging());
    final ctrl = c.read(qaSearchProvider.notifier);
    await _settle(c);

    ctrl.submitQuery('禅'); // 1 字,非 force
    await Future<void>.delayed(Duration.zero);
    final s = c.read(qaSearchProvider);
    expect(s.tooShort, isTrue);
    expect(s.items, isEmpty);
  });

  test('回车强制搜索绕过短词保护,仍发请求', () async {
    final c = await _makeContainer(_paging());
    final ctrl = c.read(qaSearchProvider.notifier);
    await _settle(c);

    ctrl.submitQuery('禅', force: true);
    await _settle(c);
    final s = c.read(qaSearchProvider);
    expect(s.tooShort, isFalse);
    expect(s.items.length, 20); // mock 忽略 query,返回第 1 页
  });
}
