# Google ③ Data safety(数据安全表)

> 位置:Play Console → **Policy and programmes → App content → Data safety**
> 所有轨道(封测/公测/正式)都必须填,即使不收集数据也要填。
> 本表与 Apple 的 App Privacy(`../apple/03-app-privacy.md`)口径已对齐,两边别填出入。

## 1. Overview(总览三问)

| 问题 | 答案 |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** — 全部走 HTTPS/TLS(API `https://api.pure-thoughts.com`) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — App 内「設定 → 刪除帳號」,并在隐私政策页写明删除路径 |

> 第三问旁边要填 **Data deletion URL**:✏️ 用隐私政策同页锚点即可,例如
> `https://www.pure-thoughts.com/privacy#delete`(页面里要写清如何删除)。

## 2. Data types(逐项)

对每个勾选的类型,Play 都会追问四件事:是否收集 / 是否共享 / 是否必需 / 用途。
下表已按 App 实际行为填好。**未列出的类型一律不勾。**

| 类别 → 类型 | Collected | Shared | Optional? | Purposes |
|---|---|---|---|---|
| **Personal info → Email address** | ✅ | ❌ | **Optional**(选填,仅找回密码) | Account management |
| **Personal info → Name** | ✅ | ❌ | Required | Account management, App functionality |
| **Personal info → User IDs** | ✅ | ❌ | Required | Account management, App functionality |
| **App activity → Other user-generated content** | ✅ | ❌ | Required | App functionality |
| **App info and performance → Crash logs** | ✅ | ❌ | Required | Analytics(崩溃诊断) |
| **App info and performance → Diagnostics** | ✅ | ❌ | Required | Analytics |
| **Device or other IDs → Device or other IDs** | ✅ | ❌ | Required | App functionality(推送令牌,仅用于送达通知) |

补充说明:

- **Name**:指显示名(可为法名/昵称),以及代报时填写的他人姓名。
- **Other user-generated content**:报数备注、自定义功课项名称、学修问答消息、举报内容。
- **Shared 一律为 No**:数据只发往我们自托管的服务器与必要的送达通道(APNs/FCM/邮件服务商);
  Play 对"共享"的定义是**转移给第三方**,推送服务商属于处理者(processor),按 Play 指南
  不计为共享。Sentry 同理(仅作为服务提供方处理崩溃数据)。
- **不勾**:Location、Financial info、Health and fitness、Messages(SMS/邮件正文)、
  Photos and videos、Audio files、Files and docs、Calendar、Contacts、Search history、
  Installed apps、Web browsing history、Purchase history、Advertising ID、
  App interactions(未接行为分析)。

## 3. Security practices(安全实践)

| 问题 | 答案 |
|---|---|
| Is your data encrypted in transit? | Yes |
| Do you follow the Play Families Policy? | 不适用(目标年龄 18+) |
| Has your app been independently validated against a global security standard? | No |
| Can users request data deletion? | Yes(App 内 + 网页说明) |

## 4. 一致性自检

- [ ] 与 `../shared/隐私政策.md` 列的数据类型逐项对得上
- [ ] 与 `../apple/03-app-privacy.md` 口径一致
- [ ] `AndroidManifest.xml` 里没有 advertising ID 权限(已确认无)
- [ ] 权限清单能对上用途:相机/麦克风(Webex 会议)、通知、震动、开机自启(定时提醒)、
      电池优化豁免(大陆厂商定时提醒)——这些属于权限声明,不是 Data safety 的数据类型,
      但审核会一起看,别在描述里漏解释
