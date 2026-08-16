# Google ④ Content rating(IARC 内容分级问卷)

> 位置:Play Console → **Policy and programmes → App content → Content rating**
> 填完会一次性生成 ESRB / PEGI / USK / IARC 等多地区分级。答案必须与 App 实际一致,
> 事后被发现不符会被下架。

## 1. 前置

| 字段 | 填什么 |
|---|---|
| Email address | ✏️(接收分级证书) |
| Category | **Utility, Productivity, Communication, or Other**(工具/效率类) |

> 不要选 Social Networking —— 本 App 无用户间私信、无好友/关注、无动态互动;
> 选社交类会触发更严的问卷分支与更高分级。

## 2. 问卷答案(逐题)

| 问题分组 | 问题 | 答案 |
|---|---|---|
| Violence | 是否含暴力内容 | No |
| Sexuality | 是否含性内容/裸露 | No |
| Language | 是否含粗俗语言 | No |
| Controlled substance | 是否涉及酒精/烟草/毒品 | No |
| Gambling | 是否含赌博或模拟赌博 | No |
| **Miscellaneous** | App 是否允许用户互相**交流**(聊天、留言、消息)? | **No** — 学修问答是用户↔管理员的一对一问答,用户之间不能互发消息 |
| Miscellaneous | 用户是否能**分享**自己创建的内容给其他用户? | **Yes** — 报数记录(功课项、数量、显示名)对团体内其他用户可见 |
| Miscellaneous | 用户是否能分享**位置**? | No |
| Miscellaneous | App 是否允许购买数字商品? | No |
| Miscellaneous | App 是否显示用户的**个人信息**给他人? | Yes — 仅显示名(用户自设,可为法名/昵称) |
| Miscellaneous | 是否含**用户生成内容**且提供**举报/管理**机制? | Yes,且有举报、拉黑、管理员删除与封禁 |
| Miscellaneous | 是否为新闻类 App | No |

## 3. 预期分级

按上表回答,通常得到:

| 机构 | 预期 |
|---|---|
| IARC 综合 | **3+ / Everyone**(若因 UGC 分享题被提到 **Teen / 12+** 也属正常) |
| ESRB(美加) | Everyone 或 Teen |
| PEGI(欧洲) | 3 或 12 |

> 分级与 §01 的 **Target audience = 18+** 不冲突:内容分级说的是"内容适合谁看",
> 目标受众说的是"你想投给谁"。两者可以不同。

## 4. 注意

- 问卷改动后分级会重算,发布中的版本可能需要重新审核,**不要来回改**。
- 若将来加入用户间私信或社交动态,必须回来重答并接受更高分级。
