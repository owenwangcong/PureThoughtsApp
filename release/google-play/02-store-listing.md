# Google ② Store listing(商店listing)

> 位置:Play Console → **Grow users → Store presence → Main store listing**
> 文案正文见 `../shared/文案库.md`。默认语言建议设 **繁體中文(台灣)**,再加简体中文。

## 1. 文本字段

| 字段 | 上限 | 填什么 |
|---|---|---|
| App name | 30 | 繁 `善護念 — 共修功課記錄` / 简 `善护念 — 共修功课记录` |
| Short description | 80 | 文案库 §2 的 Play 简短说明 |
| Full description | 4000 | 文案库 §3(繁/简各一份) |

> Play 的搜索会索引 name + short description + full description,所以完整描述里自然出现
> 「共修 / 功課 / 報數 / 誦經 / 念佛 / 打坐 / 佛曆」等词即可,**不要堆砌关键词**
> (Play 明令禁止 keyword stuffing,会被拒)。

## 2. 图形素材(全部已生成)

⚠️ **Play 的尺寸硬规则**(踩过):必须 16:9 或 9:16,而且**长边不能超过短边的 2 倍**。
所以 1080×2400(2.22 倍)这种现代手机比例**会被拒**,本套素材统一用 9:16(1.78 倍)。

| 素材 | 规格 | 文件 | 必需 |
|---|---|---|---|
| App icon | 512×512 PNG,32-bit | `screenshots/google-play/app-icon-512.png` | ✅ |
| Feature graphic | 1024×500 PNG,无 alpha | `screenshots/google-play/feature-graphic.png` | ✅ |
| 手机截图 | **1440×2560**(9:16),2–8 张 | `screenshots/google-play/phone-1440x2560/{zh-Hant,zh-Hans}/` 各 8 张 | ✅ |
| 7" 平板截图 | **1080×1920**(9:16),每边 1080–7680px | `screenshots/google-play/tablet-7-1080x1920/{zh-Hant,zh-Hans}/` 各 4 张 | ✅ Play Console 标 `*` 必填 |
| 10" 平板截图 | **1800×3200**(9:16) | `screenshots/google-play/tablet-10-1800x3200/{zh-Hant,zh-Hans}/` 各 4 张 | ✅ 同上 |
| Video | 可选 YouTube 链接 | 无 | ❌ |

> 平板两档各 4 张(首页 / 共修報數 / 個人統計 / 打坐計時)—— Play 要求「至少 4 张」
> 才有推荐资格,再多的边际收益不大,也避免仓库堆图。

截图建议顺序(前 2 张最重要,列表页只露前 2 张):

| # | 文件 | 内容 |
|---|---|---|
| 1 | `01-home.png` | 首页功能宫格 + 佛历横幅 |
| 2 | `02-community.png` | 共修總量:我的 / 全體双栏 |
| 3 | `03-dashboard.png` | 個人統計与连续用功天数 |
| 4 | `04-report.png` | 報數 |
| 5 | `05-calendar.png` | 佛历活动日历 |
| 6 | `06-timer.png` | 打坐計時 |
| 7 | `07-study-qa.png` | 學修問答 |
| 8 | `08-vows.png` | 發願 |

## 3. 本地化

| 语言 | 处理 |
|---|---|
| 繁體中文(台灣)`zh-TW` | 默认语言,用繁体文案 + `zh-Hant` 截图 |
| 繁體中文(香港)`zh-HK` | 可复制 `zh-TW` 一份(用户以港台居多时值得单列) |
| 简体中文 `zh-CN` | 用简体文案 + `zh-Hans` 截图 |
| English (US) | 可选。若开,用文案库的英文版 + `zh-Hant` 截图(界面是中文,如实呈现) |

> Play 的商店listing语言与 App 界面语言无关;App 内是繁简双语,用户首启可选。

## 4. 发布国家/地区

- 建议:全球可用,但**排除中国大陆**(Play 在大陆本就不可用,列表里保持默认即可)。
- 重点区域:美国、加拿大、澳大利亚、新西兰、新加坡、马来西亚、香港、台湾、日本、韩国、英国。

## 5. 商店listing 常见拒审点

| 问题 | 规避 |
|---|---|
| 截图带虚假 UI / 设备边框里的图与实际不符 | 本套截图是真实界面渲染,直接用 |
| 描述里出现「最好 / 第一」等最高级或未经证实的宣称 | 文案库已规避 |
| 描述里提到其他应用商店或外部下载 | 不要写 |
| 图标与截图里出现「Google Play」标志或奖项标识 | 不要加 |
| 名称里堆关键词(如「共修 报数 念佛 打坐 计数器」) | 用文案库的名称,只带一个副标题短语 |
