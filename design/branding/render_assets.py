#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""善护念 品牌位图渲染(母版 = emblem.png 透明徽记,唯一编辑源)。

把「托手莲花 + 祥云圆环」金色徽记合成到各平台图标 / 启动屏 / 运行时 logo 源图。
输出仅作构建输入,再由 flutter_launcher_icons / flutter_native_splash 生成最终资源。

用法(本目录):  python render_assets.py
依赖:          Pillow(pip install Pillow)
"""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent   # design/branding
ROOT = HERE.parent.parent                # 仓库根
BRANDING = ROOT / "app" / "assets" / "branding"
IMAGES = ROOT / "app" / "assets" / "images"

PAPER = (246, 241, 228, 255)  # 宣纸暖白 #F6F1E4(与 app_theme 及 *.yaml 一致)

emblem_src = Image.open(HERE / "emblem.png").convert("RGBA")
# 裁到不透明内容的紧致边界,便于按比例精确排版
bbox = emblem_src.getbbox()
EMBLEM = emblem_src.crop(bbox)


def _scaled(width_frac: float, canvas: int) -> Image.Image:
    """把徽记按 bbox 宽度占 canvas 的 width_frac 缩放。"""
    target_w = int(round(canvas * width_frac))
    scale = target_w / EMBLEM.width
    target_h = int(round(EMBLEM.height * scale))
    return EMBLEM.resize((target_w, target_h), Image.LANCZOS)


def compose(canvas: int, width_frac: float, bg=None, mono=False,
            out: Path = None):
    base = Image.new("RGBA", (canvas, canvas),
                     bg if bg is not None else (0, 0, 0, 0))
    mark = _scaled(width_frac, canvas)
    if mono:
        # 主题图标:用 alpha 生成纯白剪影(线描形状保留)
        white = Image.new("RGBA", mark.size, (255, 255, 255, 0))
        white.putalpha(mark.split()[3])
        mark = white
    x = (canvas - mark.width) // 2
    y = (canvas - mark.height) // 2
    base.alpha_composite(mark, (x, y))
    out.parent.mkdir(parents=True, exist_ok=True)
    base.save(out)
    print(f"  {out.relative_to(ROOT)}  {canvas}x{canvas}  frac={width_frac}")


print("emblem bbox:", bbox, "->", EMBLEM.size)
print("launcher icons:")
# iOS 全尺寸 / Android legacy / 商店 1024:不透明宣纸底,徽记留呼吸边
compose(1024, 0.80, bg=PAPER,  out=BRANDING / "icon.png")
# Android 自适应前景:透明。徽记放大到中心 ~82%,使圆环主体铺满常见方/圆角遮罩;
# 圆环直径 ≈ 0.82*(360/466) ≈ 63%,仍落在 66dp 圆形安全区内(仅祥云梢在纯圆遮罩下可能轻裁)
compose(1024, 0.82,            out=BRANDING / "icon_foreground.png")
# Android 13+ 主题图标:白色剪影
compose(1024, 0.82, mono=True, out=BRANDING / "icon_monochrome.png")

print("native splash:")
compose(768,  0.72, out=BRANDING / "splash_logo.png")
compose(768,  0.72, out=BRANDING / "splash_logo_dark.png")
# Android 12 启动图标被裁成圆,内容收进中心 ~50%
compose(1152, 0.50, out=BRANDING / "splash_logo_a12.png")
compose(1152, 0.50, out=BRANDING / "splash_logo_a12_dark.png")

print("runtime logo (assets/images):")
compose(768,  0.92, out=IMAGES / "logo_mark.png")
compose(768,  0.92, out=IMAGES / "logo_mark_dark.png")

print("done.")
