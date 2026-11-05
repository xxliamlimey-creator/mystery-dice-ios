#!/usr/bin/env python3
"""
Generate the iOS app icon and launch logo for Mystery Dice.

Source art: the site's isometric mystery cube
(https://mysterydice.ai.studio/assets/aistudio/Isometric_Mystery_Question_Cube_364c2769.png)

Requires Pillow:  pip install pillow
Usage:            python scripts/make_icons.py [path-to-cube.png]
"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "MysteryDice", "Resources", "Assets.xcassets")

BG_TOP = (13, 18, 32)      # #0D1220
BG_BOTTOM = (5, 7, 12)     # #05070C
ACCENT = (245, 158, 11)    # #F59E0B


def vertical_gradient(size, top, bottom):
    w, h = size
    base = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        base.putpixel((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return base.resize((w, h), Image.BILINEAR)


def radial_glow(size, center, radius, color, strength):
    """Soft additive glow drawn at 1/4 scale, then upscaled (cheap + smooth)."""
    w, h = size
    scale = 4
    small = Image.new("L", (w // scale, h // scale), 0)
    draw = ImageDraw.Draw(small)
    cx, cy = center[0] / scale, center[1] / scale
    r = radius / scale
    steps = 40
    for i in range(steps, 0, -1):
        t = i / steps
        alpha = int(255 * strength * (1 - t) ** 2)
        rr = r * t
        draw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=alpha)
    small = small.filter(ImageFilter.GaussianBlur(8))
    mask = small.resize((w, h), Image.BICUBIC)
    layer = Image.new("RGB", (w, h), color)
    return layer, mask


def build_icon(cube, size=1024):
    bg = vertical_gradient((size, size), BG_TOP, BG_BOTTOM).convert("RGBA")

    glow_layer, glow_mask = radial_glow((size, size), (size // 2, int(size * 0.46)), int(size * 0.42), ACCENT, 0.55)
    bg = Image.composite(glow_layer, bg, glow_mask.point(lambda v: int(v * 0.75)))

    # Cube: fit into 72% of the canvas height, keep aspect ratio.
    target_h = int(size * 0.74)
    ratio = target_h / cube.height
    target_w = int(cube.width * ratio)
    art = cube.resize((target_w, target_h), Image.LANCZOS)

    # Drop shadow.
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_mask = Image.new("L", (size, size), 0)
    s_mask = art.getchannel("A").point(lambda v: int(v * 0.55))
    pos = ((size - target_w) // 2, int(size * 0.5 - target_h * 0.5) + int(size * 0.035))
    shadow_mask.paste(s_mask, pos)
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(int(size * 0.035)))
    shadow.putalpha(shadow_mask)
    bg = Image.alpha_composite(bg, shadow)

    # The art itself, with a thin rim light so it separates from the glow.
    art_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    art_layer.paste(art, ((size - target_w) // 2, int(size * 0.5 - target_h * 0.5)), art)
    bg = Image.alpha_composite(bg, art_layer)

    # Vignette for depth.
    vignette, vmask = radial_glow((size, size), (size // 2, size // 2), int(size * 0.75), (0, 0, 0), 0.9)
    vmask = vmask.point(lambda v: int(v * 0.55))
    dark = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    bg = Image.composite(dark, bg, vmask)

    # App icons must be fully opaque (no alpha channel).
    return bg.convert("RGB")


def build_logo(cube, target_h):
    ratio = target_h / cube.height
    target_w = max(1, int(cube.width * ratio))
    return cube.resize((target_w, target_h), Image.LANCZOS)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "art", "cube.png")
    if not os.path.exists(src):
        sys.exit(f"Source art not found: {src}\nDownload it first, or pass the path as an argument.")

    cube = Image.open(src).convert("RGBA")

    # Trim the transparent border so the art fills the icon.
    bbox = cube.getchannel("A").getbbox()
    if bbox:
        pad = int(min(cube.size) * 0.02)
        bbox = (max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                min(cube.width, bbox[2] + pad), min(cube.height, bbox[3] + pad))
        cube = cube.crop(bbox)

    icon = build_icon(cube, 1024)
    icon_path = os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon-1024.png")
    icon.save(icon_path, "PNG", optimize=True)
    print("wrote", icon_path, icon.size, icon.mode)

    for scale, height in ((1, 120), (2, 240), (3, 360)):
        logo = build_logo(cube, height)
        name = f"LaunchLogo@{scale}x.png"
        path = os.path.join(ASSETS, "LaunchLogo.imageset", name)
        logo.save(path, "PNG", optimize=True)
        print("wrote", path, logo.size)


if __name__ == "__main__":
    main()


