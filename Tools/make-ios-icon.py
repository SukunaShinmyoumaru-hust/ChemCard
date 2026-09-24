#!/usr/bin/env python3
"""画 iOS 应用图标：早苗头像 + 反应液渐变底，输出 ios/Assets.xcassets/AppIcon.appiconset/icon-1024.png

用法：python3 Tools/make-ios-icon.py [角色目录名]
只依赖 Pillow。iOS 自己会切圆角，所以这里画满幅方图，且必须压成不透明 RGB
（带 alpha 的图标 App Store 会直接拒）。
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024
OUTPUT = ROOT / "ios" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"

LIQUID = (64, 196, 176)
BG_TOP = (22, 82, 76)
BG_BOTTOM = (6, 22, 30)


def background():
    """竖直渐变 + 头像后面一团柔光，让人物从暗底里浮出来。"""
    column = Image.new("RGB", (1, SIZE))
    for y in range(SIZE):
        t = y / (SIZE - 1)
        column.putpixel((0, y), tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * (t ** 1.35))
                                      for i in range(3)))
    canvas = column.resize((SIZE, SIZE), Image.BILINEAR)

    glow = Image.new("L", (SIZE, SIZE), 0)
    radius = int(SIZE * 0.40)
    cx, cy = SIZE // 2, int(SIZE * 0.44)
    ImageDraw.Draw(glow).ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(radius * 0.55))
    tint = Image.new("RGB", (SIZE, SIZE), LIQUID)
    return Image.composite(tint, canvas, glow.point(lambda v: int(v * 0.30)))


def portrait(character):
    """按不透明像素的包围盒裁出来，别把原图的透明边距一起放大。"""
    path = ROOT / "Resources" / "Characters" / character / "base.png"
    art = Image.open(path).convert("RGBA")
    box = art.getbbox() if art.has_transparency_data else None
    return art.crop(box) if box else art


def render(character="sanae"):
    canvas = background()
    art = portrait(character)
    # 按宽放大：肩和袖子溢出画框，帽子中上方留余量——青蛙帽是早苗的识别点，不能切
    width = int(SIZE * 1.12)
    height = int(width * art.height / art.width)
    art = art.resize((width, height), Image.LANCZOS)
    canvas.paste(art, ((SIZE - width) // 2, int(SIZE * 0.01)), art)
    return canvas.convert("RGB")


def main() -> None:
    character = sys.argv[1] if len(sys.argv) > 1 else "sanae"
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    render(character).save(OUTPUT)
    print(f"✓ {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
