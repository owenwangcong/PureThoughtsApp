# Apple ① App Information + 定价 + 年龄分级

> 位置:App Store Connect → 你的 App → **General → App Information / Pricing and Availability**
> 「✏️ 待填」= 需要你补的信息;其余可直接照抄。

## 1. General Information

| 字段 | 填什么 |
|---|---|
| Name(繁体本地化) | `善護念` |
| Name(简体本地化) | `善护念` |
| Subtitle(繁) | `每日功課記錄與共修統計` |
| Subtitle(简) | `每日功课记录与共修统计` |
| Bundle ID | `com.aeonlectron.purethoughts` |
| SKU | `PURETHOUGHTS001`(自定义,不对外显示) |
| Primary Language | `Chinese (Traditional)` — 繁体为默认语言(PRD 定案) |
| User Access | `Full Access` |

## 2. Localizable Information · 语言

先建 **Chinese (Traditional)** 为主语言,再加 **Chinese (Simplified)** 本地化。
两套文案见 `../shared/文案库.md`,截图分别取:

- 繁体本地化 → `release/screenshots/apple/zh-Hant/`(8 张)
- 简体本地化 → `release/screenshots/apple/zh-Hans/`(8 张)

## 3. Category(类别)

| 字段 | 填什么 | 理由 |
|---|---|---|
| Primary Category | **Lifestyle(生活)** | 宗教/信仰类 App 在 App Store 归入 Lifestyle,是宗教团体工具的常规选择 |
| Secondary Category | **Reference(参考)** | 在线经本 + 佛历 + 讲法问答检索,属参考资料性质 |

> 备选:若更想突出"记录/统计"可用 Primary = `Health & Fitness`,**不建议**——健康类会引来
> 更严的健康数据审查(HealthKit、医疗声明),本 App 与之无关。

## 4. Content Rights(内容权利)

问题:*Does your app contain, show, or access third-party content?*

**答:Yes** — 并勾选"我拥有必要的权利或已获授权"。

理由与备注(审核若追问,用这段答):
> App 内会打开第三方站点:乾隆大藏经在线经本(`qldazangjing.com`)、YouTube 频道直播与
> 回看、Webex 会议室。这些均为本共修团体自有或公开可访问的频道/资源,以链接与
> WebView 方式呈现,不复制、不再分发其内容。

## 5. Age Rating(年龄分级)⚠️ 2026 年新问卷

App Store Connect 的分级问卷在 2025–2026 扩到 4+/9+/**13+/16+/18+** 五档,并新增了
**社交功能**一组问题(2026 年 9 月起新 App 提交必答;命中社交定义会被强制锁到 13+ 并
在商品页显示 "Social Media" 标签)。按本 App 实际情况逐条答:

### 5.1 内容类问题(全部 None / No)

| 问题 | 答案 |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence / Prolonged Graphic Violence | None |
| Sexual Content or Nudity | None |
| Profanity or Crude Humor | None |
| Alcohol, Tobacco, or Drug Use | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Gambling / Contests | No |
| Medical or wellness topics(新增) | **None** — 打坐計時只是计时与铃声,不提供任何医疗、心理治疗或健康建议 |
| In-app controls / parental gates(新增) | 无家长控制需求,如实答 No |

### 5.2 网页访问

| 问题 | 建议答案 |
|---|---|
| Unrestricted Web Access | **No** |

判断依据:App 内 WebView 只加载**固定的**在线经本站点与 Webex 会议连接,没有地址栏、
没有任意网页浏览入口。**注意**:这题答 Yes 会直接把分级拉到 18+。如果审核员认为经本
站内的外链构成"不受限浏览"而要求改答,再改为 Yes 并接受更高分级即可——请勿主动答 Yes。

### 5.3 用户生成内容与社交功能 ⚠️ 需要你拍板

| 问题 | 本 App 的事实 | 建议答案 |
|---|---|---|
| 是否包含用户生成内容(UGC) | 是:报数备注、自定义功课项名称、显示名、代报姓名、学修问答提问 | **Yes** |
| 用户之间能否互相发消息 | 不能。学修问答是**用户 ↔ 管理员**的一对一问答,用户之间没有私信 | **No** |
| 是否有社交动态流(可再分发/放大/互动 UGC) | 「共修報數」页有一份全体可见的报数流水,但**不能点赞、评论、转发、关注**,也不做排名 | **No**(附理由,见下) |
| 是否有关注/好友系统 | 无 | No |
| 是否有直播(用户自己开播) | 无。直播是团体官方 YouTube 频道的**观看**,用户不能开播 | No |
| 是否有内容创作工具 | 无 | No |
| 广告 | 无 | No |

**关于"社交动态流"这题**:Apple 的定义是"通过社交动态流或类似发现机制**再分发、放大或
互动**用户生成内容"。本 App 的记录列表只是团体内的功课流水,没有任何互动与放大机制,
按定义答 No 是站得住的。**但这是审核员有裁量权的一题** —— 若答 Yes,分级会被锁到 13+
并在商店页挂 "Social Media" 标签(不影响过审,只影响分级展示)。保守派可直接答 Yes 换
省事;想要 4+ 就答 No 并在审核备注里写明"无点赞/评论/转发/关注机制"(备注文本已在
`04-app-review-information.md` 备好)。

**预期结果**:按上表回答,分级应为 **4+**(若社交题答 Yes 则为 13+)。

### 5.4 UGC 必备的合规措施(Apple Guideline 1.2,已全部实现,勾选即可)

| 要求 | App 内实现 |
|---|---|
| 过滤不当内容的机制 | 管理员可删除任意记录、封禁账号 |
| 举报机制 | 记录条目菜单 → 檢舉(进入管理员处理队列) |
| 拉黑机制 | 用户可拉黑其他用户 |
| 用户协议(EULA)同意 | 首次启动引导页勾选同意 |
| 联系方式 | 设置页 + 隐私政策页提供联系邮箱 |

## 6. License Agreement(许可协议)

用 **Apple 标准 EULA**(默认选项),无需上传自定义协议。
App 内另有《服务条款》与《社区规范》(见 `../shared/服务条款-EULA.md`),二者不冲突。

## 7. Pricing and Availability(定价与销售范围)

| 字段 | 填什么 |
|---|---|
| Price | **Free**(免费,无内购、无订阅) |
| Availability | 全球所有国家/地区(默认)。如需限制,至少保留:美国、加拿大、澳大利亚、新加坡、马来西亚、香港、台湾、日本 |
| Pre-Orders | 不开 |
| Distribution: Educational discount / Custom apps | 不勾 |

> **中国大陆区**:本 App 的服务器在境外,若上架中国大陆区需要 ICP 备案号,**当前没有**。
> 因此**中国大陆区先不上架**(大陆用户通过其他区 Apple ID 使用);这与 PRD 的服务器选址一致。

## 8. ✏️ 待填(只有你知道的信息)

| 字段 | 说明 |
|---|---|
| 开发者账号主体名称 | 显示在商店页的 Seller,个人账号=本人姓名,公司账号=公司名 |
| Copyright | 建议 `2026 【運營方名稱】` |
| Support URL | 必填,建议 `https://www.pure-thoughts.com/support`(可以是一个带联系邮箱的静态页) |
| Marketing URL | 选填,建议 `https://www.pure-thoughts.com` |
| Privacy Policy URL | 必填,见 `../shared/隐私政策.md` —— **上线后回填** |
