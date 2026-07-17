# 设计文档 · 活动时间表与资料(管理员维护)

> 对应 PRD §5(Epic 2 · 通知/活动/日历)的扩展。执行任务见 PLAN P2.4c。
> 作者:Claude(2026-07-16)· 决策依据:用户四点拍板(见 §1)。
> 状态:**设计定稿,待实现**。前置:现有活动/日历(P2.4/P2.4b ✅)、自托管 Storage(P0.2 生产部署时建 bucket)。

## 1. 需求与已定决策

管理员给活动补一份**时间表**(几点到几点做什么)和**相关资料**(PDF、链接),用户可看、可整张转发。

用户四点拍板(2026-07-16):

1. **PDF 存 Supabase Storage**——新建 `event-files` bucket(管理员可写、公开可读)。App 内直接上传/下载,走 `api.pure-thoughts.com`,**大陆可达**(这是相对 YouTube 的关键优势,§4)。
   → 偏离早前「音频不放 Storage」的决定;PDF 需在 App 内上传、量小,Storage 是唯一自然选择。PRD §8/§12 同步记此偏离。
2. **时间表支持跨多天**——每行带「第几天」+ 起讫时间;单日活动只用第 1 天,禪七等多日活动按天排完整流程。
3. **行内链接 = 自由网址;PDF 单列底部**——每行可选填一个自由网址(经文网页等);管理员上传的 PDF 作为**活动级「相关资料」**集中在详情页底部下载区。
4. **分享 = 系统分享面板 + 复制**——整张时间表渲染成纯文本,点「分享」弹系统面板直接发 Line/微信,另提供「复制到剪贴板」。新增 `share_plus` 依赖。

其余按合理默认(本文内说明,不再逐一确认):

- **时间表归属活动本身**,循环活动(如週六共修)各场次共用同一份;多日时间表只对**单次(不循环)活动**(如禪七)有意义,循环活动只用第 1 天。
- **`content` 字段保留**作活动简介/说明;时间表是新的结构化数据,二者并存。
- **改时间表/资料不再额外触发全员通知**(活动本身的新增/更新已通知;避免管理员编排时反复打扰)。
- **时间表时间是「现场墙钟时间」**,按管理员填写原样显示,**不做时区换算**(与 `start_at` 不同——现场流程表就该是当地时间;线上跨时区活动的时间表歧义列为已知限制,§12)。

## 2. 数据模型

活动表 `events` 结构不动(已有 `content` / `youtube_url` / `webex_url`)。新增两张子表 + 一个 Storage bucket。

### 2.1 `event_agenda_items`(时间表行)

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | uuid pk | |
| `event_id` | uuid FK→events(id) **on delete cascade** | 删活动连带删时间表 |
| `day_index` | int not null default 1 | 第几天(1 起);单日活动恒 1 |
| `start_time` | time not null | 起(墙钟时间,不带 tz) |
| `end_time` | time | 讫(可空——开放式/无明确结束) |
| `activity` | text not null | 做什么 |
| `link_url` | text | 自由网址(经文等,可空) |
| `link_label` | text | 链接显示文字(可空,空则显示「查看」/域名) |
| `sort_order` | int not null default 0 | 同一天内排序 |
| `created_at` | timestamptz default now() | |

展示时按 `(day_index, sort_order, start_time)` 排序、按 `day_index` 分组。

### 2.2 `event_attachments`(相关资料 / PDF)

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | uuid pk | |
| `event_id` | uuid FK→events(id) **on delete cascade** | |
| `title` | text not null | 显示名(如「地藏經 經本」) |
| `storage_path` | text not null | `event-files` bucket 内对象 key,如 `{event_id}/{uuid}.pdf` |
| `size_bytes` | bigint | 展示「1.2 MB」用 |
| `content_type` | text | MVP 固定 `application/pdf` |
| `sort_order` | int not null default 0 | |
| `created_at` | timestamptz default now() | |

> ⚠️ 删活动/删附件行时,**Storage 对象不会被 DB 级联删除**——需在客户端删行前先删 Storage 对象(§6.3),或后续加 Edge Function / 定时清理孤儿对象(§12)。

### 2.3 Storage bucket `event-files`

```sql
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('event-files', 'event-files', true, 20971520, array['application/pdf']);
```

- **public = true**:对象有公开 URL,匿名可下载(与「活动匿名可看」一致);无需签名 URL,`getPublicUrl()` 即得。
- 20 MB 上限、仅 `application/pdf`(服务端强校验,不只靠客户端)。

## 3. 权限与安全

两张新表 RLS 与 `events` 完全一致(anon/authenticated 可读、仅 App 管理员可写):

```sql
alter table public.event_agenda_items enable row level security;
create policy agenda_select on public.event_agenda_items for select using (true);
create policy agenda_write  on public.event_agenda_items for all
  using (public.is_app_admin()) with check (public.is_app_admin());
grant select on public.event_agenda_items to anon, authenticated;
grant insert, update, delete on public.event_agenda_items to authenticated; -- 行级限管理员
-- event_attachments 同上
```

Storage 对象策略(`storage.objects`):

```sql
create policy "event-files read"   on storage.objects for select
  using (bucket_id = 'event-files');                        -- 公开读
create policy "event-files insert" on storage.objects for insert
  with check (bucket_id = 'event-files' and public.is_app_admin());
create policy "event-files update" on storage.objects for update
  using (bucket_id = 'event-files' and public.is_app_admin());
create policy "event-files delete" on storage.objects for delete
  using (bucket_id = 'event-files' and public.is_app_admin());
```

**唯一新信任面**:管理员能往公开 bucket 写 PDF。`is_app_admin()` 已在库中(现有 RLS 用),复用即可。`service_role` 仅存在于 Edge Functions,客户端只有 anon key + 登录态(§CLAUDE.md 安全模型)。

## 4. 大陆可达性(重点)

| 资源 | 大陆可达 | 说明 |
|---|---|---|
| 时间表(文字/链接) | ✅ | 存 Postgres,走 api.pure-thoughts.com(实测 200) |
| **PDF 下载** | ✅ | Storage 公开 URL 同在 api.pure-thoughts.com/storage/v1/…——**大陆可下**,不像 YouTube |
| 行内自由网址 | ⚠️ 视目标 | 指向 qldazangjing 等大陆可达站点则可用;指向被墙站点则否(取决于管理员填什么) |
| YouTube 链接 | ❌ | 大陆不可达,走 P3.3 统一降级提示 |
| 分享文本里的 Storage URL | ✅ | 转发到微信后,大陆用户点开能下 PDF |

**设计红线**:时间表与 PDF 是本功能对大陆 1/3 用户**可用**的部分,不得依赖 YouTube 才能读到流程或经本。

## 5. 客户端结构

沿用 `features/events/`,新增:

```
lib/features/events/
  event_detail_models.dart   # AgendaItem / EventAttachment（纯数据）+ 文本渲染纯函数
  event_detail_screen.dart   # 用户详情页（替换现有 bottom sheet 的富内容版）
  event_agenda_editor.dart   # 管理员：时间表行增删改排 + PDF 上传/删除
  events_providers.dart      # 追加 agendaItemsProvider(eventId) / attachmentsProvider(eventId)
```

依赖新增:
- `share_plus`(系统分享面板)
- `file_picker`(管理员选 PDF,`withData: true` 拿字节上传)
- 下载:MVP 用 `url_launcher` 打开 Storage 公开 URL(浏览器下载/预览),**不引额外下载库**;「App 内下载到本地 + 打开」列入后续(与 P4.2 音频下载管理共用基建)。

## 6. 页面设计

### 6.1 用户详情页 `/calendar/event`(取代 bottom sheet)

现有 `_showDetail` 的 `showModalBottomSheet` 内容有限;时间表(可能多日)+ 资料 + 分享放不下,改为**整页**(经 go_router `extra` 传 Occurrence,冷启动无 extra → 回日历,同 QA 详情做法)。

```
┌──────────────────────────────┐
│ ←  法會/活動标题        [分享] │  AppBar；分享按钮 = 时间表文本 → 系统面板
├──────────────────────────────┤
│ 地藏法會                       │  titleLarge
│ 2026-08-01 09:00 · 90 分鐘     │  start_at（本地时区）
│ {content 简介文字}             │
│                               │
│ 時間表                    [複製]│  SectionHeader + 复制按钮
│ ── 第一天（8月1日）──          │  day_index 分组；单次活动带日期
│  06:00–07:00  早課             │
│  07:00–08:00  誦地藏經  〔經文〕│  link_url → 行尾「經文」链接（url_launcher）
│  ...                          │
│ ── 第二天（8月2日）──          │
│  ...                          │
│                               │
│ 相關資料                       │  SectionHeader
│  📄 地藏經 經本 · 1.2 MB    ⬇ │  点整行/⬇ → 打开公开 URL（浏览器下载）
│  📄 儀軌 · 0.4 MB           ⬇ │
│                               │
│ ▶ YouTube      🎥 Webex        │  沿用现有按钮（含永久保留 App 选项）
│                               │
│ ── 管理員 ──（isAdmin 时）      │
│  [編輯活動] [編輯時間表/資料]   │  → _editEvent 对话框 / 编辑器
│  [取消此次] [刪除活動]          │  沿用现有逻辑
└──────────────────────────────┘
```

- 空时间表 / 空资料区块整段隐藏(不留空标题)。
- 状态走 `core/widgets/async_states.dart`(加载骨架、错误重试)。
- 时间表 `time` 显示为 `HH:mm`;`end_time` 空则只显示起始(如「06:00 早課」)。

### 6.2 管理员编辑器 `event_agenda_editor.dart`

- **时间表 tab / 区块**:按天分组的行列表;每行可编辑 起/讫(TimePicker)、活动、自由网址+标签;可增行、删行、拖拽排序(`ReorderableListView`);可增/删「天」(day_index)。改动即时 upsert 到 `event_agenda_items`。
- **资料区块**:PDF 列表;「上传 PDF」→ `file_picker` 选文件 → `supabase.storage.from('event-files').uploadBinary('{eventId}/{uuid}.pdf', bytes, FileOptions(contentType:'application/pdf'))` → 插入 `event_attachments` 行(title 默认取文件名,可改);删除 → 先删 Storage 对象再删行(§6.3)。上传中显示进度/禁用重复提交。
- 仅 `isAdmin` 可进;非管理员即使拿到路由也被 RLS 拒写(纵深防御)。

### 6.3 删除时的 Storage 一致性

客户端删附件:**先** `storage.from('event-files').remove([path])` **再**删 `event_attachments` 行;删整个活动前先批量删其所有附件对象。任一步失败给错误提示、不静默。孤儿对象(极端情况)由后续清理任务兜底(§12)。

## 7. 分享/复制文本格式(纯函数,可单测)

`renderAgendaText(event, items, attachments, locale)` → 纯文本:

```
地藏法會
2026-08-01 09:00

【時間表】
第一天（8月1日）
  06:00–07:00  早課
  07:00–08:00  誦地藏經  https://qldazangjing.com/...
第二天（8月2日）
  06:00–07:00  早課
  ...

【相關資料】
地藏經 經本：https://api.pure-thoughts.com/storage/v1/object/public/event-files/xxx.pdf
YouTube：https://youtube.com/watch?v=...
```

- 行内 `link_url`、附件公开 URL、`youtube_url` 都以**纯 URL** 落文本 → 转发到 Line/微信后自动可点。
- 简繁按当前 `locale` 出小标题(【時間表】/【时间表】等);活动/行文字原样(管理员输入什么是什么)。
- 「分享」→ `Share.share(text)`;「复制」→ `Clipboard.setData` + SnackBar 提示。

## 8. l10n 新增键(zh_Hant 模板 + zh_Hans + zh)

`eventAgendaTitle` `eventAttachmentsTitle` `eventDayN`(带 `{n}`)`eventShare` `eventCopy` `eventCopied`
`eventAddAgendaRow` `eventAddDay` `eventUploadPdf` `eventUploading` `eventEditAgenda`
`eventLinkLabelDefault`(「查看」)`eventNoAgenda` `agendaStart` `agendaEnd` `agendaActivity` `agendaLinkUrl`

## 9. 迁移

新 migration `supabase/migrations/20260716000011_event_agenda.sql`:
1. 建 `event_agenda_items` / `event_attachments`(索引:各 `(event_id)`)。
2. 两表 RLS + grants(§3)。
3. `insert into storage.buckets ... 'event-files'`(§2.3)+ `storage.objects` 四条策略(§3)。
4. seed:给现有 seed 活动(週六共修/週三打坐)各加 2–3 行示例时间表,便于本地走查。

pgTAP `supabase/tests/`:匿名可 select 两表、非管理员写被拒、管理员写通过;bucket 存在且 public。

## 10. 测试

- **纯函数** `renderAgendaText`:多日分组、行链接、空时间表/空资料、简繁小标题 → 单测。
- **day 分组/排序** helper(`groupAgendaByDay`):`(day_index, sort_order)` 排序、单日恒第 1 天 → 单测。
- **pgTAP**:§9 的 RLS/bucket 断言。
- **widget**:详情页 + 编辑器接入 `layout_walkthrough_test` 大字号(简繁 × 2.0 不溢出)。
- **真机**:管理员建时间表 + 传 PDF → 用户看 + 下 PDF + 分享到微信;大陆网络下 PDF 可下(E6 一并验)。
- 底线同 PLAN §8:`flutter analyze` + `flutter test` 全绿。

## 11. PRD / PLAN 同步

- **PRD v0.5.12**:§5 增「活动时间表 + 相关资料(管理员维护、用户查看、整张可分享)」;§8/§12.5 记 **PDF 用 Supabase Storage** 的偏离与理由(大陆可达);§12.2 数据模型加两表 + bucket;§14 大陆可达性补 PDF 可达要点。
- **PLAN**:新增 **P2.4c**(活动时间表与资料),拆子任务:migration+RLS+Storage / 用户详情页 / 管理员编辑器 / 分享+文本 / 测试。**Storage 备份**补进 P0.4 范围(对象存储也要纳入异地备份,不只 Postgres)。

## 12. 已知限制 / 后续

1. **孤儿 Storage 对象**:客户端删除逻辑覆盖正常路径;异常中断可能留孤儿。后续加定时清理(比对 `event_attachments` 与 bucket 列表)或删活动走 Edge Function 事务性清理。
2. **时间表时区**:按现场墙钟原样显示,不换算——线上跨时区活动可能对异地用户有歧义。若将来线上活动多,再考虑给时间表加可选时区标注。
3. **App 内下载到本地**:MVP 用浏览器打开公开 URL;离线保存 + App 内打开(带进度、已用空间)与 P4.2 音频下载管理共用基建,后续一并做。
4. **多日时间表 × 循环活动**:多日仅对单次活动开放;循环活动的编辑器只允许第 1 天(避免「第 N 天」在每周重复下语义不清)。
5. **PDF 大小/类型**:服务端限 20 MB、仅 PDF;更大文件或其它类型(音频/图片)后续再评估。
