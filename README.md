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

需求定稿(PRD v0.5.1),代码尚未开工。执行按 [`docs/PLAN.md`](docs/PLAN.md) 推进:当前处于 **P0 基础设施**(自托管 Supabase 部署 + DB schema + Flutter 骨架),进度见 PLAN §1 总览。
