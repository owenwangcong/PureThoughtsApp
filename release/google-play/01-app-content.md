# Google ① App content — Dashboard「Set up your app」十项任务

> 位置:Play Console → 你的 App → **Dashboard → Set up your app**(截图里那串任务)
> 以及 **Policy and programmes → App content**。逐项照抄即可。

## 任务对照表

| # | 任务 | 本文档章节 | 状态 |
|---|---|---|---|
| 1 | Set privacy policy | §1 | 需先把政策发到官网 |
| 2 | Sign in details(App access) | §2 | 需先建演示账号 |
| 3 | Ads | §3 | 直接答 |
| 4 | Content rating | `04-content-rating.md` | 问卷 |
| 5 | Target audience | §4 | 直接答 |
| 6 | Data safety | `03-data-safety.md` | 逐项 |
| 7 | Government apps | §5 | 直接答 |
| 8 | Financial features | §6 | 直接答 |
| 9 | Health | §7 | 直接答 |
| 10 | Select app category and contact details | §8 | 部分待填 |
| 11 | Set up your store listing | `02-store-listing.md` | 文案 + 素材 |

---

## §1 Privacy policy

| 字段 | 值 |
|---|---|
| Privacy policy URL | ✏️ `https://www.pure-thoughts.com/privacy`(内容见 `../shared/隐私政策.md`) |

要求:公网可访问、不能要求登录、必须提到 App 名称与实际收集的数据。上面那份已按 App
实际行为写好,发上去即可。

---

## §2 App access(Sign in details)

选 **All or some functionality is restricted**,然后添加一条访问说明:

| 字段 | 填什么 |
|---|---|
| Name of instructions | `Practice log (login required)` |
| Username | `appreview` |
| Password | `PureThoughts-Review-2026!`(与 Apple 审核账号同一个,已在生产环境建好并铺了演示数据,详见 `../apple/04-app-review-information.md`) |
| Any other instructions | 见下方整段 |

```
Sign in from the top-right "登入" on the home screen.

Anonymous users can browse the home screen, the event calendar, the livestream page, the
online scripture library and settings. Logging a practice entry, personal statistics, vows
and notifications require an account.

The appreview account already contains sample practice entries, a vow in progress and a
Q&A thread, so every screen has content.

Account deletion is at 設定 (Settings) → 刪除帳號 (Delete account). It performs a real
deletion — please do not delete the appreview account itself.
```

---

## §3 Ads

| 问题 | 答案 |
|---|---|
| Does your app contain ads? | **No** |

App 无任何广告 SDK、无插屏、无激励视频。商店页因此不会显示「Contains ads」标签。

---

## §4 Target audience and content

| 字段 | 答案 | 说明 |
|---|---|---|
| Target age groups | **18 and over**(仅勾这一档) | App 面向共修团体的成年信众;勾选任何 13 岁以下年龄段都会触发 Families 政策(需要额外的儿童合规、广告限制、隐私加严),本 App 没必要 |
| Do you want your app available to children? | No | 同上 |
| Store presence: appeals to children? | No | 视觉与文案均为成人向宗教修行工具 |

> 若你希望 13–17 岁也能用,可加勾 `13-15` / `16-17`,但要确认 UGC 治理措施足够
> (本 App 有举报/拉黑/管理员封禁,通常可以)。**最省事是只勾 18+。**

---

## §5 Government apps

| 问题 | 答案 |
|---|---|
| Is your app a government app? | **No** |

本 App 由民间共修团体运营,不代表任何政府机构。

---

## §6 Financial features

| 问题 | 答案 |
|---|---|
| Does your app provide any financial features? | **No — My app doesn't have any financial features** |

App 无支付、无捐款、无借贷、无加密货币、无保险、无投资功能。**注意:如果将来加了
「随喜捐款」入口,这里必须回来改,并可能触发 Play 的金融类附加要求。**

---

## §7 Health

| 问题 | 答案 |
|---|---|
| Does your app have health features? | **No**(不勾任何健康功能) |

判断依据:打坐計時只是计时器与铃声,不提供健康建议、不做健康测量、不接 Health
Connect、不写入任何健康数据。冥想类功能只有在宣称健康疗效或读写健康数据时才算
health app —— 本 App 两者都没有。

---

## §8 App category and contact details

| 字段 | 填什么 |
|---|---|
| App or game | **App** |
| Category | **Lifestyle** |
| Tags | 从 Play 提供的标签里挑 3 个,建议:`Religion & Spirituality`、`Personal Growth`、`Journaling`(可选项随 Play 更新,挑最接近的) |
| Store listing contact — Email | ✏️ 必填,公开显示 |
| Store listing contact — Phone | ✏️ 选填,不建议填个人手机 |
| Store listing contact — Website | ✏️ `https://www.pure-thoughts.com` |
| External marketing | 按实际情况(一般不勾) |

---

## §9 其他必答但常被忽略的声明

| 项目 | 位置 | 答案 |
|---|---|---|
| Data deletion(账号与数据删除) | App content → Data safety 内 | 提供 App 内删除:`設定 → 刪除帳號`;另需提供一个**网页版删除说明**链接(可与隐私政策同页,写明删除路径) |
| Advertising ID | Data safety / Manifest | App **不使用** advertising ID;`AndroidManifest` 无 `AD_SERVICES` 相关声明 |
| News app | App content | No |
| COVID-19 contact tracing | App content | No |
| Data safety 表 | 见 `03-data-safety.md` | 必须与隐私政策一致 |
| Target API level | 自动检查 | Play 要求新 App 满足当前最低 target SDK;Flutter 默认已跟进,构建后看 Play 的告警 |
