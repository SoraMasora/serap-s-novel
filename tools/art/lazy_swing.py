"""Концовка «Ленивый идиот»: покадровая пиксельная анимация — герой качается на качелях под дождём,
останавливается, достаёт сигарету, прикуривает и курит. Тот же пиксель, что у крупных планов карты.
Кадры 160×90, сохраняются ×8 (1280×720, nearest) — чтобы в катсцене не мылились.
Запуск из корня репо: python3 tools/art/lazy_swing.py → godot/art/bg/lazy_*.webp"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixel_closeups import P, W, H, night_yard, slant  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "art", "bg")
HP = {"K": "#121018", "k": "#2e2a3a", "h": "#4a4560", "S": "#f3e3db", "s": "#d8c0b8", "e": "#2a2436",
      "w": "#ffffff", "m": "#9a6a70", "T": "#19181f", "t": "#2f2d3a", "J": "#6a6a78", "j": "#4e4e5a",
      "B": "#0c0c10", "W": "#d8d8de", "D": "#cfe0ff", "c": "#f0b0b8"}


def hero_swing(p, cx, seat_y, phase, hand="chains", cig="none", fire="none", eyes="half", lean=0):
    c = HP
    cy = seat_y - 27 + lean
    # затылок/объём волос — лохматые, чёрные
    p.ell(cx, cy - 2, 15, 13.5, c["K"])
    for side in (-1, 1):
        for j in range(8):
            p.px(cx + side * (15 + (j % 3 == 0)), cy - 4 + j * 2, c["K"])
        p.px(cx + side * 16, cy + 9, c["K"])
    for x, y in ((cx - 9, cy - 13), (cx - 3, cy - 15), (cx + 4, cy - 14), (cx + 10, cy - 12), (cx - 13, cy - 9)):
        p.r(x, y, 3, 2, c["K"])
    p.ell(cx - 5, cy - 9, 5, 2.5, c["k"])
    p.px(cx - 6, cy - 10, c["h"])
    p.px(cx - 3, cy - 10, c["h"])
    # лицо
    p.ell(cx, cy + 3, 10.5, 9, c["S"])
    for x in range(cx - 7, cx + 8):
        p.px(x, cy + 11, c["s"])
    # чёлка — длинные острые пряди почти до глаз
    for x in range(cx - 12, cx + 13):
        k = (x - cx + 20) % 6
        depth = [7, 4, 8, 5, 3, 6][k] if abs(x - cx) < 11 else 12
        for y in range(cy - 8, cy - 4 + depth):
            p.px(x, y, c["K"] if k not in (1, 4) else c["k"])
    # глаза: полуприкрытые, усталые
    for ex in (cx - 6, cx + 3):
        if eyes == "closed":
            p.r(ex, cy + 4, 4, 1, c["e"])
        else:
            p.r(ex, cy + 2, 4, 1, c["K"])
            p.r(ex, cy + 3, 4, 2 if eyes == "half" else 3, c["e"])
            p.px(ex + 1, cy + 3, c["w"])
    # серьги
    p.px(cx - 11, cy + 6, c["W"])
    p.px(cx + 11, cy + 6, c["W"])
    p.px(cx + 11, cy + 8, c["W"])
    # рот
    if cig == "none":
        p.r(cx - 1, cy + 8, 3, 1, c["m"])
    else:
        p.r(cx - 1, cy + 8, 2, 1, c["m"])
    # шея, футболка оверсайз
    p.r(cx - 3, cy + 11, 7, 3, c["S"])
    for j in range(15):
        hw = 11 + j * 0.3
        for x in range(round(cx - hw), round(cx + hw) + 1):
            col = c["T"] if (x * 5 + j * 3) % 13 else c["t"]
            p.px(x, cy + 13 + j, col)
    p.r(cx - 3, cy + 13, 7, 1, c["t"])
    # руки
    def arm(side, hx, hy):
        sx0, sy0 = cx + side * 11, cy + 15
        n = 14
        for i in range(n + 1):
            t = i / n
            x = round(sx0 + (hx - sx0) * t)
            y = round(sy0 + (hy - sy0) * t)
            p.r(x - 1, y, 3, 2, c["T"] if t < 0.45 else c["S"])
        p.r(hx - 1, hy - 1, 3, 3, c["S"])

    if hand == "chains":
        arm(-1, cx - 17, cy + 10)
        arm(1, cx + 17, cy + 10)
    else:
        arm(1, cx + 17, cy + 10)  # левая (справа на экране) держит цепь
        if hand == "pocket":
            arm(-1, cx - 9, seat_y - 3)
        elif hand == "pack":
            arm(-1, cx - 5, cy + 18)
            p.r(cx - 7, cy + 14, 4, 5, "#e8e4dc")
            p.r(cx - 7, cy + 16, 4, 1, "#b3202a")
            p.px(cx - 6, cy + 13, "#f0ece4")
        elif hand == "mouth":
            arm(-1, cx + 1, cy + 9)
        elif hand == "lighter":
            arm(-1, cx + 4, cy + 12)
            p.r(cx + 3, cy + 11, 2, 3, "#e8709a")
        elif hand == "rest":
            arm(-1, cx - 9, seat_y - 5)
    # сигарета во рту
    tip = None
    if cig in ("mouth", "lit"):
        for i in range(5):
            p.px(cx + 1 + i, cy + 8 + (i > 2), "#f0ece4" if i > 0 else "#d09050")
        tip = (cx + 6, cy + 9)
        if cig == "lit":
            p.px(tip[0], tip[1], "#ff6a3a")
            p.glow(tip[0], tip[1], 3, (255, 120, 60), 0.5 + 0.25 * (phase % 2))
    if fire == "spark":
        for dx, dy in ((0, 0), (1, -1), (-1, -1), (2, 0)):
            p.px(cx + 5 + dx, cy + 9 + dy, "#ffe08a")
    elif fire == "flame":
        p.px(cx + 5, cy + 10, "#4a8aff")
        p.r(cx + 5, cy + 7, 1, 3, "#ffd060")
        p.px(cx + 5, cy + 6, "#fff0b0")
        p.glow(cx + 4, cy + 6, 14, (255, 180, 90), 0.35)
    # штаны на сиденье, ноги в кедах болтаются
    p.r(cx - 12, seat_y - 3, 25, 3, c["J"])
    p.r(cx - 12, seat_y - 1, 25, 1, c["j"])
    sw = [0, 1, 0, -1][phase % 4] if hand == "chains" else 0
    for lx in (cx - 7, cx + 3):
        for j in range(13):
            x = lx + round(sw * j / 12)
            p.r(x, seat_y + 2 + j, 5, 1, c["J"] if j % 5 else c["j"])
        p.r(lx + sw - 1, seat_y + 15, 6, 2, c["B"])
        p.r(lx + sw, seat_y + 15, 2, 1, c["W"])
    for x, y in ((cx - 9, cy - 3), (cx + 8, cy - 6), (cx - 12, cy + 12), (cx + 12, cy + 18)):
        p.px(x, y, c["D"])
    return tip


def puff(p, x, y, k, a=0.4):
    for i in range(k):
        yy = y - i * 3
        xx = x + round(math.sin(i * 0.9) * 2) + i // 2
        r = 1 + i // 2
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r:
                    p.blend(xx + dx, yy + dy, (210, 212, 226), a * (1 - i / (k + 1)))


def frame(ang, phase, **kw):
    p = P()
    night_yard(p, 7)
    p.r(10, 4, 2, 62, "#2a2a30")
    p.r(6, 4, 9, 2, "#2a2a30")
    p.r(7, 6, 7, 1, "#ffe2a0")
    p.glow(11, 30, 34, (255, 214, 150), 0.14)
    red, dred = "#8a2f33", "#5e1e22"
    for x in (34, 126):
        slant(p, x, 3, x - 9, 78, red, dred)
        slant(p, x, 3, x + 9, 78, red, dred)
    p.r(28, 2, 105, 3, red)
    p.r(28, 5, 105, 1, dred)
    piv_y, ln = 5, 62
    sx = 80 + math.sin(ang) * ln
    sy = piv_y + math.cos(ang) * ln
    for cx0 in (62, 98):
        ex = cx0 + math.sin(ang) * ln
        for k in range(ln):
            t = k / ln
            p.px(round(cx0 + (ex - cx0) * t), round(piv_y + (sy - piv_y) * t), "#9a9aa6" if k % 3 else "#6a6a76")
    smoke = kw.pop("smoke", 0)
    tip = hero_swing(p, int(round(sx)), int(round(sy)), phase, **kw)
    p.r(int(round(sx - 19)), int(round(sy)), 38, 2, "#6a4426")
    p.r(int(round(sx - 19)), int(round(sy + 2)), 38, 1, "#3a2414")
    p.ell(80, 84, 20, 1.6, "#2a2832")
    if tip and smoke:
        puff(p, tip[0] + 1, tip[1] - 2, 3 + (phase % 3) * 2, 0.45)
    if smoke == 2:
        puff(p, int(sx) + 2, int(sy) - 40 - (phase % 4) * 3, 9, 0.35)
    p.rain(11, phase, n=90)
    return p.im


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.resize((W * 8, H * 8), Image.NEAREST).save(os.path.join(OUT, name + ".webp"), lossless=True)


if __name__ == "__main__":
    # 1) качается (4 кадра, цикл)
    for i in range(4):
        save(frame(math.sin(i * math.pi / 2) * 0.32, i, hand="chains"), "lazy_sw%d" % i)
    # 2) остановился и прикуривает (8 кадров, один раз)
    seq = [dict(hand="chains"), dict(hand="pocket"), dict(hand="pack"), dict(hand="mouth", cig="mouth"),
           dict(hand="lighter", cig="mouth"), dict(hand="lighter", cig="mouth", fire="spark"),
           dict(hand="lighter", cig="mouth", fire="flame", eyes="closed"), dict(hand="rest", cig="lit", smoke=1)]
    for i, kw in enumerate(seq):
        save(frame(0.0, i, **kw), "lazy_s%d" % i)
    # 3) курит (4 кадра, цикл)
    for i in range(4):
        save(frame(math.sin(i * math.pi / 2) * 0.05, i, hand="rest", cig="lit", smoke=2 if i % 2 else 1,
                   eyes="closed" if i == 2 else "half"), "lazy_l%d" % i)
    print("ok")
