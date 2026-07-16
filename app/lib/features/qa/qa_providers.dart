import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import 'qa_api.dart';
import 'qa_models.dart';

/// API 客户端(可在测试中 override 为注入 MockClient 的实例)。
final qaApiProvider = Provider<QaApi>((ref) {
  final api = QaApi();
  ref.onDispose(api.dispose);
  return api;
});

/// 全量标签(会话内缓存),按当前语言字形拉取。
final qaTagsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(qaApiProvider).tags(script: _scriptOf(ref));
});

String _scriptOf(Ref ref) =>
    ref.read(localeProvider).scriptCode == 'Hans' ? 'hans' : 'hant';

/// 搜索页状态(design/qa-search.md §6.2)。
class QaSearchState {
  const QaSearchState({
    this.items = const [],
    this.query = '',
    this.tags = const [],
    this.page = 1,
    this.total = 0,
    this.hasNext = false,
    this.loading = false,
    this.loadingMore = false,
    this.error = false,
    this.tooShort = false,
    this.searched = false,
  });

  final List<QaSegment> items;
  final String query;
  final List<String> tags;
  final int page;
  final int total;
  final bool hasNext; // 直接用后端 has_next,不自己算
  final bool loading; // 首屏 / 新搜索
  final bool loadingMore; // 触底追加
  final bool error;
  final bool tooShort; // query 非空但不足 2 字:不请求,提示
  final bool searched; // 是否已至少发起过一次请求(区分「初始」与「空结果」)

  QaSearchState copyWith({
    List<QaSegment>? items,
    String? query,
    List<String>? tags,
    int? page,
    int? total,
    bool? hasNext,
    bool? loading,
    bool? loadingMore,
    bool? error,
    bool? tooShort,
    bool? searched,
  }) =>
      QaSearchState(
        items: items ?? this.items,
        query: query ?? this.query,
        tags: tags ?? this.tags,
        page: page ?? this.page,
        total: total ?? this.total,
        hasNext: hasNext ?? this.hasNext,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error ?? this.error,
        tooShort: tooShort ?? this.tooShort,
        searched: searched ?? this.searched,
      );
}

/// 搜索控制器:无限滚动 + 400ms 防抖 + 短词保护 + 语言切换重搜。
class QaSearchController extends Notifier<QaSearchState> {
  Timer? _debounce;

  @override
  QaSearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    // 语言切换 → 用新字形重跑当前条件(保留 query/tags)
    ref.listen(localeProvider, (_, _) => _fetchFresh());
    // 首次拉取延到 build 返回之后:build 期间不能改 state
    Future.microtask(() => _fetchFresh());
    return const QaSearchState(loading: true);
  }

  String get _script => _scriptOf(ref);

  /// 输入框 onChanged:400ms 防抖(上游是 LIKE,每键一发很浪费)。
  void onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => submitQuery(text));
  }

  /// 提交搜索;[force] = true(用户回车)时绕过短词保护。
  void submitQuery(String text, {bool force = false}) {
    _debounce?.cancel();
    state = state.copyWith(query: text.trim());
    _fetchFresh(force: force);
  }

  void clearQuery() {
    _debounce?.cancel();
    state = state.copyWith(query: '');
    _fetchFresh();
  }

  void setTags(List<String> tags) {
    state = state.copyWith(tags: tags);
    _fetchFresh();
  }

  Future<void> refresh() => _fetchFresh();

  /// 触底追加下一页;失败不前进页码,否则会跳页丢内容。
  Future<void> loadMore() async {
    final s = state;
    if (s.loading || s.loadingMore || !s.hasNext) return;
    state = s.copyWith(loadingMore: true);
    try {
      final res = await ref.read(qaApiProvider).search(
            query: s.query,
            tags: s.tags,
            script: _script,
            page: s.page + 1,
          );
      state = state.copyWith(
        items: [...state.items, ...res.results],
        page: s.page + 1,
        hasNext: res.hasNext,
        total: res.total,
        loadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false); // 页码不前进
    }
  }

  Future<void> _fetchFresh({bool force = false}) async {
    final q = state.query;
    // 短词保护:子串匹配下单字噪音极大;非强制且不足 2 字 → 不请求
    if (!force && q.isNotEmpty && q.length < 2) {
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        tooShort: true,
        error: false,
        items: const [],
        total: 0,
        hasNext: false,
        searched: true,
      );
      return;
    }
    state = state.copyWith(loading: true, error: false, tooShort: false);
    try {
      final res = await ref.read(qaApiProvider).search(
            query: q,
            tags: state.tags,
            script: _script,
            page: 1,
          );
      state = state.copyWith(
        items: res.results,
        total: res.total,
        page: 1,
        hasNext: res.hasNext,
        loading: false,
        error: false,
        searched: true,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: true, searched: true);
    }
  }
}

final qaSearchProvider =
    NotifierProvider<QaSearchController, QaSearchState>(QaSearchController.new);
