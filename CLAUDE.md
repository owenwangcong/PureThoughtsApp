# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

**善护念 / PureThoughts** — 面向全球华人共修团体的功课报数与学修一体化 App。

- **客户端**:Flutter(iOS + Android 一套代码)
- **后端**:**自托管 Supabase**(Auth / Postgres+RLS / Edge Functions / pg_cron / Realtime),机房选境外(香港/新加坡/东京),**严禁放中国大陆境内**
- **用户特点**:约 1/3 在中国大陆(网络受限);年龄跨度大(大字体、简洁交互)

## 事实来源(每次会话先读)

- **需求**:`docs/PRD.md`(当前 v0.5.1)是唯一需求事实来源,已五轮澄清定稿。改需求先改 PRD,再动代码。
- **执行计划与进度**:`docs/PLAN.md` 是唯一执行事实来源。**每次会话开工先读其 §1 进度总览**,从当前 Phase 按编号领取任务;完成即勾选并更新总览计数;Phase 需通过 DoD 才能进入下一个;阻塞标 ⛔ 并登记 PLAN §7。**新任务必须先写入 PLAN(需求性变更还要先进 PRD)再实现。**
- `initial.md` 是最初的原始需求,仅作历史参考,与 PRD 冲突时以 PRD 为准。

## 已定案决策(勿重新讨论,详见 PRD §14)

- **文化基调:随喜、不攀比** —— 全 App 不做任何成员间排名/对比;个人明细仅本人可见,群只展示总量。连续用功天数仅自己可见,中断不做"断签"提醒。
- **统计口径**:每条报数落库时按报数人时区计算 `local_date`,所有按日统计一律以 `local_date` 聚合(个人与群同一口径)。补报统一计入报数当天,不归属历史日期。
- **报数记录**:软删除(`deleted_at`);本人可改删,被代报人可删,群主可删本群任意记录。
- **代报**:对象 = 群成员 / 本群共享代报名单(`proxy_names`,自动记忆自由名字)/ 任意新名字;自由名字仅计入群总量。代报群成员会通知对方。
- **推送**:APNs 原生直连(iOS 含大陆)+ FCM(仅海外 Android)+ **App 内通知中心(拉取式,大陆 Android 唯一通道,刚需)** + 邮件兜底;**不接国内厂商推送**。
- **账号删除**(MVP,上架硬性要求):删账号但报数记录匿名化保留,群总量不变。
- **UGC 举报/拉黑**(MVP,上架硬性要求)。
- **计数器只用屏幕按钮**(不用音量键,避免 iOS 拒审);念诵音频从内容方 HTTPS endpoint 下载(不放 Supabase Storage)。
- 语言:UI 维护 `zh_Hant` / `zh_Hans` 双语文案,**默认繁体**。

## 架构要点

- **安全模型**:客户端只持有 anon key;全表启用 RLS(策略见 PRD §12.3);`service_role` 只存在于 Edge Functions。**入群不直读 `groups.join_code`**,走 RPC `join_group(code, message)` 防遍历。
- **Edge Functions**(PRD §12.4):`push-dispatch`(APNs/FCM 投递)、`email-fallback`(大陆用户邮件兜底)、`delete-account`、`qa-proxy`(讲法问答 API 代理,接口待定)。
- **pg_cron 链路**:每日展开未来 14 天循环活动(RRULE + `event_overrides`)→ 生成 `notifications` → 到点触发投递。
- **数据模型**:见 PRD §12.2;统计走 `daily_user_stats` / `daily_group_stats` 视图,客户端不拉全量记录。
- **客户端关键库**:Riverpod、go_router、supabase_flutter、just_audio + audio_service(后台播放)、youtube_player_iframe、webview_flutter、table_calendar、sentry_flutter;iOS 推送为原生 APNs 注册(不经 FCM),firebase_messaging 仅用于海外 Android。

## 目录约定

- `docs/` — 需求与设计文档(PRD / PLAN)
- `app/` — Flutter 工程(package `pure_thoughts`,org `com.purethoughts`,iOS + Android)
  - `lib/core/` 环境与设置 · `lib/features/<模块>/` 按功能分目录 · `lib/l10n/` ARB(zh_Hant 模板)
  - 环境经 `--dart-define`(SUPABASE_URL / SUPABASE_ANON_KEY / SENTRY_DSN),默认本地栈;Android 模拟器用 `http://10.0.2.2:54321`
- `supabase/migrations/` — 数据库 migration SQL;`supabase/tests/` — pgTAP;`supabase/functions/` — Edge Functions(本地栈自动 serve;**新增函数后需 `npx supabase stop && start` 重载**)

## 常用命令

### Supabase 本地开发栈(Docker,已配置)

开发测试一律先对本地栈进行;migration 本地验证后再推自托管生产实例(见 PLAN P0.0 策略)。

```sh
npx supabase start     # 启动本地全栈(需 Docker Desktop 运行)
npx supabase stop      # 停止(数据保留;--no-backup 清数据)
npx supabase status    # 查看本地 API URL / anon key / Studio 地址
npx supabase db reset  # 重建本地库并按顺序执行 supabase/migrations/*.sql + seed.sql
npx supabase test db   # 运行 pgTAP 测试(supabase/tests/*.sql,改 schema 后必须全绿)
npx supabase migration new <name>   # 新建一个 migration 文件
```

本地测试账号(seed 自动创建,密码均 `test1234`):`admin@test.local`(App 管理员)、`owner@test.local`(測試共修群群主)、`member@test.local`(已入群成员)、`user@test.local`(未入群)。测试群 join code 固定 `TESTGRP2`。

### Flutter(工程创建后适用)

```sh
cd app
flutter pub get          # 安装依赖
flutter analyze          # 静态检查(提交前必须无 error)
flutter test             # 全部测试
flutter test test/xxx_test.dart   # 单个测试文件
flutter run              # 运行(需连接设备/模拟器)
flutter gen-l10n         # 生成简繁本地化(配置后)
```

## 工作约定

- 分支与提交:每个 PLAN 任务开 feature 分支(如 `feature/p1-6-practice-log`),commit 信息以任务编号开头(如 `P1.6: 代报三来源选择器`)。
- 代码任务完成底线:`flutter analyze` + `flutter test` 全绿(PLAN §8)。
- 与用户交流使用中文;文档以简体中文书写,App 内文案需同时维护简/繁两套。
- Windows 开发环境(PowerShell);路径注意反斜杠与大小写。
- 修改涉及需求的行为前,先核对 PRD 对应章节;PRD 未覆盖的新需求,先补 PRD 条目(标注版本号)再实现。
