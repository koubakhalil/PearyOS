"""Generate the PearyOS default wallpaper: a vivid, soft 'aurora' plus a few glossy glass orbs.
The orbs have crisp edges on purpose: the glass panels, dock and menus blur whatever is behind them,
and sharp shapes underneath are what makes that frosted effect visible.
usage: make-assets.py <output.jpg>"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

out = sys.argv[1]
os.makedirs(os.path.dirname(out), exist_ok=True)

W, H = 2560, 1440
SW, SH = W // 4, H // 4  # compose the aurora small, upscale smoothly (fast, and gradients stay buttery)
random.seed(7)

# ---- aurora background ---------------------------------------------------------------------------------
top, bottom = (14, 16, 52), (6, 44, 60)
grad = Image.linear_gradient("L").resize((SW, SH), Image.BILINEAR)
img = Image.composite(Image.new("RGB", (SW, SH), bottom), Image.new("RGB", (SW, SH), top), grad)


def blob(base, cx, cy, rx, ry, color, strength):
    layer = Image.new("L", (SW, SH), 0)
    ImageDraw.Draw(layer).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    layer = layer.filter(ImageFilter.GaussianBlur(min(rx, ry) * 0.55))
    layer = layer.point(lambda v: int(v * strength))
    return Image.composite(Image.new("RGB", (SW, SH), color), base, layer)


def ribbon(base, y0, amp, phase, width, color, strength, blur):
    layer = Image.new("L", (SW, SH), 0)
    d = ImageDraw.Draw(layer)
    pts = []
    for x in range(-20, SW + 21, 6):
        t = x / SW
        y = y0 + amp * math.sin(t * math.pi * 2.0 + phase) + amp * 0.35 * math.sin(t * math.pi * 5.0 + phase * 1.7)
        pts.append((x, y))
    d.line(pts, fill=255, width=width, joint="curve")
    layer = layer.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * strength))
    return Image.composite(Image.new("RGB", (SW, SH), color), base, layer)


img = blob(img, int(SW * 0.84), int(SH * 0.20), int(SW * 0.30), int(SH * 0.42), (190, 245, 70), 0.85)   # pear lime
img = blob(img, int(SW * 0.14), int(SH * 0.82), int(SW * 0.34), int(SH * 0.46), (20, 214, 222), 0.80)  # aqua
img = blob(img, int(SW * 0.50), int(SH * 0.12), int(SW * 0.26), int(SH * 0.30), (108, 76, 255), 0.70)  # violet
img = blob(img, int(SW * 0.28), int(SH * 0.36), int(SW * 0.26), int(SH * 0.26), (255, 78, 160), 0.60)  # pink
img = blob(img, int(SW * 0.86), int(SH * 0.88), int(SW * 0.30), int(SH * 0.34), (20, 190, 130), 0.70)  # emerald
img = ribbon(img, int(SH * 0.58), int(SH * 0.16), 0.6, 26, (210, 255, 240), 0.32, 14)
img = ribbon(img, int(SH * 0.70), int(SH * 0.12), 2.1, 16, (255, 220, 250), 0.22, 10)

base = img.resize((W, H), Image.BICUBIC).convert("RGBA")

# ---- glossy glass orbs -----------------------------------------------------------------------------------
SS = 2  # supersample the orb layer for clean edges


def orb(canvas, cx, cy, r, tint, alpha=0.72):
    """One glass sphere: tinted body that is lighter towards the lit upper-left, dark rim, bright specular rim."""
    size = int(2 * r * SS)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = size / 2.0
    dx, dy = xx - c, yy - c
    d = np.sqrt(dx * dx + dy * dy) / (size / 2.0)                    # 0 centre .. 1 edge
    inside = np.clip((1.0 - d) * (size / 2.0) / 1.5, 0, 1)            # ~1.5px anti-aliased edge
    # light comes from the upper left
    lx, ly = (xx - (c - 0.30 * c)) / (size / 2.0), (yy - (c - 0.36 * c)) / (size / 2.0)
    light = np.clip(1.0 - np.sqrt(lx * lx + ly * ly) / 1.15, 0, 1) ** 1.6
    rgb = np.zeros((size, size, 3), np.float32)
    for i in range(3):
        body = tint[i] * (0.55 + 0.45 * (1 - d * 0.7))
        rgb[..., i] = body * (1 - light * 0.55) + 255.0 * light * 0.55
    # darker, more transparent core with a more opaque rim (that is what makes it read as glass)
    a = alpha * (0.55 + 0.45 * d ** 2.2) * inside
    # thin bright rim on the lit side + faint one on the opposite side
    ang = np.arctan2(dy, dx)
    rim_mask = np.exp(-((d - 0.965) ** 2) / (2 * 0.012 ** 2))
    lit = np.clip(np.cos(ang - math.radians(225)) * 0.5 + 0.5, 0, 1)  # 225 deg = upper left
    rim = rim_mask * (0.25 + 0.75 * lit ** 2)
    rgb = rgb * (1 - rim[..., None] * 0.9) + 255.0 * rim[..., None] * 0.9
    a = np.clip(a + rim * 0.5 * inside, 0, 1)
    layer = np.dstack([rgb, a * 255.0]).clip(0, 255).astype(np.uint8)
    tile = Image.fromarray(layer, "RGBA").resize((int(2 * r), int(2 * r)), Image.LANCZOS)
    canvas.alpha_composite(tile, (int(cx - r), int(cy - r)))


orbs = [
    # (x, y, radius) as fractions of the screen height for radius; chosen so some sit behind the top bar and dock
    (0.50, 0.985, 0.17, (255, 92, 170), 0.70),   # behind the dock
    (0.66, 0.012, 0.085, (190, 245, 70), 0.80),  # behind the top bar
    (0.17, 0.30, 0.115, (60, 220, 230), 0.62),
    (0.88, 0.62, 0.150, (150, 110, 255), 0.62),
    (0.34, 0.80, 0.060, (190, 245, 70), 0.78),
    (0.93, 0.13, 0.055, (255, 120, 190), 0.72),
    (0.07, 0.72, 0.085, (150, 110, 255), 0.62),
    (0.74, 0.90, 0.045, (60, 220, 230), 0.75),
    (0.30, 0.045, 0.040, (255, 220, 120), 0.75),  # also near the top bar
]
for fx, fy, fr, tint, al in orbs:
    orb(base, fx * W, fy * H, fr * H, tint, al)

img = base.convert("RGB")

# gentle film grain so the big gradients do not band
noise = Image.effect_noise((W, H), 14).convert("RGB")
img = ImageChops.blend(img, ImageChops.add(img, noise, scale=2.0, offset=-64), 0.10)

img.save(out, "JPEG", quality=92, optimize=True, progressive=True)
print("wrote", out, os.path.getsize(out), "bytes")
