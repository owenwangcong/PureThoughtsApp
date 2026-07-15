# 品牌图片资源(善护念 PureThoughts)

「金蓮」标志:莲花(清净发心)+ 顶上一点(护念之心)+ 水面涟漪(随喜平和)。
配色取自 `app/lib/core/theme/app_theme.dart`:古铜金 `#8A6D3B` 系 + 宣纸暖白 `#F6F1E4`。

## 文件

| 母版(SVG,唯一编辑源) | 用途 |
| --- | --- |
| `icon.svg` | 主应用图标(iOS 全尺寸 / Android legacy / 商店 1024) |
| `icon_foreground.svg` | Android 自适应图标前景(透明底,内容在 66% 安全区内) |
| `icon_monochrome.svg` | Android 13+ 主题图标(白色剪影) |
| `splash_logo.svg` / `splash_logo_dark.svg` | 启动图 logo(浅/深两版)+ App 内运行时 logo |
| `alt/icon_lineart.svg` | 备选:線描·禪圓(未采用) |
| `alt/icon_dark.svg` | 备选:墨金深色(宣传素材可用) |

生成的 PNG 落在 `app/assets/branding/`(仅作构建输入,**不打包进 App**)与
`app/assets/images/`(运行时 logo,已注册 pubspec assets)。

## 修改 / 再生成流程

1. 只改本目录的 SVG 母版(PNG 一律是生成物,不手改);
2. 本目录执行:`npm install sharp && node render_assets.js`;
3. 在 `app/` 执行:`dart run flutter_launcher_icons` 与 `dart run flutter_native_splash:create`
   (配置见 `app/flutter_launcher_icons.yaml`、`app/flutter_native_splash.yaml`);
4. `node_modules/` 勿提交(已 gitignore)。
