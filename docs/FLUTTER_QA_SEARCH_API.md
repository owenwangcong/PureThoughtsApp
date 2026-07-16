# 问答视频搜索 API — Flutter 对接文档

给 Flutter app 用的后端接口说明。后端是 FastAPI，数据是已经切好片、带时间戳和 AI 摘要的**问答片段**（不是整条视频）。

- **Base URL**：`https://www.pure-thoughts.com/api`
- **认证**：无。所有接口公开只读，不需要 API Key、不需要 Header。
- **方法**：全部 `GET`
- **编码**：UTF-8，返回中文原文（不转义）
- **CORS**：`Access-Control-Allow-Origin: *`，Flutter Web 可直接调用，无需代理

> 一条记录 = 一个问答片段。`timestamp_url` 是带 `?t=` 秒数的 YouTube 链接，点开直接跳到该问题的回答位置。

---

## 一、接口列表

### 1. `GET /search` — 搜索问答片段

主接口。所有参数都可选；不传任何参数 = 按日期倒序列出全部。

**请求参数**

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `query` | string | 无 | 搜索关键词。见下方「关键词匹配规则」 |
| `date_start` | date | 无 | 起始日期，格式必须是 `YYYY-MM-DD` |
| `date_end` | date | 无 | 结束日期，格式必须是 `YYYY-MM-DD` |
| `tags` | string | 无 | 标签过滤，**英文逗号分隔**，如 `唯识,禅七` |
| `sort` | string | `desc` | `desc` = 最新在前，`asc` = 最早在前 |
| `page` | int | `1` | 页码，从 1 开始，必须 ≥ 1 |
| `per_page` | int | `20` | 每页条数，**范围 1–100** |

**示例**

```
GET /api/search?query=禅修&per_page=2&page=1
GET /api/search?query=业力&date_start=2025-01-01&date_end=2026-01-01&sort=asc
GET /api/search?tags=唯识,三性&per_page=50
```

**响应**（HTTP 200，真实返回样例）

```json
{
  "total": 6,
  "page": 1,
  "per_page": 2,
  "total_pages": 3,
  "has_next": true,
  "has_prev": false,
  "results": [
    {
      "id": 1,
      "qa_title": "转境、转性与转度的区别",
      "video_title": "2026年1月10日  讲法直播问答",
      "summary": "问题：修行中提到\"转境、转性、转度\"...\n回答：\n1. 转境：心不随境转...",
      "timestamp_url": "https://www.youtube.com/watch?v=o3dBw8Su_oA&t=239s",
      "start_time": "00:03:59",
      "duration_seconds": 696,
      "published_date": "2026-01-11",
      "tags": ["唯识", "三性", "转依", "修行次第"]
    }
  ]
}
```

**字段含义与可空性**（这部分很重要，直接决定 Dart 模型怎么写）

| 字段 | 类型 | 可空 | 说明 |
|------|------|------|------|
| `total` | int | 否 | 匹配到的总条数（不是本页条数） |
| `page` | int | 否 | 当前页码，回显请求值 |
| `per_page` | int | 否 | 每页条数，回显请求值 |
| `total_pages` | int | 否 | 总页数。**无结果时为 `0`**，不是 1 |
| `has_next` / `has_prev` | bool | 否 | 是否有下/上一页，可直接驱动翻页按钮 |
| `results` | array | 否 | 结果数组，无结果时为 `[]` |
| `results[].id` | int | 否 | 片段唯一 ID |
| `results[].qa_title` | string | 否 | 问答标题，列表主标题用这个 |
| `results[].video_title` | string | 否 | 所属整场视频的标题，如「2026年1月10日 讲法直播问答」 |
| `results[].summary` | string | 否 | AI 摘要。**可能是空字符串 `""`，但不会是 null**。内含 `\n` 换行 |
| `results[].timestamp_url` | string | 否 | 带时间戳的 YouTube 链接，播放/跳转用这个 |
| `results[].start_time` | string | **是** | 形如 `"00:03:59"` 的字符串，不是数字 |
| `results[].duration_seconds` | int | **是** | 片段时长（秒） |
| `results[].published_date` | string | **是** | `"YYYY-MM-DD"` 字符串，不是完整 datetime |
| `results[].tags` | string[] | 否 | 标签数组，无标签时为 `[]`，不会是 null |

### 2. `GET /tags` — 获取全部标签

给筛选器做标签列表用。无参数。

```json
{ "tags": ["三性", "业力", "修行次第", "唯识", "禅七"] }
```

已按字典序排序、已去重。

### 3. `GET /health` — 健康检查

```json
{ "status": "healthy" }
```

---

## 二、关键词匹配规则（务必先读）

后端用的是数据库 `LIKE %关键词%` 子串匹配，**不是全文检索、不是分词、不是语义搜索**。具体行为：

1. **按空格拆词，词与词之间是 AND**
   `query=禅修 业力` → 必须同时包含「禅修」和「业力」的片段才返回。词越多结果越少。

2. **每个词在三个字段里是 OR**
   一个词只要命中 `qa_title`、`summary`、`video_title` 任意一个即可。

3. **中文不需要空格**
   `query=转境` 会匹配到 summary 里任何位置出现「转境」的记录。中文直接传整串即可，**不要自己分词**——自己拆成空格反而会变成 AND 收紧结果。

4. **子串匹配、区分不了词边界**
   搜「性」会命中「转性」「圆成实性」「性格」等一切含该字的内容。短关键词噪音大，UI 上建议提示用户输入 2 字以上。

5. **`tags` 多个标签之间是 OR**
   `tags=唯识,禅七` → 含「唯识」**或**「禅七」的都返回（注意和 `query` 的 AND 相反）。

6. **`sort` 不校验**
   只有传 `asc` 才是升序，传 `desc`、`DESC`、拼错的、乱填的，**一律当降序处理**，不报错。

---

## 三、错误处理

| 状态码 | 场景 | 说明 |
|--------|------|------|
| `200` | 成功 | 无匹配也是 200，`results: []`、`total: 0`、`total_pages: 0` |
| `422` | 参数不合法 | `per_page > 100` 或 `< 1`、`page < 1`、日期格式不是 `YYYY-MM-DD` |
| `500` | 服务端错误 | 数据库异常等 |

**422 是 FastAPI 标准校验错误**，结构如下：

```json
{
  "detail": [
    {
      "loc": ["query", "per_page"],
      "msg": "Input should be less than or equal to 100",
      "type": "less_than_equal"
    }
  ]
}
```

注意：`detail` 是**数组**不是字符串，不要直接往 UI 上甩。这类错误基本都是客户端传参 bug，正确做法是在 Dart 侧就把 `per_page` clamp 到 1–100、`page` clamp 到 ≥1，从根上避免。

---

## 四、Flutter 接入代码

依赖（`pubspec.yaml`）：

```yaml
dependencies:
  http: ^1.2.0
```

### 4.1 数据模型

```dart
class VideoSegment {
  final int id;
  final String qaTitle;
  final String videoTitle;
  final String summary;
  final String timestampUrl;
  final String? startTime;        // "00:03:59"，可空
  final int? durationSeconds;     // 可空
  final DateTime? publishedDate;  // 可空
  final List<String> tags;

  VideoSegment({
    required this.id,
    required this.qaTitle,
    required this.videoTitle,
    required this.summary,
    required this.timestampUrl,
    this.startTime,
    this.durationSeconds,
    this.publishedDate,
    this.tags = const [],
  });

  factory VideoSegment.fromJson(Map<String, dynamic> json) {
    final rawDate = json['published_date'] as String?;
    return VideoSegment(
      id: json['id'] as int,
      qaTitle: json['qa_title'] as String,
      videoTitle: json['video_title'] as String,
      summary: json['summary'] as String? ?? '',
      timestampUrl: json['timestamp_url'] as String,
      startTime: json['start_time'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      // 后端给的是 "2026-01-11"，DateTime.parse 能直接吃
      publishedDate: rawDate == null ? null : DateTime.tryParse(rawDate),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

class SearchResponse {
  final int total;
  final int page;
  final int perPage;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;
  final List<VideoSegment> results;

  SearchResponse({
    required this.total,
    required this.page,
    required this.perPage,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
    required this.results,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) => SearchResponse(
        total: json['total'] as int,
        page: json['page'] as int,
        perPage: json['per_page'] as int,
        totalPages: json['total_pages'] as int,
        hasNext: json['has_next'] as bool,
        hasPrev: json['has_prev'] as bool,
        results: (json['results'] as List<dynamic>)
            .map((e) => VideoSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
```

### 4.2 API Service

```dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class VideoApi {
  static const String _host = 'www.pure-thoughts.com';
  static const String _basePath = '/api';

  final http.Client _client;
  VideoApi({http.Client? client}) : _client = client ?? http.Client();

  Future<SearchResponse> search({
    String? query,
    DateTime? dateStart,
    DateTime? dateEnd,
    List<String>? tags,
    String sort = 'desc',
    int page = 1,
    int perPage = 20,
  }) async {
    // 在客户端就夹紧范围，避免后端返回 422
    final safePage = page < 1 ? 1 : page;
    final safePerPage = perPage.clamp(1, 100);

    final params = <String, String>{
      'page': '$safePage',
      'per_page': '$safePerPage',
      'sort': sort,
    };

    final q = query?.trim();
    if (q != null && q.isNotEmpty) params['query'] = q;
    if (dateStart != null) params['date_start'] = _fmtDate(dateStart);
    if (dateEnd != null) params['date_end'] = _fmtDate(dateEnd);
    if (tags != null && tags.isNotEmpty) params['tags'] = tags.join(',');

    final uri = Uri.https(_host, '$_basePath/search', params);
    return _getJson(uri, (json) => SearchResponse.fromJson(json));
  }

  Future<List<String>> getTags() async {
    final uri = Uri.https(_host, '$_basePath/tags');
    return _getJson(
      uri,
      (json) => (json['tags'] as List<dynamic>).cast<String>(),
    );
  }

  Future<bool> healthCheck() async {
    try {
      final uri = Uri.https(_host, '$_basePath/health');
      final json = await _getJson(uri, (j) => j);
      return json['status'] == 'healthy';
    } catch (_) {
      return false;
    }
  }

  Future<T> _getJson<T>(Uri uri, T Function(Map<String, dynamic>) parse) async {
    http.Response res;
    try {
      res = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
    } on SocketException {
      throw ApiException('网络连接失败，请检查网络后重试');
    } catch (e) {
      throw ApiException('请求失败：$e');
    }

    // 后端返回 UTF-8 中文，必须用 utf8.decode(bodyBytes)，
    // 直接用 res.body 在部分情况下会因缺少 charset 而变乱码
    final decoded = utf8.decode(res.bodyBytes);

    if (res.statusCode == 200) {
      return parse(jsonDecode(decoded) as Map<String, dynamic>);
    }
    if (res.statusCode == 422) {
      throw ApiException('搜索条件不合法', 422);
    }
    throw ApiException('服务器错误（${res.statusCode}）', res.statusCode);
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void dispose() => _client.close();
}
```

### 4.3 搜索 + 分页加载

```dart
class SearchController extends ChangeNotifier {
  final VideoApi _api;
  SearchController(this._api);

  final List<VideoSegment> items = [];
  String _query = '';
  int _page = 1;
  bool _hasNext = false;
  bool isLoading = false;
  String? error;
  int total = 0;

  Timer? _debounce;

  /// 输入框 onChanged 调用它。后端是 LIKE 查询，每次按键都打会很浪费，
  /// 400ms 防抖。
  void onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      newSearch(text);
    });
  }

  Future<void> newSearch(String query) async {
    _query = query;
    _page = 1;
    items.clear();
    error = null;
    notifyListeners();
    await _fetch();
  }

  /// 列表滚到底时调用
  Future<void> loadMore() async {
    if (isLoading || !_hasNext) return;
    _page++;
    await _fetch();
  }

  Future<void> _fetch() async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await _api.search(query: _query, page: _page, perPage: 20);
      items.addAll(res.results);
      total = res.total;
      _hasNext = res.hasNext;   // 直接用后端给的，别自己算
      error = null;
    } on ApiException catch (e) {
      error = e.message;
      if (_page > 1) _page--;   // 失败回退页码，否则会跳页
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
```

### 4.4 UI 注意事项

- **摘要换行**：`summary` 里有 `\n`，用 `Text(item.summary)` 默认就能渲染换行；列表页想截断用 `maxLines: 3, overflow: TextOverflow.ellipsis`。
- **播放跳转**：`timestamp_url` 已带 `&t=239s`，用 `url_launcher` 的 `launchUrl(Uri.parse(item.timestampUrl), mode: LaunchMode.externalApplication)` 直接跳 YouTube app / 浏览器，会自动定位到该问题。想内嵌播放可用 `youtube_player_iframe`，从 URL 里解析 `v` 和 `t` 参数。
- **空结果**：`total == 0` 时给「未找到相关内容，试试其他关键词」，不要显示报错样式——这是正常结果。
- **空态与首屏**：不传 `query` 就是全部内容按日期倒序，适合做首页默认列表。
- **标签筛选**：先调 `/tags` 拿全量标签做 chips，选中后把 `tags` 传给 `/search`（多选是 OR）。

---

## 五、快速验证

接口是活的，可以直接在浏览器 / curl 里打开确认：

```bash
curl "https://www.pure-thoughts.com/api/health"
curl "https://www.pure-thoughts.com/api/search?query=禅修&per_page=2"
curl "https://www.pure-thoughts.com/api/tags"
```

FastAPI 自带的交互式文档（如果线上没关）：`https://www.pure-thoughts.com/api/docs`

---

## 六、已知限制

- **无认证、无限流**：接口完全公开，任何人都能调。app 里不要假设它有防刷保护。
- **搜索是 LIKE 不是全文索引**：数据量涨上去后 `query` 搜索会变慢；目前数据量小，无感。
- **标签匹配是 JSON 字符串子串检查**：`tags=性` 这种短标签理论上可能误命中含该字的其他标签，用 `/tags` 返回的完整标签值就不会有问题。
- **没有「按 id 取单条」的接口**：详情页要么把列表项对象整个传过去，要么用 `query` 搜 `qa_title`。如果 app 需要分享/深链到单条，得在后端加 `GET /segments/{id}`。
- **`sort` 参数不校验**：传错不报错，静默当 `desc`。

---

*本文档依据 `backend/main.py`（FastAPI 源码）与线上接口实际返回编写。注意：`backend/README.md` 里 `/search` 写的是 `limit` 参数，那是过时的，实际是 `page` / `per_page`，以本文档为准。*
