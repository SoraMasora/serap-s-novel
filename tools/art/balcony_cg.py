"""Кадры сцены курения (ветка «Дальше больше») из присланных артов.

Источники: tools/art/src/bal_light.webp (Кир прикуривает Сере),
tools/art/src/bal_talk.webp (оба у перил).
Выход godot/art/bg/: bal_s0 (статичный), bal_l0..3 (огонёк зажигалки
мерцает), bal_t0..3 (дождь, дымок от сигарет), end_more1..3 (концовка).
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "art", "src")
OUT = os.path.join(ROOT, "godot", "art", "bg")


def load(name):
    return np.asarray(Image.open(os.path.join(SRC, name)).convert("RGB")).astype(np.float32) / 255.0


def save(a, name):
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    img.save(os.path.join(OUT, name + ".webp"), quality=92, method=6)


def rain(h, w, seed, n=420, alpha=0.10):
    rnd = random.Random(seed)
    layer = Image.new("L", (w, h), 0)
    px = layer.load()
    for _ in range(n):
        x0, y0 = rnd.uniform(0, w), rnd.uniform(-40, h)
        ln = rnd.uniform(14, 34)
        val = int(rnd.uniform(110, 255))
        for k in range(int(ln)):
            x, y = int(x0 + k * 0.08), int(y0 + k)
            if 0 <= x < w and 0 <= y < h:
                px[x, y] = max(px[x, y], val)
    a = np.asarray(layer.filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255.0
    return a[..., None] * alpha


def screen(base, add, color):
    c = np.array(color, np.float32)
    return 1 - (1 - base) * (1 - add * c)


def glow(h, w, cx, cy, r):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d2 = ((xx - cx) ** 2 + (yy - cy) ** 2) / (r * r)
    return np.exp(-d2)[..., None]


def smoke(h, w, x0, y0, phase, seed, length=150, amp=7.0, alpha=0.32):
    """Тонкая струйка дыма вверх от кончика сигареты."""
    rnd = random.Random(seed)
    layer = Image.new("L", (w, h), 0)
    px = layer.load()
    f1, f2 = rnd.uniform(0.035, 0.05), rnd.uniform(0.09, 0.12)
    for i in range(length):
        t = i / length
        y = y0 - i
        x = x0 + math.sin(i * f1 + phase) * amp * (0.3 + t * 1.6) + math.sin(i * f2 + phase * 1.7) * 2.5 * t
        v = int(255 * (1 - t) ** 1.3 * min(1.0, i / 6))
        wid = 1 + int(t * 5)
        for dx in range(-wid, wid + 1):
            xi = int(x + dx)
            if 0 <= xi < w and 0 <= y < h:
                px[xi, int(y)] = max(px[xi, int(y)], int(v * (1 - abs(dx) / (wid + 1))))
    a = np.asarray(layer.filter(ImageFilter.GaussianBlur(2.2))).astype(np.float32) / 255.0
    return a[..., None] * alpha


def ember(h, w, x, y, k):
    return glow(h, w, x, y, 3.5) * (0.55 + 0.35 * k)


def main():
    os.makedirs(OUT, exist_ok=True)
    light = load("bal_light.webp")
    h, w, _ = light.shape
    save(light, "bal_s0")
    # огонёк: мерцание тёплого ореола вокруг пламени зажигалки
    for i, k in enumerate([0.0, 0.9, 0.35, 1.0]):
        a = light.copy()
        a = screen(a, glow(h, w, 652, 445, 95) * (0.10 + 0.16 * k), (1.0, 0.62, 0.25))
        a = screen(a, glow(h, w, 656, 440, 14) * (0.15 + 0.35 * k), (1.0, 0.85, 0.5))
        a = screen(a, rain(h, w, 100 + i), (0.8, 0.82, 0.95))
        save(a, "bal_l%d" % i)
    talk = load("bal_talk.webp")
    h, w, _ = talk.shape
    for i in range(4):
        ph = i * math.pi / 2
        a = talk.copy()
        a = screen(a, smoke(h, w, 342, 306, ph, 7), (0.85, 0.85, 0.9))
        a = screen(a, smoke(h, w, 746, 434, ph + 1.3, 11, length=120), (0.85, 0.85, 0.9))
        k = 0.5 + 0.5 * math.sin(ph)
        a = screen(a, ember(h, w, 341, 309, k), (1.0, 0.5, 0.2))
        a = screen(a, ember(h, w, 745, 438, 1 - k), (1.0, 0.5, 0.2))
        a = screen(a, rain(h, w, 200 + i), (0.8, 0.82, 0.95))
        save(a, "bal_t%d" % i)
        if i == 1:
            t1 = a
    # концовка: курят (теплее) / смотрят на трубы (крупнее) / снег
    warm = t1 * np.array([1.06, 1.0, 0.92], np.float32) + 0.02
    save(warm, "end_more1")
    crop = Image.fromarray((np.clip(t1, 0, 1) * 255).astype(np.uint8)).crop((0, 60, 1100, 674))
    save(np.asarray(crop.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255.0, "end_more2")
    rnd = random.Random(9)
    lay = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(lay)
    for _ in range(520):
        x, y, r = rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(1.0, 3.2)
        d.ellipse((x - r, y - r, x + r, y + r), fill=int(rnd.uniform(120, 240)))
    sn = np.asarray(lay.filter(ImageFilter.GaussianBlur(0.7))).astype(np.float32)[..., None] / 255.0
    cold = talk * np.array([0.92, 0.97, 1.08], np.float32) + 0.03
    save(screen(cold, sn * 0.85, (0.97, 0.97, 1.0)), "end_more3")


if __name__ == "__main__":
    main()
