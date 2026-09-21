#!/usr/bin/env python3
"""画一张 app 图标并编译成 build/AppIcon.icns（build.sh 会拷进 bundle）。

用法：python3 Tools/make_icon.py
只依赖 Pillow，iconutil 由系统提供。
"""

import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024
ICONSET = ROOT / "build" / "AppIcon.iconset"

CARD_TOP = (255, 246, 235)
CARD_EDGE = (206, 74, 62)
LIQUID = (64, 196, 176)
ACCENT = (255, 209, 102)
BG_TOP = (24, 62, 74)
BG_BOTTOM = (8, 20, 30)


def rounded_background(box, radius, top, bottom):
    """圆角矩形 + 竖直渐变。"""
    column = Image.new("RGB", (1, SIZE))
    for y in range(SIZE):
        t = y / (SIZE - 1)
        column.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    gradient = column.resize((SIZE, SIZE), Image.BILINEAR)
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return Image.composite(gradient, Image.new("RGB", (SIZE, SIZE), (0, 0, 0)), mask), mask


def draw_card(image, offset, tilt, scale=1.0):
    """一张带红边的牌，返回它自己的绘图上下文坐标原点。"""
    width = int(430 * scale)
    height = int(600 * scale)
    card = Image.new("RGBA", (width + 40, height + 40), (0, 0, 0, 0))
    paint = ImageDraw.Draw(card)
    body = (20, 20, width + 20, height + 20)
    paint.rounded_rectangle(body, radius=int(56 * scale), fill=CARD_TOP,
                            outline=CARD_EDGE, width=int(16 * scale))
    paint.rounded_rectangle((int(46 * scale), int(46 * scale),
                             width + 20 - int(46 * scale), height + 20 - int(46 * scale)),
                            radius=int(34 * scale), outline=(238, 214, 190), width=int(6 * scale))
    card = card.rotate(tilt, resample=Image.BICUBIC, expand=True)
    image.alpha_composite(card, offset)
    return paint, body


def draw_flask(image, center, scale=1.0):
    """锥形瓶：细颈 + 向下变宽的锥体 + 圆底，液体严格贴合瓶壁。"""
    cx, cy = center
    half_neck = int(37 * scale)
    half_base = int(166 * scale)
    neck_top = cy - int(215 * scale)
    shoulder = cy - int(96 * scale)
    base = cy + int(140 * scale)

    def half_width(y):
        if y <= shoulder:
            return half_neck
        t = (y - shoulder) / (base - shoulder)
        return half_neck + (half_base - half_neck) * (t ** 0.85)

    flask = Image.new("RGBA", image.size, (0, 0, 0, 0))
    paint = ImageDraw.Draw(flask)

    silhouette = [(cx - half_neck, neck_top), (cx + half_neck, neck_top),
                  (cx + half_neck, shoulder), (cx + half_width(base), base - int(22 * scale)),
                  (cx + half_base - int(30 * scale), base),
                  (cx - half_base + int(30 * scale), base),
                  (cx - half_width(base), base - int(22 * scale)),
                  (cx - half_neck, shoulder)]
    paint.polygon(silhouette, fill=(253, 251, 247, 235))

    liquid_top = cy + int(24 * scale)
    top_half = int(half_width(liquid_top)) - int(9 * scale)
    bottom_half = half_base - int(9 * scale)
    paint.polygon([(cx - top_half, liquid_top), (cx + top_half, liquid_top),
                   (cx + bottom_half, base - int(26 * scale)),
                   (cx + bottom_half - int(26 * scale), base - int(12 * scale)),
                   (cx - bottom_half + int(26 * scale), base - int(12 * scale)),
                   (cx - bottom_half, base - int(26 * scale))],
                  fill=LIQUID + (255,))
    paint.ellipse((cx - top_half, liquid_top - int(15 * scale),
                   cx + top_half, liquid_top + int(15 * scale)),
                  fill=(126, 226, 208, 255))
    for radius, dx, dy in [(int(19 * scale), -int(54 * scale), int(62 * scale)),
                           (int(13 * scale), int(40 * scale), int(88 * scale)),
                           (int(8 * scale), -int(6 * scale), int(108 * scale))]:
        paint.ellipse((cx + dx - radius, cy + dy - radius, cx + dx + radius, cy + dy + radius),
                      fill=(238, 255, 252, 235))

    paint.line(silhouette + [silhouette[0]], fill=(96, 78, 74, 255), width=int(11 * scale),
               joint="curve")
    paint.line([(cx - half_neck - int(17 * scale), neck_top),
                (cx + half_neck + int(17 * scale), neck_top)],
               fill=(96, 78, 74, 255), width=int(19 * scale))
    image.alpha_composite(flask)


def render(size=SIZE):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    margin = int(size * 0.055)
    box = [margin, margin, size - margin, size - margin]
    radius = int(size * 0.215)
    background, mask = rounded_background(box, radius, BG_TOP, BG_BOTTOM)
    canvas.paste(background, (0, 0), mask)

    paint = ImageDraw.Draw(canvas)
    paint.rounded_rectangle(box, radius=radius, outline=(58, 132, 140, 200), width=int(size * 0.012))

    scale = size / SIZE
    draw_card(canvas, (int(150 * scale), int(232 * scale)), 9, 0.82)
    draw_card(canvas, (int(322 * scale), int(196 * scale)), -7, 1.0)
    draw_flask(canvas, (int(size // 2), int(size * 0.53)), 0.92 * scale)

    for (px, py) in [(0.20, 0.20), (0.80, 0.20), (0.20, 0.82), (0.80, 0.82)]:
        r = int(15 * scale)
        paint.ellipse((size * px - r, size * py - r, size * px + r, size * py + r), fill=ACCENT)
    return canvas


def main() -> None:
    iconset = ICONSET
    if iconset.exists():
        shutil.rmtree(iconset)
    iconset.mkdir(parents=True)

    full = render()
    full.save(ROOT / "build" / "AppIcon-1024.png")
    specs = [("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
             ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
             ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
             ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
             ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)]
    for name, pixel in specs:
        full.resize((pixel, pixel), Image.LANCZOS).save(iconset / name)

    target = ROOT / "build" / "AppIcon.icns"
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(target)], check=True)
    shutil.rmtree(iconset)
    print(f"✓ {target.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
