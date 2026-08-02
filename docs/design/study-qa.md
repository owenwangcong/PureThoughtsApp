# 设计文档 · 学修问答(在线提问)

> 对应 PRD §16(v0.5.18),执行任务见 PLAN P8。
> **本文件同时是开发与测试的跟踪清单**:实施按 §7 勾选,测试按 §8 勾选;全部勾完即 P8 DoD 达成。
> 定案日期:2026-07-29(与项目负责人五问五答定稿)。

---

## 1. 目标与需求

用户在 App 内向管理员提出学修问题的**私密一对一问答**。原始六条需求:

1. 用户可以提交问题。
2. 用户只能看到自己问的问题和对这个问题的回答,不能看到别人的问题。
3. 管理员可以看到所有问题并回答。
4. 问题被回答后会通知用户。
5. 一个问题中可以多轮问答。
6. 用户和管理员都可以删除问题。

### 1.1 定案(2026-07-29)

| 事项 | 定案 |
|---|---|
| 回答者 | 使用 `is_app_admin` 管理员账号;**App 与管理后台(Web)双端都要能回答** |
| 功能命名 | **学修问答**(繁体文案「學修問答」) |
| 入口 | 首页「共修」组宫格加一格 |
| 内容形式 | 纯文字(不做图片附件) |
| 会话生命周期 | 回答后**永远可以追问**,不设「关闭/已解决」状态 |
| 删除语义 | **硬删**:整个问题连同全部往来消息永久删除(私密内容不留档;与报数软删口径不同,因其不影响任何统计) |
| 通知隐私 | 通知中心与锁屏推送**均不携带问题正文**,只显示通用文案 |
| 防滥用 | 封禁用户不可提问/发消息;每人同时最多 **3 个待回覆**问题;单条消息 ≤ **2000 字** |
| 账号删除 | 其全部提问随账号**级联硬删**(FK cascade,无需改 `delete-account` 函数,联测验证) |

### 1.2 与「往期问答检索」(PRD §6 / P6.1)的关系

两者互补、完全独立:

| | 往期问答检索(已有) | 学修问答(本文) |
|---|---|---|
| 数据源 | 内容方 FastAPI(客户端直连,与 Supabase 无关) | Supabase 自有表 |
| 性质 | 只读检索既有讲法片段 | 私密互动提问 |
| 可见性 | 匿名可用、内容公开 | 仅本人 + 管理员 |
| Flutter 模块 | `features/qa/` | `features/study_qa/` |
| 路由 | `/qa` | `/study-qa` |

文案上注意区分:「往期問答」vs「學修問答」。

---

## 2. 总体方案

零新外部依赖,完全骑在既有基础设施上:

- **数据**:两张新表 `qa_threads`(线程)+ `qa_messages`(消息),一个问题 = 一个线程,首问与全部往来统一存消息表,聊天式渲染。
- **权限**:纯 RLS 实现需求 2/3/6(`user_id = auth.uid() or is_app_admin()`),与全 App 同一安全模型,不引入新特权面。
- **通知**:数据库触发器(security definer,沿用 `announcement`/`proxy_log` 既有模式)写 `notifications` 表 → 自动接上通知中心(大陆 Android 刚需通道)+ `push-dispatch` 推送 + 邮件兜底,深链进会话页。管理员回复通知提问人;用户提问/追问通知全体管理员。
- **两端界面**:App 内同一入口按 `is_app_admin` 分流用户视图/管理员视图;管理后台(`admin/`)新增「學修問答」页。

---

## 3. 数据模型与安全(Supabase)

### 3.1 表结构

```sql
create table public.qa_threads (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.profiles(id) on delete cascade,
  last_sender_role      text not null default 'user' check (last_sender_role in ('user','admin')),
  last_message_at       timestamptz not null default now(),
  first_message_preview text not null default '',   -- 首问前 100 字,列表标题用;触发器维护
  last_message_preview  text not null default '',   -- 最后一条前 100 字;触发器维护
  user_last_read_at     timestamptz not null default now(),  -- 提问人已读位点(未读红点)
  created_at            timestamptz not null default now()
);
create index idx_qa_threads_user    on public.qa_threads (user_id, last_message_at desc);
create index idx_qa_threads_pending on public.qa_threads (last_message_at desc)
  where last_sender_role = 'user';   -- 管理员「待回覆」筛选

create table public.qa_messages (
  id          uuid primary key default gen_random_uuid(),
  thread_id   uuid not null references public.qa_threads(id) on delete cascade,
  sender_id   uuid references public.profiles(id) on delete set null,  -- 发送者删号后保留消息,按 role 显示
  sender_role text not null check (sender_role in ('user','admin')),
  body        text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at  timestamptz not null default now()
);
create index idx_qa_messages_thread on public.qa_messages (thread_id, created_at);
```

要点:
- `last_sender_role` 即线程状态:`user` = 待回覆,`admin` = 已回覆。不设独立 status 列(定案:不做关闭态)。
- 冗余列(`last_*` / `first_message_preview`)由触发器维护,两端列表**单表一查**即可渲染,且不产生新的暴露面(线程行本身已被 RLS 限定)。
- `qa_threads.user_id → profiles` **on delete cascade** ⇒ 账号删除自动清空其全部提问(定案 §1.1);`qa_messages.sender_id` **set null** ⇒ 某管理员被删号不影响其他人线程里已有的回复(仍按「管理員」显示)。

### 3.2 RLS 策略

沿用 `is_group_member` 模式,先建 security definer 辅助函数避免策略递归:

```sql
create or replace function public.qa_thread_owner(tid uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select t.user_id from qa_threads t where t.id = tid;
$$;
```

| 表 | 操作 | 策略 |
|---|---|---|
| `qa_threads` | select | `user_id = auth.uid() or is_app_admin()`(需求 2/3) |
| | insert | `user_id = auth.uid() and is_active_user()`(封禁拦截;上限见触发器) |
| | update | **不开放**(冗余列走触发器,已读走 RPC) |
| | delete | `user_id = auth.uid() or is_app_admin()`(需求 6,硬删级联) |
| `qa_messages` | select | `qa_thread_owner(thread_id) = auth.uid() or is_app_admin()` |
| | insert | `sender_id = auth.uid() and is_active_user() and ((sender_role = 'user' and qa_thread_owner(thread_id) = auth.uid()) or (sender_role = 'admin' and is_app_admin()))` |
| | update / delete | **无**(消息不可单条改删,只随线程整删级联) |

### 3.3 触发器与通知链路

**① 提问上限**(before insert on `qa_threads`):

```sql
-- 同一 user_id 且 last_sender_role='user' 的线程已达 3 个 → raise exception
-- errcode 用自定义 message 'QA_PENDING_LIMIT',客户端据此显示友好文案
```

**② 消息后处理**(after insert on `qa_messages`,security definer——`notifications` 维持「仅服务端写」不变):

1. 更新 `qa_threads` 冗余列:`last_sender_role` / `last_message_at` / `last_message_preview`(截 100 字);若为线程首条消息,一并写 `first_message_preview`。
2. `sender_role = 'admin'` 且线程主人 ≠ 发送者 → 写一条通知(需求 4):
   `scope='user', target_id=<线程主人>, type='qa_reply', payload={'thread_id': ...}, channels='{inapp,push}'`
3. `sender_role = 'user'` → 对每个 `is_app_admin and banned_at is null and id <> sender_id` 的管理员各写一条:
   `type='qa_question'`,payload/channels 同上。(管理员就几个人,不做合并去重。)

**③ RPC 两个**(不新增 Edge Function):

| RPC | 安全模式 | 职责 |
|---|---|---|
| `create_qa_thread(p_body text) returns uuid` | **security invoker** | 单事务原子创建线程 + 首条消息(RLS 与上限触发器正常生效,不绕权限);避免客户端两笔写第二笔失败留空线程 |
| `mark_qa_thread_read(p_thread_id uuid)` | security definer | `update qa_threads set user_last_read_at = now() where id = p and user_id = auth.uid()`(update 不对客户端开放,已读只能走此口) |

**④ push-dispatch 推送文案**(`renderText` 增两个 case,**不带正文**——隐私定案):

| type | zh_Hans | zh_Hant | body |
|---|---|---|---|
| `qa_reply` | 您的提问有新回复 | 您的提問有新回覆 | (空) |
| `qa_question` | 有新的学修提问 | 有新的學修提問 | (空) |

### 3.4 边界情况

- **旧通知点进已删线程**:通知不 FK 到线程(仅 payload 带 id),线程硬删后点击 → 会话页查无此线程 → 空态「該提問已刪除」+ 返回。
- **管理员被撤权后**:其历史回复 `sender_role='admin'` 已固化,仍显示「管理員」——正确,不回溯。
- **多管理员同时回复**:无锁,消息按 `created_at` 排;提问人收到多条通知,可接受。
- **管理员自己提问**:允许(以 owner 身份 `sender_role='user'` 发消息);回复自己的线程不产生自通知(§3.3 ②的 ≠ 判断)。
- **离线**:不做离线暂存(报数的离线补传机制不适用);提交失败明确报错,文字保留在输入框。
- **大陆可达性**:全走 Supabase(新加坡),与报数同一可达性面,无新增风险;通知中心兜底保证大陆 Android 能收到回复提醒。

---

## 4. App 客户端(Flutter)

### 4.1 模块与路由

```
lib/features/study_qa/
  study_qa_providers.dart      # myThreadsProvider / adminThreadsProvider(待回覆|全部)
                               # threadMessagesProvider(family) / 发送・删除・已读操作
  study_qa_list_screen.dart    # 列表页:按 is_app_admin 分流用户/管理员视图
  study_qa_thread_screen.dart  # 会话页(气泡流 + 底部输入框 + 删除)
  study_qa_compose_screen.dart # 新提问页
```

路由:`/study-qa`(列表)、`/study-qa/new`(新提问)、`/study-qa/:id`(会话)。

### 4.2 用户视图

**列表页「我的提問」**(查 `qa_threads` 单表,按 `last_message_at desc`):

```
│ ←  學修問答                 [+ 提問] │
│ ┌──────────────────────────────┐ │
│ │ 打坐時妄念很多怎麼辦…        ● │ │  first_message_preview + 未读红点
│ │ 已回覆 · 07-28 21:03           │ │  状态章 + last_message_at
│ ├──────────────────────────────┤ │
│ │ 誦經迴向給家人是否如法…        │ │
│ │ 待回覆 · 07-27 09:15           │ │
│ └──────────────────────────────┘ │
```

- 状态章:`last_sender_role='user'` → 「待回覆」;`='admin'` → 「已回覆」。
- 未读红点:`last_sender_role='admin' and last_message_at > user_last_read_at`。
- 空态:「還沒有提問。點右上角向管理員請教學修問題。」骨架屏/错误重试用 `async_states.dart` 统一组件。

**会话页**(聊天气泡:本人右侧主色,管理员左侧署名统一「管理員」——不暴露具体管理员身份):

- 进入即调 `mark_qa_thread_read`;底部多行输入框 + 发送(insert `qa_messages`,`sender_role='user'`)。
- AppBar 溢出菜单「刪除提問」→ 确认对话框(「刪除後問答內容將永久消失,無法恢復」)→ delete 线程 → 返回列表。
- 下拉刷新;发送后本地追加 + invalidate。

**新提问页**:多行输入(计数 ≤2000)→ 调 `create_qa_thread` → 进入会话页。
`QA_PENDING_LIMIT` 错误 → 提示「您已有 3 個提問待回覆,請耐心等待回覆後再提問」。

### 4.3 管理员视图(同一入口,`profiles.is_app_admin` 分流)

- 列表页变为两个 tab:**待回覆**(`last_sender_role='user'`,默认)/ **全部**;行内多显示提问人 `display_name`(RLS:管理员可全读 profiles)。
- 会话页同一页面复用:管理员发送 `sender_role='admin'`;可删除任意线程。
- 管理员也会收到 `qa_question` 通知(通知中心 + 推送),点击深链进该会话。

### 4.4 首页入口与未登录

- 「共修」组宫格加一格「學修問答」(`Icons.question_answer_outlined`),5 格布局:
  `(直播, 經本)(群組, 日曆)(學修問答, 占位)`;待 E14 完成「往期問答」回归后成 6 格:
  `(直播, 往期問答)(經本, 群組)(日曆, 學修問答)`。
- **账号类功能**:未登录点击跳登录页(v0.5.8 口径,加入 `_guard` 清单);`home_screen.dart` 顶部注释同步。

### 4.5 通知中心渲染与深链

`notifications_screen.dart` 增两个 case(通知中心同样**不显示正文**):

| type | 标题(l10n) | 副标题 | 图标 | onTap |
|---|---|---|---|---|
| `qa_reply` | notifQaReply(您的提問有新回覆) | (空) | `Icons.question_answer_outlined` | `push('/study-qa/${payload['thread_id']}')` |
| `qa_question` | notifQaQuestion(有新的學修提問) | (空) | 同上 | 同上(管理员视角同一会话页) |

### 4.6 l10n 键清单(三份 ARB 同步,简繁双语)

`studyQaTitle`(學修問答)· `studyQaMine`(我的提問)· `studyQaAsk`(提問)· `studyQaNewHint`(請寫下您的學修問題…)· `studyQaPending`(待回覆)· `studyQaAnswered`(已回覆)· `studyQaTabAll`(全部)· `studyQaAdminLabel`(管理員)· `studyQaDelete`(刪除提問)· `studyQaDeleteConfirm`(刪除後問答內容將永久消失,無法恢復)· `studyQaDeleted`(該提問已刪除)· `studyQaEmpty`(還沒有提問…)· `studyQaLimitHit`(您已有 3 個提問待回覆…)· `studyQaSend`(發送)· `notifQaReply` · `notifQaQuestion`(准确措辞实现时定,简繁各一份)。

---

## 5. 管理后台(`admin/`,Next.js)

新增导航「學修問答」→ 路由 `/qa`(supabase-js 直查,RLS 把关,与后台既有模式一致):

- **列表**:tab 待回覆(默认)/ 全部;列 = 提問人 / 首問摘要(`first_message_preview`)/ 最後訊息(`last_message_preview`)/ 最後更新 / 狀態章;按 `last_message_at desc`。
- **会话面板**(行点击展开 Sheet 或详情页):完整消息流(角色区分样式)+ 回复输入框(insert `sender_role='admin'`)+「刪除提問」二次确认。
- **侧栏角标**:待回覆线程计数(导航加载时查询,不做实时)。
- 发布走既有 `admin/scripts/deploy.ps1`(**静态站无热更新,改版必须重跑**——P7.5 教训)。

---

## 6. 对 PRD / PLAN 的影响(随本文档一并落地)

- **PRD v0.5.18**:新增 §16 学修问答;§2 权限矩阵加一行;§12.2 加 `qa_threads` / `qa_messages`;§12.3 加两表 RLS;§13 Roadmap 加一行。
- **PLAN**:新增 Phase **P8**(五个任务,进度总览同步);P8 与 P2–P5 及 P7 余项独立,可并行。

---

## 7. 实施计划(= PLAN P8;完成一项勾一项,并同步 PLAN §1 计数)

- [x] **P8.1 数据层**(M)— ✅ 2026-07-30:migration `20260730000018_study_qa.sql`(两表 + 索引 + **最小授权:qa_threads 不授 update、qa_messages 不授 update/delete,表级即锁死** + RLS + `qa_thread_owner` + 上限触发器 + 消息后处理触发器 + 两 RPC);`push-dispatch` renderText 增 `qa_reply`/`qa_question`(文案不带正文);pgTAP `study_qa.test.sql` 36 项。
  **验收 ✅**:`npx supabase test db` 全绿(7 文件 121 项);本地栈 REST 冒烟:真 JWT 走 `create_qa_thread` → 管理员 insert 回复 → 冗余列更新 + `qa_reply` 通知(target/payload/channels 正确,title/body 空)→ owner REST 删除级联清空。
- [x] **P8.2 App 用户端**(L)— ✅ 2026-07-30:`features/study_qa/`(providers + 列表/会话/新提问三屏);首页共修组第三行加「學修問答」格(`_guard` 未登录跳登录);通知中心 `qa_reply`/`qa_question` 渲染 + 深链 `/study-qa/:tid`;l10n 三份 ARB 各 +19 键(studyQa* / notifQa* / back);走查测试接入列表页 + 会话页(简繁 × 2.0)。
  **验收 ✅**:T-APP-01…07 勾完;`flutter analyze` 0 issue + `flutter test` 159 项全绿(含本地栈 smoke `study_qa_flow_smoke_test.dart`:提问→隔离→回复→通知→追问→上限→删除全链路)。
- [x] **P8.3 App 管理员视图**(M)— ✅ 2026-07-30(与 P8.2 同批实现,同屏分流):列表按 `is_app_admin` 变待回覆/全部两 tab + 提问人名;会话页按 `qaSenderRole`(线程主人恒 user,他人即管理员回复)发送;管理员对任意线程有删除入口。
  **验收 ✅**:T-APP-08…10 勾完(T-APP-09 由 smoke 测试在库中验 sender_role='admin');analyze/test 全绿。
- [x] **P8.4 管理后台页**(M)— ✅ 2026-07-30:`admin/src/app/(admin)/qa/page.tsx`(待回覆/全部 tab 含计数、行点击开会话 Dialog、气泡流按角色分色、回复 insert(管理员自问自答按 owner 口径取 role)、删除二次确认);侧栏「學修問答」导航 + 待回覆红点角标(`qa-pending-count` 查询,回复/删除后 invalidate);`npm run gen:types` 已含两新表。
  **验收 ✅**:§8.3 T-ADM-01…05 勾完;lint + build 全绿(13 路由含 /qa);本地栈浏览器实测:登录→角标 7 与库一致→回复(库中中文/通知行/无正文全对,角标 7→6)→删除(确认→行消失→用户侧同步消失,角标→5)→登出直访 /qa 弹回登录;控制台零报错。
  **要点**:`.env.local` 被指向生产(2026-07-20 用户设置),本地浏览器实测须临时建 `.env.development.local` 指回本地栈跑 `npm run dev`(测毕删除,不动用户文件);静态产物 `out/` 恒为生产配置,不能拿来本地实测。
- [ ] **P8.5 联测与发布**(S)— 🔄 **服务端发布已完成(2026-07-30)**:migration 0018/0019 推生产 + 记账(并补 0016/0017 漏记账)· push-dispatch 同步 + functions 容器重启 · admin 站 deploy.ps1 重发布;T-PROD-01/03 ✅。**余(需用户设备)**:§8.4 真机 App 走查(数据层已全部自动化验证)+ T-PROD-02 真机通知闭环。
  **验收**:§8.4 + §8.5 勾完;PLAN P8 全部勾选并更新 §1。

分支约定:`feature/p8-1-study-qa-db` 等;commit 以任务编号开头(如 `P8.1: 学修问答数据层`)。

---

## 8. 测试计划(跟踪清单)

> 本地栈 seed 账号(密码均 `test1234`):`admin@test.local`(管理员)、`owner@test.local`、`member@test.local`、`user@test.local`。
> 以下「A」= user@test.local,「B」= member@test.local,「管」= admin@test.local。

### 8.1 pgTAP(`supabase/tests/study_qa_test.sql`,随 P8.1)

**RLS 隔离(需求 2/3)**
- [x] T-DB-01 A 建线程发首问后:A 可 select 该线程与消息;**B select 结果为 0 行**;管理员可 select。
- [x] T-DB-02 anon 对两表 select / insert 全部拒绝或 0 行。
- [x] T-DB-03 B 向 A 的线程 insert 消息被拒(RLS)。
- [x] T-DB-04 A 可追问自己的线程;管理员可以 `sender_role='admin'` 回复任意线程。
- [x] T-DB-05 非管理员以 `sender_role='admin'` insert 被拒;伪造 `sender_id` ≠ auth.uid() 被拒。

**封禁与防滥用**
- [x] T-DB-06 置 `banned_at` 后,该用户建线程 / 发消息均被拒;解封恢复。
- [x] T-DB-07 A 已有 3 个待回覆线程 → 建第 4 个报 `QA_PENDING_LIMIT`;管理员回复其中一个(`last_sender_role` 变 `admin`)后,可再建新线程。
- [x] T-DB-08 body 为空白 / 超 2000 字被 check 拒绝。

**删除(需求 6)**
- [x] T-DB-09 B 删 A 的线程被拒;A 删自己的成功且消息级联清空;管理员删任意线程成功。
- [x] T-DB-10 删除 profiles 行(模拟删号)→ 其线程与消息级联消失;删某管理员 profiles 行 → 其他人线程中该管理员的回复保留且 `sender_id` 为 null。

**触发器与通知(需求 4)**
- [x] T-DB-11 管理员回复 → 恰好 1 条 `notifications`(scope=user,target=A,type=qa_reply,payload.thread_id 正确,channels 含 inapp+push);**title/body 不含消息正文**。
- [x] T-DB-12 A 提问/追问 → 每个未封禁管理员各 1 条 `qa_question`;发送者本人不收;管理员回复自己拥有的线程不产生自通知。
- [x] T-DB-13 消息插入后线程冗余列正确(`last_sender_role`/`last_message_at`/两个 preview;首条写 `first_message_preview`;preview 截断 ≤100 字)。
- [x] T-DB-14 客户端直接 update `qa_threads` 被拒;`mark_qa_thread_read` 仅 owner 生效(B 调 A 的线程无效果)。
- [x] T-DB-15 `create_qa_thread` 原子性:body 非法时线程与消息都不产生;成功时两者都在且返回 id 正确。

### 8.2 Flutter 自动化(`app/test/study_qa_*.dart`,随 P8.2/P8.3)

**用户端(P8.2)**
- [x] T-APP-01 列表页三态:骨架屏 / 空态文案 / 错误重试(provider override)。
- [x] T-APP-02 列表行渲染:待回覆/已回覆状态章、未读红点逻辑(`last_message_at > user_last_read_at` 且 admin 最后发言)。
- [x] T-APP-03 新提问页:空内容发送钮禁用;超 2000 字受限;`QA_PENDING_LIMIT` 错误显示上限文案。
- [x] T-APP-04 会话页:气泡按 `sender_role` 左右分侧;管理员署名「管理員」;发送后列表追加。
- [x] T-APP-05 删除流:确认对话框 → 删除 → 返回列表。
- [x] T-APP-06 通知中心:`qa_reply`/`qa_question` 渲染标题与图标,副标题不含正文;onTap 路由到 `/study-qa/:id`。
- [x] T-APP-07 `layout_walkthrough_test`:列表页 + 会话页,简繁 × 字号 2.0 不溢出。
- [x] 底线:`flutter analyze` + `flutter test` 全绿。(159 项,2026-07-30)

**管理员视图(P8.3)**
- [x] T-APP-08 `is_app_admin` 分流:管理员进列表见「待回覆/全部」tab 与提问人名。
- [x] T-APP-09 管理员发送的消息 `sender_role='admin'`。
- [x] T-APP-10 管理员可对任意线程出现删除入口。

### 8.3 管理后台(随 P8.4,本地栈浏览器实测)

- [x] T-ADM-01 非管理员登录被 AdminGuard 拒(既有机制,冒烟确认新页不漏)。
- [x] T-ADM-02 列表:待回覆/全部 tab 过滤正确;列内容与库一致;侧栏角标数 = 待回覆线程数。
- [x] T-ADM-03 会话面板完整显示多轮消息;回复后 App 端 A 可见且收到通知。
- [x] T-ADM-04 删除需二次确认;删除后列表消失、A 的 App 列表同步消失。
- [x] T-ADM-05 `npm run lint` + `npm run build` 全绿,新路由计入导出。

### 8.4 本地栈端到端手工联测(随 P8.5,四账号)

> **2026-07-30 状态**:全部场景的**数据层路径**已由自动化覆盖(pgTAP 36 + Flutter smoke 全链路 + 后台浏览器实测);
> 下列勾选项特指**真机/模拟器上的 App UI 走查**,待用户提供设备时执行(与 T-PROD-02 可同批做)。

- [ ] T-E2E-01 A 提问 → B 的 App 完全看不到 → 管理员后台「待回覆」出现,角标 +1。
- [ ] T-E2E-02 管理员后台回复 → A 通知中心出现「您的提問有新回覆」(无正文)→ 点击深链进会话 → 红点清除。
- [ ] T-E2E-03 A 追问 → 管理员 App 收到 `qa_question` 通知 → 在 **App 内**回复 → A 再收通知(双端回答闭环)。
- [ ] T-E2E-04 A 删除自己的问题 → 后台列表消失;管理员删另一问题 → A 列表消失;A 点旧通知 → 「該提問已刪除」空态。
- [ ] T-E2E-05 未登录点首页「學修問答」→ 跳登录;登录后进入。
- [ ] T-E2E-06 后台封禁 A → A 提问被拒;解封恢复。
- [ ] T-E2E-07 A 连发 3 问不回复 → 第 4 问提示上限;管理员回复一个后可再问。
- [ ] T-E2E-08 简繁切换全部新文案正确;字号 2.0 走查列表/会话/新提问三页。

### 8.5 生产冒烟(随 P8.5,发布后)

- [x] T-PROD-01 ✅ 2026-07-30:migration 0018+0019 已应用并记账(顺带补上 0016/0017 漏记的记账);anon REST 探测两表 401;authenticated 授权矩阵与设计一致(threads=SELECT/INSERT/DELETE,messages=SELECT/INSERT);functions 容器重启后 push-dispatch 由 pg_cron 正常调度。
- [ ] T-PROD-02 真机(或 TestFlight)提问 → 线上后台回复 → 真机通知中心收到;若 P2.1 推送已通,锁屏推送出现且**不含正文**。
- [x] T-PROD-03 ✅ 2026-07-30:deploy.ps1 重发布,线上 `/qa` 200(14 路由)。

### P8 DoD

§7 五任务全勾 + §8 全部测试项勾完 + §9 修复项勾完;用户隔离与双端回复经 T-E2E 验证;生产冒烟通过。

---

## 9. P8.6 角色语义修复(2026-08-01,PRD v0.5.19)

### 9.1 缺陷(用户真机 + 线上后台实测发现)

同一账号手机提问、后台回答时:①后台回复显示为「提問人」;②手机端看不出这是回复;③手机收不到通知;④管理员在手机端无法以管理员身份回答自己的提问。

**根因链**(四处叠加):

1. **角色从所有权推导**:后台 `qa/page.tsx` 与 App `qaSenderRole` 均为 `线程主人 ? 'user' : 'admin'` → 管理员回答**自己的**线程被记成 `user`,触发器走「用户提问」分支且排除发送者 → 零通知、状态仍「待回覆」。
2. **触发器自通知抑制**:0018 中 admin 消息若 owner==sender 不发 `qa_reply` → 即使角色修好,自答仍无通知。
3. **App 气泡按 `sender_id` 分侧**:同一人的问与答全在右侧、无署名,视觉上"回复没显示"。
4. **qa providers 非 autoDispose**:缓存常驻,重进页面不重拉,别端写入须手动下拉刷新才可见。

### 9.2 定案(PRD §16「消息角色」)

**角色 = 发言时的身份语境,不从所有权推导。**

- 管理后台:回复恒 `sender_role='admin'`。
- App:管理员列表三 tab **待回覆 / 全部 / 我的提問**;从 待回覆/全部(及 `qa_question` 通知)进入会话 → 以管理员身份发言(路由 `?as=admin`);从 我的提問(及 `qa_reply` 通知)进入 → 以提问人身份发言。非管理员不受影响(RLS 兜底:`sender_role='admin'` 必须 `is_app_admin`)。
- 渲染(三端):气泡按**角色对当前语境**分侧;`admin` 消息恒署「管理員」,管理员语境下 `user` 消息署「提問人」。
- 通知:migration 0020 去掉自通知抑制,admin 消息一律向线程主人发 `qa_reply`(文案本就无正文);`qa_question` 维持排除发送者。
- 刷新:qa 三 provider 改 `autoDispose`;会话页返回列表时 invalidate 列表。

### 9.3 实施清单

- [ ] F-1 migration `20260801000020_qa_reply_self_notify.sql`:重建 `on_qa_message_insert` 去掉 owner==sender 抑制;pgTAP T-DB-12c 断言反转(自答产生 1 条 qa_reply,target=本人)。
- [ ] F-2 App:providers autoDispose + `qaSenderRole` 改语境判定;列表三 tab;路由 `?as=admin` + 通知深链带语境;气泡按角色分侧/署名;返回刷新;l10n +「提問人」键。
- [ ] F-3 后台:回复恒 `admin`;lint+build 绿。
- [ ] F-4 测试:pgTAP + Flutter 全绿(受影响用例更新:三 tab、气泡分侧、深链语境)。
- [ ] F-5 发布:0020 推生产+记账;admin 站重发布;真机重装复测 §9.1 四现象消失。
