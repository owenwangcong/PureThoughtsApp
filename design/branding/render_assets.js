// 品牌图片资源再生成脚本:SVG 母版 → PNG(图标 / 自适应前景 / 单色 / 启动图 / 运行时 logo)
// 用法(在本目录):npm install sharp && node render_assets.js
// 输出后需在 app/ 重跑:dart run flutter_launcher_icons && dart run flutter_native_splash:create
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const BRAND = path.join(__dirname, '../../app/assets/branding');
const IMAGES = path.join(__dirname, '../../app/assets/images');

const svg = (name) => fs.readFileSync(path.join(__dirname, name));

async function render(svgName, outPath, size) {
  await sharp(svg(svgName), { density: (72 * size) / 1024 })
    .resize(size, size)
    .png()
    .toFile(outPath);
  console.log('wrote', outPath, size);
}

// Android 12+ 启动图:1152×1152 画布,内容须落在中心 768px 圆内
async function renderA12(svgName, outPath) {
  const inner = await sharp(svg(svgName), { density: (72 * 800) / 1024 })
    .resize(800, 800)
    .png()
    .toBuffer();
  const pad = (1152 - 800) / 2;
  await sharp({
    create: { width: 1152, height: 1152, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
  })
    .composite([{ input: inner, left: pad, top: pad }])
    .png()
    .toFile(outPath);
  console.log('wrote', outPath, '1152 (a12)');
}

async function main() {
  fs.mkdirSync(BRAND, { recursive: true });
  fs.mkdirSync(IMAGES, { recursive: true });

  await render('icon.svg', path.join(BRAND, 'icon.png'), 1024);
  await render('icon_foreground.svg', path.join(BRAND, 'icon_foreground.png'), 1024);
  await render('icon_monochrome.svg', path.join(BRAND, 'icon_monochrome.png'), 1024);
  await render('splash_logo.svg', path.join(BRAND, 'splash_logo.png'), 768);
  await render('splash_logo_dark.svg', path.join(BRAND, 'splash_logo_dark.png'), 768);
  await renderA12('splash_logo.svg', path.join(BRAND, 'splash_logo_a12.png'));
  await renderA12('splash_logo_dark.svg', path.join(BRAND, 'splash_logo_a12_dark.png'));

  // 备选方案(存档/宣传用,不接入构建)
  await render('alt/icon_dark.svg', path.join(BRAND, 'icon_dark_alt.png'), 1024);
  await render('alt/icon_lineart.svg', path.join(BRAND, 'icon_lineart_alt.png'), 1024);

  // App 内运行时 logo(pubspec assets 已注册 assets/images/)
  await render('splash_logo.svg', path.join(IMAGES, 'logo_mark.png'), 768);
  await render('splash_logo_dark.svg', path.join(IMAGES, 'logo_mark_dark.png'), 768);
}

main().catch((e) => { console.error(e); process.exit(1); });
