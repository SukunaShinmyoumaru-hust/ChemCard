#!/usr/bin/env python3
"""把立绘原图抠掉纯色背景、裁成正方形半身像，写入 Resources/Characters/<角色>/base.png。

用法：python3 Tools/cut_portraits.py <原图目录> [角色...]
原图命名约定 <角色>_*.png，同名多张取最新修改的一张。
换自己的立绘时，只要图片是「纯色背景 + 角色居中」，跑一遍这条命令即可。
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Resources" / "Characters"
SIZE = 640
CHARACTERS = ("sanae", "reimu", "marisa", "seiga", "sakuya", "cirno", "eirin")


def source_image(folder: Path, character: str) -> Path:
    candidates = sorted(folder.glob(f"{character}*.png"), key=lambda p: p.stat().st_mtime)
    if not candidates:
        raise SystemExit(f"找不到 {character} 的立绘原图：{folder}/{character}*.png")
    return candidates[-1]


def background_color(rgb: np.ndarray) -> np.ndarray:
    """只取上方两角：半身像的肩膀和衣摆一定会压到下两角。"""
    patch = 24
    corners = np.stack([
        rgb[:patch, :patch].reshape(-1, 3),
        rgb[:patch, -patch:].reshape(-1, 3),
    ])
    return np.median(corners.reshape(-1, 3), axis=0)


def matte(rgb: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """背景按色距认，羽化只贴在背景边缘 2px 上。

    整图套 34–78 的渐变会把颜色接近底色的衣服抠穿：永琳的红袍离品红底只差
    47，输出成半透明墨绿。只渐变背景轮廓一圈，袍子内部就是实心的。
    """
    dist = np.abs(rgb.astype(np.int16) - bg.astype(np.int16)).max(axis=2)
    low, high = 34.0, 78.0
    outside = dist < low
    structure = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]])
    rim = ndimage.binary_dilation(outside, structure=structure, iterations=2) & ~outside
    return np.where(outside, 0.0, np.where(rim, np.clip((dist - low) / (high - low), 0.0, 1.0), 1.0))


def unmix(rgb: np.ndarray, alpha: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """去掉半透明边缘上混进去的背景色，避免立绘轮廓泛品红。"""
    a = alpha[..., None]
    safe = np.maximum(a, 1e-3)
    straight = (rgb.astype(np.float64) - (1.0 - a) * bg.astype(np.float64)) / safe
    return np.where(a > 0.02, np.clip(straight, 0, 255), rgb).astype(np.uint8)


def bust_square(rgb: np.ndarray, alpha: np.ndarray):
    """取上方正方形：头颈构图，同时切掉原图右下角的水印。"""
    h, w = rgb.shape[:2]
    side = min(w, h)
    top = 0 if h == side else max(0, int((h - side) * 0.28))
    left = (w - side) // 2
    return rgb[top:top + side, left:left + side], alpha[top:top + side, left:left + side]


def process(path: Path, destination: Path) -> None:
    image = Image.open(path).convert("RGB")
    rgb = np.asarray(image)
    bg = background_color(rgb)
    alpha = matte(rgb, bg)
    rgb, alpha = bust_square(unmix(rgb, alpha, bg), alpha)

    canvas = Image.new("RGBA", (SIZE, SIZE))
    canvas.paste(Image.fromarray(rgb).resize((SIZE, SIZE), Image.LANCZOS), (0, 0))
    canvas.putalpha(Image.fromarray((alpha * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.LANCZOS))

    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, optimize=True)
    covered = float((alpha > 0.5).mean())
    print(f"✓ {destination.relative_to(ROOT)}  背景 {bg.astype(int)}  覆盖率 {covered:.0%}")


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    folder = Path(sys.argv[1]).expanduser().resolve()
    wanted = sys.argv[2:] or list(CHARACTERS)
    unknown = [name for name in wanted if name not in CHARACTERS]
    if unknown:
        raise SystemExit(f"不认识的角色：{'、'.join(unknown)}；可选：{'、'.join(CHARACTERS)}")
    for character in wanted:
        process(source_image(folder, character), OUT / character / "base.png")


if __name__ == "__main__":
    main()
