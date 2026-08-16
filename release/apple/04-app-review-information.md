# Apple ④ App Review Information(审核信息)

> 位置:版本页最下方 **App Review Information**
> 这一页决定审核顺不顺。演示账号 + 备注写清楚,能省掉一到两轮来回。

## 1. Sign-In Information

> ⚠️ 本节含审核账号密码。仓库请保持私有;上架完成后可改密并同步更新两端控制台。

| 字段 | 填什么 |
|---|---|
| Sign-in required | ✅ **Yes** |
| Username | `appreview` |
| Password | `PureThoughts-Review-2026!` |

### 账号状态 ✅ 已在生产环境建好(2026-08-13)

| 项 | 值 |
|---|---|
| 登录用户名 | `appreview`(App 内部映射为 `appreview@u.pure-thoughts.com`) |
| 用户 ID | `a7a6449f-2c72-4c8d-a53a-db67529337ca` |
| 显示名 | `App Review` |
| 时区 | `Asia/Hong_Kong` |
| 共修体成员 | 已自动入会(status=approved,role=member) |
| 登录实测 | ✅ `POST /auth/v1/token?grant_type=password` 返回 200 |

### 已铺好的演示数据

| 页面 | 数据 |
|---|---|
| 個人統計 / 共修報數 | 10 条报数:心經 1 部 × 近 5 天(连续)、大悲咒 7 遍 × 3 天、靜坐 20 分鐘 × 2 天 → **连续用功天数 5**,趋势图与今日卡片都不空 |
| 發願 | 心經 100 部 / 100 天,进行中(已完成 5 部,进度条约 5%) |
| 學修問答 | 一个会话:提问「打坐時妄念紛飛……」+ 管理员「果明」的回覆 |
| 通知中心 | 1 条 `qa_reply` 通知(问答有回覆) |

**审核期间不要删这个账号、不要改密码。** 上线后保留,供后续版本审核复用。

### 审核通过后如何清理演示数据(可选)

这些报数会计入共修总量(新增合计 66,总量 321 → 387)。若想在上线后把它们从统计里
拿掉,软删即可(App 的统计一律排除 `deleted_at` 非空的行):

```sql
-- 在生产库执行;只影响 appreview 自己的记录
update public.practice_logs
   set deleted_at = now()
 where reporter_id = 'a7a6449f-2c72-4c8d-a53a-db67529337ca'
   and deleted_at is null;
```

> 建议**等 iOS 与 Android 都上线之后**再清,后续版本审核还会用到同一个账号。
> 发愿与问答会话可以留着,它们不进共修总量。

## 2. Contact Information

| 字段 | 填什么 |
|---|---|
| First / Last Name | ✏️ |
| Phone Number | ✏️(带国家码,审核员极少打，但必填) |
| Email | ✏️(用能收到信的邮箱,拒审沟通走这里) |

## 3. Notes(审核备注)——整段复制

**英文版(建议用这份)**

```
About the app
PureThoughts is a daily practice log for a Buddhist practice group. Members record what
they chanted, recited or meditated each day; the app aggregates the group's total. The
group view shows aggregate totals only — the app provides no per-member ranking or
comparison feature.

Demo account
Username: appreview
Password: <see Sign-In Information above>
Sign in from the top-right "登入" on the home screen. The account already contains sample
entries, a vow in progress and a Q&A thread so every screen has content.

Where to find the review-relevant features
• User-generated content: practice notes, custom practice item names, display names, and
  Q&A messages.
• Report: 共修報數 (Group Log) → any entry's overflow menu → 檢舉 (Report).
• Block a user: same menu → 封鎖 (Block).
• Community guidelines + EULA: shown on first launch and under 設定 (Settings) → 隱私與條款.
• Account deletion: 設定 (Settings) → 刪除帳號 (Delete account) → confirm. This performs a
  real deletion. Please DO NOT delete the appreview account itself, or later review rounds
  will lose access — you can verify the flow up to the confirmation dialog.

Web views
The app opens exactly three fixed external destinations: the group's public YouTube channel
(livestream and replays), a Webex meeting room used for the group's weekly session, and an
online Buddhist scripture library (qldazangjing.com). There is no address bar and no
general-purpose browsing.

Notifications
Push notifications carry event reminders (weekly group practice, meditation evenings),
replies in Q&A, and livestream start alerts. Users can mute categories and set a
do-not-disturb window in Settings.

No monetisation
The app is entirely free: no in-app purchases, no subscriptions, no advertising, no
donation or payment flow of any kind.

Religious content
Content is devotional material of a Buddhist practice group (sutra names, a dedication
verse, festival dates). It does not disparage any group or belief.
```

**中文版(如需)**

```
关于本 App
善護念是一个共修团体的每日功课记录工具:成员记录当天诵经、念佛、打坐的数量,App 汇总
共修总量。全体视图只显示汇总数据,App 不提供成员之间的排名或对比功能。

演示账号
用户名:appreview 密码:见上方 Sign-In Information
在首页右上角「登入」进入。该账号已有示例记录、一条进行中的发愿与一个问答会话,
每个页面都有内容可看。

审核关注点在哪
• 用户生成内容:报数备注、自定义功课项名称、显示名、学修问答消息。
• 举报:共修報數 → 任一条目菜单 → 檢舉。
• 拉黑:同一菜单 → 封鎖。
• 社区规范与用户协议:首次启动引导页,以及 設定 → 隱私與條款。
• 账号删除:設定 → 刪除帳號 → 二次确认(真实删除)。请勿真的删除 appreview 账号,
  否则后续版本审核会无法登录;走到确认弹窗即可验证该流程存在。

WebView 用途
只打开三个固定目的地:团体公开 YouTube 频道(直播与回看)、每周共修用的 Webex 会议室、
在线经本站点 qldazangjing.com。没有地址栏,不能任意浏览网页。

推送
推送内容为活动提醒(周六共修、周三打坐)、问答回复、直播开始。用户可在设置中按分类
静音,并设置免打扰时段。

无任何商业化
完全免费:无内购、无订阅、无广告、无捐款或支付流程。

宗教内容
内容为该共修团体的修行资料(经名、回向偈、佛教节日),不贬损任何团体或信仰。
```

## 4. Attachment(附件)

一般不需要。若审核员对「代报」或「删除账号」流程有疑问,可再补一段录屏。

## 5. 常见拒审点自查(本 App 已覆盖)

| Guideline | 要求 | 现状 |
|---|---|---|
| 1.2 UGC | 举报 + 拉黑 + 过滤 + EULA | ✅ 全部已实现 |
| 5.1.1(v) | 应用内删除账号 | ✅ 設定 → 刪除帳號 |
| 5.1.1 | 不强制索取无关权限 | ✅ 相机/麦克风仅在 Webex 会议时申请;通知权限带说明 |
| 4.2 | 最低功能门槛 | ✅ 报数/统计/日历/工具/问答,功能充分 |
| 3.1.1 | 不得绕过 IAP | ✅ 无任何支付与捐款入口 |
| 2.1 | 演示账号可用 | ⚠️ 提交前务必按上面 §1 建好并实测登录 |
| 5.1.2 | 代报他人数据 | ✅ 代报会通知被代报人,被代报人可自行删除该记录 |
