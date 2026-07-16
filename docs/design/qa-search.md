# 设计文档 · 往期问答检索

> 对应 PRD §6「讲法问答检索」的详细设计,执行任务见 PLAN P6.1。
> 作者:Claude(2026-07-15)· 决策依据:用户六点拍板(见 §1)· 上游接口现状为**实测**结果(见 §2),非文档转述。
> 状态:**客户端已实现**(2026-07-16,PLAN P6.1.2/P6.1.3;`features/qa/`,Flutter 85/85、analyze 0 issue)。
> 仅余后端 E14 简繁双字形改造(§4,不在本仓库,提示词已交付)——未完成前搜索对繁体默认用户仍不可用,但功能可运行、不报错。

## 1. 需求与已定决策

对接内容方已有的问答检索 API(`docs/FLUTTER_QA_SEARCH_API.md`),在 App 内提供**往期讲法问答的搜索与阅读**。
一条记录 = 一个**问答片段**(不是整场视频):有独立标题、AI 摘要正文、带时间戳的 YouTube 链接。

用户决策(2026-07-15 拍板):

1. **简繁归一化在后端做,且做到「双字形存储 + script 参数」**——入库时用 OpenCC 生成简/繁两份,
   API 加 `script` 参数,App 按当前语言取对应字形。搜索、显示、标签一次性全干净(§4)。
2. **客户端直连上游 API,不走 `qa-proxy` Edge Function**——接口本就完全公开、无认证、CORS 全开,
   代理的两个立项理由(隐藏上游地址、统一鉴权)均已不成立;直连少一跳、少一个故障点(§3)。
   → 需求性变更,PRD §6 / §12.4 同步修订。
3. **详情页以播放器为主**、摘要在下(§7.3)。受 YouTube 嵌入限制,「播放器」的现实形态是
   **封面 + 大播放按钮 → 全屏播放页**,不是内嵌 16:9 iframe(原因见 §7.3.1,已有真机结论)。
4. **标签做可搜索的选择器**(§7.2),不做全量 chips、不做人工精选清单。
5. **入口:首页九宫格加一格 + 直播页加入口**(§8)。
6. 匿名可用——与直播/經本/日曆同类,不需要登录(PRD v0.5.8)。

## 2. 上游接口现状(2026-07-15 实测)

`curl` 打线上接口的实际结果,与对接文档有出入的地方以本节为准:

| 项 | 实测值 | 影响 |
|---|---|---|
| 数据量 | **903 条**片段,`published_date` 最新到 2026-02-01 | 首屏不传 query 即 45 页内容,足够做默认列表 |
| 字形 | **简繁混杂**——不同场次来源不同,有的入库是简体,有的是繁体 | ⛔ 致命,见下 |
| `/tags` | **1000+ 个**,且「禅修/禪修」「金刚经/金剛經」「唯识/唯識」「烦恼/煩惱」成对重复 | 全量 chips 不可用;归一后预计约 600 |
| `video_title` | 大量是「"善護念"正在直播!」这类无信息量标题 | 列表主标题只用 `qa_title`;日期靠 `published_date` |
| 单条接口 | **无** `GET /segments/{id}` | 详情页只能传对象,不支持深链/分享(§7.3.2) |
| 限流 | 无 | 客户端自己防抖 + clamp,不要打爆自家服务器 |

**字形问题为什么致命**:后端是 `LIKE %词%` 子串匹配,**无简繁归一**。实测:

```
query=禅修(简) → total 6
query=禪修(繁) → total 1     ← 两批完全不同的记录,互不包含
```

App 默认繁体(PRD §14 已定案),即繁体用户搜「禪修」会漏掉全部 6 条简体记录。
这不是体验瑕疵,是**搜索功能对默认语言用户基本不可用**。故 §4 的后端改造是本功能的**硬前置**。

## 3. 架构:直连,不代理

```
Flutter App ──HTTPS──> www.pure-thoughts.com/api  (FastAPI, 新加坡)
                       与自托管 Supabase 同区、同域名根
```

**为什么放弃 PRD 原定的 `qa-proxy` Edge Function**:

| PRD 原立项理由 | 现状 | 结论 |
|---|---|---|
| 隐藏上游地址 | 接口完全公开、无认证、CORS `*`,任何人可直接调 | 无可隐藏 |
| 统一鉴权 | 上游无鉴权,App 侧问答页匿名可用 | 无鉴权可统一 |

保留代理的唯一实际价值是「未来可加缓存/限流」和「换上游不动客户端」。
代价是多一跳延迟、多一个部署件,且 **Supabase 挂了问答也跟着挂**——而问答与 Supabase 无任何数据关系。
当前 903 条、无并发压力,不值得。若日后上游需要保护,再引入代理,客户端只改 `Channels.qaApiBase` 一个常量。

**大陆可达性**:`pure-thoughts.com` 多年服务同一批用户(含大陆),与 P0.1 选新加坡机房是同一实践背书。
故**搜索与摘要阅读对大陆用户可用**;不可用的只有 YouTube 播放(§9)。

## 4. 后端改造规格(E14 · 硬前置)

后端 FastAPI 不在本仓库(`backend/main.py` 在内容方服务器上),此节是交付给后端的规格。

### 4.1 转换管线

```python
from opencc import OpenCC
_t2s   = OpenCC('t2s')     # 繁 → 简（简体输入幂等）
_s2twp = OpenCC('s2twp')   # 简 → 繁（台湾正体 + 常用词转换）

def normalize(raw: str) -> tuple[str, str]:
    hans = _t2s.convert(raw)      # 先归一到简体
    hant = _s2twp.convert(hans)   # 再从简体生成繁体
    return hans, hant
```

**必须「先 t2s 归一、再 s2twp 生成」**,不能对原文直接 s2twp:
原文本身可能简繁混排,直接转会残留混排;先归一到简体再转,两份输出才稳定一致。

### 4.2 表结构

对每条片段新增(原始列保留不动,便于回溯):

| 列 | 内容 |
|---|---|
| `qa_title_hans` / `qa_title_hant` | 标题双字形 |
| `summary_hans` / `summary_hant` | 摘要双字形 |
| `video_title_hans` / `video_title_hant` | 视频标题双字形 |
| `tags_hans` / `tags_hant` | 标签数组双字形(**`tags_hans` 内先去重**——归一后「禅修/禪修」会撞成同一个) |
| `search_norm` | = `qa_title_hans + '\n' + summary_hans + '\n' + video_title_hans` |

一次性回填脚本跑完存量 903 条;新片段入库时走同一管线。

### 4.3 查询改造

```python
terms = [ _t2s.convert(t) for t in query.split() ]   # 每个词先转简体
# 词间 AND，每个词 LIKE %term% on search_norm
```

原来「每个词在 `qa_title`/`summary`/`video_title` 三列 OR」→ 现在「单列 `search_norm` 匹配」,
**行为等价**(命中任一字段 = 命中拼接串)且更快。字段间用 `\n` 分隔,用户 query 不含换行,不会跨字段误命中。

`tags` 过滤参数同样先 `t2s` 转简体,再匹配 `tags_hans`。

### 4.4 API 契约变更

**新增 `script` 参数**(`/search` 与 `/tags` 均支持):

| 值 | 行为 |
|---|---|
| `hans` | 返回简体字形(**默认值**,现有调用方行为不变) |
| `hant` | 返回繁体字形 |

**响应字段名一律不变**(仍是 `qa_title` / `summary` / `video_title` / `tags`),只是按 `script` 选取对应列。
好处:Dart 模型与对接文档 §4.1 的代码完全不用改,API 契约稳定。

`/tags?script=hant` 返回**归一化去重后**的标签(以 `tags_hans` 去重、按 script 输出字形),预计 1000+ → 约 600。

**验收**:
- `/search?query=禅修` 与 `/search?query=禪修` 返回**同一批** 7 条(6 简 + 1 繁合并)。
- `/tags` 返回列表中不再存在「禅修」与「禪修」同时出现。
- `/search?script=hant` 返回的 `summary` 中无简体字。

### 4.5 风险与限制(诚实交代)

- **一简对多繁歧义**:OpenCC `s2twp` 有词库,能处理绝大部分,但佛学名相仍可能出错
  (如「藏」「著/着」「乾」)。**建议转换后人工抽检若干条**,并用 OpenCC 自定义词典维护 override 表。
  这是转换方案的固有代价,不是实现 bug。
- **`LIKE %词%` 用不上 B-tree 索引**:903 条无感;数据量上去后需换 FTS5(SQLite)/ GIN + pg_trgm(PG)。本期不做。
- **`GET /segments/{id}` 仍缺**:不加就没有分享/深链(§7.3.2)。本期不做,列为后续增强。

## 5. 客户端目录与依赖

```
app/lib/features/qa/
  qa_models.dart          # QaSegment / QaSearchResponse（纯数据 + fromJson）
  qa_api.dart             # QaApi（http 客户端）+ QaApiException
  qa_providers.dart       # qaApiProvider / qaTagsProvider / qaSearchProvider
  qa_search_screen.dart   # 列表页（主入口）
  qa_tag_picker_screen.dart
  qa_detail_screen.dart
```

- 依赖新增 `http: ^1.2.0`(supabase_flutter 已传递依赖,但直接使用就应显式声明)。
- API 基址常量放 `core/channels.dart`(与 YouTube/Webex 固定频道同一约定):
  `static const qaApiBase = 'https://www.pure-thoughts.com/api';`

⚠️ **对接文档 §4.3 的示例是 `ChangeNotifier` 风格,本项目用 Riverpod 3**,须改写为 Notifier(§6.2),
不要照抄。文档 §4.1/§4.2 的模型与 API service 可基本沿用。

## 6. 状态与数据流

### 6.1 模型

沿用对接文档 §4.1 的 `VideoSegment`,更名 `QaSegment`(项目命名一致性)。可空性照抄文档表格:
`start_time` / `duration_seconds` / `published_date` **可空**;`summary` 可能是 `""` 但不为 null;`tags` 无标签时为 `[]`。

### 6.2 搜索状态(Riverpod 3 Notifier)

```dart
class QaSearchState {
  final List<QaSegment> items;
  final String query;
  final List<String> tags;
  final int page;
  final bool hasNext;      // 直接用后端的 has_next，不自己算
  final bool loading;      // 首屏 / 新搜索
  final bool loadingMore;  // 触底追加
  final Object? error;
  final int total;
}
```

关键行为:

| 项 | 设计 |
|---|---|
| 分页 | **无限滚动**,`per_page = 20`;触底且 `hasNext && !loadingMore` → `page++` 拉下一页追加 |
| 失败回退 | 追加失败时 `page--`,否则会跳页丢内容(对接文档 §4.3 已提示) |
| 防抖 | 输入 400ms 防抖;后端是 LIKE,每键一发是浪费 |
| 短词 | `query` 去空格后不足 2 字**不自动搜**,提示「請輸入 2 個字以上」(子串匹配下单字噪音极大);用户按回车可强制搜 |
| 参数夹紧 | `page ≥ 1`、`per_page ∈ [1,100]` 在 Dart 侧 clamp,从根上不产生 422 |
| script | `ref.watch(localeProvider).scriptCode == 'Hans' ? 'hans' : 'hant'`;**语言切换 → 重置并重搜** |
| 超时 | 15s;`SocketException`/超时 → 走 `ErrorRetry` |
| 422 | clamp 后不该出现,出现即客户端 bug → 上报 Sentry,UI 走通用错误态(`detail` 是数组,**绝不甩到 UI**) |

`qaTagsProvider`(`FutureProvider<List<String>>`)拉 `/tags`,会话内缓存;标签选择器本地过滤。

## 7. 页面设计

### 7.1 列表页 `/qa`(主入口)

```
┌──────────────────────────────┐
│ ←  往期問答                    │  AppBar
├──────────────────────────────┤
│ 🔍 搜尋關鍵詞（2 字以上）    ✕ │  搜索框（autofocus=false，进来先看内容不弹键盘）
│ [禪修 ✕] [業力 ✕]  ＋ 標籤     │  已选标签 chips + 选择器入口
│ 共 903 條                      │
├──────────────────────────────┤
│ 打坐後的虛幻感與出離心          │  qa_title（titleMedium，主标题）
│ 2026-02-01 · 01:23:34 · 3:10  │  published_date · start_time · 时长
│ 提問者分享打坐時觀到身體是一團  │  summary，maxLines: 3 + ellipsis
│ 業力、痛感變幻，下座後覺得…     │
│ [禪修體驗] [出離心] [身見]      │  最多 3 个标签
├──────────────────────────────┤
│ …                             │
└──────────────────────────────┘
```

- **默认(无 query 无标签)= 全部按日期倒序**,首屏即 903 条内容,不是空页面。
- 状态统一走 `core/widgets/async_states.dart`:加载 `SkeletonList`、错误 `ErrorRetry`、
  空结果 `EmptyState(icon: search_off, title: 未找到相關內容, hint: 試試其他關鍵詞，或清除標籤篩選)`。
  ⚠️ `total == 0` 是**正常结果不是错误**,绝不用错误样式。
- 下拉刷新(`RefreshIndicator`)、底部追加转圈。
- 点击卡片 → `/qa/detail`(传 `QaSegment` 对象)。

### 7.2 标签选择器 `/qa/tags`

- 顶部搜索框,本地过滤 `/tags` 全量结果(归一后约 600 条,本地过滤足够快)。
- `FilterChip` 多选;底部「完成(N)」返回选中列表。
- 提示一行:「選多個標籤時,符合任一即顯示」——`tags` 参数是 **OR**,与 `query` 的 AND 相反,不说明用户必然误解。

### 7.3 详情页 `/qa/detail`(播放器为主)

```
┌──────────────────────────────┐
│ ←                             │
│ ┌──────────────────────────┐  │
│ │                          │  │  16:9 封面 = YouTube 缩略图
│ │          ▶               │  │  + 中央大播放按钮
│ │              01:23:34    │  │  + 右下角时间戳
│ └──────────────────────────┘  │  点击 → /watch/{vid}?t={秒}
│ 打坐後的虛幻感與出離心          │  headlineSmall
│ 2026-02-01 · 出自「…直播」·3:10│
│                               │
│ 提問者分享打坐時觀到身體是一團   │  摘要全文，SelectableText
│ 業力、痛感變幻…（全文，含 \n）  │  始终渲染 ← 关键
│                               │
│ [禪修體驗] [出離心] [身見]      │  点击 → 以该标签搜索
│ 用 YouTube App 開啟            │  外部打开兜底
└──────────────────────────────┘
```

- 封面图 `https://i.ytimg.com/vi/{vid}/hqdefault.jpg`。**大陆 `i.ytimg.com` 同样被墙** →
  `errorBuilder` 降级为主题色块 + `play_circle` 图标,播放按钮功能不变,不留破图。
- **摘要正文与播放是否可用无关,永远完整渲染**——这是大陆 1/3 用户拿到的全部价值(§9)。
- 底部保留「用 YouTube App 開啟」,与「Webex 入口永远保留 App 选项」同一原则(PRD §6)。

#### 7.3.1 为什么不是内嵌 16:9 播放器

`video_player_screen.dart` 已记录真机结论:**YouTube 拒绝无真实 Referer 的 iframe 嵌入(错误 153)**,
Android WebView 的 `loadHtmlString(baseUrl)` 不发真实 Referer,内嵌播放器路线在真机上不可行;
现行方案是整页加载 `m.youtube.com/watch`。把整个 YouTube 移动网页塞进 16:9 框里(带导航栏、评论)
比封面+按钮更糟。故「播放器为主」= **视觉上播放区占据首屏、一击直达带时间戳的播放页**。

#### 7.3.2 详情页参数传递的限制

上游无 `GET /segments/{id}`,详情页只能用 go_router `extra` 传对象。
后果:**冷启动直接打开 `/qa/detail` 会没有 extra** → `extra == null` 时重定向回 `/qa`,不崩。
分享/深链到单条问答**本期不做**,要做须后端先加单条接口(§4.5)。

### 7.4 播放路由扩展

现有 `/watch/:vid` 不接时间戳,需扩展:

```dart
GoRoute(path: '/watch/:vid', builder: (c, s) => VideoPlayerScreen(
  videoId: s.pathParameters['vid']!,
  startSeconds: int.tryParse(s.uri.queryParameters['t'] ?? ''),
))
// VideoPlayerScreen: url = 'https://m.youtube.com/watch?v=$videoId'
//                        + (startSeconds != null ? '&t=${startSeconds}s' : '')
```

从 `timestamp_url` 解析:`vid` 复用 `live_providers.dart` 已有的 `youtubeVideoId()`;
`t` 用 `RegExp(r'[?&]t=(\d+)')`。解析失败 → 退化为直接 `launchUrl(timestamp_url)`。

## 8. 入口

1. **首页九宫格**(`home_screen.dart` 共修组)——重排为:
   `(直播, 往期問答) (經本, 群) (日曆, ——)`
   「往期問答」紧邻「直播」(同属视频内容),末行单格用 `Expanded(SizedBox.shrink())` 占位保持等宽。
   图标 `Icons.forum_outlined`,label `l10n.qaTitle` → `/qa`。
2. **直播页**——「往期回看」区块上方加一条 `ListTile`(`Icons.search`,「往期問答檢索」)→ `/qa`。

两处入口匿名可用,不做登录拦截。

## 9. 大陆降级(对齐 P3.3)

| 能力 | 大陆可用性 | 说明 |
|---|---|---|
| 搜索 / 列表 / 标签 | ✅ | 上游与自托管 Supabase 同在新加坡,同域名根,有实践背书 |
| 摘要全文阅读 | ✅ | **本功能对大陆用户的主要价值** |
| 封面缩略图 | ❌ | `i.ytimg.com` 被墙 → `errorBuilder` 降级色块,不留破图 |
| 视频播放 | ❌ | 走 P3.3 统一的「YouTube 不可达检测与提示」,不在本功能重复造轮子 |

设计上的硬要求:**播放不可用不得影响摘要渲染**。详情页任何情况下都要能读到全文。

## 10. l10n 新增键(zh_Hant 模板 + zh_Hans + zh 三份)

`qaTitle` `qaSearchHint` `qaTooShort` `qaResultCount`(带 `{n}`)`qaEmpty` `qaEmptyHint`
`qaTagsAdd` `qaTagPickerTitle` `qaTagPickerHint` `qaTagPickerOr` `qaTagPickerDone`(带 `{n}`)
`qaPlay` `qaOpenExternal` `qaFromVideo`

## 11. 测试

`test/qa_api_test.dart`(`package:http/testing.dart` 的 `MockClient`,不打真网):

- `fromJson`:`start_time`/`duration_seconds`/`published_date` 为 null;`summary: ""`;`tags: []`;`total_pages: 0`
- URL 构建:`per_page` clamp(0→1、200→100)、`page` clamp(0→1)、`script` 随 locale、`tags` 逗号拼接、空 query 不传该参
- 错误:422 → `QaApiException(422)`(且 `detail` 数组不外泄)、500 → `QaApiException`、超时 → 网络文案
- UTF-8:`utf8.decode(bodyBytes)` 而非 `res.body`(缺 charset 会乱码,对接文档 §4.2 已提示)

`test/qa_search_test.dart`:分页追加、`has_next: false` 后不再请求、失败回退 `page`、防抖(`FakeAsync`)。

已有 `layout_walkthrough_test.dart` 覆盖大字号布局回归,新页面接入其清单。

底线同 PLAN §8:`flutter analyze` + `flutter test` 全绿。

## 12. 需求与计划的同步改动

- **PRD v0.5.11**:§6 讲法问答检索定稿(直连 + 双字形 + 播放器为主);§12.4 移除 `qa-proxy`;§14 待确认项 1 关闭。
- **PLAN**:E12 ✅(样例已提供);**新增 E14**(后端简繁双字形改造,⛔ 阻塞 P6.1);P6.1 拆为三个子任务。

## 13. 开放问题

1. **E14 谁做、何时做**——后端不在本仓库。客户端可以先写(`script` 参数对老后端是未知参数,
   FastAPI 默认忽略未声明的 query 参数,不会 422),但**搜索对繁体用户不可用的状态会一直存在到 E14 完成**。
2. **OpenCC 抽检**由谁验收(佛学名相转换质量,§4.5)。
3. **分享/深链**是否要——要则后端加 `GET /segments/{id}`(§7.3.2)。
