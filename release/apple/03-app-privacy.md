# Apple ③ App Privacy(隐私营养标签)

> 位置:App Store Connect → **App Store → App Privacy**
> 先填 Privacy Policy URL,再逐个数据类型勾选。下表是按 App 代码实际行为核对过的答案。

## 0. Privacy Policy URL

✏️ 填官网上线后的地址,例如 `https://www.pure-thoughts.com/privacy`(内容见 `../shared/隐私政策.md`)。
两个本地化(繁/简)可以填同一个 URL。

## 1. 第一问:Do you or your third-party partners collect data from this app?

**答:Yes**(收集账号与修行记录)。

## 2. 逐个数据类型

下面只列**要勾**的;未列出的类型一律不勾(位置、健康、财务、联系人、照片、搜索历史、
浏览历史、购买记录、敏感信息、广告数据……本 App 都不收集)。

| 数据类型 | 勾选 | 用途 Purpose | 是否关联身份 | 是否用于追踪 | 依据 |
|---|---|---|---|---|---|
| **Contact Info → Email Address** | ✅ | App Functionality | **Linked** | No | 邮箱为选填,仅用于找回密码 |
| **Contact Info → Name** | ✅ | App Functionality | **Linked** | No | 显示名;代报时可填他人姓名 |
| **User Content → Other User Content** | ✅ | App Functionality | **Linked** | No | 报数备注、自定义功课项名称、学修问答消息、举报内容 |
| **Identifiers → User ID** | ✅ | App Functionality | **Linked** | No | 账号 ID(Supabase auth uid) |
| **Identifiers → Device ID** | ✅ | App Functionality | **Linked** | No | APNs / FCM 推送令牌,仅用于送达通知 |
| **Diagnostics → Crash Data** | ✅ | App Functionality | **Not Linked** | No | Sentry;未设置 user context,不关联账号 |
| **Diagnostics → Performance Data** | ✅ | App Functionality | **Not Linked** | No | 同上 |

> **Other Diagnostic Data**:不勾。
> **Usage Data → Product Interaction**:不勾 —— App 没有接任何行为分析 SDK。
> **Health & Fitness**:不勾 —— 打坐時長是修行记录,不是 HealthKit 健康数据,也不写入健康 App。

## 3. Tracking(追踪)

**答:No** —— App 不做跨 App / 跨网站追踪,不接广告 SDK,不使用 IDFA,
因此**不需要** App Tracking Transparency 弹窗。

## 4. 数据删除(Apple 会核对)

| 问题 | 答案 |
|---|---|
| 用户能否请求删除数据 | 能,App 内「設定 → 刪除帳號」直接删除,无需邮件申请 |
| 删除后如何处理 | 账号与个人资料永久删除;历史报数**匿名化保留**(reporter/subject 置空、显示名替换),用于维持共修总量,无法反推到个人 |

> 这条是 Apple Guideline 5.1.1(v) 的硬性要求,已实现(`delete-account` Edge Function)。
> 审核员通常会真的点进去试,所以演示账号要能走到这一步——**但请提醒审核员不要真的删**,
> 备注文案已在 `04-app-review-information.md` 写好。

## 5. 一致性自检(填之前对一遍)

- [ ] 隐私政策里列出的数据类型 = 这里勾选的类型(两边不一致是常见拒审理由)
- [ ] Play 的 Data safety 表(`../google-play/03-data-safety.md`)与本表口径一致
- [ ] 如果以后接入了行为分析或广告 SDK,必须回来改这一页
