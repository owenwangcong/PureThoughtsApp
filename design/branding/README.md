# 品牌图片资源(善护念 PureThoughts)

标志:**托手莲花 + 祥云圆环**金色徽记 —— 手托金莲(护念、随喜),祥云环绕,象征清净发心。
底色沿用 `app/lib/core/theme/app_theme.dart`:古铜金 `#8A6D3B` 系 + 宣纸暖白 `#F6F1E4`(浅)/ 墨黑 `#15130E`(深)。

用户原始图源在 `docs/images/`(浅版 `logo (2).jpg`、深版 `logo (1).jpg`、去背徽记 favicon、宣传 banner)。

## 母版

| 文件 | 说明 |
| --- | --- |
| `emblem.png` | **唯一编辑源**:去背透明徽记(取自 `docs/images/cropped-pure_thought_favicon-removebg-preview.png`)。所有平台图标 / 启动屏 / 运行时 logo 均由它合成。 |

## 生成物(勿手改,都是 `render_assets.py` 的输出)

落在 `app/assets/branding/`(仅作构建输入,不打包进 App):

| 文件 | 用途 | 排版 |
| --- | --- | --- |
| `icon.png` | iOS 全尺寸 / Android legacy / 商店 1024 | 宣纸暖白不透明底,徽记宽 80% |
| `icon_foreground.png` | Android 自适应前景(透明) | 徽记宽 82%,圆环主体落在 66dp 安全区内 |
| `icon_monochrome.png` | Android 13+ 主题图标 | 白色剪影,同前景排版 |
| `splash_logo.png` / `_dark.png` | 启动图 logo(浅/深) | 透明,徽记宽 72% |
| `splash_logo_a12.png` / `_a12_dark.png` | Android 12 启动图(圆形遮罩) | 透明,徽记宽 50% |

以及 `app/assets/images/logo_mark.png` / `logo_mark_dark.png`(运行时 App 内 logo,已注册 pubspec assets;透明,徽记宽 92%)。

## 修改 / 再生成流程

1. 换标志只改 `emblem.png`(位图母版;若要新徽记,替换这张去背 PNG);排版比例在 `render_assets.py` 顶部各 `compose(...)` 调整;
2. 本目录执行:`python render_assets.py`(依赖 `pip install Pillow`);
3. 在 `app/` 执行:
   `dart run flutter_launcher_icons` 与 `dart run flutter_native_splash:create`
   (配置见 `app/flutter_launcher_icons.yaml`、`app/flutter_native_splash.yaml`);
4. 真机核对图标(自适应遮罩)与启动屏后提交。

> 说明:旧版「金蓮」占位标(SVG 母版 + node/sharp 的 `render_assets.js`)已于 v0.5.14 弃用,
> 改为位图徽记 + Pillow 流程 —— 因为正式徽记是位图,不再有可编辑的矢量母版。
