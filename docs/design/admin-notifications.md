# 管理员发布通知 + 首页管理区 · 设计

> 状态:**已实现并真机验证(2026-07-18)**;定案 = 核心 + 已排程列表 + 撤回 · PRD v0.5.16 · PLAN P2.11
> 复用现有通知基建:`notifications` 表(scheduled_at/type=general)、通知中心 general 渲染、
> push-dispatch(分钟级 cron 对 scheduled_at 到点投递)——本功能只补入口、界面与安全写入通道。

## 1. 定案范围

- **首页「管理」分组**:仅 `is_app_admin` 可见(普通用户不渲染),放在「通用」区之前;首批两格:**發布通知**(新)+ **檢舉處理**(自设置页迁入,设置页原入口移除;「預設活動時區」属设置项,留在设置页)。
- **发布界面** `/admin/notify`:標題(必填)+ 內容(多行);「定時發送」开关(关=立即;开=日期+时间选择器,按管理员设备本地时间,界面明示);提交前**预览确认弹窗**(全员通知,误发代价高)。
- **已排程列表**(同页):未发送的定时通知(`sent_at is null and scheduled_at > now()`),可**取消**;
- **撤回已发**(同页):近期已发送的 general 通知列表,可**撤回**(删行,级联清 reads,所有人通知中心消失;已弹出的手机推送无法收回——界面注明)。
- **不做**(本轮定案):简繁双语输入、点击跳转、指定群范围、发送历史统计、仅App内不推送、周期重复(循环提醒走活动日历机制)。

## 2. 技术设计

- **写入通道**:notifications 维持「客户端不可直写」;新增两个 security definer RPC(migration 0015):
  - `admin_publish_notification(p_title, p_body, p_scheduled_at default null) → uuid`:校验 `is_app_admin()`;insert(scope=all, type=general, channels={inapp});立即发的由既有 insert 触发器秒级推送,定时的由 cron 到点投递(sent_at 抢占语义天然支持,零改动)。
  - `admin_cancel_notification(p_id)`:校验管理员;**仅限 type='general'** 的行可删(防误删系统生成的代报/活动类通知);排程取消与已发撤回同一个 RPC(删行)。
- **既有小漏洞修复**:通知中心查询目前不看 scheduled_at,定时通知会提前出现在用户通知中心。修法:`myNotificationsProvider` 查询加 `or(scheduled_at.is.null, scheduled_at.lte.now)`(红点随 visible 派生自动正确)。注:RLS 层不拦截未来行,仅查询层过滤——通知内容非敏感,接受;管理员排程列表正需要读到未来行(scope=all 对登录用户可读)。
- **客户端**:`features/moderation/admin_notify_screen.dart`(表单+两列表);路由 `/admin/notify`;首页 `管理` 分组(myProfileProvider.is_app_admin);l10n 三份 ARB。
- **时区**:scheduled_at 为 timestamptz,选择器按管理员设备本地时间,界面标注「按您的時間」——通知是时刻不是墙钟事件,不引入活动的显式时区机制。

## 3. TODO

- [x] T1 设计定稿(本文)+ PRD v0.5.16 + PLAN P2.11
- [x] T2 migration 0015:两个 RPC + pgTAP(管理员可发/普通用户拒;取消仅限 general;定时行 sent_at 为空)
- [x] T3 发布界面(表单/定时/预览确认/排程列表/撤回)+ 路由 + l10n
- [x] T4 首页管理分组 + 檢舉處理迁入(设置页移除原入口)
- [x] T5 通知中心过滤 scheduled 未到点行(修复提前可见)
- [x] T6 质量门(analyze/test/pgTAP)+ 真机走查(发即时→秒级收推送;发定时→列表可见可取消;撤回→中心消失)
