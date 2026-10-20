"""Кадры «2 месяц · Дедлайн» (арт сгенерирован по референсам игры, исходники — tools/art/src/m2/*.jpg).

Выход godot/art/bg/:
  m2_w0..w3   — герой работает: 11:30 / 15:40 / 19:30 / 20:30 (свет меняется, часы в углу)
  m2_sleep    — уснул за столом
  m2_enter0..6 — покадрово: открывает дверь «24 часа» (0–2, дождь), входит с закрытыми глазами (3),
                 Сера выходит из-за стеллажа (4–5) и упирается ладонью ему в грудь (6)
  m2_knock    — Сера в дверях ночью
  m2_rs0..3   — сидят на крыше (дым от сигареты, огонёк зажигалки, морось)
  m2_palm     — Сера рисует летучую мышь с будильником на ладони
  m2_shift, m2_portrait — ночная смена / портрет в мастерской
  m2_sn0..5, m2_hug0..5 — первый снег (падающий снег, цикл; большая снежинка в исходниках заменена обычной)
Запуск из корня: python3 tools/art/month2.py
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "art", "src", "m2")
OUT = os.path.join(ROOT, "godot", "art", "bg")
FONT = os.path.join(ROOT, "godot", "assets", "fonts", "Comfortaa.ttf")
W, H = 1376, 768


def load(name):
    im = Image.open(os.path.join(SRC, name + ".jpg")).convert("RGB").resize((W, H), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def grain(a, seed, amt=0.018):
    rng = np.random.default_rng(seed)
    return a + rng.normal(0, amt, a.shape[:2])[..., None].astype(np.float32)


def save(a, name, seed=1):
    a = grain(a, seed)
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(
        os.path.join(OUT, name + ".webp"), quality=90, method=6
    )


def glow(cx, cy, r):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    return np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (r * r))[..., None]


def screen(base, add, color):
    return 1 - (1 - base) * (1 - add * np.array(color, np.float32))


def grade(a, mul, add=(0, 0, 0), sat=1.0, gamma=1.0):
    g = a.mean(axis=2, keepdims=True)
    a = g + (a - g) * sat
    a = np.clip(a, 0, 1) ** gamma
    return a * np.array(mul, np.float32) + np.array(add, np.float32)


def clock(a, text):
    """Часы в углу кадра — как таймскип в аниме."""
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    f = ImageFont.truetype(FONT, 58)
    x, y = 1090, 40
    d.rounded_rectangle((x - 22, y - 14, x + 232, y + 74), 18, fill=(12, 10, 18, 150), outline=(200, 90, 120, 200), width=2)
    d.text((x + 105, y + 30), text, font=f, fill=(242, 236, 244, 255), anchor="mm")
    im = Image.alpha_composite(im, lay).convert("RGB")
    return np.asarray(im).astype(np.float32) / 255.0


def smoke(x0, y0, phase, seed, length=140, amp=6.0, alpha=0.3):
    rnd = random.Random(seed)
    lay = Image.new("L", (W, H), 0)
    px = lay.load()
    f1, f2 = rnd.uniform(0.035, 0.05), rnd.uniform(0.09, 0.12)
    for i in range(length):
        t = i / length
        y = int(y0 - i)
        x = x0 + math.sin(i * f1 + phase) * amp * (0.3 + t * 1.6) + math.sin(i * f2 + phase * 1.7) * 2.5 * t
        v = int(255 * (1 - t) ** 1.3 * min(1.0, i / 6))
        wid = 1 + int(t * 5)
        for dx in range(-wid, wid + 1):
            xi = int(x + dx)
            if 0 <= xi < W and 0 <= y < H:
                px[xi, y] = max(px[xi, y], int(v * (1 - abs(dx) / (wid + 1))))
    return np.asarray(lay.filter(ImageFilter.GaussianBlur(2.2))).astype(np.float32)[..., None] / 255.0 * alpha


def rain(seed, n=380, alpha=0.09):
    rnd = random.Random(seed)
    lay = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(lay)
    for _ in range(n):
        x, y, ln = rnd.uniform(0, W), rnd.uniform(-30, H), rnd.uniform(14, 30)
        d.line((x, y, x + 1.5, y + ln), fill=int(rnd.uniform(120, 255)), width=1)
    return np.asarray(lay.filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32)[..., None] / 255.0 * alpha


def snow_frames(base, n, seed, count=260):
    """Снег падает по полосам высотой BAND; за n кадров каждая снежинка проходит полосу — цикл бесшовный."""
    band = 192
    rnd = random.Random(seed)
    flakes = []
    for _ in range(count):
        flakes.append(
            (rnd.uniform(0, W), rnd.uniform(0, band), rnd.randrange(H // band), rnd.uniform(1.0, 3.0), rnd.uniform(0.5, 1.0), rnd.uniform(0, 6.28))
        )
    out = []
    for k in range(n):
        lay = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(lay)
        for x0, y0, row, r, a, ph in flakes:
            yy = (y0 + k * band / n) % band
            env = math.sin(math.pi * yy / band)  # плавно появляются и тают
            x = x0 + math.sin(ph + k * 2 * math.pi / n) * 6
            y = row * band + yy
            d.ellipse((x - r, y - r, x + r, y + r), fill=int(255 * a * env))
        s = np.asarray(lay.filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32)[..., None] / 255.0
        out.append(screen(base, s * 0.8, (0.96, 0.96, 1.0)))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    work = load("work")
    looks = [
        ("11:30", grade(work, (1.0, 1.0, 1.0))),
        ("15:40", grade(work, (1.04, 0.99, 0.92), (0.02, 0.01, 0.0), 1.05)),
        ("19:30", grade(work, (0.78, 0.82, 0.98), (0.0, 0.0, 0.03), 0.9, 1.1)),
        ("20:30", grade(work, (0.55, 0.6, 0.8), (0.0, 0.0, 0.02), 0.8, 1.25)),
    ]
    for i, (t, a) in enumerate(looks):
        if i >= 2:  # вечером экран светит сильнее
            a = screen(a, glow(310, 460, 230) * (0.18 + 0.1 * i), (0.6, 0.75, 1.0))
        save(clock(a, t), "m2_w%d" % i, 10 + i)
    save(clock(load("sleep"), "23:57"), "m2_sleep", 20)
    for k in ("knock", "palm", "shift", "portrait"):
        save(load(k), "m2_" + k, 30)
    for i in range(7):
        a = load("enter%d" % i)
        if i <= 2:  # улица: свой дождь на каждом кадре — капли «живые» при покадровой смене
            a = screen(a, rain(80 + i, 300, 0.07), (0.8, 0.82, 0.95))
        save(a, "m2_enter%d" % i, 70 + i)
    rs = load("roofsit")
    for i in range(4):
        ph = i * math.pi / 2
        a = screen(rs, smoke(649, 432, ph, 5), (0.85, 0.85, 0.9))
        a = screen(a, glow(790, 536, 22) * (0.25 + 0.2 * abs(math.sin(ph + 0.7))), (1.0, 0.7, 0.3))
        a = screen(a, rain(60 + i), (0.8, 0.82, 0.95))
        save(a, "m2_rs%d" % i, 40 + i)
    for name, src in (("m2_sn", "snow"), ("m2_hug", "snow_hug")):
        for i, a in enumerate(snow_frames(load(src), 6, 7)):
            save(a, "%s%d" % (name, i), 50 + i)
    print("ok")


if __name__ == "__main__":
    main()
