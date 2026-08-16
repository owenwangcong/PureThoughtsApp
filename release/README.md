# 善護念 PureThoughts · 上架资料包

> 生成日期:2026-08-13 · 对应 App 版本 `1.0.0 (build 1)` · PRD v0.6.1 / PLAN P5.4
> 用途:App Store Connect 与 Google Play Console 两端**照着抄进去**的填表资料 + 现成图片素材。

## 目录

```
release/
├── README.md                     ← 本文件:总览、流程、必须先补的三件事
├── apple/                        ← App Store Connect 逐字段填写清单
│   ├── 01-app-information.md         App Information(名称/类别/年龄分级/版权)
│   ├── 02-版本文案.md                 描述/关键词/推广文本/新功能(繁简双语)
│   ├── 03-app-privacy.md             App Privacy 数据类型逐项答案
│   ├── 04-app-review-information.md  审核联系人/演示账号/审核备注(可整段复制)
│   └── 05-提交前检查清单.md
├── google-play/                  ← Play Console 逐任务填写清单
│   ├── 01-app-content.md             Dashboard「Set up your app」十项任务答案
│   ├── 02-store-listing.md           商店listing 文案 + 图形素材对应关系
│   ├── 03-data-safety.md             数据安全表逐项答案
│   ├── 04-content-rating.md          IARC 内容分级问卷答案
│   └── 05-发布流程.md                封闭测试 12 人 14 天 → 正式发布
├── shared/
│   ├── 隐私政策.md                    ⚠️ 需发布到官网,两端强制要 URL(源文本)
│   ├── privacy-policy-wordpress.html  ← WordPress「自定义 HTML」区块用的片段(实际发布用这份)
│   ├── privacy-policy.html            独立单页版(不用 WordPress 时才用)
│   ├── 服务条款-EULA.md
│   └── 文案库.md                      名称/简介/描述 繁·简·英三套,统一改这里
└── screenshots/
    ├── apple/                            ASC 按显示尺寸分槽,传错档会报 dimensions wrong
    │   ├── 6.9-1290x2796/zh-Hant|zh-Hans/*.png   iPhone 6.9" 槽,各 8 张
    │   └── 6.5-1284x2778/zh-Hant|zh-Hans/*.png   iPhone 6.5" 槽,各 8 张(任填一档即可)
    └── google-play/
        ├── zh-Hant|zh-Hans/*.png         1080×2400,各 8 张
        ├── feature-graphic.png           1024×500(Play 必需)
        └── app-icon-512.png              512×512(Play 必需)
```

## ⚠️ 提交前必须先补的三件事(缺一样就卡住)

| # | 事项 | 现状 | 怎么办 |
|---|---|---|---|
| 1 | **公开的隐私政策 URL** | App 内只有草案文案(`privacy_screen.dart`),**没有网页** | 把 `shared/隐私政策.md` 发到官网,例如 `https://www.pure-thoughts.com/privacy`;两端都强制填 URL,且必须公网可访问、不能要求登录 |
| 2 | ~~**审核用演示账号**~~ | ✅ **已完成 2026-08-13** | `appreview` 已建在生产库并铺好演示数据(报数/发愿/问答/通知),登录实测通过;账号与密码见 `apple/04-app-review-information.md`。审核期间勿删勿改密 |
| 3 | ~~**iPad 支持要不要留**~~ | ✅ **已改为仅 iPhone 2026-08-16**(`TARGETED_DEVICE_FAMILY = "1"`) | ASC 原本强制要 13" iPad 截图;App 是手机布局,iPad 上大片留白还可能被按 4.0 挑刺,故关掉。**新 build 上传后该要求才消失**。若日后要恢复 iPad:改回 `"1,2"`,iPad 截图素材已备在 `screenshots/apple/ipad-13-2048x2732/` |

## 两端提交顺序

**Apple**(约 1–3 天审核)
1. App Store Connect → 新建 App(Bundle ID `com.aeonlectron.purethoughts`)
2. 按 `apple/01` → `apple/02` → `apple/03` 填完三块
3. Codemagic 出 ipa 上传 TestFlight → 自测通过
4. 填 `apple/04` 的审核信息 → 提交审核

**Google**(新开发者账号需先过封测)
1. Play Console → 完成 `google-play/01` 的十项 App content 任务
2. 按 `google-play/02` 填 Store listing、传 `screenshots/google-play/` 素材
3. **封闭测试:12 名测试员连续 14 天**(个人开发者账号硬性要求,`google-play/05`)
4. 封测达标 → 申请正式发布

## 关键事实(两端填表都要用)

| 项目 | 值 |
|---|---|
| App 名称(繁 / 简) | 善護念 / 善护念 |
| 英文名 | PureThoughts |
| Bundle ID / Package | `com.aeonlectron.purethoughts` |
| 版本 / Build | `1.0.0` / `1` |
| 价格 | 免费,无内购、无订阅、无广告 |
| 主要语言 | 繁体中文(zh-Hant),另做简体中文本地化 |
| 后端 | 自托管 Supabase(境外机房),API `https://api.pure-thoughts.com` |
| 崩溃统计 | Sentry(仅在配置了 DSN 的构建中启用) |
| 推送 | iOS 原生 APNs;海外 Android FCM;App 内通知中心兜底 |
| 账号删除 | App 内「設定 → 刪除帳號」(Apple 5.1.1(v) 硬性要求,已实现) |
| UGC 治理 | 举报 + 拉黑 + 管理员封禁 + 社区规范同意(Apple 1.2 要求,已实现) |

## 截图怎么重新生成

界面改版后重跑一条命令即可(数据是演示数据,不含真实用户信息):

界面改版后重跑**两条**命令(第二条不能省):

```sh
cd app
flutter test tool/screenshots/store_screenshots_test.dart --update-goldens
powershell -ExecutionPolicy Bypass -File tool/screenshots/flatten-png.ps1
```

- 第一条:`store_screenshots_test.dart` 渲染**真实 App 界面与主题**(演示数据),
  输出直接覆盖 `release/screenshots/` 下对应文件。它放在 `tool/` 不在 `test/`,
  不会被日常 `flutter test` 扫到。
- 第二条:去掉 alpha 通道。Flutter golden 出的是 RGBA,而 **Apple 要求截图 flattened、
  Play 要求 24-bit PNG(no alpha)**,带透明通道会被打回。`app-icon-512.png` 例外
  (Play 图标规格允许 alpha),脚本会自动跳过。

当前 `release/screenshots/` 里的文件**已经处理过**,可以直接上传。
