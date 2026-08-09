# 设计文档 · 通知系统改造（投递可靠性 / 免打扰 / 活动提醒 / 降噪 / 深链 / 治理）

> 对应 PRD §5 / §5.1 / §5.2 / §12.4（拟升 v0.5.21），执行任务见 PLAN **P2.12 – P2.17**。
> **本文件同时是开发与测试的跟踪清单**：实施按 §11 勾选，测试按 §12 勾选；全部勾完即达成 §14 DoD。
> 立项依据：2026-08-07 通知链路全量勘察（结论见 §1），2026-08-08 定稿。
> 本次改造**不含** P2.2 邮件兜底，但为其准备了前置条件（`channels` 字段生效 + 大陆用户判据重建），见 §9.5。

---

## 0. 摘要

现状一句话：**日历活动的通知只有「管理员改了活动 → 全站广播」一种，PRD §5 承诺的「周六共修提前一天预告 / 当天连接通知」一条都没有实现**；同时投递管道存在三个会在生产暴露的正确性缺陷。

本次改造分六步，按依赖顺序推进：

| 步 | 任务号 | 主题 | 为什么是这个顺序 |
|---|---|---|---|
| 1 | **P2.12** | 投递管道加固 | 不修这步，后面做出来的提醒也发不出去（见 §1 缺陷 A） |
| 2 | **P2.13** | 免打扰 + 通知偏好上云 | 上生产前必须，否则大陆用户凌晨 00:05 被佛历通知叫醒 |
| 3 | **P2.14** | 活动提醒排程 | 兑现 PRD §5 核心承诺，本次最大价值项 |
| 4 | **P2.15** | 变更通知降噪 | 提醒上线后通知量翻倍，必须同期降噪 |
| 5 | **P2.16** | 推送深链闭环 | 「活动快开始了」点开必须直达该场活动 |
| 6 | **P2.17** | 通知中心与数据治理 | 收尾：分页、Realtime、已读语义、retention、索引、死字段清理 |

---

## 1. 现状勘察结论（改造的事实依据）

### 1.1 链路全貌（改造前）

```
events / event_overrides 写入
  └─ 行级触发器 notify_event_change / notify_override_change
       └─ insert notifications(scope='all', type='event_changed', channels='{inapp}')
            ├─ 语句级触发器 trg_push_dispatch ──┐
            └─ pg_cron push-dispatch-sweep(每分钟) ─┤
                                                   └─ pg_net.http_post(5s)
                                                        └─ Edge Function push-dispatch
                                                             ├─ 抢占(先写 sent_at)
                                                             ├─ scope=all → 全表 push_tokens 无过滤
                                                             └─ 逐 token 串行 APNs / FCM
客户端
  └─ myNotificationsProvider(FutureProvider, limit 50, 无分页/无 Realtime)
       └─ 进页面即全部标已读；event_changed 点击 → /calendar(到不了具体活动)
推送点击 → 无任何处理(App 只是被拉起)
```

### 1.2 已确认的缺陷清单

**A. 定时通知超过 24 小时永远发不出去**（现成 bug，且会掐死活动提醒）
`supabase/functions/push-dispatch/index.ts:219-225` 取数条件同时要求 `created_at > now()-24h` 且 `scheduled_at <= now()`。而 `admin_publish_notification`（migration 0015）允许管理员定任意未来时点。定到 24 小时以后 → 到点时 `created_at` 已滑出窗口 → `sent_at` 恒为 null，**永久不投递**，还会永久计入后台看板的「通知积压」告警。
PRD §12.4 设计的「每日展开未来 14 天 occurrence → 生成带 `scheduled_at` 的提醒」，其绝大多数行 `created_at` 会早于触发时刻 24 小时以上 —— **不修这条，第 3 步做出来一条也发不出去**。

**B. 投递失败 = 永久静默丢失**
`index.ts:228-233` 在发送**之前**就写 `sent_at` 抢占，之后 APNs/FCM 失败只 `failed++` 计数返回 HTTP body，不回滚、不重试、不落错误。fetch 无 try/catch，网络异常让整个 handler 500，而该批通知已被标记「已发送」。

**C. 佛历通知会在大陆用户凌晨 00:05 推送**
`almanac-daily` cron 为 `5 16 * * *`(UTC) = 北京时间次日 00:05，生成后被语句级触发器秒级推送。PRD §5.2 要求「默认 22:00–07:00（用户本地时区）不发系统推送，顺延」，但服务端从不读 `profiles.timezone`（`profile_sync.dart` 注释明写「暂不同步」）。P2.1-4 一旦上生产即暴露。

**D. 设置页佛历开关是假的**
`notifications_providers.dart:27-32` 仅做客户端列表过滤，服务端照推。用户关了开关仍收系统推送。

**E. 变更通知全员、无节流、无去重**
`notifications` 表**无任何唯一约束**；连改 5 次标题 = 全站每人 5 条推送。且发给所有人（无活动报名表）。

**F. 撤销取消/撤销改期无通知**
`trg_notify_override_change` 只挂 `after insert or update`。管理员恢复一场被取消的共修，没人知道。

**G. 推送点开无深链**
`push_service.dart` 无 `onMessageOpenedApp`/`getInitialMessage`，本地通知 `initialize()` 无响应回调，APNs/FCM 报文只有 title/body。通知中心的 `event_changed` 也只跳 `/calendar`，因为 `/calendar/event` 靠 `state.extra` 传不可序列化的 `Occurrence` 对象，无 `:id` 路径参数。

**H. 通知中心时效与已读语义**
无 Realtime 无轮询（红点只在冷启动/下拉刷新时更新）；`limit(50)` 无分页；进页面即全标已读，用户没细看的也被清掉；`created_at` 裸 UTC 显示未做时区换算（`notifications_screen.dart:156`）。

**I. 架构债**
`channels` 是死字段（所有写入点一律 `'{inapp}'`，push-dispatch 完全不读它）；`notifications.event_id` 是死列（所有 insert 都不写，event id 只在 `payload->>'event_id'`）；无 retention job；投递查询走 `sent_at is null` 但只有 `(scope,target_id,created_at desc)` 一个索引；`notification_reads` 无 `(user_id)` 索引；`push_tokens.fcm_failed` 恒为 false（失效 token 是直接 DELETE，且大陆机根本没有 token 行）。

---

## 2. 定案（每项已给推荐值；**未答复前按推荐值实现**，改选只影响局部）

| # | 问题 | 推荐值 | 影响面 |
|---|---|---|---|
| **Q1** | 新建活动默认给几个提醒点？ | **提前一天（1440）+ 提前 30 分钟（30）+ 活动开始时（0）三档**（2026-08-08 用户定案）；管理员可在编辑器增删。三档各司其职见下方「Q1 决策依据」 | §6 |
| **Q2** | 提醒可选的提前量档位 | **0 / 10 / 15 / 30 / 60 / 180 / 1440 / 2880 分钟**（活动开始时 / 10 分钟 / 15 分钟 / 30 分钟 / 1 小时 / 3 小时 / 提前一天 / 提前两天） | §6 |
| **Q3** | 活动提醒发给谁？ | **全站所有人**（`scope='all'`，与现有 `event_changed` 一致；仓库无活动报名表）；用户可用分类订阅关掉 `event_reminder` | §6 |
| **Q4** | 免打扰默认值 | **默认开启，22:00–07:00（用户本地时区）**，与 PRD §5.2 一致；用户可改起讫或整体关闭 | §5 |
| **Q5** | 免打扰是否放行「活动开始时」的提醒？ | **放行**。PRD §5.2 明写「活动开始前的实时通知（如"共修连接"）不受限」。判据：`offset_minutes <= 60` 的 `event_reminder` 绕过免打扰；其余（含提前一天预告）遵守 | §5 §6 |
| **Q6** | 分类订阅（静音某 type）的语义 | **不推送 + 通知中心不显示 + 不计红点**（与现有佛历开关行为一致，避免「关了还在列表里」的困惑） | §5 |
| **Q7** | 通知中心已读语义 | 改为 **点击单条标已读 + AppBar「全部已读」按钮**，取消「进页面全标已读」。红点数因此真实反映未读 | §9 |
| **Q8** | 管理员编辑活动时可否选择「不通知全体」？ | **做**（`admin_save_event` RPC + 编辑器开关，默认开）。这是降噪的根本手段；若要压缩范围可单独推迟 P2.15-4，其余降噪措施不受影响 | §7 |
| **Q9** | 通知保留期 | **180 天**，每日 cron 删除更早的（级联清 `notification_reads`） | §9 |
| **Q10** | `push_tokens.fcm_failed` 列如何处理 | **保留列但加 comment 标注废弃**，看板改读新判据 `notification_prefs.push_unavailable`；不 drop，避免动 `admin/src/lib/database.types.ts` 与既有 pgTAP | §9 |

### Q1 决策依据（2026-08-08 讨论定案，三档缺一不可）

| 档位 | 作用 | 为什么不能砍 |
|---|---|---|
| **1440**（提前一天） | 让用户安排时间 | **大陆 Android 用户唯一能看到的一档**。PRD §5.1 定案：这批用户（约 1/3）收不到任何实时系统推送，只能靠「打开 App 即见」通知中心。只有覆盖 24 小时的预告，他们才有机会在打开 App 时看到；10–30 分钟级的提醒对他们等于不存在，还会在通知中心留下指向已结束活动的死条目。同时这也是 PRD §5.1 邮件兜底的唯一有意义载体（「时效性强的通知（如周六共修预告）对大陆用户额外发邮件」） |
| **30**（提前半小时） | 临门一脚的准备提醒 | 补上原方案 1440 → 0 之间 24 小时的空档（用户提出的真实痛点：提前一天太远，当天会忘）。选 30 而非 10：与「开始时」拉开距离避免两条推送挤在一起，且给足找安静处、翻经本、进 Webex 的时间——用户群年龄跨度大，从看到通知到完成操作的时间更长 |
| **0**（活动开始时） | 点击直进 Webex/YouTube | PRD §5「周六当天 Webex/YouTube 连接」的原文要求 |

实际节奏（周六共修 09:00）：周五 09:00「明日共修預告」→ 周六 08:30「30 分鐘後開始」→ 周六 09:00「活動開始了 · 點擊進入」。管理员可按活动增删（如禪七这类多天活动可去掉 30 分钟档），用户可在设置里整类关闭 `event_reminder`。

---

## 3. 总体架构（改造后）

```
① 通知产生
   ├─ events/overrides 触发器 → event_changed(降噪:5 分钟防抖聚合 + 恢复通知)
   ├─ pg_cron event-reminders-daily(每日 15:00 UTC)
   │    └─ expand_event_reminders(14) → event_reminder(scheduled_at=提醒时刻, event_id 真实写入)
   ├─ pg_cron almanac-daily(不变)
   └─ admin_publish_notification / 其余既有触发器(不变)

② 投递触发
   ├─ 语句级触发器 trg_push_dispatch(改:仅当本批含「已到点」行才外呼)
   └─ pg_cron push-dispatch-sweep(每分钟,不变)
        └─ pg_net.http_post → Edge Function push-dispatch

③ push-dispatch(重写核心流程)
   ├─ 鉴权:DISPATCH_SECRET 必需 + 仅 POST
   ├─ claim_notifications(50)  ← RPC,FOR UPDATE SKIP LOCKED + 租约 + attempts++
   ├─ push_audience(id)        ← RPC,一次返回 token/platform/locale/quiet_until
   │     内含:channels 含 push? · muted_types 过滤 · 免打扰计算 · 未封禁
   ├─ 免打扰命中 → 克隆一条 scope='user' & channels='{push}' & scheduled_at=顺延时刻
   ├─ 并发 20 批量发送(APNs/FCM,报文带 data.route + collapse id)
   └─ complete_notification(id, ok, invalid, failed, error)
         成功 → sent_at;全失败 → 释放租约重试;attempts≥5 → failed_at

④ 客户端
   ├─ 深链:APNs/FCM data.route → PushService 路由消费 → /calendar/event/:id?date=
   ├─ 通知中心:游标分页 + Realtime 红点 + 单条已读 + 本地时区时间
   └─ 设置页「通知」分组:免打扰起讫 + 分类订阅开关(经 notification_prefs 上云)

⑤ 治理
   ├─ pg_cron notifications-retention(每日,180 天)
   └─ 部分索引 idx_notifications_pending / idx_notification_reads_user
```

---

## 4. Step 1 · 投递管道加固（P2.12）

**目标**：让「已生成的通知一定会被投递，失败会重试，失败有痕迹」。这是后续所有步骤的地基。

### 4.1 数据模型变更 —— migration `20260808000023_push_pipeline.sql`

```sql
alter table public.notifications
  add column claimed_at timestamptz,           -- 投递租约(抢占时置位,失败释放)
  add column attempts   smallint not null default 0,
  add column failed_at  timestamptz,           -- 终局失败(attempts 用尽)
  add column last_error text;                  -- 最近一次投递结果摘要

-- 投递队列索引(现表只有 (scope,target_id,created_at desc),帮不上抢占查询)
create index idx_notifications_pending
  on public.notifications (coalesce(scheduled_at, created_at))
  where sent_at is null and failed_at is null;
```

### 4.2 抢占改为租约式 RPC（替代现在的「先写 sent_at 再发」）

```sql
create or replace function public.claim_notifications(p_limit int default 50)
returns setof public.notifications
language plpgsql security definer set search_path = public as $$
begin
  return query
  update public.notifications n
     set claimed_at = now(), attempts = n.attempts + 1
   where n.id in (
     select id from public.notifications
      where sent_at is null
        and failed_at is null
        and (scheduled_at is null or scheduled_at <= now())
        -- 修缺陷 A:窗口基准从 created_at 改为「到点时刻」,定时通知不再永久卡死;
        -- 保留 6 小时上限,避免服务长时间宕机后恢复时把过期提醒雪崩推出。
        and coalesce(scheduled_at, created_at) > now() - interval '6 hours'
        -- 租约:2 分钟内被抢占过的跳过(函数崩溃后自动可重试)
        and (claimed_at is null or claimed_at < now() - interval '2 minutes')
      order by coalesce(scheduled_at, created_at)
      limit p_limit
      for update skip locked
   )
  returning n.*;
end $$;

revoke execute on function public.claim_notifications(int) from public, anon, authenticated;
```

`for update skip locked` 同时解决并发问题：语句级触发器与每分钟 cron 可能同时外呼，现在的两步「先 select 再条件 update」在高并发下会互相空转。

### 4.3 完成/失败回写 RPC

```sql
create or replace function public.complete_notification(
  p_id uuid, p_ok int, p_invalid int, p_failed int, p_error text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare v_summary text;
begin
  v_summary := format('ok=%s invalid=%s failed=%s%s',
                      p_ok, p_invalid, p_failed,
                      case when p_error is null then '' else ' · ' || left(p_error, 300) end);
  if p_ok > 0 or (p_failed = 0 and p_ok = 0) then
    -- 有成功投递,或受众为空(如全站无 token) → 视为完成
    update public.notifications
       set sent_at = now(), claimed_at = null, last_error = v_summary
     where id = p_id;
  else
    -- 全部失败 → 释放租约等待重试;次数用尽则终局失败
    update public.notifications
       set claimed_at = null,
           last_error = v_summary,
           failed_at  = case when attempts >= 5 then now() else null end
     where id = p_id;
  end if;
end $$;

revoke execute on function public.complete_notification(uuid, int, int, int, text)
  from public, anon, authenticated;
```

**已知取舍（重要，必须写进代码注释）**：重试粒度是「整条通知」而非「单个 token」。一条 `scope='all'` 的通知若发到一半崩溃，重试会对已成功的用户重复推送一次。权衡结论：
- 共修团体量级（数百人）下，「发一半崩溃」远少于「整体失败」，而整体失败正是重试要解决的；
- 重复推送由 §7.3 的 `apns-collapse-id` / FCM `collapse_key` 折叠成通知栏里的一条，用户侧影响可接受；
- 做 per-token 投递状态表（`push_deliveries`）成本远高于收益，明确不做。

### 4.4 语句级触发器改为「仅当本批含已到点行才外呼」

现状：管理员定时通知、活动提醒排程等未来行插入时也会白白外呼一次（还会与 §5 的免打扰克隆形成空转递归）。

```sql
create or replace function public.trg_invoke_push_dispatch() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from inserted
              where scheduled_at is null or scheduled_at <= now()) then
    perform public.invoke_push_dispatch();
  end if;
  return null;
end $$;

drop trigger if exists trg_push_dispatch on public.notifications;
create trigger trg_push_dispatch
  after insert on public.notifications
  referencing new table as inserted        -- Postgres 10+ 转换表
  for each statement execute function public.trg_invoke_push_dispatch();
```

### 4.5 Edge Function 重写要点（`supabase/functions/push-dispatch/index.ts`）

| 现状 | 改为 |
|---|---|
| `DISPATCH_SECRET` 未配置则**跳过校验** | **未配置则拒绝**（500 + 日志）。本地开发在 `supabase/functions/.env` 预置开发用 secret，与生产口径一致 |
| 无 method 校验（GET 也能触发） | 仅 `POST`，其余 405 |
| 两步 select + 条件 update 抢占 | `rpc('claim_notifications', {p_limit: 50})` |
| 受众查询散在函数里（scope 分支 + group_members 子查） | `rpc('push_audience', {p_notification_id: id})` 一次取齐（§5.3） |
| 逐 token 串行 `await` | 并发 20 的分批 `Promise.allSettled` |
| fetch 无 try/catch，异常 → handler 500 且通知已标已发 | 全流程 try/catch；任何异常都走 `complete_notification` 释放租约 |
| 结果只回 HTTP body | `rpc('complete_notification', ...)` 落库 |
| `renderText(n, hans) → {title, body}` | `renderPush(n, hans) → {title, body, route}`（route 见 §8.2） |
| APNs payload 无 collapse/expiration/data | 加 `apns-collapse-id`、`apns-expiration`、自定义键 `route` |
| FCM 无 data/collapse | 加 `data.route`、`android.collapse_key`、`android.priority` |

**保持不变**：APNs ES256 JWT 45 分钟缓存、生产域优先沙盒回退、FCM v1 OAuth token 缓存、失效 token 直接 DELETE、按 `profiles.locale` 简繁渲染。

### 4.6 文件清单

| 文件 | 动作 |
|---|---|
| `supabase/migrations/20260808000023_push_pipeline.sql` | 新建 |
| `supabase/functions/push-dispatch/index.ts` | 重写主流程（`Deno.serve` 部分 + 报文构造） |
| `supabase/functions/.env.example` | 新建/补 `DISPATCH_SECRET` 开发值说明 |
| `supabase/tests/push.test.sql` | 扩充（现 9 项 → 见 §12.1） |
| `docs/infra/deploy-aws-ec2.md` §11 | 补「函数改动后重建容器」与新增排查项 |

---

## 5. Step 2 · 免打扰与通知偏好上云（P2.13）

**目标**：兑现 PRD §5.2 免打扰时段与 §5 分类订阅；让设置页的开关真正生效（修缺陷 C、D）。

### 5.1 数据模型 —— migration `20260808000024_notification_prefs.sql`

```sql
create table public.notification_prefs (
  user_id          uuid primary key references public.profiles(id) on delete cascade,
  quiet_enabled    boolean not null default true,
  quiet_start      time    not null default '22:00',
  quiet_end        time    not null default '07:00',
  muted_types      text[]  not null default '{}',    -- 静音的通知 type
  push_unavailable boolean not null default false,   -- FCM 注册失败(大陆 Android 判据,替代 fcm_failed)
  updated_at       timestamptz not null default now()
);

alter table public.notification_prefs enable row level security;
create policy notification_prefs_all on public.notification_prefs for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notification_prefs_admin_read on public.notification_prefs for select
  using (public.is_app_admin());

-- ⚠️ 教训(migration 0016/0019/0022):自托管生产库对新建表存在 default privileges,
-- 会把 anon/authenticated 全权塞进来;必须显式 revoke 后再按需 grant。
revoke all on public.notification_prefs from public, anon, authenticated;
grant select, insert, update, delete on public.notification_prefs to authenticated;
grant all on public.notification_prefs to service_role;

create trigger trg_notification_prefs_updated before update
  on public.notification_prefs for each row execute function public.set_updated_at();
```

**为什么用 `muted_types text[]` 而不是一堆 bool 列**：PRD §5「用户可按类型开关推送」本质是「关掉哪些 type」；每新增一类通知就加一列不可持续。

**为什么 `push_unavailable` 放这里而不是 `push_tokens`**：大陆 Android 机 `getToken()` 直接失败，`push_tokens` 里**根本没有该设备的行**可标记 —— 这正是 `fcm_failed` 永远为 false 的根因。放在按用户一行的偏好表才有落点。

### 5.2 免打扰计算函数

```sql
-- 返回「该用户此刻处于免打扰、应顺延到的时刻」;null = 不在免打扰。
create or replace function public.quiet_until(p_user uuid)
returns timestamptz
language sql stable security definer set search_path = public as $$
  with u as (
    select coalesce(p.timezone, 'UTC')            as tz,
           coalesce(np.quiet_enabled, true)       as en,
           coalesce(np.quiet_start, '22:00'::time) as qs,
           coalesce(np.quiet_end,   '07:00'::time) as qe
      from public.profiles p
      left join public.notification_prefs np on np.user_id = p.id
     where p.id = p_user
  ), t as (
    select tz, en, qs, qe,
           (now() at time zone tz)::time as lt,
           (now() at time zone tz)::date as ld
      from u
  )
  select case
    when not en then null
    -- 跨午夜窗口(22:00–07:00):当前 ≥ 起点 → 顺延到次日终点;当前 < 终点 → 顺延到今日终点
    when qs > qe and lt >= qs then ((ld + 1)::timestamp + qe) at time zone tz
    when qs > qe and lt <  qe then ( ld::timestamp      + qe) at time zone tz
    -- 同日窗口(如 01:00–06:00)
    when qs <= qe and lt >= qs and lt < qe then (ld::timestamp + qe) at time zone tz
    else null
  end from t;
$$;
```

### 5.3 受众解析 RPC（push-dispatch 一次取齐）

```sql
create or replace function public.push_audience(p_notification_id uuid)
returns table (token text, platform public.push_platform,
               locale text, quiet_until timestamptz, user_id uuid)
language plpgsql security definer set search_path = public as $$
declare n public.notifications%rowtype;
begin
  select * into n from public.notifications where id = p_notification_id;
  if not found or not ('push' = any(n.channels)) then return; end if;   -- channels 正式生效

  return query
  select pt.token, pt.platform, p.locale,
         case when public.reminder_bypasses_quiet(n) then null
              else public.quiet_until(p.id) end,
         p.id
    from public.push_tokens pt
    join public.profiles p on p.id = pt.user_id
    left join public.notification_prefs np on np.user_id = p.id
   where p.banned_at is null
     and not (n.type = any(coalesce(np.muted_types, '{}')))          -- 分类订阅
     and (
       n.scope = 'all'
       or (n.scope = 'user'  and p.id = n.target_id)
       or (n.scope = 'group' and exists (
             select 1 from public.group_members gm
              where gm.group_id = n.target_id and gm.user_id = p.id
                and gm.status = 'approved'))
     );
end $$;

-- Q5:活动开始前 60 分钟内的实时提醒不受免打扰限制(PRD §5.2)
create or replace function public.reminder_bypasses_quiet(n public.notifications)
returns boolean language sql immutable as $$
  select n.type = 'event_reminder'
     and coalesce((n.payload->>'offset_minutes')::int, 99999) <= 60;
$$;

revoke execute on function public.push_audience(uuid) from public, anon, authenticated;
```

### 5.4 免打扰的顺延实现（关键设计）

一条 `scope='all'` 的通知面向全球所有时区，**无法有单一 `scheduled_at`**。方案：

> push-dispatch 处理时，对每个「命中免打扰」的用户，**克隆一条 `scope='user'`、`channels='{push}'`、`scheduled_at = quiet_until` 的通知**；原通知照常发给其余用户。克隆通知走完全相同的投递路径，零新增代码路径。

```ts
// push-dispatch 内,service_role 直写
await admin.from("notifications").insert(deferred.map(d => ({
  scope: "user", target_id: d.user_id,
  type: n.type, title: n.title, body: n.body,
  event_id: n.event_id,
  payload: { ...n.payload, deferred_from: n.id },
  channels: ["push"],              // ← 仅推送,不进通知中心(原通知已在通知中心)
  scheduled_at: d.quiet_until,
})));
```

这一设计**顺带让 `channels` 死字段活过来**：
- 原通知 `channels = '{inapp,push}'` → 通知中心显示 + 立即推送给非免打扰用户
- 克隆通知 `channels = '{push}'` → 通知中心**不显示**（避免重复条目），到点只发推送
- `push_audience` 开头的 `'push' = any(n.channels)` 保证 `channels` 真正生效

客户端 `myNotificationsProvider` 需相应加过滤：`.contains('channels', ['inapp'])`。

### 5.5 客户端改动

**偏好上云**（`app/lib/features/auth/profile_sync.dart`）：
```dart
// 现有注释「profiles.timezone 暂不同步(推送免打扰在 P2 才用到)」——本次兑现
await client.from('profiles').update({
  'locale': ..., 'font_scale': ..., 'region': ...,
  'timezone': await FlutterTimezone.getLocalTimezone(),   // 新增
}).eq('id', user.id);

await client.from('notification_prefs').upsert({
  'user_id': user.id,
  'quiet_enabled': ..., 'quiet_start': ..., 'quiet_end': ...,
  'muted_types': ...,
}, onConflict: 'user_id');
```

**新增 `app/lib/features/notifications/notification_prefs.dart`**：
- `notificationPrefsProvider`（FutureProvider，读云端；未登录返回本地默认）
- `updateNotificationPrefs({quietEnabled, quietStart, quietEnd, mutedTypes})`
- **一次性迁移**：首次登录时把本地 `almanac_festival_notify` / `almanac_zhai_notify` 两个 prefs 转成 `muted_types`（关闭 → 加入 `almanac` 的对应静音标记）。因两个开关同属 `type='almanac'`、靠 `payload.kind` 区分，`muted_types` 采用 **`almanac:festival` / `almanac:zhai` 的带 kind 形式**；`push_audience` 的过滤条件相应改为同时匹配裸 type 与 `type||':'||payload->>'kind'`。

**设置页**（`settings_screen.dart` L235-250 现「佛历提醒」分组升级为「通知」分组）：
```
通知                                    ← Text(l10n.notifySection)
  免打擾時段              [开关]         ← quiet_enabled
  22:00 – 07:00          [点击改起讫]    ← showTimePicker × 2,quiet_enabled 时才显示
  提示:活動開始前的提醒不受限            ← bodySmall,对应 Q5
  ── 接收以下通知 ──
  活動提醒               [开关]         ← muted_types 含 event_reminder ?
  活動變動               [开关]         ← event_changed
  佛教節日提醒            [开关]         ← almanac:festival(承接现有开关)
  十齋日提醒             [开关]         ← almanac:zhai(承接现有开关)
  學修問答回覆            [开关]         ← qa_reply
```
位置：保持在「地区」之后、「隐私与合规」之前（地区分组注释已写明「决定通知送达方式（PRD §5.1）」，语义相邻）。

**大陆 Android 判据**（`push_service.dart:56-69`）：`getToken()` 抛异常或返回 null 时，调用
```dart
await Supabase.instance.client.from('notification_prefs')
    .upsert({'user_id': uid, 'push_unavailable': true}, onConflict: 'user_id');
```
成功拿到 token 时置回 false。这是 P2.2 邮件兜底的判据来源。

### 5.6 文件清单

| 文件 | 动作 |
|---|---|
| `supabase/migrations/20260808000024_notification_prefs.sql` | 新建 |
| `supabase/functions/push-dispatch/index.ts` | 接 `push_audience` + 免打扰克隆 |
| `app/lib/features/notifications/notification_prefs.dart` | 新建 |
| `app/lib/features/auth/profile_sync.dart` | 加 timezone + prefs 同步 |
| `app/lib/features/settings/settings_screen.dart` | 佛历分组升级为「通知」分组 |
| `app/lib/core/push_service.dart` | FCM 失败标记 `push_unavailable` |
| `app/lib/features/notifications/notifications_providers.dart` | 过滤改读云端 prefs；加 `channels` 含 inapp 条件 |
| `app/lib/core/settings.dart` | 两个佛历本地 prefs 标注为「仅迁移用」 |
| 三份 ARB + `l10n/gen/*` | 新增键（§9.6） |

---

## 6. Step 3 · 活动提醒排程（P2.14）

**目标**：兑现 PRD §5「周六共修预告（提前一天）、周六当天 Webex/YouTube 连接、周三打坐提醒」与 §12.4 的 pg_cron 展开设计。这是 PLAN P2.4 注明「推迟到 P2.1」的欠账。

### 6.1 数据模型 —— migration `20260808000025_event_reminders.sql`

```sql
create table public.event_reminders (
  id             uuid primary key default gen_random_uuid(),
  event_id       uuid not null references public.events(id) on delete cascade,
  offset_minutes int  not null check (offset_minutes >= 0 and offset_minutes <= 10080),
  enabled        boolean not null default true,
  created_at     timestamptz not null default now(),
  unique (event_id, offset_minutes)
);
create index idx_event_reminders_event on public.event_reminders (event_id);

alter table public.event_reminders enable row level security;
create policy event_reminders_select on public.event_reminders for select using (true);
create policy event_reminders_write  on public.event_reminders for all
  using (public.is_app_admin()) with check (public.is_app_admin());

revoke all on public.event_reminders from public, anon, authenticated;
grant select on public.event_reminders to anon, authenticated;
grant insert, update, delete on public.event_reminders to authenticated;
grant all on public.event_reminders to service_role;

-- 幂等键(现表无任何唯一约束,连改 5 次发 5 条正是此因)
create unique index uq_notifications_event_reminder
  on public.notifications (event_id, (payload->>'occurrence_date'), (payload->>'offset_minutes'))
  where type = 'event_reminder';

-- 存量活动补默认提醒(Q1 三档:提前一天 / 提前 30 分钟 / 活动开始时)
insert into public.event_reminders (event_id, offset_minutes)
select e.id, o.m from public.events e cross join (values (1440), (30), (0)) as o(m)
on conflict do nothing;
```

> `uq_notifications_event_reminder` 要求 `notifications.event_id` **被真正写入** —— 顺带激活了死列，`on delete set null` 的外键语义第一次生效。

### 6.2 展开函数（本次最大工作量）

必须与 Dart 的 `occurrence_utils.dart:64-129` **口径完全一致**：
- RRULE 子集：`null`/空 = 单次；含 `FREQ=WEEKLY` = 每周；其余按单次处理
- 每周展开在**活动时区**做日历算术，跨 DST 保持当地墙钟不变
- `occurrence_date` = 该场次在**活动时区**的日期（全球用户一致）
- `event_overrides.patch`：`cancelled=true` 跳过；`start_at` 覆盖实际开始时刻（**但 `occurrence_date` 仍是原定日**，与 Dart 一致）

```sql
create or replace function public.expand_event_reminders(
  p_days int default 14, p_event_id uuid default null
) returns int
language plpgsql security definer set search_path = public as $$
declare
  e           record;
  r           record;
  v_wall      timestamp;      -- 首场在活动时区的墙钟
  v_local     timestamp;      -- 第 i 场的墙钟
  v_utc       timestamptz;
  v_date      date;
  v_patch     jsonb;
  v_start     timestamptz;
  v_remind    timestamptz;
  v_horizon   timestamptz := now() + make_interval(days => p_days);
  v_weekly    boolean;
  i           int;
  n           int := 0;
begin
  for e in select * from public.events
            where (p_event_id is null or id = p_event_id) loop

    -- 关键:先落到活动时区的墙钟,加周后再转回 UTC → 跨 DST 墙钟不变
    v_wall   := e.start_at at time zone e.timezone;
    v_weekly := coalesce(e.recurrence_rule, '') like '%FREQ=WEEKLY%';

    for r in select * from public.event_reminders
              where event_id = e.id and enabled loop
      i := 0;
      loop
        v_local := v_wall + (case when v_weekly then i * interval '7 days'
                                  else interval '0' end);
        v_utc   := v_local at time zone e.timezone;
        exit when v_utc > v_horizon;

        v_date := v_local::date;
        select patch into v_patch from public.event_overrides
         where event_id = e.id and occurrence_date = v_date;

        if coalesce(v_patch->>'cancelled', '') <> 'true' then
          v_start  := coalesce((v_patch->>'start_at')::timestamptz, v_utc);
          -- cron 粒度补偿:push-dispatch-sweep 每分钟跑一次,若 scheduled_at 正好等于
          -- 活动开始时刻,最坏会在开始后 59 秒才被扫到 → 「活动开始了」迟到。
          -- 统一提前 60 秒排程,让提醒落在目标时刻的前一分钟内。
          v_remind := v_start - make_interval(mins => r.offset_minutes) - interval '60 seconds';

          if v_remind > now() then
            insert into public.notifications
              (scope, type, event_id, payload, channels, scheduled_at)
            values ('all', 'event_reminder', e.id,
              jsonb_build_object(
                'event_id',       e.id,
                'occurrence_date', v_date,
                'offset_minutes',  r.offset_minutes,
                'title',           e.title,
                'start_at',        v_start,
                'timezone',        e.timezone,
                'has_webex',       e.webex_url   is not null,
                'has_youtube',     e.youtube_url is not null),
              '{inapp,push}', v_remind)
            on conflict do nothing;          -- 命中 uq_notifications_event_reminder
            n := n + coalesce((select 1 where found), 0);
          end if;
        end if;

        exit when not v_weekly;              -- 单次活动只展开一场
        i := i + 1;
        exit when i > 400;                   -- 保险丝(14 天窗口正常 ≤3 次迭代)
      end loop;
    end loop;
  end loop;
  return n;
end $$;

revoke execute on function public.expand_event_reminders(int, uuid)
  from public, anon, authenticated;
```

> **注意** `v_wall + i*interval '7 days'` 作用在**无时区的 timestamp** 上，再 `at time zone` 转回 —— 这正是 Dart 侧 `tz.TZDateTime(loc, y, m, d + 7*i, h, min)` 的 SQL 等价写法。若写成对 `timestamptz` 直接加 7 天，跨 DST 会漂 1 小时（P2.10 修过同一个坑）。

### 6.3 排程与变更联动

```sql
-- 每日展开(避开佛历 cron 的 16:05 UTC)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'event-reminders-daily') then
      perform cron.unschedule('event-reminders-daily');
    end if;
    perform cron.schedule('event-reminders-daily', '0 15 * * *',
      $job$select public.expand_event_reminders(14)$job$);
  end if;
end $$;
```

**变更联动**（修「事件改期/取消后旧提醒仍会发」）：

```sql
create or replace function public.resync_event_reminders() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_event uuid := coalesce(
  case tg_table_name when 'events' then coalesce(new.id, old.id)
                     else coalesce(new.event_id, old.event_id) end, null);
begin
  -- 先清掉该活动所有未发的提醒,再按最新状态重排
  delete from public.notifications
   where type = 'event_reminder' and event_id = v_event and sent_at is null;
  if tg_op <> 'DELETE' or tg_table_name <> 'events' then
    perform public.expand_event_reminders(14, v_event);
  end if;
  return coalesce(new, old);
end $$;

create trigger trg_resync_reminders_events
  after insert or update or delete on public.events
  for each row execute function public.resync_event_reminders();

create trigger trg_resync_reminders_overrides
  after insert or update or delete on public.event_overrides
  for each row execute function public.resync_event_reminders();

create trigger trg_resync_reminders_prefs
  after insert or update or delete on public.event_reminders
  for each row execute function public.resync_event_reminders();
```

### 6.4 推送文案（`push-dispatch` `renderPush` 新增分支）

| offset | 繁体 title | 繁体 body 模板 | 默认档 |
|---|---|---|---|
| ≥1440（提前一天/两天） | 活動預告 | `{title} · {活动时区当地日期时间}` | ✅ 1440 |
| 60–180 | 活動即將開始 | `{title} · {n} 小時後開始` | — |
| 1–59 | 活動即將開始 | `{title} · {n} 分鐘後開始` | ✅ 30 |
| 0 | 活動開始了 | `{title}`＋有链接时追加「點擊進入」 | ✅ 0 |

简体同结构（`活动预告` / `活动即将开始` / `活动开始了`）。时间按**活动时区**渲染并在墙钟与设备时区不同时由客户端加注（沿用 `event_detail_screen.dart:61-71` 的既有口径）。

### 6.5 客户端改动

**编辑器**（`app/lib/features/events/event_edit.dart`）：在「每週重複」开关下方新增「提醒」区，新建活动默认勾选三档：
```
提醒
  [✓] 提前一天         ← 1440
  [✓] 提前 30 分鐘      ← 30
  [✓] 活動開始時        ← 0
  [ + 新增提醒 ]        ← 弹 Q2 档位选择(0/10/15/30/60/180/1440/2880)
```
保存时对 `event_reminders` 做 diff（新增 insert / 取消 delete）。

**详情页**（`event_detail_screen.dart`）：管理员区之外，为所有用户显示一行只读「已設提醒：提前一天 · 提前 30 分鐘 · 活動開始時」，让用户知道会被提醒（这也是缺陷「日历页无任何提醒状态展示」的答复）。

**providers**（`events_providers.dart`）：新增 `eventRemindersProvider.family(eventId)`；`invalidateEvents` 一并失效。

### 6.6 文件清单

| 文件 | 动作 |
|---|---|
| `supabase/migrations/20260808000025_event_reminders.sql` | 新建 |
| `supabase/functions/push-dispatch/index.ts` | `renderPush` 加 `event_reminder` 分支 |
| `supabase/tests/event_reminders.test.sql` | 新建（§12.1） |
| `app/lib/features/events/event_edit.dart` | 提醒编辑区 |
| `app/lib/features/events/event_detail_screen.dart` | 只读提醒展示 |
| `app/lib/features/events/events_providers.dart` | `eventRemindersProvider` |
| `app/lib/features/notifications/notifications_screen.dart` | `event_reminder` 渲染 + 图标 + 深链 |
| `admin/src/app/(admin)/events/page.tsx` | 后台同步支持提醒编辑 |
| `admin/src/lib/database.types.ts` | `npm run gen:types` 重生成 |
| 三份 ARB + `l10n/gen/*` | 新增键（§9.6） |

---

## 7. Step 4 · 变更通知降噪（P2.15）

**目标**：活动提醒上线后通知量翻倍，必须同期把「管理员一改活动全站被轰炸」压下去。

### 7.1 防抖聚合 —— migration `20260808000026_event_notify_denoise.sql`

```sql
create or replace function public.notify_event_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_action text; v_title text; v_event uuid; v_pending uuid;
begin
  if tg_op = 'INSERT' then      v_action := 'created'; v_title := new.title;
  elsif tg_op = 'DELETE' then   v_action := 'deleted'; v_title := old.title;
  else
    if (new.title, new.start_at, new.duration_minutes, new.recurrence_rule,
        new.webex_url, new.youtube_url, new.content, new.event_type_id, new.timezone)
       is not distinct from
       (old.title, old.start_at, old.duration_minutes, old.recurrence_rule,
        old.webex_url, old.youtube_url, old.content, old.event_type_id, old.timezone)
    then return new; end if;
    v_action := 'updated'; v_title := new.title;
  end if;
  v_event := coalesce(new.id, old.id);

  -- 管理员可选「本次不通知」(§7.4);会话变量只能由 definer RPC 设置,客户端无法伪造
  if coalesce(current_setting('app.suppress_event_notify', true), '') = 'on' then
    return coalesce(new, old);
  end if;

  -- created / deleted 立即发;updated 类走 5 分钟防抖窗口,窗口内重复编辑只更新同一条
  if v_action = 'updated' then
    select id into v_pending from public.notifications
     where type = 'event_changed' and event_id = v_event and sent_at is null
     limit 1;
    if v_pending is not null then
      update public.notifications
         set payload = payload || jsonb_build_object('action', v_action, 'title', v_title),
             scheduled_at = now() + interval '5 minutes'
       where id = v_pending;
      return coalesce(new, old);
    end if;
  end if;

  insert into public.notifications (scope, type, event_id, payload, channels, scheduled_at)
  values ('all', 'event_changed', v_event,
          jsonb_build_object('action', v_action, 'title', v_title, 'event_id', v_event),
          '{inapp,push}',
          case when v_action = 'updated' then now() + interval '5 minutes' end);
  return coalesce(new, old);
end $$;
```

同样改写 `notify_override_change()`（写入 `event_id` 列、`channels='{inapp,push}'`、`occurrence_*` 走防抖）。

### 7.2 补「恢复」通知（修缺陷 F）

```sql
-- 现有触发器只挂 after insert or update;删除 override = 撤销取消/改期,用户却收不到
create or replace function public.notify_override_delete() returns trigger ... 
  -- action = 'occurrence_restored'
create trigger trg_notify_override_delete
  after delete on public.event_overrides
  for each row execute function public.notify_override_delete();
```
客户端与 push-dispatch 均新增 `occurrence_restored` 文案（繁「單次恢復」/ 简「单次恢复」）。

### 7.3 通知栏折叠

| 通道 | 字段 | 值 |
|---|---|---|
| APNs | `apns-collapse-id` header | `evt:<event_id>`（uuid 36 字节，上限 64 OK） |
| APNs | `apns-expiration` header | `event_reminder` 取该场活动开始时刻；其余取 `now + 24h` |
| FCM | `message.android.collapse_key` | 同 `evt:<event_id>` |

同一活动的连续变更在通知栏折叠成一条；也顺带兜住 §4.3 重试可能造成的重复推送。

### 7.4 管理员「本次不通知全体」（Q8）

触发器无法感知 UI 意图，走 definer RPC 设置会话变量：

```sql
create or replace function public.admin_save_event(p_event jsonb, p_notify boolean default true)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_app_admin() then
    raise exception '仅管理员可编辑活动' using errcode = '42501';
  end if;
  if not p_notify then perform set_config('app.suppress_event_notify', 'on', true); end if;
  ...  -- insert 或 update events,返回 id
  return v_id;
end $$;
revoke execute on function public.admin_save_event(jsonb, boolean) from public, anon;
grant  execute on function public.admin_save_event(jsonb, boolean) to authenticated;
```

客户端 `event_edit.dart` 的 insert/update 改调此 RPC，表单底部加 `SwitchListTile`「通知所有人」（默认开）。后台 `admin/src/app/(admin)/events/page.tsx` 同步。

> 此子项（P2.15-4）可**独立推迟**：防抖 + 折叠 + 恢复通知三项已覆盖大部分噪音，不做它其余仍成立。

### 7.5 文件清单

| 文件 | 动作 |
|---|---|
| `supabase/migrations/20260808000026_event_notify_denoise.sql` | 新建 |
| `supabase/functions/push-dispatch/index.ts` | collapse/expiration header + `occurrence_restored` 文案 |
| `app/lib/features/events/event_edit.dart` | 改调 `admin_save_event` + 「通知所有人」开关 |
| `app/lib/features/notifications/notifications_screen.dart` | `occurrence_restored` 渲染 |
| `admin/src/app/(admin)/events/page.tsx` | 同步 RPC 与开关 |
| 三份 ARB + `l10n/gen/*` | `actOccRestored` 等 |

---

## 8. Step 5 · 推送深链闭环（P2.16）

**目标**：点「共修快开始了」的推送，直达该场活动详情。三处必须一起改，缺一不可。

### 8.1 可 URL 化的活动详情路由

现状 `/calendar/event` 只吃 `extra: Occurrence`（不可序列化），无法从推送表达。

```dart
// app/lib/router.dart 新增(保留原 extra 快路径,列表点击零加载)
GoRoute(
  path: '/calendar/event/:eventId',
  builder: (context, state) => EventDetailScreen(
    eventId: state.pathParameters['eventId'],
    dateKey: state.uri.queryParameters['date'],   // occurrence_date,yyyy-MM-dd
  ),
),
```

`EventDetailScreen` 改为：`occ != null` 用快路径；否则 watch `eventsProvider` + `eventOverridesProvider` → `expandOccurrences` 在 `dateKey` 前后 ±1 天的窄区间展开 → 匹配构造 `Occurrence`；加载中出 `SkeletonList`，找不到出既有空态。

### 8.2 route 对照表（服务端 `renderPush` 与客户端 `notifications_screen` 必须一致）

| type | route |
|---|---|
| `event_reminder` | `/calendar/event/{payload.event_id}?date={payload.occurrence_date}` |
| `event_changed`（含 occurrence_*） | 同上；无 `occurrence_date` 时退化为 `/calendar/event/{event_id}` |
| `almanac` | `/calendar` |
| `live_started` | `/live` |
| `qa_reply` | `/study-qa/{payload.thread_id}` |
| `qa_question` | `/study-qa/{payload.thread_id}?as=admin` |
| `announcement` | `/groups/{target_id}` |
| `proxy_log` | `/dashboard` |
| `general` / 未知 | `/notifications` |

> 跨语言无法共享常量，两端改动必须成对。测试用例 T-E2E-07 逐条核对。

### 8.3 报文承载

```ts
// APNs:route 与 aps 同级
{ aps: { alert: {title, body}, sound: "default", "thread-id": `evt:${eventId}` }, route }
// FCM v1
{ message: { token, notification: {title, body},
             data: { route },
             android: { priority: "high", collapse_key: `evt:${eventId}` } } }
```

### 8.4 客户端消费（现在完全缺失）

| 场景 | 实现位置 |
|---|---|
| Android 后台点击 | `push_service.dart` 加 `FirebaseMessaging.onMessageOpenedApp.listen(...)` |
| Android 冷启动 | `FirebaseMessaging.instance.getInitialMessage()` |
| iOS 点击（前台/后台/冷启动） | `AppDelegate.swift` 实现 `userNotificationCenter(_:didReceive:withCompletionHandler:)` → MethodChannel `onNotificationTap` → Dart |
| 前台横幅（本地通知镜像）点击 | `reminder_scheduler.dart` 的 `initialize()` 补 `onDidReceiveNotificationResponse`；`_showForegroundNotification` 把 route 写进 `payload` |

**冷启动时序**：router 未 ready 时先存 `pendingRoute`，由 `HomeScreen` 首帧后消费。
**未登录**：route 指向账号类页面（`/dashboard`、`/study-qa/*`、`/groups/*`）时改跳 `/auth`（router 无守卫，需在跳转前判断）。
**通知 id 冲突**：前台镜像现用 `message.hashCode`，可能撞进正念提醒保留区 `[900000, 901100)`。改为 `800000 + (hash.abs() % 1000)`。

### 8.5 文件清单

| 文件 | 动作 |
|---|---|
| `app/lib/router.dart` | 新增 `/calendar/event/:eventId` |
| `app/lib/features/events/event_detail_screen.dart` | 支持 (eventId, dateKey) 自加载 |
| `app/lib/core/push_service.dart` | 点击消费 + pendingRoute + 通知 id 区间 |
| `app/lib/features/reminders/reminder_scheduler.dart` | `onDidReceiveNotificationResponse` |
| `app/ios/Runner/AppDelegate.swift` | `didReceive` → MethodChannel |
| `app/lib/features/home/home_screen.dart` | 首帧消费 pendingRoute |
| `app/lib/features/notifications/notifications_screen.dart` | onTap 改用同一张 route 表 |
| `supabase/functions/push-dispatch/index.ts` | 报文加 route/thread-id |

---

## 9. Step 6 · 通知中心与数据治理（P2.17）

### 9.1 通知中心（`notifications_providers.dart` / `notifications_screen.dart`）

| 项 | 现状 | 改为 |
|---|---|---|
| 分页 | 硬 `limit(50)` | `AsyncNotifier` + 游标（`created_at < last`），每页 30，触底加载 |
| 时效 | 无 Realtime 无轮询 | 订阅 `notifications` insert（RLS 生效）→ invalidate 红点。⚠️ 需确认 `supabase_realtime` publication 含该表（参考 migration 0009 的做法） |
| 已读（Q7） | 进页面全标已读 | 点击单条标已读 + AppBar「全部已讀」按钮 |
| 时间显示 | `substring(0,16)` 裸 UTC | 本地时区格式化（`intl`） |
| 过滤 | 本地 prefs 过滤佛历 | 读云端 `muted_types`；并加 `channels` 含 `inapp` 条件（排除 §5.4 的克隆行） |

### 9.2 Retention 与索引 —— migration `20260808000027_notifications_retention.sql`

```sql
create or replace function public.purge_old_notifications(p_days int default 180)
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  delete from public.notifications
   where created_at < now() - make_interval(days => p_days);   -- reads 级联
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.purge_old_notifications(int) from public, anon, authenticated;

-- 每日 17:00 UTC(避开 almanac 16:05 与 event-reminders 15:00)
perform cron.schedule('notifications-retention', '0 17 * * *',
  $job$select public.purge_old_notifications(180)$job$);

create index idx_notification_reads_user on public.notification_reads (user_id);
comment on column public.push_tokens.fcm_failed is
  '已废弃(2026-08):大陆机拿不到 token 即无行可标,判据改用 notification_prefs.push_unavailable';
```

### 9.3 后台看板（`admin/src/app/(admin)/dashboard/page.tsx`）

| 卡片 | 现状 | 改为 |
|---|---|---|
| 推送健康 | `fcm_failed` 率（恒 0） | `notification_prefs.push_unavailable` 计数 |
| 通知积压 | `scheduled_at` 到点未 `sent_at` | 同左，但排除 `failed_at is not null`；新增「终局失败」计数与 `last_error` 明细 |
| 新增 | — | 「近 24h 投递结果」：ok / invalid / failed 汇总（从 `last_error` 摘要解析或加轻量计数列） |

`admin/src/app/(admin)/notifications/page.tsx` 的状态判定（现 `page.tsx:52-54` 靠两个时间戳推导）改为读 `failed_at` / `attempts` / `last_error` 真实状态。

### 9.4 死字段清理

- `channels`：已在 §5.3/§5.4 生效，无需再动
- `notifications.event_id`：已在 §6.1/§7.1 写入，无需再动
- `push_tokens.fcm_failed`：按 Q10 保留 + comment 标废弃

### 9.5 为 P2.2 邮件兜底铺路（本次不实现）

改造完成后，`email-fallback` 所需的前置全部就绪：
- 判据：`notification_prefs.push_unavailable = true` 或 `profiles.region = 'cn'`
- 分渠道：`channels` 含 `email` 的通知才发邮件（字段已生效）
- 触发点：`complete_notification` 内可级联，或独立 cron 扫 `channels && '{email}'` 且 `sent_at` 已置位的行

### 9.6 l10n 新增键清单（三份 ARB + `flutter gen-l10n` 重生成并提交）

```
notifySection, notifyQuietTitle, notifyQuietHint, notifyQuietStart, notifyQuietEnd,
notifySubscribeHeader, notifyTypeEventReminder, notifyTypeEventChanged,
notifyTypeQaReply, notifyMarkAllRead,
notifEventReminderEve, notifEventReminderSoon, notifEventReminderNow,
reminderSectionTitle, reminderAddButton, reminderOffsetAtStart, reminderOffsetMinutes,
reminderOffsetHours, reminderOffsetOneDay, reminderOffsetTwoDays, reminderListLabel,
actOccRestored, notifyOnChangeSwitch
```
（沿用现有惯例：扁平 camelCase、按域前缀分簇、带占位符的补 `@key.placeholders`。）

### 9.7 文件清单

| 文件 | 动作 |
|---|---|
| `supabase/migrations/20260808000027_notifications_retention.sql` | 新建 |
| `app/lib/features/notifications/notifications_providers.dart` | 分页 + Realtime + 过滤 |
| `app/lib/features/notifications/notifications_screen.dart` | 单条已读 + 全部已读 + 本地时间 |
| `admin/src/app/(admin)/dashboard/page.tsx` | 看板指标 |
| `admin/src/app/(admin)/notifications/page.tsx` | 真实状态 |
| 三份 ARB + `l10n/gen/*` | §9.6 |

---

## 10. 对 PRD / PLAN 的影响（实施第一步，随 P2.12 一并落地）

### 10.1 PRD（升 **v0.5.21**，顶部 blockquote 加一行摘要）

| 章节 | 改动 |
|---|---|
| §5 | 「通知类型」条补充：活动提醒由 `event_reminders` 配置，**默认三档 = 提前一天 / 提前 30 分钟 / 活动开始时**（Q1/Q2，三档依据见设计文档 §2）；「分类订阅」条细化为 `notification_prefs.muted_types` 语义（Q6）；新增「管理员编辑活动可选本次不通知全体」（Q8） |
| §5.1 | 大陆用户判据由 `push_tokens.fcm_failed` 改为 `notification_prefs.push_unavailable`（Q10） |
| §5.2 | 免打扰落地细则：默认开、22:00–07:00、用户可改；放行判据 = `event_reminder` 且 `offset_minutes ≤ 60`（Q5）；佛历两开关从纯客户端改为上云 |
| §5.3 | 已排程通知列表补「终局失败」状态 |
| §5.4（新增） | **通知中心与投递可靠性**：已读语义（Q7）、分页、Realtime 红点、retention 180 天（Q9）、投递重试与失败可见 |
| §12.2 | 数据模型表新增 `notification_prefs`、`event_reminders`；`notifications` 补 `claimed_at/attempts/failed_at/last_error` |
| §12.3 | RLS 表补两张新表 |
| §12.4 | pg_cron 段补 `event-reminders-daily`、`notifications-retention`；`push-dispatch` 职责更新 |
| §14 | 已定案决策补：活动提醒全站发送（Q3）、重试粒度为通知级而非 token 级（§4.3 取舍） |
| §15.2 | 看板指标更新（§9.3） |

### 10.2 PLAN

- §1 总览：**P2 进度 6/12 → 6/18**，备注补「P2.12–P2.17 通知系统改造 2026-08-08 新增，设计见 `design/notification-overhaul.md`」
- §5 P2 章节：追加 P2.12 – P2.17 六条任务（含子任务与验收）
- §5 P2.4 的「推迟到 P2.1」备注：改为「已转 P2.14 兑现」
- §7 阻塞登记：新增三条 P0 缺陷记录（A/B/C，均标「本次改造修复」）
- §8 无需改动
- 顶部「最后更新」日期刷新

---

## 11. 实施清单（执行跟踪；完成即勾选，并同步 PLAN §1 计数）

> **当前进度（2026-08-08）**：A–G 七组代码全部完成并验证；**服务端已发布生产**
> （migration 0023–0027 推送并记账，记账数 22→27；push-dispatch 容器已 `--force-recreate`
> 重建，鉴权 405/403/403、`invoke_push_dispatch` 外呼 200 均验证通过）。
> 自动化底线全绿：`npx supabase test db` **198**（原 124 + 本次 74）· `flutter analyze` **0 issue**
> · `flutter test` **194**（原 161 + 本次 33）· admin `lint` + `build`（14 路由）。
> 剩余：H-4 App UI 端到端走查、H-6 真机矩阵 + 生产冒烟（§12.4/§12.5/§12.6）。
>
> **生产发布记录（2026-08-08）**：发布前打了快照 `~/pre-notification-overhaul-20260808-2357.dump`
> （1.3M，`pg_restore -l` 校验可读）—— ⚠️ 发现生产的每日定时备份**从未运行**（`pt-backup.sh`
> 在但 crontab 为空），属 PLAN P0.4 未竟项，需尽快补。旧函数备份在
> `~/push-dispatch-old-20260809-0023.ts`。发布后核对：5 个 cron job、Realtime publication
> 含 notifications、anon 读 `notification_prefs` 为 401、25 个存量活动补齐 75 行提醒档位、
> 生成 24 条未来提醒且**无一条会立即投递**（不会惊动用户）。

### A. 文档与计划（P2.12-0）
- [x] A-1 PRD 升 v0.5.21，按 §10.1 逐章改
- [x] A-2 PLAN 追加 P2.12–P2.17、更新 §1 计数、§7 登记三条缺陷
- [x] A-3 开 feature 分支 `feature/p2-12-notification-overhaul`

### B. P2.12 投递管道加固
- [x] B-1 migration 0023：四个新列 + `idx_notifications_pending`
- [x] B-2 RPC `claim_notifications` / `complete_notification`（含 revoke）
- [x] B-3 语句级触发器改「仅已到点行才外呼」（转换表写法）
- [x] B-4 `push-dispatch` 重写：鉴权强制 + POST-only + RPC 抢占 + 并发 20 + 全流程 try/catch + 结果回写
- [x] B-5 `supabase/functions/.env.example` 补 `DISPATCH_SECRET` 开发值
- [x] B-6 pgTAP `push.test.sql` 扩充至 §12.1 清单
- [x] B-7 `deploy-aws-ec2.md` §11 补函数重建与新排查项

### C. P2.13 免打扰与偏好上云
- [x] C-1 migration 0024：`notification_prefs` 表 + RLS + **显式 revoke**（0016 教训）
- [x] C-2 `quiet_until()` / `reminder_bypasses_quiet()` / `push_audience()` 三个函数
- [x] C-3 `push-dispatch` 接 `push_audience` + 免打扰克隆（`channels='{push}'`）
- [x] C-4 `profile_sync.dart` 同步 timezone + prefs
- [x] C-5 `notification_prefs.dart` provider + 本地佛历开关一次性迁移
- [x] C-6 设置页「通知」分组（免打扰起讫 + 5 个分类开关）
- [x] C-7 `push_service.dart` FCM 失败置 `push_unavailable`
- [x] C-8 `notifications_providers.dart` 过滤改云端 + `channels` 含 inapp
- [x] C-9 pgTAP `notification_prefs.test.sql`

### D. P2.14 活动提醒排程
- [x] D-1 migration 0025：`event_reminders` 表 + RLS + revoke + 幂等唯一索引 + 存量补默认
- [x] D-2 `expand_event_reminders()`（活动时区墙钟算术，与 Dart 口径对齐）
- [x] D-3 cron `event-reminders-daily` + `resync_event_reminders()` 三个联动触发器
- [x] D-4 `push-dispatch` `renderPush` 加 `event_reminder` 四档文案（简繁）
- [x] D-5 编辑器提醒区（增删档位）+ 详情页只读展示 + `eventRemindersProvider`
- [x] D-6 通知中心 `event_reminder` 渲染 + 图标
- [x] D-7 后台 events 页支持提醒编辑 + `gen:types`
- [x] D-8 pgTAP `event_reminders.test.sql`（含 DST 与 Dart 口径对齐用例）

### E. P2.15 变更通知降噪
- [x] E-1 migration 0026：`notify_event_change` 防抖重写 + `notify_override_change` 同步 + `event_id` 写入
- [x] E-2 `notify_override_delete()` + 触发器（`occurrence_restored`）
- [x] E-3 `push-dispatch` collapse-id / expiration / thread-id
- [x] E-4 `admin_save_event(jsonb, boolean)` RPC + 编辑器「通知所有人」开关 + 后台同步（**可独立推迟**）
- [x] E-5 客户端 `occurrence_restored` 文案
- [x] E-6 pgTAP 降噪用例并入 `rls.test.sql` 或新建

### F. P2.16 推送深链闭环
- [x] F-1 router 新增 `/calendar/event/:eventId?date=`
- [x] F-2 `EventDetailScreen` 支持 (eventId, dateKey) 自加载 + 骨架/空态
- [x] F-3 `push-dispatch` 报文加 `route`（按 §8.2 对照表）
- [x] F-4 `push_service.dart`：`onMessageOpenedApp` + `getInitialMessage` + pendingRoute + 通知 id 改区间
- [x] F-5 `AppDelegate.swift` `didReceive` → MethodChannel `onNotificationTap`
- [x] F-6 `reminder_scheduler.dart` `onDidReceiveNotificationResponse`
- [x] F-7 `notifications_screen.dart` onTap 改用同一张 route 表
- [x] F-8 未登录 route 降级到 `/auth`

### G. P2.17 通知中心与治理
- [x] G-1 通知中心游标分页（每页 30，触底加载）
- [x] G-2 Realtime 订阅红点（先确认 publication 含 `notifications`）
- [x] G-3 已读语义改单条 + 「全部已讀」按钮
- [x] G-4 时间本地时区格式化
- [x] G-5 migration 0027：`purge_old_notifications` + cron + `idx_notification_reads_user` + `fcm_failed` comment
- [x] G-6 后台看板与通知页状态指标更新
- [x] G-7 l10n 三份 ARB + `flutter gen-l10n` 重生成并提交

### H. 收尾
- [x] H-1 `flutter analyze` 0 issue + `flutter test` 全绿
- [x] H-2 `npx supabase test db` 全绿
- [x] H-3 admin `npm run lint && npm run build` 全绿
- [ ] H-4 §12.4 本地栈端到端手工联测通过
- [x] H-5 生产发布（migration 0023–0027 已推并记账 2026-08-08；push-dispatch 已重建部署并验证；admin 站已重发布 2026-08-09,14 路由全 200）
- [ ] H-6 §12.5 真机矩阵 + §12.6 生产冒烟
- [x] H-7 PLAN 勾选 + §1 计数刷新 + 本文档 §11/§12 全勾

---

## 12. 测试计划（跟踪清单）

> 本地栈 seed 账号（密码均 `test1234`）：`admin@test.local`（管理员，`…0001`）、`owner@test.local`（`…0002`）、`member@test.local`（B，`…0003`）、`user@test.local`（A，`…0004`）。测试群 `TESTGRP2`。
> pgTAP 惯例：文件内单事务 + `rollback`，`xx_login(uid)` 切身份；`now()` 在事务内恒定，「时间前进」类断言用预置时间戳。
> ⚠️ seed 的 2 条 events 会经触发器产生 2 条 `event_changed` 通知，测试基线**不为空**。

### 12.1 pgTAP（`npx supabase test db` 必须全绿）

**投递管道 —— `supabase/tests/push.test.sql` 扩充（P2.12）**
- [x] T-DB-01 `claim_notifications` 只抢 `sent_at is null and failed_at is null` 且已到点的行
- [x] T-DB-02 **缺陷 A 回归**：`created_at` 为 3 天前、`scheduled_at = now()-1min` 的行**能**被抢到（改造前抢不到）
- [x] T-DB-03 到点超过 6 小时的行不再被抢（防雪崩上限生效）
- [x] T-DB-04 租约：抢占后 1 分钟内不可重抢；模拟 `claimed_at = now()-3min` 后可重抢且 `attempts` 递增
- [x] T-DB-05 `complete_notification(ok>0)` → `sent_at` 置位、`claimed_at` 清空、`last_error` 有摘要
- [x] T-DB-06 `complete_notification(ok=0, failed>0)` → `claimed_at` 释放、`sent_at` 仍空；`attempts=5` 时置 `failed_at`
- [x] T-DB-07 语句级触发器：插未来 `scheduled_at` 行**不**外呼；插已到点行外呼（`lives_ok` + `net._http_response` 断言或 url 空时静默）
- [x] T-DB-08 `claim_notifications` / `complete_notification` 对 anon/authenticated 无 execute 权限
- [x] T-DB-09 既有 9 项断言全部保留通过

**通知偏好 —— `supabase/tests/notification_prefs.test.sql`（P2.13）**
- [x] T-DB-10 RLS：A 只能读写自己的 prefs；B 读 A 的为 0 行；管理员可读
- [x] T-DB-11 anon 对 `notification_prefs` 无任何权限（显式 revoke 生效，非「空结果」）
- [x] T-DB-12 `quiet_until`：用户 tz=`Asia/Shanghai`、当地 23:30 → 返回次日 07:00 的 UTC 时刻；当地 12:00 → null
- [x] T-DB-13 `quiet_until`：跨午夜与同日窗口（如 01:00–06:00）两种配置各自正确
- [x] T-DB-14 `quiet_enabled=false` → 恒 null
- [x] T-DB-15 `push_audience`：`channels` 不含 `push` 的通知返回 0 行（**channels 死字段复活**）
- [x] T-DB-16 `push_audience`：`muted_types` 含该 type 的用户被过滤；`almanac:festival` 与 `almanac:zhai` 分别独立生效
- [x] T-DB-17 `push_audience`：`banned_at` 非空的用户被过滤
- [x] T-DB-18 `push_audience`：scope=group 只返回 `status='approved'` 成员
- [x] T-DB-19 `reminder_bypasses_quiet`：`offset_minutes=0/60` 为 true，`1440` 为 false，非 `event_reminder` 恒 false

**活动提醒 —— `supabase/tests/event_reminders.test.sql`（P2.14）**
- [x] T-DB-20 单次活动 + 1440 提醒 → 恰好 1 条 `event_reminder`，`scheduled_at = start_at - 1 天 - 60 秒`（含 cron 粒度补偿）
- [x] T-DB-21 每周活动 14 天窗口 → 2 条（每周一场），`occurrence_date` 为**活动时区**日期
- [x] T-DB-22 **幂等**：连跑 3 次 `expand_event_reminders` 通知数不变（唯一索引生效）
- [x] T-DB-23 **DST 口径**：`America/Los_Angeles` 的每周活动跨 3 月夏令时切换，各场次的活动时区墙钟不变（与 `occurrence_tz_test.dart` 同一组期望值）
- [x] T-DB-24 override `cancelled=true` 的场次不生成提醒
- [x] T-DB-25 override `start_at` 改期 → 提醒时刻跟随新时刻，`occurrence_date` 仍为原定日
- [x] T-DB-26 `remind_at <= now()` 的场次不生成（不补过去）
- [x] T-DB-27 改活动 `start_at` → 旧未发提醒被删、按新时刻重建；已发的（`sent_at` 非空）不动
- [x] T-DB-28 删活动 → 未发提醒随之消失（触发器 + FK cascade）
- [x] T-DB-29 `enabled=false` 的 reminder 不生成；删 reminder 行 → 对应未发通知消失
- [x] T-DB-30 `event_reminders` RLS：匿名可读、非管理员写被拒、管理员写通过
- [x] T-DB-31 `notifications.event_id` 被真实写入（死列复活）
- [x] T-DB-32 cron `event-reminders-daily` 已注册
- [x] T-DB-33 **默认三档**：新建活动后 `event_reminders` 恰好 3 行（1440 / 30 / 0）；migration 对存量活动补齐同样三行
- [x] T-DB-34 **cron 粒度补偿**：`offset_minutes=0` 的提醒 `scheduled_at = start_at - 60 秒`（不是 `= start_at`）；30 档为 `start_at - 30 分 - 60 秒`

**降噪 —— 并入 `rls.test.sql` 或新建（P2.15）**
- [x] T-DB-35 连续 3 次 update 同一活动 → 只有 1 条未发 `event_changed`（防抖聚合）
- [x] T-DB-36 `created` / `deleted` 立即发（`scheduled_at is null`）；`updated` 有 5 分钟 `scheduled_at`
- [x] T-DB-37 删除 override → 产生 `occurrence_restored` 通知（**缺陷 F 回归**）
- [x] T-DB-38 `admin_save_event(p_notify:=false)` → 不产生 `event_changed`；`true` → 产生
- [x] T-DB-39 非管理员调 `admin_save_event` 抛 42501
- [x] T-DB-40 既有 49 项 `rls.test.sql` 断言全部保留通过

**治理（P2.17）**
- [x] T-DB-41 `purge_old_notifications(180)` 删除 181 天前的行且级联清 `notification_reads`；180 天内保留
- [x] T-DB-42 cron `notifications-retention` 已注册；`idx_notification_reads_user` 存在

### 12.2 Edge Function（本地栈手工，`supabase/functions/` 无 Deno 测试基建）

> 前置：`npx supabase stop && npx supabase start`（新增/改动函数须重载）；`supabase/functions/.env` 配 `DISPATCH_SECRET`。

- [x] T-FN-01 无 `x-dispatch-key` header → 403；GET 方法 → 405
- [x] T-FN-02 `DISPATCH_SECRET` 未配置时函数返回 500 并记日志（不再静默放行）
- [x] T-FN-03 插一条 `channels='{inapp}'`（不含 push）的通知 → `push_audience` 0 行，`sent_at` 仍置位，无推送
- [x] T-FN-04 免打扰：把测试账号 tz 设为当前处于 22:00–07:00 的时区 → 原通知 `sent_at` 置位，且产生一条 `scope='user' channels='{push}'` 的克隆行，`scheduled_at` 正确
- [x] T-FN-05 克隆行插入**不**触发外呼递归（转换表触发器条件生效）
- [ ] T-FN-06 制造 APNs/FCM 全失败（改 topic 为错值）→ `sent_at` 仍空、`claimed_at` 释放、`attempts` 递增、`last_error` 有内容；重复 5 次后 `failed_at` 置位
- [ ] T-FN-07 报文抓包/日志确认含 `route`、`apns-collapse-id`、`apns-expiration`（FCM 侧 `data.route`、`collapse_key`）
- [ ] T-FN-08 50 条通知 × 多 token 并发发送不超时（观察函数耗时）

### 12.3 Flutter 自动化（`flutter analyze` 0 issue + `flutter test` 全绿）

- [x] T-APP-01 `notification_prefs` 纯逻辑：本地佛历开关 → `muted_types` 迁移映射正确（含两开关四种组合）
- [x] T-APP-02 route 对照表纯函数：按 §8.2 逐 type 断言（与服务端表逐条对齐）
- [x] T-APP-03 提醒档位纯函数：`offset_minutes` → 本地化标签（0/15/30/60/180/1440/2880，简繁各一遍）
- [ ] T-APP-04 通知中心分页：游标拼接正确、触底加载追加、无重复行
- [x] T-APP-05 通知中心已读：点击单条只标该条；「全部已讀」标全部；红点数随之变化
- [x] T-APP-06 通知中心过滤：`muted_types` 命中的行不显示且不计红点；`channels` 不含 inapp 的行不显示
- [x] T-APP-07 `event_reminder` 渲染：四档文案 + 图标；副标题含活动名与时间
- [x] T-APP-08 `occurrence_restored` 渲染
- [x] T-APP-09 `EventDetailScreen` 从 (eventId, dateKey) 加载：命中出详情、未命中出空态、加载中出骨架
- [ ] T-APP-10 编辑器提醒区：默认三档回显、增删档位、保存时 diff 正确
- [ ] T-APP-11 设置页「通知」分组 widget 测：免打扰开关联动起讫行显隐
- [x] T-APP-12 `layout_walkthrough_test` 加设置页通知分组 + 通知中心 + 活动详情，**简繁 × 字号 2.0 不溢出**
- [x] T-APP-13 既有 161 项测试全部保留通过

### 12.4 本地栈端到端手工联测（四账号，改造完成后一次跑通）

- [ ] T-E2E-01 **活动提醒主链路**：管理员建「周六共修」每周活动（默认提醒 1440 / 30 / 0 三档）→ 查 `notifications` 出现三批 `event_reminder` 且 `scheduled_at` 正确（含 60 秒补偿）→ 手工把某条 `scheduled_at` 改到 `now()` → 通知中心与推送同时到达；三档文案分别为「活動預告 / 30 分鐘後開始 / 活動開始了」
- [ ] T-E2E-02 **提醒改期联动**：把活动改到次日 → 旧未发提醒消失、新提醒按新时刻生成
- [ ] T-E2E-03 **单次取消联动**：取消某场 → 该场提醒消失；删除该 override → 提醒回来 + 收到「單次恢復」通知
- [ ] T-E2E-04 **降噪**：连续改 3 次活动标题 → 通知中心只多 1 条；勾掉「通知所有人」再改 → 无新通知
- [ ] T-E2E-05 **免打扰**：把 A 的 tz 设为当前处于 22:00–07:00 的时区 → 发一条 `almanac` → A 通知中心立即可见但**无推送**，克隆行 `scheduled_at` 为其本地 07:00；把 `offset_minutes=0` 的活动提醒发给 A → **放行推送**（Q5）
- [ ] T-E2E-06 **分类订阅**：A 关「活動變動」→ 管理员改活动 → A 通知中心无该条、红点不变、无推送；B 正常收到
- [ ] T-E2E-07 **深链逐条**：按 §8.2 对照表，每种 type 各发一条，点通知与点通知中心条目，落地页一致且正确（9 条）
- [ ] T-E2E-08 **重试**：停掉外网让 APNs 不可达 → 观察 `attempts` 递增、`sent_at` 保持空；恢复后自动补发
- [ ] T-E2E-09 **定时通知回归（缺陷 A）**：管理员发一条 48 小时后的定时通知 → 手工把 `scheduled_at` 调到 `now()` → **能发出**（改造前永久卡死）
- [ ] T-E2E-10 **未登录深链**：登出后点一条指向 `/dashboard` 的通知 → 落 `/auth`
- [ ] T-E2E-11 **通知中心**：>30 条时触底加载、Realtime 红点在 App 前台自动变化、时间显示为本地时区
- [ ] T-E2E-12 **偏好上云**：A 在设备 1 改免打扰 → 设备 2 登录后一致

### 12.5 真机矩阵（需用户设备；可与 P2.1-4 iOS TestFlight 验证同批做）

- [ ] T-DEV-01 iOS（海外网络）：收到活动提醒推送 → 点击直达该场活动详情
- [ ] T-DEV-02 iOS（大陆网络）：同上（APNs 大陆可用）
- [ ] T-DEV-03 海外 Android：FCM 推送 + 深链
- [ ] T-DEV-04 大陆 Android：**无系统推送**，但 `notification_prefs.push_unavailable` 被置 true，通知中心内容完整（PRD §5.1 的刚需路径）
- [ ] T-DEV-05 免打扰真机：设备时间调到 23:00 → 佛历通知不弹、次日 07:00 后弹（**缺陷 C 回归**）
- [ ] T-DEV-06 折叠：连续触发同一活动的多条变更 → 通知栏只见一条
- [ ] T-DEV-07 冷启动深链：杀进程后点推送 → 正确落地（pendingRoute 生效）
- [ ] T-DEV-08 正念提醒不受影响（通知 id 区间隔离，`[900000,901100)` 未被侵占）

### 12.6 生产冒烟（发布后）

- [ ] T-PROD-01 migration 0023–0027 已推生产并记入 `_applied_migrations`
- [ ] T-PROD-02 三个新 cron job 在生产 `cron.job` 中存在且按时执行（查 `cron.job_run_details`）
- [ ] T-PROD-03 `push-dispatch` 容器重建后，`select invoke_push_dispatch();` 返回 200（密钥校验通过）
- [ ] T-PROD-04 anon REST 读 `notification_prefs` / 调 `claim_notifications` 均 401/403（**0016 教训回归**）
- [ ] T-PROD-05 线上发一条测试通知 → 真机收到 + 后台看板状态正确
- [ ] T-PROD-06 线上建一个明天的活动 → 次日 15:00 UTC cron 后 `event_reminder` 正确生成
- [ ] T-PROD-07 admin 站重发布后所有路由 200，通知页显示新状态字段

---

## 13. 风险、回滚与已知取舍

| # | 风险 | 缓解 |
|---|---|---|
| R1 | **SQL 与 Dart 两套 RRULE 展开口径漂移**（本次最大正确性风险） | T-DB-23 与 `occurrence_tz_test.dart` 使用**同一组 DST 期望值**；两处代码互相加注释引用；未来改展开规则必须同改并同跑两套测试 |
| R2 | 免打扰克隆行导致通知量放大 | 克隆只对**处于免打扰的用户**产生，且 `channels='{push}'` 不进通知中心；retention job 一并清理 |
| R3 | 重试粒度为通知级 → 极端情况重复推送 | §4.3 已论证取舍；collapse-id 折叠兜底；`last_error` 可观测 |
| R4 | 生产新表默认授权把 anon 全权塞进来（0016/0019/0022 已踩三次） | 每张新表 migration 内**显式 `revoke all ... from public, anon, authenticated`** 后再 grant；T-PROD-04 强制回归 |
| R5 | `DISPATCH_SECRET` 改为强制后，生产忘配 → 全站通知停摆 | 部署文档 §11 置顶提示；T-PROD-03 冒烟必查；函数返回 500 并打明确日志 |
| R6 | Realtime publication 未含 `notifications` → 红点不更新 | G-2 实施前先查 `supabase_realtime` publication；不支持则降级为「App 恢复前台时 invalidate」 |
| R7 | 存量活动补默认提醒后，一次性生成大量通知 | migration 只插 `event_reminders` 行，**不立即展开**；首次展开由次日 cron 执行，且只覆盖未来 14 天、`remind_at > now()` |
| R8 | 已发出的提醒无法撤回 | 产品层面接受（`admin_cancel_notification` 仍仅限 `general`）；改期时只清未发的，已发的靠新通知覆盖说明 |
| R9 | Edge Function 改动大，回滚成本 | 每步一个 migration 独立可回滚；`push-dispatch` 改动集中在 `Deno.serve` 主流程与报文构造，保留旧 `renderText` 分支结构便于对照 |

**明确不做**：per-token 投递状态表（`push_deliveries`）· 活动报名/参与者表（提醒仍全站发）· 国内厂商推送通道（PRD §14 已定案）· 邮件兜底（P2.2 独立任务）

---

## 14. 验收标准（DoD）

1. §11 实施清单全部勾选。
2. §12.1 pgTAP 全绿（现 124 项 + 本次新增 42 项）；§12.3 `flutter analyze` 0 issue、`flutter test` 全绿（现 161 项 + 本次新增）；admin `lint` + `build` 全绿。
3. §12.4 本地栈端到端 12 项全部通过。
4. **三个 P0 缺陷回归用例通过**：T-DB-02 / T-E2E-09（缺陷 A）、T-FN-06 / T-E2E-08（缺陷 B）、T-DEV-05（缺陷 C）。
5. **PRD §5 核心承诺兑现**：T-E2E-01 演示「周六共修 → 提前一天预告 → 当天开始提醒」完整链路——即 PLAN P2.7 的「周六共修全流程演练」。
6. §12.5 真机矩阵四场景（iOS 大陆/海外、海外 Android、大陆 Android）全部验证——即 **PLAN P2 DoD 的「推送矩阵四种场景全部验证可达」**。
7. §12.6 生产冒烟 7 项通过。
8. PRD 升 v0.5.21、PLAN P2 计数刷新、本文档 §11/§12 全勾。

> 本次改造完成后，PLAN **P2 DoD 的两项硬指标（推送矩阵可达 + 共修流程演练）同时达成**，P2 具备结项条件（余 P2.2 邮件兜底与 P2.8 正念提醒暂缓项另计）。
