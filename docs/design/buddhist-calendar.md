# 佛教日历(纪念日 / 节日 / 十斋日)+ 跨时区 · 详细设计

> 状态:**设计稿(2026-07-16)** · 分支 `feature/p2-9-buddhist-calendar`
> 对应 PRD v0.5.15 §5「佛教日曆」与 §5 跨时区补充;PLAN 任务 **P2.9(佛历)/ P2.10(活动时区)**
> 数据源参考:[6tail lunar 系列库](https://github.com/6tail/lunar-javascript)(官方 Dart 版 pub 包 [`lunar`](https://pub.dev/packages/lunar),含佛历 `Foto`)

---

## 0. 待拍板问题(每项已给推荐;**未答复前按推荐值实现**,改选只影响局部)

| # | 问题 | 选项 | 推荐(默认采用) | 改选的代价 |
|---|------|------|----------------|------------|
| Q1 | 佛历数据怎么来 | A. 纯预生成文件:`tools/almanac/` 生成器一次性产出 2026–2075 逐日农历+节日 JSON 进 App 资产,同一生成器再产出服务端节日表(供 pg_cron 排通知);客户端零农历运行时依赖<br>B. 客户端引入 lunar Dart 包运行时计算,只预生成节日文件 | **A**。三处消费(日历/首页横幅/通知)同一份数据,内容方可审;完全满足"50 年数据放文件、离线可读";50 年外无农历可接受 | B 只需把客户端 loader 换成运行时计算,资产层设计不变 |
| Q2 | 节日收录范围 | A. 精选约 26 条主要佛菩萨纪念日 + 十斋日(清单见 §3.3,生成器配置可改)<br>B. A + 春节/清明/中秋等传统节日(次要样式、不通知)<br>C. lunar 佛历全量 50+ 条(含冷门与"犯者夺纪"类宜忌) | **A**。C 信息噪音大且宜忌文风与本 App 不合;B 可日后加一行配置就支持 | 改清单=改 `tools/almanac/config` 后重新生成+发版;结构不变 |
| Q3 | 通知策略 | A. 节日+十斋日当天各一条全员通知;重大节日(§3.3 标 ★)额外**提前一天**预告;设置页两个开关(佛教节日/十斋日)默认开<br>B. 节日通知,十斋日只显示不通知<br>C. 都只当天一条、无预告 | **A**。周六共修式的"提前知道好安排"体验;不想被打扰的用户可各自关闭 | 开关与 cron 都按类型分流,改选只是删一类插入/改默认值 |
| Q4 | 用户端时区 | A. 一律跟随设备自动(现状),活动详情加注"活动当地时间"<br>B. 设置页增加手动固定显示时区(存 `profiles.timezone`) | **A**。设备本来就知道时区,手动固定容易忘改出错,也少一个设置项(年长用户友好) | B 是纯增量:加设置项+display 层统一走一个 provider |

另有两个**设计判定**(非选项,认为无争议,如有异议请提出):

- **节日/十斋日的时区语义**:农历日按中国时间(UTC+8)定义,映射到一个**公历日期**后全球统一显示在那一天(全天性质,不随时区平移)。共修团体全球同一天过佛诞,不存在"美国用户晚一天"。
- **十斋日口径**:农历每月初一、初八、十四、十五、十八、廿三、廿四、廿八、廿九、三十(小月无三十则该月只有 9 天),与 lunar 库 `Foto.isDayZhaiTen()` 一致。内容方如有别的传承口径(如小月补廿七),改生成器一行即可。

---

## 1. 需求 → 方案映射

| 原始需求 | 落地方案 |
|---|---|
| 1. 日历加佛教纪念日/节日/十斋日,含农历日期 | 日历月视图每格加**农历副标签**;节日日显示金色节日短名、十斋日显示标记;选中某天在活动列表上方显示**当日佛历卡**(农历全称+节日全名+十斋日) |
| 2. 打开 App 有节日/十斋日要让用户看到 | **首页顶部横幅**(登录/未登录都显示):莲花图标+「今日 · 農曆四月初八 · 釋迦牟尼佛聖誕(浴佛節)」,点击进日历;非特殊日不占位 |
| 3. 跨时区友好;管理员定时间要设时区+默认值;用户按所在时区看 | `events.timezone`(IANA 名)+ 管理员编辑器时区选择器;默认值存 `app_settings`(管理员可改);每周循环在**活动时区**展开(跨 DST 保持墙钟时间);用户显示跟随设备时区,详情页加注活动当地时间(Q4) |
| 4. 节日/十斋日要通知,将来接推送 | pg_cron 每日按 UTC+8 零点后写 `notifications`(scope=all, type=almanac);通知中心即时可见;P2.1 推送接通后经既有 `push-dispatch` webhook 链路自动升级,零改造 |
| 5. 日历离线可读;未来 50 年数据放文件;建文件夹生成数据 | `tools/almanac/` 独立 Dart 生成器 → `app/assets/almanac/`(每年一个 JSON,2026–2075)+ 服务端数据 migration;农历/节日/十斋日展示**完全离线**(资产内置),仅"活动"仍需网络 |

---

## 2. 总体架构

```
tools/almanac/  (独立 Dart 包,开发期工具,不进 App)
  ├─ pubspec.yaml            依赖 6tail 官方 lunar 包
  ├─ bin/generate.dart       生成器入口:dart run bin/generate.dart
  ├─ lib/festivals.dart      ★精选节日配置(简繁名/短名/★重大/农历月日)——唯一人工维护点
  └─ README.md               再生成流程、校验锚点说明

        │ 生成(提交进库,重跑幂等)
        ▼
app/assets/almanac/
  ├─ festivals.json          节日目录(id→名称简繁/短名/major)
  └─ almanac_2026.json … almanac_2075.json   逐日农历+节日id+十斋日(每年≈6KB)

supabase/migrations/
  ├─ …_almanac_tz.sql        schema:almanac_days 表 + app_settings 表 + events.timezone
  │                          + generate_almanac_notifications() + pg_cron 排程
  └─ …_almanac_data.sql      生成器产出的节日/十斋日数据(仅特殊日,≈7500 行,幂等 upsert)

app/lib/core/almanac/        客户端佛历模块(跨 feature 共用)
  ├─ almanac.dart            模型 + 每年懒加载 loader(rootBundle,内存缓存)
  └─ lunar_format.dart       农历文案渲染(初八/廿三/正月/閏四月…,简繁两套)

消费方:
  · 日历页(格子副标签+当日佛历卡)          ← assets(离线)
  · 首页横幅(今日节日/十斋日)               ← assets(离线,匿名可见)
  · 通知中心(节日/十斋日通知,按开关过滤)     ← notifications 表(pg_cron 产)
  · 将来推送                                 ← 同一 notifications 行,push-dispatch 兜走
```

**为什么客户端不直接用 lunar 运行时算**(Q1 推荐 A 的理由):通知在服务端排程,Postgres 里无法跑农历算法,服务端反正需要一份预生成表;客户端再运行时算就成了两套数据源,节日清单也没法由内容方审定。单一生成器产两端数据,口径必然一致。

## 3. 数据生成器 `tools/almanac/`

### 3.1 输入与算法
- 依赖 pub 包 `lunar`(6tail 官方 Dart 版,与 lunar-javascript 同源算法)。
- 逐日遍历 2026-01-01 → 2075-12-31:`Solar.fromYmd(...).getLunar()` 取农历月/日/闰月;十斋日按 §0 口径判定(直接按农历日号集合,不依赖 Foto 对象,便于单测)。
- 节日:按 `lib/festivals.dart` 配置(农历月+日)匹配;**月末回退**:配置日为三十而当月只有廿九 → 落在廿九(如药师佛圣诞九月三十)。

### 3.2 输出格式

`app/assets/almanac/almanac_<year>.json`(紧凑,每年约 6KB):
```json
{
  "y": 2026,
  "days": [[11,13,0],[11,14,0], …],       // 按公历日序:[农历月, 农历日, 是否闰月]
  "fest": {"05-24": ["sakyamuni_birth"]}, // 公历MM-DD → 节日id列表
  "zhai": ["01-19","01-26", …]            // 十斋日的公历MM-DD
}
```

`app/assets/almanac/festivals.json`:
```json
[{"id":"sakyamuni_birth","m":4,"d":8,"hant":"釋迦牟尼佛聖誕(浴佛節)","hans":"释迦牟尼佛圣诞(浴佛节)","short_hant":"佛誕","short_hans":"佛诞","major":true}, …]
```

`supabase/migrations/<ts>_almanac_data.sql`(生成器产出,仅特殊日):
```sql
insert into public.almanac_days (solar_date, lunar_month, lunar_day, is_leap_month,
       festival_ids, names_hant, names_hans, is_zhai_ten, has_major)
values ('2026-05-24', 4, 8, false, '{sakyamuni_birth}',
        '{"釋迦牟尼佛聖誕(浴佛節)"}', '{"释迦牟尼佛圣诞(浴佛节)"}', false, true), …
on conflict (solar_date) do update set …;  -- 幂等,改清单后重新生成可覆盖
```

### 3.3 精选节日清单(Q2-A 初版;生成器配置,内容方可审改)

★ = 重大节日(提前一天预告 + `has_major`):

| 农历 | 节日 | ★ |
|---|---|---|
| 正月初一 | 彌勒菩薩聖誕 | ★ |
| 正月初六 | 定光佛聖誕 | |
| 二月初八 | 釋迦牟尼佛出家日 | ★ |
| 二月十五 | 釋迦牟尼佛涅槃日 | ★ |
| 二月十九 | 觀世音菩薩聖誕 | ★ |
| 二月廿一 | 普賢菩薩聖誕 | |
| 三月十六 | 準提菩薩聖誕 | |
| 四月初四 | 文殊菩薩聖誕 | |
| 四月初八 | 釋迦牟尼佛聖誕(浴佛節) | ★ |
| 四月廿八 | 藥王菩薩聖誕 | |
| 五月十三 | 伽藍菩薩聖誕 | |
| 六月初三 | 韋馱菩薩聖誕 | |
| 六月十九 | 觀世音菩薩成道日 | ★ |
| 七月十三 | 大勢至菩薩聖誕 | |
| 七月十五 | 佛歡喜日(盂蘭盆節) | ★ |
| 七月廿四 | 龍樹菩薩聖誕 | |
| 七月三十 | 地藏菩薩聖誕 | ★ |
| 八月廿二 | 燃燈佛聖誕 | |
| 九月十九 | 觀世音菩薩出家日 | ★ |
| 九月三十 | 藥師琉璃光如來聖誕(小月落廿九) | |
| 十月初五 | 達摩祖師聖誕 | |
| 十一月十七 | 阿彌陀佛聖誕 | ★ |
| 十二月初八 | 釋迦牟尼佛成道日(臘八) | ★ |
| 十二月廿九 | 華嚴菩薩聖誕 | |

### 3.4 正确性校验(生成时强制断言,错则拒绝产出)
- 锚点日期:2026 春节(正月初一)= 2026-02-17;佛诞(四月初八)/腊八等 3–5 个已知锚点核对。
- 结构断言:每年 days 数 = 365/366;十斋日每月 9–10 天;每个节日每年出现 0–1 次(闰月不重复计——**节日只落非闰月**,闰四月初八不是佛诞)。
- 生成器输出 sanity 报告(前 3 年节日对照表)供人工复核。

## 4. 客户端

### 4.1 `core/almanac/` 模块
- `AlmanacYear` 解析 JSON;`almanacYearProvider(year)` FutureProvider.family,rootBundle 懒加载+内存缓存;范围外年份返回 null(日历只是不显示农历,不报错)。
- `AlmanacDay { lunarMonth, lunarDay, isLeap, festivals, isZhaiTen }`;`todayAlmanacProvider` 按设备本地日期取当日。
- `lunar_format.dart`:数字→农历文案(初一…三十、正月…臘月、閏/闰前缀),简繁各一套(僅「臘/腊、閏/闰」有差异,其余同字)。**日历格子副标签**:初一显示月名(如「四月」),其余显示日名(如「初八」)——与通行农历日历一致。

### 4.2 日历页(`calendar_screen.dart`)
- `CalendarBuilders` 增加 `defaultBuilder/todayBuilder/selectedBuilder/outsideBuilder` 共用一个 `_DayCell`:日号 + 农历副标签(FittedBox 防大字号溢出);节日日副标签改为节日**短名**(金色);十斋日在格子右上角加小圆点(莲花色)。活动图标 marker 维持现状(底部)。
- 选中日的活动列表上方插入**当日佛历卡**:「農曆四月初八 · 釋迦牟尼佛聖誕(浴佛節)」/「十齋日」chip;无特殊内容时只显示一行农历日期(轻量灰字)。
- 日历可视范围维持 ±365 天,数据覆盖(至 2075)绰绰有余。

### 4.3 首页横幅(需求 2,"你来定"→ 顶部横幅方案)
- 位置:首页 ListView 最顶(「日課」区之上),登录/未登录都显示;当天无节日且非十斋日时**不渲染**(不占空间)。
- 样式:tonal 卡片(secondaryContainer 底、金色莲花图标 `Icons.spa`),单行两段文案:`今日 · 農曆四月初八` + 节日全名(或「十齋日」);同日多节日全列。点击 → `/calendar`。
- 数据来自资产,**离线/匿名可用**;跨零点重建(以设备本地日期为准)。

### 4.4 设置与通知过滤(Q3-A)
- 设置页「通知」区新增两个开关:**佛教節日提醒 / 十齋日提醒**,默认开,存 prefs(登录后随 profile 偏好同步机制走,与现有语言/字号同模式)。
- 通知中心 provider 端过滤:`type='almanac'` 的行按 `payload.kind`(festival/festival_eve/zhai)与开关决定是否展示与计入红点。将来 P2.1 推送侧同一偏好上云做服务端过滤(挂到既有「分类订阅」设计)。
- 通知文案客户端按 payload 渲染(既有模式):payload 携带 `kind / date / names_hant / names_hans / lunar{m,d}`,按当前语言取简繁。

## 5. 服务端

### 5.1 新表(migration `…_almanac_tz.sql`)
| 表 | 字段 | RLS |
|---|---|---|
| `almanac_days` | solar_date date PK, lunar_month, lunar_day, is_leap_month, festival_ids text[], names_hant text[], names_hans text[], is_zhai_ten bool, has_major bool | anon 可读(与 events 同口径);无人可写(仅 service/migration) |
| `app_settings` | key text PK, value text, updated_at | 所有人可读;仅 `is_app_admin()` 可写;seed:`default_event_timezone = 'Asia/Shanghai'` |
| `events` 加列 | `timezone text not null default 'Asia/Shanghai'`(IANA 名) | 沿用 events 现有策略 |

### 5.2 通知排程(pg_cron)
- 函数 `generate_almanac_notifications()`(security definer):取「UTC+8 的今天」对应 `almanac_days` 行 →
  - 有节日 → 插一条 `scope=all, type='almanac', payload{kind:'festival', …}`;
  - 是十斋日 → 插一条 `payload{kind:'zhai', …}`;
  - 「UTC+8 的明天」`has_major` → 插 `payload{kind:'festival_eve', …}` 预告。
  - **幂等**:payload 带 `date`,插入前 `not exists (type='almanac' and payload->>'date' = … and payload->>'kind' = …)`;cron 重跑/漏跑补跑都安全。
- 排程:`cron.schedule('almanac-daily', '5 16 * * *', …)`(16:05 UTC = UTC+8 次日 00:05);migration 内 `create extension if not exists pg_cron` 后注册,本地栈与生产一致。
- **与推送衔接**:P2.1 完成后 notifications insert → webhook → `push-dispatch`,本功能零改造;免打扰时段在 push 层处理(纪念日通知属非实时类,顺延)。

### 5.3 pgTAP
- almanac_days / app_settings 的 RLS(anon 读、非管理员写拒、管理员写 app_settings 通过);
- `generate_almanac_notifications()` 幂等(跑两次只产一套);已知节日日产出 festival + (前一日)eve 两类。

## 6. 时区设计(P2.10)

### 6.1 语义分层
| 对象 | 语义 | 存储 | 显示 |
|---|---|---|---|
| 佛历节日/十斋日 | **日期**(全天,全球同一天) | 公历日期 | 原样,不换算 |
| 活动(events) | **时刻** + 举办地时区 | `start_at timestamptz`(不变)+ `timezone`(新) | 用户设备时区;详情页加注活动当地时间 |
| 报数统计 | 报数人当日(`local_date`) | 不变 | 不变 |

### 6.2 管理员侧
- 活动编辑器:日期/时间选择器旁加**时区下拉**(常用 14 城清单:北京/台北/香港/新加坡/吉隆坡/东京/悉尼/奥克兰/洛杉矶/温哥华/纽约/多伦多/伦敦/巴黎,+「其他…」全 IANA 搜索);所选墙钟时间按该时区转 UTC 存 `start_at`,时区名存 `events.timezone`。
- 新建默认值:读 `app_settings.default_event_timezone`;管理员可在**设置页管理员区**改默认值(下拉同上)。
- 编辑既有活动:回显其时区,墙钟时间按该时区反算显示。

### 6.3 循环展开与 DST(正确性关键)
- 现状 bug 级缺陷:`FREQ=WEEKLY` 按「首次 UTC 时刻 +7×24h」展开,若活动定在洛杉矶 19:00,夏令时切换后会漂移 1 小时。
- 改造:`expandOccurrences` 在**活动时区**做日历算术——用 `timezone` 包(已在依赖里)`TZDateTime(loc, y, m, d+7, hh, mm)` 逐周生成,保持当地墙钟不变;再转本地显示。存量活动 default `Asia/Shanghai` 无 DST,行为与现状完全一致(无回归)。
- pg_cron 侧将来展开 occurrence(P2.1)同理在活动时区算,本设计先落客户端与数据模型。

### 6.4 用户侧(Q4-A)
- 显示一律设备时区(现状);活动详情页当 `events.timezone` 的当地时间 ≠ 设备显示时间时,加注一行:「活動當地時間 19:00(洛杉磯)」。
- 不做手动固定时区设置(改选 Q4-B 时:加 `profiles.timezone` 设置项 + 全局 display provider,纯增量)。

## 7. 边界与已知取舍
- 农历/节日数据覆盖 **2026–2075**;范围外日历仅无农历副标签,不报错。50 年后重跑生成器续期。
- 节日清单改动需重新生成 + 发版(客户端资产);服务端表可单独重跑 data migration 先行生效(通知先对、格子随发版对)。
- 闰月不过节(节日只匹配非闰月);十斋日闰月照常(每个农历月都有斋日)。
- 通知依赖 pg_cron 在生产实例启用(P0.2 部署时验证);本地栈由 migration 一并注册,可手动 `select generate_almanac_notifications()` 验证。
- 横幅/格子文案长度受大字号(×2.0)约束:节日短名 ≤4 字,横幅两行封顶,走 `layout_walkthrough_test` 回归。

## 8. TODO List(执行跟踪;完成即勾选)

### A. 定案与文档
- [x] A1 设计文档(本文)
- [ ] A2 用户拍板 Q1–Q4(未答复按推荐实现;若改选,更新本文 §0 与受影响小节)
- [ ] A3 PRD 升 v0.5.15:§5 佛教日曆小节 + 跨时区补充;§12.2 新表/新列;§12.4 cron 任务
- [ ] A4 PLAN 增补 P2.9 / P2.10 任务与外部依赖 E15(节日清单内容方审定,非阻塞)

### B. 数据生成器(P2.9-1)
- [ ] B1 `tools/almanac/` Dart 包骨架(pubspec 依赖 `lunar`,README 再生成流程)
- [ ] B2 精选节日配置 `lib/festivals.dart`(§3.3 清单,简繁+短名+★)
- [ ] B3 生成逻辑:逐日农历、十斋日、节日匹配(含九月三十小月回退、闰月不过节)
- [ ] B4 校验断言 + 锚点(§3.4)+ sanity 报告
- [ ] B5 产出并提交:`app/assets/almanac/*.json`(51 个文件)+ `…_almanac_data.sql`
- [ ] B6 pubspec assets 注册 `assets/almanac/`

### C. 服务端(P2.9-2 / P2.10-1)
- [ ] C1 migration `…_almanac_tz.sql`:almanac_days + app_settings(seed 默认时区)+ events.timezone + RLS
- [ ] C2 `generate_almanac_notifications()`(幂等)+ pg_cron 注册
- [ ] C3 pgTAP:两表 RLS + 函数幂等/产出(§5.3),`supabase test db` 全绿
- [ ] C4 本地栈 `db reset` 全链路验证(手动调函数 → 通知中心可见)

### D. 客户端佛历(P2.9-3)
- [ ] D1 `core/almanac/`:模型、每年懒加载 provider、农历文案渲染(简繁)+ 单测(初一→月名、廿三、閏月、边界年)
- [ ] D2 日历格子:农历副标签 + 节日短名(金色)+ 十斋日角点;大字号不溢出
- [ ] D3 当日佛历卡(选中日,农历全称+节日全名+十斋日 chip)
- [ ] D4 首页横幅(§4.3;匿名可见、无特殊日不渲染)+ 纯函数单测(文案拼装/多节日)
- [ ] D5 设置页两个提醒开关 + 通知中心 `type=almanac` 渲染与过滤(红点同步)+ 单测
- [ ] D6 l10n 三份 ARB 新增键(横幅/斋日/开关/时区标注等,约 15 键)

### E. 活动时区(P2.10-2)
- [ ] E1 活动编辑器时区选择器(常用清单+搜索全 IANA;新建默认读 app_settings;编辑回显)
- [ ] E2 设置页管理员区「活動預設時區」编辑项
- [ ] E3 `expandOccurrences` 改为活动时区日历算术展开(timezone 包);DST 单测(洛杉矶跨 3/11 月保持 19:00)+ 存量回归单测(Asia/Shanghai 行为不变)
- [ ] E4 活动详情页「活動當地時間」加注(时区异于设备时显示)
- [ ] E5 tz 数据初始化复用 reminders 已有 `initializeTimeZones()`(提为 app 启动共用)

### F. 收尾
- [ ] F1 `flutter analyze` 0 issue + `flutter test` 全绿 + pgTAP 全绿(`scripts/check.ps1`)
- [ ] F2 大字号走查:日历格子/横幅/佛历卡进 `layout_walkthrough_test`(简繁 × 2.0)
- [ ] F3 真机走查:横幅显示、日历农历/节日、管理员建跨时区活动、通知中心收到节日通知(本地栈手动触发)
- [ ] F4 PLAN 勾选与进度计数更新;本文档状态改「已实现」并记录偏差

## 9. 验收标准(DoD)
1. 日历任意月份每格显示农历;节日/十斋日按 §4.2 呈现;完全离线可用(飞行模式验证)。
2. 佛诞等锚点日期与通行万年历一致(§3.4 锚点全过)。
3. 当天为节日/十斋日时,打开 App 首页顶部可见横幅,点击进日历。
4. 本地栈手动执行排程函数后,通知中心出现当日节日/十斋日通知;重复执行不产生重复通知;设置开关可分别隐藏两类。
5. 管理员建活动可选时区、默认值可配;洛杉矶每周活动跨 DST 各场次当地时间不变;设备换时区显示正确换算。
6. `flutter analyze`/`flutter test`/pgTAP 全绿;简繁 × 2.0 字号无溢出。
