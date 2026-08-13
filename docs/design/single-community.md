# 设计文档 · 去群化改造(单一共修体)

> 立项:2026-08-11 · 对应 PRD **v0.6.0**(§1/§2/§3/§4/§10/§12/§15 改写)· 对应 PLAN **P9**
> 本文是本次改造的**唯一设计与跟踪事实来源**:§11 实施清单与 §12 测试清单逐项勾选,完成后同步 PLAN P9。

---

## 0. 摘要

**问题**(用户 2026-08-11 提出):现在加入报数群要「拿到群 ID → 输入群 ID → 写申请说明 → 等群主审核」四步,群 ID 是 8 位随机码,不便于在微信/Line 里传播,老年用户记不住也不会操作。多群模型当初是为「面向大众任何人都能建群」设计的,而实际使用场景只有**善护念一个每天报数群**。

**决策**:**产品层面取消「群」概念**——全 App 只有一个共修体,App 内叫「**共修報數**」,注册即入、零门槛、无审核、无群 ID;传播的东西从「App + 群 ID + 申请 + 等审核」收敛为「App 下载链接」一件事。

**关键取舍**:**数据层保留 `group_id` 列与单例 `groups` 行,不做破坏性重构**(理由见 Q1)。用户看到的产品里彻底没有「群 / 群主 / 入群 / 群 ID」,数据库里 `practice_logs.group_id` 恒等于共修体 id。

**收益**
- 入会门槛:4 步 → 0 步(注册即完成)。
- 传播物:群 ID(需记忆、需转述)→ **无**(不再有任何需要转述的东西;让人装上 App 本就发生在 App 之外,故不做 App 内邀请功能,见 §6)。
- 概念数:群、群主、入群申请、群 ID、退群、解散、转让 6 个概念 → 0。
- 代码面:App 删 3 个页面(群列表/群详情/群统计入口层),客户端不再有「选群」分支。

**代价与风险**(详见 §13)
- 报数流水从「群内可见」变为「全体注册用户可见」——语义等价(同修之间可见),但规模放大。
- 自定义功课项**收紧**为仅创建者可选(Q8,用户定案),但其**名称**仍会随该人的报数记录出现在共修流水里。
- 一次改动生产数据(合并群、回填成员),**执行前必须有可用备份**(见 §13.1,PLAN 已记录生产定时备份从未运行)。

---

## 1. 现状勘察(改造前)

### 1.1 用户视角的入会路径

```
注册 → 首页「我的群組」→ 底部「申請入群」→ 输入 8 位群 ID + 申请说明
     → 提交 → 状态「審核中」(不可报数) → 群主在群详情页「入群審核」通过
     → 成为成员 → 才能报数
```
群 ID 由群主在群详情页点开「群 ID」卡片复制(`get_group_join_code` RPC),口头/文字转述给新人。

### 1.2 「群」概念在代码中的分布(工作量依据)

**数据库**(`supabase/migrations/20260707000001_init_schema.sql` 为主)

| 类别 | 对象 | 改造动作 |
|---|---|---|
| 表 | `groups` | 保留;加 `is_default`,只保留一行有效 |
| 表 | `group_join_codes` | 保留但不再产生新值(建群路径关闭);共修体行删码 |
| 表 | `group_members` | 保留;所有注册用户恒为 `approved` |
| 列 | `practice_logs.group_id`(NOT NULL) | 保留,值恒为共修体 id |
| 列 | `practice_types.group_id`(null=全局) | 保留,自定义项挂共修体;**加 `created_by`**(Q8:仅创建者可选) |
| 列 | `proxy_names.group_id` | 保留,代报名单全站共享 |
| 列 | `vows.group_id`(null=全部群) | 保留,新建发愿一律写 null |
| 触发器 | `handle_new_user` | **加**:自动加入共修体 |
| 触发器 | `handle_new_group` | 加 null-owner 容错(共修体行 owner_id 为空) |
| 触发器 | `guard_group_members` | 保留(共修体无 owner,守卫自然不触发) |
| RPC | `join_group` | **停用**(保留函数,直接抛「已无需申请」) |
| RPC | `get_group_join_code` / `reset_group_join_code` | 保留(仅管理员;App 不再调用) |
| RPC | `transfer_group_ownership` / `dissolve_group` | 保留(不再有调用方) |
| 视图 | `group_member_display` | 保留(现等价于全站成员目录),**客户端改为不再全量拉** |
| 视图 | `daily_group_stats` / `group_practice_totals` | 保留,按共修体 id 过滤即全站总量 |
| 策略 | `groups_insert` | **删除** + `revoke insert on groups`(关闭建群) |

**App 客户端**(18 个文件引用 group)

| 文件 | 改造 |
|---|---|
| `features/groups/groups_screen.dart` | **删除**(群列表/建群/入群) |
| `features/groups/group_detail_screen.dart` | **删除**(能力拆解见 §5.4) |
| `features/groups/groups_providers.dart` | 重写为 `community_providers.dart` |
| `features/groups/add_practice_type_dialog.dart` | 保留,`groupId` 参数改内部取共修体 id |
| `features/logs/report_log_screen.dart` | 去掉 `groupId` 构造参数;代报成员改搜索 |
| `features/logs/group_logs_screen.dart` | 改名 `community_logs_screen.dart`,去 `groupId` |
| `features/logs/logs_providers.dart` | 三个 family provider 去掉 `groupId` 参数 |
| `features/dashboard/group_stats_screen.dart` | 改名 `community_stats_screen.dart` |
| `features/dashboard/dashboard_providers.dart` | 群相关 family 去参数;Realtime 频道去过滤 |
| `features/dashboard/quick_report_section.dart` | 选择 key 从 `groupId\|typeId` → `typeId` |
| `features/tools/report_bridge.dart` | 去掉选群下拉 |
| `features/vows/vows_screen.dart` | 去掉「範圍(全部群/某群)」选择器 |
| `features/home/home_screen.dart` | 「我的群組」格 → 「共修報數」;`_startReport` 去掉选群分支 |
| `features/notifications/notifications_screen.dart` | 通知文案去群名;`announcement` 深链改 `/community` |
| `features/notifications/notifications_providers.dart` | route 表同上 |
| `router.dart` | 路由重排 + 旧路由兼容重定向(§3.3) |
| `l10n/*.arb` × 3 | 22 个键改写/删除/新增(§8) |

**管理后台**:`admin/src/app/(admin)/groups/page.tsx`(全部群列表 + 转让/解散)→ 改为「共修體」单页(公告 / 成员 / 总量)。

**Edge Function**:`push-dispatch` 的 `routeOf()` 中 `announcement` 分支指向 `/groups/:id` —— **本次不动**(§5.9 双向兼容定案),留到 P9.8。

---

## 2. 定案(每项已给推荐值;**未答复前按推荐值实现**)

| # | 问题 | 选项 | **推荐** | 理由 |
|---|---|---|---|---|
| **Q1** | 彻底删 `group_id` 列,还是保留单例行? | A 真删(8 表 3 视图 6 RPC 全改) / B 保留列+单例行,UI 去群化 | **B** | A 的收益只有「schema 更干净」,用户看不到差别;代价是一次不可逆的大迁移,还要重写 31+ 项 pgTAP、全部统计视图与后台。B 保留了「将来真要分组(地区/期别)」的可逆性。真要清理,留作 P9.8 后续任务 |
| **Q2** | 共修体这一行从哪来? | A 新建一行 / B 把现有成员最多的群升格 | **B(有则升格,无则新建)** | 生产现在只有 1 个活跃群、19 条报数,升格 = 0 行数据搬迁;migration 写成通用+幂等,本地栈同样自洽 |
| **Q3** | 其余群怎么处理? | A 保留可见 / B 合并进共修体后软删 | **B** | 群总量口径必须唯一;记录 `group_id` 改指共修体,`proxy_names`/自定义功课项合并(撞唯一键则并单),旧群行软删保留供追溯 |
| **Q4** | 新用户如何入会? | A 注册触发器自动入 / B 首次进 App 时客户端调 RPC | **A** | 零门槛的唯一彻底做法;客户端方案会漏(注册后没打开报数页就没入会) |
| **Q5** | 传播方式? | A App 内「邀請同修」卡片(文案+链接+二维码) / **B 不做,注册即入已经解决问题** | **B(用户 2026-08-11 定案,推翻原推荐 A)** | 「入会」与「让人知道有这个 App」是两件事,原来被群 ID 混成一件。去群化后前者已归零(注册即成员),后者本就发生在 App 外(口头/发链接/商店搜索),在 App 里做按钮是绕圈。且官网下载页尚不存在(P5.4),现在做只会指向死链。**P9.3 取消**,分享链接留到 P5.4 上架时顺带做(十几行) |
| **Q5-a** | 去掉群 ID + 审核后,谁都能注册进来看流水,要不要补一道门? | A 邀请码 / B 注册后管理员审核 / **C 不加门,靠事后治理** | **C** | A、B 正是这次亲手拆掉的两样东西,加回去等于原地绕回。共修社群滥用动机低,已有举报 / 拉黑 / 封禁 / 管理员删任意记录四道事后手段 |
| **Q6** | 代报选「同修」怎么选? | A 全量下拉(现状) / B 搜索(输入≥1 字,limit 20) | **B** | 全站成员规模从几十涨到几百上千,全量下拉不可用;且全量视图等于把全站用户目录发给每个客户端 |
| **Q7** | 共修报数流水(谁报了什么)可见范围? | A 全体注册用户可见(= 现状群内语义) / B 仅本人 + 管理员 | **A** | 「随喜」基调靠的就是看得见大众在用功;这本就是群内语义,只是规模变大。举报入口保留,备注仍逐条可举报 |
| **Q8** | 自定义功课项的可见范围? | A 全站可见(原推荐) / **B 仅创建者可见** | **B(用户 2026-08-11 定案)** | 谁加的谁用,不污染公共清单。落地为**「可读」与「可选」两层**(详见下方 Q8-a) |
| **Q8-a** | 「仅自己可见」的落地语义 | —— | **可选=仅自己;可读=所有注册用户** | 自定义项**只出现在创建者的功课选择器与清单**里(`created_by = 我` 或全局主清单);但**名称仍对所有人可读**——否则别人在共修报数记录里看到的将是一条**无名记录**(记录页与共修总量按功课项分行,读不到名字就没法渲染)。即:别人不会在自己的清单里"撞见"我加的项,但会在**我的那条报数记录**上看到它的名字。 |
| **Q8-b** | 用自定义项报的数,计不计入共修总量? | A 计入 / B 只进个人统计 | **A 计入** | 数量是真实用功,随喜基调下不该被排除;且 B 会让"个人累计 ≠ 共修总量中我的部分",口径分裂。**若你要 B,说一声,是一处 where 条件的事** |
| **Q9** | 群主角色 | 取消 | **取消** | 能力并入 App 管理员(审核消失、移除成员→封禁、公告→后台编辑、删任意记录→已有管理员权限) |
| **Q10** | 群公告去哪 | A 删除,改用「發布通知」 / B 保留一条常驻共修公告 | **B** | 通知是流水,公告是常驻信息(如本期共修安排);展示在 `/community` 顶部卡片,管理员在后台编辑 |
| **Q11** | 共修体名称 | —— | **「共修報數 / 共修报数」**(用户 2026-08-11 定案) | 首页格子、页面标题、`groups.name` 统一用它(管理员后台可改)。⚠️ 与日課组的「**報數**」格并列,二者是**动作 vs 查看**的关系:「報數」=提交我的功课(大色块主动作),「共修報數」=看大众与自己的数字与记录。图标与位置已分区(日課 / 共修),不会混淆 |
| **Q12** | 旧版 App 兼容 | —— | **优雅降级,不做强制升级** | 旧版读到的仍是「我的群組」里一个叫「共修報數」的群,报数/统计照常;仅「建立群組 / 申請入群」两个按钮会报错(已被服务端关闭),属预期 |

---

## 3. 改造后的产品形态

### 3.1 角色矩阵(PRD §2 替换)

| 能力 | 匿名用户 | 注册用户 | App 管理员 |
|---|:---:|:---:|:---:|
| 浏览经本 / 日历 / 直播 / 工具 | ✅ | ✅ | ✅ |
| **报数 / 代报 / 补报** | ❌(跳登录) | ✅ **注册即可,无需申请** | ✅ |
| 改 / 删自己提交的报数 | ❌ | ✅ | ✅ |
| 删任意报数记录 | ❌ | ❌ | ✅ |
| 查看个人统计 / 发愿 | ❌ | ✅(仅自己) | ✅ |
| 查看共修总量与报数流水 | ❌ | ✅ | ✅ |
| 添加自定义功课项 | ❌ | ✅(**仅自己可选**,Q8) | ✅ |
| 举报 / 拉黑 | ❌ | ✅ | ✅ |
| 编辑共修公告 / 维护功课主清单 / 发布通知 / 处理举报 / 封禁 | ❌ | ❌ | ✅ |

> **群主**这一列整列删除;「加入报数群」「审核入群」「转让/解散/重置群 ID」四行删除。

### 3.2 首页布局(共修组换一格)

```
日課    [ 報數 ]        [ 快捷報數 ]      ← 提交我的功课(动作)
共修    [ 直播 ]        [ 經本 ]
        [ 共修報數 ]★   [ 活動日曆 ]      ← ★ 原「我的群組」;看数字与记录(查看)
        [ 學修問答 ]    [ (空) ]
修行    [ 個人統計 ]    [ 我的發願 ]
        [ 打坐計時 ]    [ 念珠計數 ]
管理    [ 發布通知 ]    [ 檢舉處理 ]      (仅管理员)
```

「共修報數」`/community` 页内容(自上而下):
1. **共修公告**卡(有内容才显示;**App 内只读**,编辑只在管理后台,见 §7)
2. **今日** —— **「我的」与「全體」并排双卡**(用户 2026-08-11 要求「全体的和自己的都要有统计」):
   - 我的今日:我的总量(按功课项拆分)
   - 全体今日:已报人数 + 全体总量(按功课项拆分)
   > 并排是**自己 vs 整体**的对照,不是成员之间的对比 —— 不违反"不做任何成员间排名"(PRD §4.3)。
3. **近 14 天趋势**:同图双系列(我的 / 全体),图例区分
4. **累计**:同样「我的 / 全體」双列
5. 「**共修報數紀錄**」入口 → `/community/logs`(全体流水)
6. 「**我的自訂功課**」区(仅在我有自定义项时渲染,§5.7)

> 个人的**明细**(按日期回看每条记录、连续用功天数、发愿进度)仍在「個人統計」`/dashboard`,两页分工:`/community` 看**数字对照**,`/dashboard` 看**我的明细**。

### 3.3 路由对照与兼容

| 旧 | 新 | 处理 |
|---|---|---|
| `/groups` | `/community` | **redirect**(保留 2 个版本) |
| `/groups/:gid` | `/community` | redirect |
| `/groups/:gid/report` | `/report` | redirect |
| `/groups/:gid/logs` | `/community/logs` | redirect |
| `/groups/:gid/stats` | `/community` | redirect |

> 保留重定向的原因:①线上旧版 App 与服务端 route 表可能短期不同步;②推送深链 `announcement → /groups/:id` 在旧报文里已存在。新版服务端 `routeOf()` 一并改为 `/community`。

### 3.4 文案对照(去「群」)

| 旧 | 新(繁 / 简) |
|---|---|
| 我的群組 | **共修報數 / 共修报数** |
| 群統計 | 共修統計 / 共修统计 |
| 群報數記錄 | 共修報數紀錄 / 共修报数记录 |
| 本群功課項 | 我的自訂功課 / 我的自定功课 |
| 群公告 | 共修公告 |
| 群成員 | 同修 |
| 選擇群組 / 全部群組 | (删除) |
| 群 ID / 申請入群 / 建立群組 / 群主 / 退出群組 / 解散群組 / 轉讓群主 / 入群審核 / 移除成員 / 檢舉群組 | (删除) |

---

## 4. Step 1 · 数据层(P9.1)

### 4.1 migration `20260811000028_single_community.sql`

**① 标记位与唯一约束**

```sql
alter table public.groups add column is_default boolean not null default false;
-- 全库最多一行 is_default
create unique index uq_groups_default on public.groups (is_default) where is_default;
```

**② 建群触发器容错**(共修体行 `owner_id` 为 NULL,现有触发器会插 `group_members(user_id=null)` 崩)

```sql
create or replace function public.handle_new_group() returns trigger ... as $$
begin
  if new.owner_id is not null then
    insert into public.group_members (group_id, user_id, status, role, approved_at)
    values (new.id, new.owner_id, 'approved', 'owner', now());
  end if;
  if not new.is_default then          -- 共修体不需要 join code
    insert into public.group_join_codes (group_id, code) values (new.id, public.gen_join_code());
  end if;
  return new;
end $$;
```

**③ 确定共修体(幂等:已有 is_default 行则复用)**

```
若存在 is_default 行           → 用它
否则取「未解散、approved 成员最多」的群 → 升格(is_default=true,owner_id=null,name 改共修体名)
否则(空库)                     → 新建一行(owner_id=null)
删除该行的 group_join_codes(不再有群 ID 概念)
```

**④ 合并其余群 → 共修体**(顺序不能错)

```
practice_logs.group_id      → 共修体(直接 update)
proxy_names                 → 改指共修体;撞 (group_id,name) 唯一键的,累加 use_count 后删旧行
practice_types(自定义项)     → 改指共修体;同名同单位的合并(报数改指保留项后删重复项)
vows.group_id               → 一律置 null(= 跨全部,语义等价)
其余群                       → deleted_at = now()
其余群的 group_members       → status='left'(共修体成员行不动)
```

**⑤ 全员入会**

```sql
-- 存量:所有未封禁 profile 补一行 approved
insert into public.group_members (group_id, user_id, status, role, approved_at)
select v_gid, p.id, 'approved', 'member', now() from public.profiles p
on conflict (group_id, user_id) do update
  set status = 'approved', approved_at = coalesce(group_members.approved_at, now());

-- 新注册:handle_new_user() 末尾追加(共修体不存在时静默跳过,保证注册永不失败)
insert into public.group_members (group_id, user_id, status, role, approved_at)
select g.id, new.id, 'approved', 'member', now() from public.groups g
where g.is_default and g.deleted_at is null
on conflict do nothing;
```

> ⚠️ `handle_new_user` 是 auth 注册链路上的触发器,**任何异常都会让注册整体失败**。共修体缺失时必须静默跳过而不是抛错。

**⑥ 关闭建群与入群申请**

```sql
drop policy groups_insert on public.groups;
revoke insert on public.groups from authenticated;
-- join_group 保留函数体,直接抛错(旧版 App 点「申請入群」时给出可读提示)
create or replace function public.join_group(p_code text, p_message text default null) returns uuid ... as $$
begin raise exception 'joining is no longer required: everyone is a member'; end $$;
```

**⑦ 同修搜索 RPC**(替代全量成员视图)

```sql
create or replace function public.search_members(p_q text, p_limit int default 20)
returns table (user_id uuid, display_name text)
language sql stable security definer set search_path = public as $$
  select p.id, p.display_name
  from profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.banned_at is null
    and length(btrim(coalesce(p_q,''))) >= 1
    and p.display_name ilike '%' || btrim(p_q) || '%'
    and not exists (select 1 from user_blocks b
                    where b.user_id = auth.uid() and b.blocked_user_id = p.id)
  order by p.display_name
  limit least(greatest(p_limit, 1), 50);
$$;
revoke all on function public.search_members(text,int) from public, anon;
grant execute on function public.search_members(text,int) to authenticated;
```

> 设计要点:definer 但**内部自校验 `auth.uid()`**(anon 调用返回空集而非全表);限流靠 `limit ≤50` + 必须给关键词;排除自己/封禁/已拉黑。

**⑧ 授权收口**

```sql
revoke insert on public.groups from authenticated;   -- 见 ⑥
-- group_member_display 视图对 authenticated 的 grant 保留(管理员/后台仍用),
-- 但 App 客户端不再全量查询(改 search_members)
```

**⑨ 自定义功课项归属到人(Q8:仅创建者可选)**

```sql
alter table public.practice_types
  add column created_by uuid references public.profiles(id) on delete set null;
create index idx_ptypes_created_by on public.practice_types (created_by) where is_custom;

-- 回填:取首条引用该项的报数的报数人;取不到则留 null(= 无人可选,自然退役,仅管理员可见)
update public.practice_types t set created_by = sub.uid
from (select distinct on (l.practice_type_id) l.practice_type_id, l.reporter_id as uid
      from public.practice_logs l order by l.practice_type_id, l.created_at) sub
where t.id = sub.practice_type_id and t.is_custom and t.created_by is null;

-- 新增时自动落创建者(客户端不必传,也改不了)
create or replace function public.set_practice_type_creator() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.is_custom and new.created_by is null then new.created_by := auth.uid(); end if;
  return new;
end $$;
create trigger trg_set_practice_type_creator
  before insert on public.practice_types
  for each row execute function public.set_practice_type_creator();
```

**「可选」的收口在查询层,不在 RLS**(Q8-a):`practice_types` 的 select 策略维持"注册用户可读"(渲染他人记录必须读得到名字),客户端与选择器一律加过滤条件

```
group_id is null            -- 全局主清单
or created_by = auth.uid()  -- 我自己加的
```

服务端可直接表达(`.or('group_id.is.null,created_by.eq.<uid>')`),无需新策略;**管理后台**另有全量视图用于治理(停用/改名/合并)。

### 4.2 seed 改造(`supabase/seed.sql`)

- 删除「測試共修群 + join code TESTGRP2 + 三条 group_members」段落。
- 四个测试账号由 `handle_new_user` 自动入会(migration 已建共修体行)。
- 示例报数记录(若有)改指共修体。
- **`CLAUDE.md` 里「测试群 join code 固定 TESTGRP2」一句同步删除**。

### 4.3 pgTAP(`supabase/tests/community.test.sql`,新增)

| # | 用例 |
|---|---|
| T-DB-01 | 全库有且仅有一行 `is_default`;该行 `deleted_at is null` |
| T-DB-02 | 新注册用户自动成为共修体 `approved` 成员 |
| T-DB-03 | 共修体不存在时 `handle_new_user` 不抛错(注册仍成功) |
| T-DB-04 | `authenticated` 直接 insert `groups` 被拒(42501) |
| T-DB-05 | `join_group('ANYCODE')` 抛「no longer required」 |
| T-DB-06 | 任一注册用户可直接 insert `practice_logs`(无需审核) |
| T-DB-07 | `search_members('李')` 返回匹配项;不含自己、不含封禁、不含已拉黑 |
| T-DB-08 | `search_members('')` 返回空集;anon 调用返回空集 |
| T-DB-09 | 迁移后无任何 `practice_logs.group_id` 指向非共修体 |
| T-DB-10 | `proxy_names` 合并后 `(group_id,name)` 无重复,`use_count` 为累加值 |
| T-DB-11 | `vows.group_id` 全为 null |
| T-DB-12 | `daily_group_stats` / `group_practice_totals` 按共修体聚合的数字 = 迁移前各群之和 |
| T-DB-13 | 新建自定义功课项自动落 `created_by = auth.uid()`;客户端伪造 `created_by` 无效(触发器只在为 null 时填,伪造值需 §5 客户端不传 + 后台校验;策略层另加 `with check (created_by is null or created_by = auth.uid())`) |
| T-DB-14 | 「可选」过滤:A 用户查 `group_id is null or created_by = A` 拿不到 B 的自定义项;但**直接按 id 查 B 的项能读到名称**(渲染他人记录所必需) |
| T-DB-15 | 存量自定义项回填后 `created_by` = 首条引用该项的报数人;无报数引用的项 `created_by` 为 null |

---

## 5. Step 2 · App 客户端(P9.2)

### 5.1 共修体 id 的取得

新建 `features/community/community_providers.dart`:

```dart
/// 共修体(单例)。RLS:每个注册用户都是 approved 成员 → has_group_relation 命中。
final communityProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(currentUserProvider);              // 登录态变化即重取
  return Supabase.instance.client.from('groups')
      .select('id, name, announcement')
      .eq('is_default', true).maybeSingle();
});

/// 便捷:共修体 id(未就绪时为 null,调用方需处理)
final communityIdProvider = Provider<String?>((ref) =>
    ref.watch(communityProvider).value?['id'] as String?);
```

> 报数提交路径必须拿到 id 才能落库。`/report` 页在 `communityProvider` loading 时显示骨架屏、error 时显示重试(沿用 `async_states.dart`),**不做本地硬编码**(共修体 id 生产/本地不同)。

### 5.2 provider 去参数

`logs_providers.dart` / `dashboard_providers.dart` 的 family provider 全部改为无参(内部 watch `communityIdProvider`):
`reportablePracticeTypesProvider` · `proxyNamesProvider` · `groupLogsProvider→communityLogsProvider` · `groupDailyStatsProvider→communityDailyStatsProvider` · `groupTotalsProvider→communityTotalsProvider` · `groupTodayReportersProvider→communityTodayReportersProvider` · `groupLogsRealtimeProvider→communityLogsRealtimeProvider`(Realtime 过滤器保留 `group_id=eq.<community>`,减少无关行推送)。

两处**必须区分"可选"与"可读"**(Q8-a):

| provider | 语义 | 过滤 |
|---|---|---|
| `reportablePracticeTypesProvider` | 我**能选来报数**的项(报数表单、快捷报数、工具转报、发愿选项) | `active` + `group_id.is.null,created_by.eq.<myUid>` |
| `allPracticeTypesMapProvider` | **渲染名称**用的全量映射(共修记录页、共修统计、个人统计) | 不加过滤(否则他人自定义项的记录会显示为无名条目) |

### 5.3 页面

| 动作 | 文件 |
|---|---|
| 删除 | `features/groups/groups_screen.dart`、`group_detail_screen.dart`、`groups_providers.dart` |
| 新建 | `features/community/community_screen.dart`(§5.7 六个区块,今日/趋势/累计**均为「我的 / 全體」双栏**)、`community_providers.dart` |
| 改名+去参 | `logs/group_logs_screen.dart` → `logs/community_logs_screen.dart`;`dashboard/group_stats_screen.dart` 的统计区块并入 `community_screen.dart` |
| 改造 | `report_log_screen.dart`(去 `groupId` 参数;代报「同修」改搜索框,§5.5)、`quick_report_section.dart`(key 去 groupId、去群名副标题)、`report_bridge.dart`(去选群下拉)、`vows_screen.dart`(去范围选择器,建愿一律 `group_id: null`)、`home_screen.dart`(格子 + `_startReport` 直进 `/report`)、`add_practice_type_dialog.dart`(内部取共修体 id;**不传 `created_by`**,由触发器落;提示改「**僅自己可見**」) |

### 5.4 `group_detail_screen` 能力的去处

| 原能力 | 去处 |
|---|---|
| 群公告展示 / 编辑 | `/community` 顶部卡片(管理员可编辑) |
| 报数记录入口 / 群统计入口 | `/community` 页内 |
| 成员列表 | **删除**(代报改搜索);管理需求走管理后台 |
| 入群审核 | **删除**(无审核) |
| 本群功课项管理(停用/启用) | App 内「共修報數」页设「**我的自訂功課**」区(仅列自己创建的,可停用/启用);全站治理在管理后台「功課主清單」 |
| 拉黑 / 举报用户 | 移到**报数记录条目的菜单**(记录卡片已有「檢舉」,新增「封鎖此人」) |
| 群 ID / 重置 / 转让 / 解散 / 退群 | **删除** |

### 5.5 代报对象选择器(PRD §4.2 三来源保持,来源①换实现)

```
① 同修  → 搜索框(输入即查 search_members,防抖 300ms,结果 ≤20,点选)
② 代报名單 → proxy_names(不变,现在全站共享)
③ 任意名字 → 自由输入(不变)
```
`groupMembersProvider`(全量视图)从客户端删除。

### 5.6 深链与通知

- `notifications_providers.dart` 与 `push-dispatch/index.ts` 的 route 表:`announcement → '/community'`(两端必须成对改,文件头注释已写明此约束)。
- `notifications_screen.dart`:`proxy_log` / `announcement` 文案去掉群名前缀(`'$groupName · ...'` → 直接功课内容)。
- 离线队列(`offline_queue.dart`)中残留的旧 `group_id` 条目补传时会被服务端拒(旧群已软删 → `is_group_member` false),现有「服务器明确拒绝即丢弃」逻辑已覆盖,无需改代码;**在 §12 手动测试里验一次**。

### 5.7 「共修報數」页(`/community`)组件级规格

> 本页是 P9.2 唯一的新页面,以下为实现依据。沿用 `core/widgets/async_states.dart`
> (`SkeletonList` / `ErrorRetry` / `EmptyState` / `SectionHeader`)与 `app_theme.dart` 三级按钮层级。

```
AppBar: 共修報數
─────────────────────────────────────────────────
[公告卡]  secondaryContainer 底 · 前置 campaign 图标
          「共修公告」标题 + 正文(最多 4 行,超出「展開」)
          仅在 announcement 非空时渲染,平日不占位
─────────────────────────────────────────────────
SectionHeader「今日」
┌──────────────┐ ┌──────────────┐
│  我的         │ │  全體         │      ← Row + Expanded ×2
│  12 部        │ │  386 部       │         每卡内按功课项分行(最多 4 行,
│  3 遍         │ │  1,204 遍     │         其余折叠为「其他 N 項」)
│              │ │  28 人已報     │      ← 「今日已報人數」只在全體卡
└──────────────┘ └──────────────┘
   ⚠️ 大字号(≥1.6)自动改为上下堆叠(LayoutBuilder 阈值 340px/卡)
─────────────────────────────────────────────────
SectionHeader「近 14 天」
   分组条形图:每天两根并排细条(我的 = primary,全體 = primary 38% 透明)
   顶部图例两个色块 + 文字;纵轴不标数字(不攀比),点按某天显示气泡数值
   ⚠️ 全體量级远大于我的 → **两条各自归一化到自己的最大值**,
      否则「我的」永远是贴底的一根线。图例下方注明「各自比例」
─────────────────────────────────────────────────
SectionHeader「累計」
   两列表格:功课项 | 我的 | 全體(按功课项分行,复用 units.dart 单位文案)
─────────────────────────────────────────────────
[ 共修報數紀錄 ]  outlined 按钮,整宽 → /community/logs
─────────────────────────────────────────────────

SectionHeader「我的自訂功課」(仅在我有自定义项时渲染)
   ListTile ×N:名称 + 分类/单位 + 「停用/啟用」开关
   末行 ActionChip「+ 新增功課」→ showAddPracticeTypeDialog
   区块下方小字:「自訂功課僅自己可見,別的同修看不到你的清單。」
```

**数据来源**

| 区块 | provider |
|---|---|
| 公告 | `communityProvider`(含 announcement) |
| 今日 · 我的 | `myDailyStatsProvider` 过滤 `local_date = 今天`(已有) |
| 今日 · 全體 | `communityDailyStatsProvider` 过滤同上 + `communityTodayReportersProvider` |
| 近 14 天 | 上两者的 14 天切片(同一份数据,无额外请求) |
| 累計 | `myTotalsProvider` + `communityTotalsProvider`(均已有) |
| 我的自訂功課 | `myCustomPracticeTypesProvider`(新增:`is_custom` + `created_by = 我`,含停用项) |

**空态**:全体今日为 0 时显示 `EmptyState`「今日還沒有人報數 · 隨喜您先行」+「去報數」动作;我的今日为 0 时该卡显示「—」不显示劝导文案(不施压,PRD §4.3 基调)。

### 5.8 同修搜索(代报来源①)交互规格

- 位置:报数表单「替他人報數」展开后,`SegmentedButton` 选中「同修」时。
- 控件:`TextField`(hint = `searchMemberHint`「輸入姓名搜尋同修」)+ 结果列表。
- 行为:
  - **防抖 300ms**;输入 `trim` 后长度 0 时不发请求、清空结果(与 `search_members` 的服务端约束一致)。
  - 结果 ≤20 条,`ListTile`(显示名 + 单选 radio);选中后**收起列表**、上方显示「已選:某某」+ 一个 `close` 图标清除。
  - 无结果:行内小字「找不到這位同修,可改用『任意名字』代報」(直接引导到来源③,避免死路)。
  - 请求失败:行内 `ErrorRetry` 的紧凑版(不整页报错)。
  - `_memberId` 语义不变,提交逻辑零改动。
- 不做:分页、头像、拼音检索(YAGNI;库里只有 display_name)。

### 5.9 路由与深链的**双向**兼容(原设计只写了单向,已补)

| 方向 | 情形 | 处理 |
|---|---|---|
| 新 App ← 旧路由 | 新版收到旧报文 / 旧收藏 `/groups/...` | `router.dart` 保留 5 条 `GoRoute` 做 `redirect`(§3.3) |
| **旧 App ← 新路由** | **服务端改发 `/community`,而线上旧版没有这条路由 → go_router 抛未知路由** | **本次服务端 `routeOf()` 的 `announcement` 分支暂不改**,继续发 `/groups/<共修体id>`(新版会重定向到 `/community`,旧版原样可用);待新版普及后另起一个小任务切换。**这是零风险方案:两端都能落地** |

> 也就是说 **P9.2 不改 `push-dispatch/index.ts`**,只改客户端的 `routeOfNotification`(让它把 `/groups/<id>` 也导向 `/community`)。§11 清单与 §1.2 的「Edge Function」一行按此修正 —— 本次改造**不需要重新部署 push-dispatch**,少一个生产动作。

### 5.10 P9.2 的实施顺序(保证每一步都能编译)

14 个文件互相引用,顺序错了会有一长段编译不过的中间态。按此序:

1. `community_providers.dart`(新增,不动任何旧文件)
2. `logs_providers.dart` / `dashboard_providers.dart`:**新增无参 provider,旧 family 暂留**(两套并存,编译不断)
3. `community_screen.dart` + `community_logs_screen.dart`(新页面用新 provider)
4. `router.dart`:加 `/community`、`/community/logs`、`/report` 三条新路由(旧路由暂留)
5. `home_screen.dart`:格子指向新路由 + `_startReport` 直进 `/report`
6. `report_log_screen.dart` / `quick_report_section.dart` / `report_bridge.dart` / `vows_screen.dart` / `add_practice_type_dialog.dart` 改用新 provider
7. `notifications_screen.dart` / `notifications_providers.dart`:文案去群名 + route 表把 `/groups/<id>` 映射到 `/community`
8. 删 `features/groups/` 三文件 + `group_stats_screen.dart` + 旧 family provider + `PrefKeys.lastReportGroup`
9. `router.dart` 旧路由改为 redirect;`flutter analyze` 清零

> 第 8 步之前 `flutter analyze` 会有「未使用」提示但不会有 error;第 9 步后必须 0 issue。

---

## 6. ~~Step 3 · 邀请与传播(P9.3)~~ —— **取消**(2026-08-11 用户定案,设计 Q5)

**不做 App 内的邀请卡片 / 分享文案 / 二维码,不引入 `qr_flutter`。**

理由(Q5):
1. 「入会」在 P9.1 之后已经归零 —— **注册即成员**,没有任何需要转述的东西(原来要转述的正是群 ID)。
2. 「让新人知道并装上 App」发生在 App 之外(口头告知、发商店链接、官网下载 APK);在 App 里放一个"让已装的人去拉没装的人"的按钮,并不改变分发渠道本身。
3. 官网下载页(PRD §14.4)**尚不存在**,属 P5.4 上架任务。现在实现只会指向死链,反而砸掉可信度。

**将来要做时的落点**:P5.4 上架、官网下载页真实上线之后,在设置页或首页加一个「分享下載連結」——`share_plus` 已在依赖里(P2.4c 引入),十几行即可,不需要单独立项。

> 本节保留而不删除,是为了记住"为什么没做",避免日后有人当作遗漏重新提出来。

---

## 7. Step 4 · 管理后台(P9.4)

`admin/src/app/(admin)/groups/page.tsx` → **`community/page.tsx`**「共修體」:

- 基本信息:名称(可改)、成员数、创建时间。
- **公告编辑**(`groups.announcement`,即时保存 + 生成群通知,沿用 migration 0006 的触发器)。
  > **定案(原设计两处矛盾,已收敛)**:公告**只在管理后台编辑**,App 内**只读展示**。理由:①公告更新会给全体成员发通知,是"广播级"操作,该和「發布通知」一样待在桌面端、有预览和二次确认;②App 内再做一套编辑器要多一个权限分支与一套 l10n,收益低。§3.2 里「管理员可见『編輯』」一句作废,改为不渲染任何编辑入口。
- **同修列表**:分页 + 搜索(显示名 / 登录名,复用 `admin_list_logins`)、封禁/解封、代删账号(走 `admin-ops`,已有)。
- **共修总量**:按单位聚合(复用 `group_practice_totals`)。
- 侧栏「群總覽」→「共修報數」;历史群列表**保留一个折叠区**(只读,含已软删群)供追溯。
- `content/page.tsx` 的「功課主清單」增加**自定义项治理区**:列出全部 `is_custom` 项及其 `created_by` 显示名(App 端各人只看得到自己的),管理员可停用 / 改名 / 提升为全局主清单项(`group_id`、`is_custom`、`created_by` 三列置空即"转正")。
- `dashboard/page.tsx` 的「活躍群」卡片 → 改为「同修人數」(注册用户数即成员数)。

---

## 8. Step 5 · 文案与 l10n(P9.5)

三份 ARB(`app_zh_Hant.arb` 模板 / `app_zh_Hans.arb` / `app_zh.arb` 兜底)+ `flutter gen-l10n` 重生成并提交。

**删除(26 键)**:`createGroup` `joinGroup` `groupName` `groupDescription` `joinCodeLabel` `applyMessageLabel` `pendingApplications` `groupCreated` `leaveGroup` `removeMember` `transferOwner` `dissolveGroup` `reportGroup` `resetJoinCode` `confirmResetCode` `confirmDissolve` `confirmLeave` `confirmTransfer` `confirmRemove` `roleOwner` `statusPending` `approve` `reject` `chooseGroup` `scopeAllGroups` `groupsEmptyHint`
> 顺序:**先删 UI 引用 → `grep -n "l10n\.<key>" app/lib` 确认 0 命中 → 再删 ARB 键 → `flutter gen-l10n`**。`flutter analyze` 不会因为未使用的 getter 报错,所以必须靠 grep 兜底,否则会留下一堆死文案。

**改写(6 键)**:`groupsTitle`→「**共修報數**」· `groupStats`→「共修統計」· `groupPracticeTypes`→「**我的自訂功課**」· `announcement`→「共修公告」· `notifAnnouncement`→「共修公告更新」· `members`→「同修」

**新增(9 键)**(邀请相关 5 键随 §6 取消一并去掉)

| key | zh_Hant | zh_Hans |
|---|---|---|
| `communityTitle` | 共修報數 | 共修报数 |
| `communityLogs` | 共修報數紀錄 | 共修报数记录 |
| `communityTotals` | 累計 | 累计 |
| `statsMine` | 我的 | 我的 |
| `statsAll` | 全體 | 全体 |
| `statsScaledNote` | 各自比例 | 各自比例 |
| `communityEmptyToday` | 今日還沒有人報數 · 隨喜您先行 | 今日还没有人报数 · 随喜您先行 |
| `searchMemberHint` | 輸入姓名搜尋同修 | 输入姓名搜索同修 |
| `customTypePrivateHint` | 自訂功課僅自己可見,別的同修看不到你的清單。 | 自定功课仅自己可见,别的同修看不到你的清单。 |

> `app_zh.arb`(兜底)三份同步;新增键一律带 `@key` 描述,与现有 ARB 风格一致。

---

## 9. 对 PRD 的影响(升 **v0.6.0**,随 P9.1 一并落地)

| 章节 | 改动 |
|---|---|
| 版本头 | v0.5.21 → **v0.6.0**,加改动摘要「去群化:单一共修体,注册即入」 |
| §1 产品概述 | 「核心是**分群报数与统计**」→「核心是**每日功课报数与统计**(单一共修体)」 |
| §2 角色与权限矩阵 | 整表替换为 §3.1;删「群主」列与建群/入群/审核/转让 4 行;补一句「无群概念,注册即可报数」 |
| §3 报数群模型 | 整章改写为「**§3 共修体模型(单一)**」:注册即入 / 无审核 / 无群 ID / 管理由 App 管理员承担 / 公告 |
| §4.2 代报 | 来源①「群成员」→「同修(搜索)」;代报名单「本群共享」→「全站共享」 |
| §4.3 统计 | 「群整体」→「共修整体」;「群主视角」段删除 |
| §4.4 发愿 | 删「也可在发愿时限定单个群」 |
| §9.1/9.2 工具转报 | 删「选群后提交」 |
| §10.2 举报 | 举报目标删「群」;拉黑入口改「报数记录条目」 |
| §11 NFR | 无改动 |
| §12.2 数据模型 | `groups` 加 `is_default`;`group_members`/`group_join_codes` 标注「单一共修体后为历史结构」;`vows.group_id` 标注恒 null |
| §12.3 RLS | `groups` 行改为「共修体成员可读、仅管理员写,**不再开放 insert**」;新增 `search_members` 说明 |
| §12.4 | 深链表 `announcement → /community` |
| §13 Roadmap | 加 **v0.6 去群化**一行 |
| §14 已定案 | 追加:「**去群化(v0.6.0)**:全 App 单一共修体,注册即入、无群 ID、无审核;群主角色取消并入 App 管理员;数据层保留 `group_id` 单例以保可逆」 |
| §15.2 管理后台 | 「群总览」→「共修体管理(公告/成员/总量)」 |

---

## 10. 对 PLAN 的影响

新增 **P9 · 去群化(单一共修体)**,任务 P9.1–P9.7(见 §11);§1 进度总览加一行;§2 外部依赖**无新增**(邀请页链接依赖 P5.4 官网下载页,但不阻塞本 Phase)。

---

## 11. 实施清单(逐项勾选)

### P9.1 数据层(M)✅ 2026-08-11
- [x] migration `20260811000028_single_community.sql`:①–⑨ 九段(§4.1,含 `practice_types.created_by` 归属与回填)
- [x] `seed.sql` 去掉测试群,`CLAUDE.md` 同步删 TESTGRP2 说明并加「不要再新增选群/建群/入群路径」约束
- [x] `supabase/tests/community.test.sql` 15 个编号 / 17 项断言(§4.3)
- [x] `rls.test.sql` 按新模型重写(删建群/join code/审核/转让/解散/退群六组,替换为注册即入会、建群关闭、join_group 停用、封禁不能报数;35 项)
- [x] `notification_prefs.test.sql` T-DB-18 改用共修体 + 构造 `left` 成员保住边界语义
- [x] `npx supabase db reset` + `npx supabase test db` 全绿(**10 文件 200 项**)

> 本地验证实况:共修体 1 行(`共修報數`,owner_id 为空)· 4 个 seed 账号全部 approved · 3 条报数全部归口共修体 · `group_join_codes` 0 行。

### P9.2 App 客户端(L)✅ 2026-08-11
- [x] **①** `features/community/community_providers.dart`:`communityProvider` / `communityIdProvider` / `communityAnnouncementProvider` / `myCustomPracticeTypesProvider`
- [x] **②** `logs_providers.dart` + `dashboard_providers.dart`:6 个无参 provider,`reportablePracticeTypesProvider` 加 `created_by` 过滤,`allPracticeTypesMapProvider` **保持不过滤**;另加 `logDisplayNamesProvider`(按当前这一屏记录里出现的 id 反查显示名 —— 成员规模变全站后不能再全量拉成员表,这是原设计漏掉的一环)
- [x] **③** `community_screen.dart`(§5.7 六区块)+ `logs/community_logs_screen.dart`(条目菜单加「封鎖此人」)
- [x] **④** `router.dart` 加 `/community`、`/community/logs`、`/report`
- [x] **⑤** `home_screen.dart`:格子换「共修報數」;`_startReport` 三分支整段删除,直进 `/report`;深链 `needAuth` 补 `/community` `/report` `/groups`
- [x] **⑥** `report_log_screen.dart`(去 `groupId` + §5.8 同修搜索)· `quick_report_section.dart`(key → `typeId`)· `report_bridge.dart`(删选群下拉,并**改用 `reportablePracticeTypesProvider`** —— 原来用的是不过滤的全量映射,去群化后会把别人的自定义项也列进选择器)· `vows_screen.dart`(同上两处)· `add_practice_type_dialog.dart` 移到 `features/community/`,签名改 `(context, ref)`
- [x] **⑦** 通知文案去群名前缀 + 客户端 route 表 `/groups/<id>` → `/community`(服务端 `push-dispatch` 本次不动,§5.9)
- [x] **⑧** 删除 `features/groups/` 整个目录(4 文件)、`dashboard/group_stats_screen.dart`、`logs/group_logs_screen.dart`、`PrefKeys.lastReportGroup`
- [x] **⑨** 旧 5 条路由改 redirect;`flutter analyze` **0 issue**
- [x] Flutter 测试:新增 `community_screen_test.dart`(T-APP-01/03/04/08)+ `community_flow_smoke_test.dart`(取代 `groups_flow_smoke_test`,覆盖 T-E2E-01/05 与 T-APP-06/07);`batch_utils_test` / `logs_flow_smoke_test` / `compliance_flow_smoke_test` / `notification_overhaul_test` / `layout_walkthrough_test` 随新模型更新。**`flutter test` 197 全绿**

> **实施偏差(如实记录)**:§5.10 的九步本意是每步都能编译;实际做法是第 ② 步就直接替换了旧 family provider(没有并存),于是中间态有一段编译不过,靠 `flutter analyze` 的报错清单当作"待改文件清单"推进。对**一次性做完**的场景这样更快也更不易漏改;若是分多天做,仍建议按原九步并存推进。
>
> **补 migration 0029**:`daily_user_stats` 补 `entries` 列。趋势图要画「我的 / 全體」双系列,两条必须同口径;`daily_group_stats` 早有 `entries`,个人视图只有 `total`,而数量跨单位(部/遍/次/分钟)不能相加成一根柱子。
>
> **测试抓到的真实缺陷**:`_TwoColumn` 的 `Row + CrossAxisAlignment.stretch` 放在 `ListView` 里会拿到无限高约束直接 assert 崩 —— 必须包 `IntrinsicHeight`。T-APP-08 一跑就炸,静态检查发现不了。

### ~~P9.3 邀请与传播~~ —— **取消**(2026-08-11 用户定案,§6)
不做 App 内邀请卡片 / 二维码,不引入 `qr_flutter`。分享下载链接留到 P5.4 上架时顺带做。

### P9.4 管理后台(M)✅ 2026-08-11
- [x] `groups/page.tsx` → `community/page.tsx`:共修体信息(名称可改)+ 公告编辑(**唯一编辑入口**)+ 同修人数 / 共修总量 / 建立时间三卡 + 历史群只读折叠区
- [x] 删除「转让群主 / 解散群」两个操作(单一共修体后无意义)
- [x] `content/page.tsx` 新增「自訂功課」tab:全部自定义项 + 创建者显示名 + 停用/启用 + **提升為主清單**(清 `group_id`/`is_custom`/`created_by` 三列;表上有 `check (is_custom = (group_id is not null))`,必须同一次 update 清)
- [x] `layout.tsx` 侧栏 + 首页卡片「群組總覽」→「共修報數」;`dashboard`「活躍群組」→「同修人數」(去群化后群数恒为 1,已无信息量)
- [x] `reports` / `users` 页去群化措辞;`target_type='group'` 的历史举报仍可渲染(标注「歷史」)
- [x] `npm run gen:types` + `lint` + `build` 全绿(14 路由,`/groups` → `/community`)

> **与原设计的一处偏差(有意)**:设计里写后台「共修體」页要带**同修列表**(搜索/封禁/代删)。实际没做 —— 去群化后「同修」= 全部注册用户,那正是 `/users` 页在管的同一张表,再实现一遍是纯重复。改为在共修体页显示同修人数并链到 `/users`。
>
> **`useEffect` 同步表单被 lint 拦下**(`react-hooks/set-state-in-effect`):改用「草稿覆盖」模式(`draft ?? serverValue`)。顺带修掉一个真 bug —— 用 effect 同步的话,查询后台刷新会把管理员正在输入的公告冲掉。

### P9.5 文案与 l10n(S)✅ 2026-08-11
- [x] 三份 ARB:**删 34 键 / 改 1 键(`notifAnnouncement`)/ 增 10 键**,`flutter gen-l10n` 重生成
- [x] 删键前逐个 `grep` 确认 0 引用(实删 34:§8 列的 26 个 + `joinRequested`/`vowScope`/`groupsTitle`/`groupStats`/`groupPracticeTypes`/`announcement`/`members`/`editAnnouncement`/`deleteOwnerBlocked`)
- [x] **顺带清掉 5 条仍在说「群」的用户可见文案**(§8 只列了键的增删,漏了这些):`subjectMember`「群成員」→「同修」· `logsEmptyHint`「本群還沒有報數」· `deleteAccountWarn`「保留於群統計中」· `authResetNeedAdmin`「請聯繫群主或管理員」· `deleteOwnerBlocked` 整条(该分支已不可达,连同 `settings_screen` 里的特判一并删)。现在三份 ARB 里**一个「群」字都没有**
- [x] `layout_walkthrough_test` 增补 `/community`(公告 + 双栏 + 双系列趋势 + 自訂功課,简繁 × 2.0 不溢出)

### P9.6 文档(S)
- [x] PRD 升 v0.6.0(§9 逐条)✅ 2026-08-11
- [x] PLAN 加 P9 + 总览行 + 顶部日期 ✅ 2026-08-11
- [ ] 实施完成后回填本文 §11 勾选与 PLAN P9 进度计数

### P9.7 测试与发布(M)🔄 服务端已发布 2026-08-12
- [x] 手工全量快照 `pre-single-community-20260812-0503.sql.gz`(1.1M),已 scp 到本机 `docs/secretFiles/backups/`(gitignored)并 `gzip -t` 校验
- [x] 迁移前计数留档:**30 条活跃报数 / 4 个群 / 总量 290.00 / 33 条含软删 / 5 名 approved / 7 个 profile**
- [x] `0028` + `0029` 应用生产,**每个文件与其记账语句同一事务**(记账 27→29)
- [x] §12.4 迁移后核对**全过**(下方实况)
- [x] 生产冒烟:anon 调 `search_members` / 建群 → **401**;新注册账号 → `group_members` 立刻 approved → **报数 HTTP 201**;登录用户 `search_members` 200;建群 **403**;冒烟账号已清理,数据回到基线
- [x] admin 站重发布(14 路由全 200,`/groups` 已 404;线上 chunk 含「唯一編輯入口」新文案,确证非旧缓存)
- [x] **补上生产备份 crontab**(P0.4 未竟项):root crontab `0 3 * * * /usr/local/bin/pt-backup.sh`,已试跑成功产出 1.1M 备份
- [ ] ⏳ **发新版 App**(用户自行在 Codemagic 构建)
- [ ] ⏳ 真机走查:注册新号 → 全程无「群」字 → 报数 → 双栏数字 → 同修搜索代报

**生产迁移后实况(2026-08-12)**

| 核对项 | 结果 |
|---|---|
| 共修体唯一且未删 | 1 ✅ |
| 报数指向非共修体 | 0 ✅ |
| **活跃总量(守恒)** | **290.00 = 迁移前 290.00** ✅ |
| 记录数 | 33 = 迁移前 33 ✅ |
| approved 成员 | 5 → **7**(= 全部 profile,全员补齐)✅ |
| 共修体 join code | 0 ✅ |
| `vows.group_id` 非空 | 0 ✅ |
| `_pre_community_log_groups` 留档 | **10** = 从另 3 个群搬来的记录数(1+4+5)✅ |
| 共修体名称 | 共修報數 ✅ |
| 其余群未软删 | 0 ✅ |

> **生产实况与设计假设的偏差**:设计 Q2 写「生产只有 1 个活跃群、19 条报数,升格 = 0 行数据搬迁」——**实际是 4 个群(3 活跃)、33 条报数**,合并真的搬了 10 条。migration 写成通用+幂等是对的;`_pre_community_log_groups` 留档也因此真正派上用场。
>
> **升格的是 `test` 群**(approved 成员最多:2 名 / 23 条记录),已改名「共修報數」、`owner_id` 置空。
>
> **自定义功课项回填**:3 个自定义项只有 1 个拿到 `created_by`(另 2 个从未被报数引用,按设计留 null = 无人可选、自然退役)。
>
> **踩到的两个坑**:①`( sudo crontab -l; echo ... ) | sudo crontab -` 这种管道 + sudo 组合装不进去(退出码 0 但内容为空),必须写临时文件再 `sudo crontab <file>`;②bash 的 `UID` 是只读变量,冒烟脚本里当变量名用会直接报错。

⚠️ **仍未解决的备份缺口(非本次引入,但必须记着)**:`pt-backup.sh` 现在只写**本机磁盘** `/root/backups`(保留 14 份),而部署文档 §6 原本设计的是 `aws s3 cp` 到**异地**对象存储 —— 服务器上根本没装 aws cli。也就是说:**磁盘或实例挂了,备份跟数据库一起没**。补齐需要用户提供 S3 桶 + IAM 决策,已在 PLAN §7 登记。P0.4 的「恢复演练」同样仍未做。

### P9.8 收尾(XS,发布 90 天后)
- [ ] migration 清理 `_pre_community_log_groups` 备份表
- [ ] 视新版普及率,把服务端 `announcement` 深链切到 `/community` 并撤掉客户端 5 条旧路由 redirect

---

## 12. 测试计划

### 12.1 pgTAP ✅ 2026-08-11
`community.test.sql` T-DB-01…15(17 项断言)+ `rls.test.sql` 按新模型重写(35 项)+ `notification_prefs.test.sql` T-DB-18 改造。全套 **10 文件 200 项全绿**。
> T-DB-12(迁移前后总量一致)在本地栈无从构造(reset 后没有"迁移前"),改由 §12.4 生产冒烟以真实数据验证。

### 12.2 Flutter 单测/组件测
| # | 用例 |
|---|---|
| T-APP-01 | `communityProvider` 未就绪时报数页显示骨架屏,不崩 |
| T-APP-02 | 快捷报数 key 去 groupId 后仍能正确聚合「上次数量」(`batch_utils` 现有用例更新) |
| T-APP-03 | 首页「報數」直达 `/report`(无选群弹层) |
| T-APP-04 | 旧路由 `/groups/xxx/report` 被重定向到 `/report` |
| T-APP-05 | 大字号(2.0)× 简繁,`/community`(含双栏与趋势图)不溢出 |
| T-APP-06 | 报数表单的功课选择器**不含他人的自定义项**,含全局主清单与自己的 |
| T-APP-07 | 共修报数记录中他人用自定义项报的记录**名称正常显示**(不是空白/id) |
| T-APP-08 | `/community` 今日双栏:我的数字 = 个人统计页今日数字;全体数字 ≥ 我的 |

### 12.3 手动 / 端到端(本地栈)
| # | 场景 |
|---|---|
| T-E2E-01 | **新注册用户直接报数**:注册 → 首页「報數」→ 提交成功(全程无「入群」字样) |
| T-E2E-02 | 迁移前后共修总量一致(迁移前记数 → 应用 0028 → 比对) |
| T-E2E-03 | 代报:搜索同修 → 代报 → 对方收到通知且可删该记录 |
| T-E2E-04 | 代报自由名字 → 进入代报名单 → 下次可点选 |
| T-E2E-05 | 陌生新用户全流程:注册 → 无任何等待/审核 → 报数 → 在共修记录里看到自己那条 |
| T-E2E-06 | 管理员在后台改公告 → App `/community` 顶部卡片更新 + 通知中心收到「共修公告更新」 |
| T-E2E-07 | 离线队列:断网报数入队 → 恢复联网自动补传成功 |
| T-E2E-08 | 举报 / 拉黑从报数记录条目可发起,后台可处理 |
| T-E2E-09 | **旧版 App 兼容**:用改造前的 APK 登录 → 仍见「善護念共修」且能报数;点「建立群組」给出可读错误 |

### 12.4 生产冒烟(应用 0028 后)

**迁移前**先记账(留在发布记录里):
```sql
select count(*) as logs, count(distinct group_id) as groups_used,
       sum(quantity) as qty_total from public.practice_logs where deleted_at is null;
select count(*) as members from public.group_members where status = 'approved';
```
**迁移后**逐条核对:
- [ ] `select count(*) from groups where is_default and deleted_at is null;` → **1**
- [ ] `select count(*) from practice_logs where group_id <> (select id from groups where is_default);` → **0**
- [ ] `sum(quantity)` 与迁移前**完全相等**(总量守恒,DoD 第 2 条)
- [ ] `select count(*) from group_members where status='approved';` ≥ 迁移前(全员补齐,只增不减)
- [ ] `select count(*) from group_join_codes where group_id = (select id from groups where is_default);` → **0**
- [ ] `select count(*) from vows where group_id is not null;` → **0**
- [ ] anon REST 调 `search_members` → **401/403**(未授 execute)
- [ ] 新注册一个账号 → `group_members` 立刻出现 approved 行 → App 内直接报数成功
- [ ] 管理后台「共修體」页可读、改公告后 App 通知中心收到

### 12.5 生产发布顺序(不可颠倒)

1. **手工全量快照**:`pg_dump` → 下载到本机异地保存(§13.1,没有这步不得继续)
2. 跑 §12.4「迁移前」两条计数并记录
3. 应用 `0028` + `_applied_migrations` 记账**同事务**执行(沿用 P2.12–P2.17 的做法:失败即回滚,杜绝"记账已插、migration 未跑")
4. 跑 §12.4「迁移后」九条核对
5. 发新版 App(旧版仍可用,§12.3 T-E2E-09)
6. admin 站 `deploy.ps1` 重发布(静态站无热更新,不重发新页面 404)
7. 顺手补上生产备份 crontab(P0.4 未竟项)

> `push-dispatch` **本次不动**(§5.9),少一个重启动作,也避免旧版 App 收到无法识别的路由。

---

## 13. 风险与回滚

### 13.1 ⚠️ 生产备份(硬前置)
PLAN §5 已记录:**生产每日定时备份从未运行**(`pt-backup.sh` 在,crontab 为空)。本次是**首个改动存量业务数据**的 migration,执行前必须:
1. 手工 `pg_dump` 全量快照并**下载到本地异地保存**;
2. 顺手把 crontab 补上(P0.4 未竟项)。
没有第 1 步不得执行 0028。

### 13.2 回滚脚本(可直接执行,不建 down migration)

0028 的破坏性动作有四处,全部可逆(`_pre_community_log_groups` 留档了唯一无法从现状推回的那一处):

```sql
begin;
-- 1) 报数归位
update public.practice_logs l
   set group_id = b.old_group_id
  from public._pre_community_log_groups b
 where b.log_id = l.id;

-- 2) 群恢复可见(只恢复本次软删的那批:deleted_at 落在 0028 执行时刻附近)
update public.groups set deleted_at = null
 where deleted_at is not null and not is_default
   and deleted_at >= '<0028 执行时刻>'::timestamptz;

-- 3) 成员关系恢复(本次被置 left 的行)—— 需从快照恢复,现状无法区分
--    ⚠️ 这一项只能靠 §13.1 的 pg_dump 快照,不要指望脚本

-- 4) 重开建群(如确需回到多群)
create policy groups_insert on public.groups for insert
  with check (owner_id = auth.uid() and public.is_active_user());
grant insert on public.groups to authenticated;
commit;
```

> **结论**:报数与群本身可脚本回滚;**成员状态与 `vows.group_id` 只能靠快照恢复** —— 这就是 §13.1 把手工快照列为硬前置的原因,别把它当形式。
> `_pre_community_log_groups` 保留 90 天,由 P9.8 的清理 migration 删除。

### 13.3 其他风险
| 风险 | 缓解 |
|---|---|
| 报数流水全站可见带来的隐私顾虑 | Q7 已定;举报/拉黑保留;若反馈不佳,后续可加「僅顯示功課與數量、不顯示備註」的开关(不在本次) |
| 自定义功课项污染公共清单 | **Q8 已定案解决**:自定义项仅创建者可选,公共清单只有管理员维护的主清单;残留风险是他人在**共修报数记录**上仍会看到我用的功课名(名称必须可读,否则记录无名),后台可改名治理 |
| 同一功课被多人各建一份(如三个「大方廣佛華嚴經」) | 共修总量按 `practice_type_id` 分行 → 会拆成三行。缓解:添加弹窗先做同名检索提示「主清單已有相近項」;后台可合并(把报数改指保留项后删重复项,同 migration ④ 的手法) |
| 全站成员目录暴露 | `search_members` 需关键词 + limit + 排除封禁/拉黑;客户端不再全量拉 |
| 旧版 App 用户点「建立群組」报错 | 预期行为(Q12);错误文案经 `errText` 已中文化;发版说明中告知 |
| 将来真要分组 | 数据层单例结构完整保留,恢复多群 = 恢复 UI 与 `groups_insert` 策略 |

---

## 14. DoD

1. 新用户从注册到完成第一次报数,**全程不出现「群」字,且无任何审核等待**。
2. 迁移前后**共修总量与个人累计数字完全一致**(T-E2E-02 / 生产冒烟)。
3. `npx supabase test db` / `flutter analyze` / `flutter test` / admin `lint`+`build` 全绿。
4. 旧版 App 仍可正常报数(优雅降级)。
5. PRD v0.6.0 与 PLAN P9 已更新并勾选;§11 清单全部打勾。

---

## 15. 待确认

**无。** 原唯一阻塞项(官网下载页真实地址)已随 2026-08-11 的 Q5 定案(取消 App 内邀请功能)自动关闭 —— 设计可直接进入实施。

> 以下 §16 的 8 项是我代为定案的工程判断;不同意任何一条,改起来都只是文档几行 + 局部实现。

## 16. 我已代为定案的 8 项(供复核)

| # | 事项 | 定案 | 一句话理由 |
|---|---|---|---|
| 1 | 自定义功课「仅自己可见」的落地 | **可选=仅自己,可读=所有人**;并在 DB 层禁止用他人的自定义项报数 | 名称若不可读,别人的记录会显示成无名条目 |
| 2 | 自定义项报的数是否进共修总量 | **进** | 否则"个人累计 ≠ 共修总量里我的部分",口径分裂 |
| 3 | 共修公告的编辑入口 | **只在管理后台**,App 内只读 | 公告更新会给全员发通知,属广播级操作,该和「發布通知」一样待在桌面端 |
| 4 | 旧版 App 的深链兼容 | **服务端 route 表本次不动**,继续发 `/groups/<id>`;新版客户端自己把它导向 `/community` | 唯一的零风险方案:新旧两版都能落地,还少一次生产部署 |
| 5 | 趋势图双系列的画法 | 分组条形图,**两条各自归一化**,注明「各自比例」 | 全体量级远大于个人,同轴的话"我的"永远贴底看不见 |
| 6 | 「我的自訂功課」区的位置 | 放 `/community` 页最下方 | 它和报数强相关;个人统计页的主题是"数字回顾",塞管理功能会串味 |
| 7 | 存量自定义项的重复合并 | **migration 不自动合并**,交管理后台人工治理 | 同名未必同义(不同译名/单位),自动合并可能改错历史归属 |
| 8 | 同修搜索的能力边界 | 只做防抖 + 前 20 条 + 姓名子串;**不做**分页/头像/拼音 | 库里只有 display_name,其余都是 YAGNI |
