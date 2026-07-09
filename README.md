# 善护念 PureThoughts

面向全球华人共修团体的功课报数与学修一体化 App(iOS + Android)。

核心功能:分群报数与统计(不排名、随喜不攀比)、通知/活动/日历、直播与回看、在线经本、念诵导引音视频、打坐计时/念珠计数工具。

## 技术栈

- **客户端**:Flutter(单代码库,iOS + Android)
- **后端**:自托管 Supabase(Auth / Postgres+RLS / Edge Functions / pg_cron / Realtime)
- **推送**:APNs(iOS 原生直连)+ FCM(海外 Android)+ App 内通知中心(大陆 Android 兜底)

## 文档

| 文件 | 说明 |
|---|---|
| [`docs/PRD.md`](docs/PRD.md) | **产品需求文档(唯一需求事实来源,当前 v0.5.1)** |
| [`docs/PLAN.md`](docs/PLAN.md) | **执行计划与进度(唯一执行事实来源:Phase 拆解 / 任务清单 / DoD / 外部依赖)** |
| [`initial.md`](initial.md) | 最初原始需求(历史参考) |
| [`CLAUDE.md`](CLAUDE.md) | Claude Code 工作指引与已定案决策摘要 |

## 仓库结构(规划)

```
docs/                  需求与设计文档
app/                   Flutter 工程(待创建)
supabase/migrations/   数据库 migration SQL(待创建)
supabase/functions/    Edge Functions(待创建)
```

## 当前状态

**功能开发基本完成**(PRD v0.5.8):MVP 核心闭环(群/报数/统计/发愿/合规)、通知中心、活动日历(动态类型+变更通知)、工具(计时/计数)、直播(YouTube 开播检测+App 内播放)、Webex 应用内会议、在线经本、宣纸+古铜金双主题。本地开发栈 + 真机验证全绿(Flutter 33 项 + pgTAP 49 项测试)。

**待外部依赖**(PLAN §2):生产服务器(E1)、Apple 开发者账号(E3)、Firebase(E4)、发信服务(E5)、Codemagic 配置(E13)——解锁生产部署、推送、TestFlight 与分发。进度详见 [`docs/PLAN.md`](docs/PLAN.md) §1。
