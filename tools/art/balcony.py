"""Балкон героя (ветка «Дальше больше»): фон balcony, CG cg_balcony1..3, кадры концовки end_more1..3.
Собирается из готовых ассетов игры (вид — roof.webp, персонажи — спрайты) + дорисованные кодом
перила, стены, банка-пепельница, сигареты, дым, дождь/снег. Линия и зерно — как у остальных фонов.
Запуск из корня репо: python3 tools/art/balcony.py → godot/art/bg/*.webp"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
A = os.path.join(ROOT, "godot", "assets")
OUT = os.path.join(ROOT, "godot", "art", "bg")
W, H = 1376, 768
SS = 2  # суперсэмплинг для линий
INK = (43, 33, 40, 255)


def load(p):
    return Image.open(os.path.join(A, p)).convert("RGBA")


def grain(im, amt=7, seed=1):
    rng = np.random.default_rng(seed)
    a = np.asarray(im).astype(np.int16)
    n = rng.normal(0, amt, a.shape[:2])[..., None]
    a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def grade(im, mul, add=(0, 0, 0)):
    a = np.asarray(im).astype(np.float32)
    a[..., :3] = np.clip(a[..., :3] * np.array(mul) + np.array(add), 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def watercolor(im, seed=11):
    """Акварельные пятна (низкочастотный шум яркости) + мягкость линии, как у фонов игры."""
    rng = np.random.default_rng(seed)
    n = rng.normal(0, 1, (H // 24 + 2, W // 24 + 2)).astype(np.float32)
    n = np.asarray(Image.fromarray(((n + 3) * 40).clip(0, 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(np.float32)
    k = 1 + (n / 255 - 0.47) * 0.22
    a = np.asarray(im.filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32)
    a[..., :3] *= k[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def wobble(pts, amp=1.2, seed=0):
    r = random.Random(seed)
    return [(x + r.uniform(-amp, amp), y + r.uniform(-amp, amp)) for x, y in pts]


def view(time="night"):
    """Вид с балкона: небо, ТЭЦ, дома — из roof.webp (без парапета и будки), чуть размыт (глубина)."""
    src = load("bg/roof.webp")
    v = src.crop((0, 221, 820, 221 + 458)).resize((W, H), Image.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (30, 28, 44, 255))
    canvas.paste(v, (0, 0))
    canvas = canvas.filter(ImageFilter.GaussianBlur(1.6))
    if time == "dawn":
        canvas = grade(canvas, (1.18, 1.0, 0.92), (26, 10, 0))
        g = Image.new("RGBA", (W, H))
        d = ImageDraw.Draw(g)
        for y in range(H):
            t = max(0.0, 1 - abs(y - 430) / 330)
            d.line([(0, y), (W, y)], fill=(255, 170, 120, int(70 * t)))
        canvas = Image.alpha_composite(canvas, g)
    return canvas


class Layer:
    def __init__(self):
        self.im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def poly(self, pts, fill, line=INK, w=3, seed=0):
        p = [(x * SS, y * SS) for x, y in wobble(pts, 0.9, seed)]
        self.d.polygon(p, fill=fill)
        if line:
            self.d.line(p + [p[0]], fill=line, width=w * SS, joint="curve")

    def line(self, pts, col=INK, w=3, seed=0):
        p = [(x * SS, y * SS) for x, y in wobble(pts, 0.7, seed)]
        self.d.line(p, fill=col, width=max(1, int(w * SS)), joint="curve")

    def ell(self, box, fill, line=INK, w=3):
        b = [c * SS for c in box]
        self.d.ellipse(b, fill=fill, outline=line, width=w * SS if line else 0)

    def done(self, paint=True):
        im = self.im.resize((W, H), Image.LANCZOS)
        return watercolor(im) if paint else im


def balcony(time="night", snow=False, seed=3):
    """Передний план: потолочная плита, левая стена с дверью (тёплый свет), правая — лыжи, перила."""
    L = Layer()
    night = time == "night"
    wall = (150, 160, 140, 255) if not night else (92, 98, 96, 255)
    wall_d = (118, 126, 112, 255) if not night else (70, 74, 76, 255)
    conc = (120, 116, 118, 255) if not night else (64, 62, 70, 255)
    # потолок (плита балкона сверху)
    L.poly([(0, 0), (W, 0), (W, 58), (1240, 70), (150, 74), (0, 64)], conc, seed=1)
    L.line([(150, 74), (1240, 70)], (30, 26, 32, 255), 2)
    for x in range(180, 1220, 64):
        L.line([(x, 66), (x + 3, 72)], (40, 36, 44, 200), 2, seed=x)
    # бельевая верёвка + прищепки + полотенце
    rope = [(150 + i * 27, 112 + 22 * math.sin(i / 40 * math.pi)) for i in range(41)]
    L.line(rope, (210, 205, 196, 255) if not night else (150, 146, 140, 255), 2)
    for x in (430, 470, 860):
        y = 112 + 22 * math.sin((x - 150) / 1080 * math.pi)
        L.poly([(x - 4, y - 8), (x + 4, y - 8), (x + 3, y + 10), (x - 3, y + 10)], (196, 120, 140, 255), w=2, seed=x)
    ty = 112 + 22 * math.sin((450 - 150) / 1080 * math.pi)
    L.poly([(424, ty), (478, ty + 2), (474, ty + 118), (452, ty + 112), (430, ty + 120)],
           (196, 182, 160, 255) if not night else (120, 112, 104, 255), w=2, seed=5)
    for k in range(4):
        L.line([(428, ty + 30 + k * 18), (476, ty + 31 + k * 18)], (160, 70, 80, 220), 3, seed=k)
    # левая стена и балконная дверь с тёплым светом
    L.poly([(0, 64), (150, 74), (150, H), (0, H)], wall, seed=2)
    L.poly([(18, 150), (128, 156), (128, H), (18, H)], (60, 46, 40, 255), seed=3)
    L.poly([(30, 166), (116, 170), (116, 470), (30, 466)],
           (255, 214, 150, 255) if night else (236, 226, 200, 255), w=2, seed=4)
    L.line([(73, 168), (73, 468)], INK, 3)
    L.line([(30, 318), (116, 320)], INK, 3)
    L.poly([(30, 490), (116, 492), (116, H), (30, H)], (88, 66, 54, 255), w=2, seed=6)
    for (x, y, r) in ((60, 600, 26), (100, 120, 14), (20, 700, 18)):
        L.poly([(x - r, y), (x - r * 0.3, y - r * 0.8), (x + r, y - r * 0.3), (x + r * 0.6, y + r * 0.7)],
               wall_d, line=(60, 60, 60, 160), w=2, seed=x)
    # правая стена + лыжи
    L.poly([(1240, 70), (W, 58), (W, H), (1240, H)], wall, seed=7)
    for k, col in enumerate(((150, 52, 58, 255), (60, 92, 140, 255))):
        x0 = 1262 + k * 34
        L.poly([(x0, 130), (x0 + 16, 126), (x0 + 30, H), (x0 + 14, H)], col if not night else
               tuple(int(c * 0.62) for c in col[:3]) + (255,), seed=20 + k)
        L.line([(x0 + 6, 128), (x0 + 22, H)], (230, 230, 220, 150), 2)
    L.ell((1250, 116, 1330, 150), (60, 56, 52, 255), w=2)  # загнутые носы
    # перила: нижняя панель (крашеный профлист, ржавчина), поручень
    top = 480
    panel = (78, 112, 112, 255) if not night else (46, 64, 70, 255)
    L.poly([(150, top + 18), (1240, top + 14), (1240, H), (150, H)], panel, seed=9)
    for x in range(168, 1240, 30):
        L.line([(x, top + 22), (x + 2, H)], (30, 44, 48, 200) if night else (52, 80, 82, 220), 3, seed=x)
        L.line([(x + 12, top + 22), (x + 13, H)], (110, 150, 150, 120) if night else (130, 170, 168, 140), 2, seed=x + 1)
    rnd = random.Random(seed)
    for _ in range(14):
        x = rnd.uniform(170, 1220)
        y = rnd.uniform(top + 30, H - 40)
        L.line([(x, y), (x + rnd.uniform(-3, 3), y + rnd.uniform(30, 120))], (140, 70, 40, 140), rnd.uniform(3, 7), seed=int(x))
    L.poly([(140, top - 6), (1250, top - 10), (1250, top + 16), (140, top + 20)],
           (112, 84, 64, 255) if night else (150, 112, 84, 255), seed=10)
    L.line([(146, top - 2), (1246, top - 6)], (200, 170, 140, 160), 2)
    im = L.done()
    return im, top


def can_ashtray(L, cx, by, butts=2, s=1.0):
    """Банка из-под шпрот на поручне: овальная, с отогнутой крышкой, окурки."""
    w, h = 64 * s, 26 * s
    L.ell((cx - w / 2, by - h, cx + w / 2, by), (150, 150, 160, 255), w=2)
    L.ell((cx - w / 2 + 5, by - h + 4, cx + w / 2 - 5, by - 6), (64, 56, 52, 255), w=2)
    L.poly([(cx + w / 2 - 6, by - h + 2), (cx + w / 2 + 20 * s, by - h - 26 * s), (cx + w / 2 + 26 * s, by - h - 20 * s),
            (cx + w / 2, by - h + 8)], (186, 186, 196, 255), w=2, seed=int(cx))
    for k in range(butts):
        x = cx - 18 * s + k * 16 * s
        L.poly([(x, by - 14 * s), (x + 22 * s, by - 20 * s), (x + 23 * s, by - 16 * s), (x + 1, by - 10 * s)],
               (230, 222, 206, 255), w=2, seed=k + 40)
        L.poly([(x, by - 14 * s), (x + 7 * s, by - 16 * s), (x + 8 * s, by - 12 * s), (x + 1, by - 10 * s)],
               (196, 140, 80, 255), line=None)


def smoke(im, x, y, seed, length=260, alpha=110, drift=1.0):
    g = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    r = random.Random(seed)
    px, py = x, y
    for i in range(70):
        t = i / 70
        px += math.sin(i * 0.23 + seed) * 2.2 * drift + 0.6 * drift
        py -= length / 70
        rad = 3 + t * 22
        a = int(alpha * (1 - t) * (0.6 + 0.4 * r.random()))
        d.ellipse([px - rad, py - rad, px + rad, py + rad], fill=(220, 220, 232, a))
    g = g.filter(ImageFilter.GaussianBlur(7))
    return Image.alpha_composite(im, g)


def glow(im, x, y, r, col, a):
    g = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    d.ellipse([x - r, y - r, x + r, y + r], fill=col + (a,))
    g = g.filter(ImageFilter.GaussianBlur(r * 0.45))
    return Image.alpha_composite(im, g)


def rain(im, seed, n=320, snow=False):
    g = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    r = random.Random(seed)
    for _ in range(n):
        x, y = r.uniform(0, W), r.uniform(70, H)
        if snow:
            s = r.uniform(1.5, 4.2)
            d.ellipse([x - s, y - s, x + s, y + s], fill=(240, 242, 250, int(r.uniform(120, 220))))
        else:
            ln = r.uniform(14, 34)
            d.line([(x, y), (x - ln * 0.18, y + ln)], fill=(200, 210, 235, int(r.uniform(40, 110))), width=1)
    return Image.alpha_composite(im, g.filter(ImageFilter.GaussianBlur(0.6 if snow else 0.3)))


def drips(im, top, seed):
    """Капли, висящие на поручне и на краю плиты."""
    L = Layer()
    r = random.Random(seed)
    for _ in range(26):
        x = r.uniform(160, 1230)
        y = top + 16 + r.uniform(-2, 2)
        L.ell((x - 3, y, x + 3, y + 8), (190, 205, 230, 200), line=None)
    for _ in range(16):
        x = r.uniform(170, 1220)
        L.ell((x - 2.5, 72, x + 2.5, 80), (190, 205, 230, 180), line=None)
    return Image.alpha_composite(im, L.done())


def sprite(name, h, night=True):
    s = load("sprites/%s.webp" % name)
    k = h / s.height
    s = s.resize((int(s.width * k), int(h)), Image.LANCZOS)
    if night:
        s = grade(s, (0.74, 0.74, 0.86), (4, 2, 10))
    return s


def cigarette(L, x0, y0, ang, ln=34, ember=True):
    """Сигарета между пальцами: фильтр, бумага, тлеющий кончик."""
    dx, dy = math.cos(ang), math.sin(ang)
    nx, ny = -dy * 3.2, dx * 3.2
    x1, y1 = x0 + dx * ln, y0 + dy * ln
    xf, yf = x0 + dx * ln * 0.3, y0 + dy * ln * 0.3
    L.poly([(x0 + nx, y0 + ny), (xf + nx, yf + ny), (xf - nx, yf - ny), (x0 - nx, y0 - ny)], (206, 146, 84, 255), w=2)
    L.poly([(xf + nx, yf + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (xf - nx, yf - ny)], (240, 236, 228, 255), w=2)
    if ember:
        L.ell((x1 - 4, y1 - 4, x1 + 4, y1 + 4), (255, 120, 60, 255), line=(120, 40, 30, 255), w=1)
    return x1, y1


def compose_people(base, top, pair, night=True, snow=False, seed=1, smoking=True):
    """Сера слева, герой справа, спиной к перилам. pair = (sera_expr, hero_expr)."""
    im = base.copy()
    se, he = pair
    L0 = Layer()
    can_ashtray(L0, 640, top - 4, 2)
    im = Image.alpha_composite(im, L0.done())
    sk, hk = 1000 / 1494, 980 / 1494
    sx, sy, hx, hy = 250, 92, 690, 40
    s = sprite("sera_" + se, 1000, night)
    h = sprite("hero_" + he, 980, night)
    im.alpha_composite(s, (sx, sy))
    im.alpha_composite(h, (hx, hy))
    L = Layer()
    embers = []
    if smoking:
        # Сера: сигарета в пальцах, выглядывающих из рукава (руки сложены у пояса)
        embers.append(cigarette(L, sx + 600 * sk, sy + 1000 * sk, -1.2, 30))
        # герой: в опущенной правой руке (на спрайте слева)
        embers.append(cigarette(L, hx + 228 * hk, hy + 1040 * hk, -0.45, 32))
    im = Image.alpha_composite(im, L.done(False))
    for (x, y) in embers:
        im = glow(im, x, y, 30, (255, 120, 60), 130)
        im = smoke(im, x, y - 4, seed=int(x), length=300, alpha=90)
    return im


def lighter_close(night=True, mugs=False, snow=False, seed=4):
    """Крупный план: поручень, банка-пепельница, пачка, розовая зажигалка с огоньком; размытый город."""
    v = view("night" if night else "dawn").filter(ImageFilter.GaussianBlur(9))
    v = v.resize((int(W * 1.25), int(H * 1.25)), Image.LANCZOS).crop((120, 40, 120 + W, 40 + H))
    # боке окон
    g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    r = random.Random(seed)
    for _ in range(60):
        x, y, rr = r.uniform(0, W), r.uniform(200, 470), r.uniform(8, 26)
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(255, 200, 120, int(r.uniform(30, 90))))
    v = Image.alpha_composite(v, g.filter(ImageFilter.GaussianBlur(3)))
    L = Layer()
    top = 520
    L.poly([(-10, top), (W + 10, top - 30), (W + 10, top + 70), (-10, top + 110)], (106, 80, 62, 255), w=4, seed=1)
    L.poly([(-10, top + 110), (W + 10, top + 70), (W + 10, H + 10), (-10, H + 10)], (40, 56, 62, 255), w=4, seed=2)
    for x in range(0, W, 60):
        L.line([(x, top + 116 - x * 0.03), (x + 4, H)], (24, 34, 38, 220), 5, seed=x)
    # банка крупно
    cx, by = 560, top + 28
    w, hh = 260, 96
    L.ell((cx - w / 2, by - hh, cx + w / 2, by), (156, 156, 166, 255), w=4)
    L.ell((cx - w / 2 + 16, by - hh + 12, cx + w / 2 - 16, by - 18), (58, 50, 46, 255), w=3)
    L.poly([(cx + w / 2 - 20, by - hh + 8), (cx + w / 2 + 70, by - hh - 90), (cx + w / 2 + 94, by - hh - 70),
            (cx + w / 2 + 4, by - hh + 30)], (192, 192, 202, 255), w=4, seed=8)
    for i in range(5):
        L.line([(cx - w / 2 + 30 + i * 46, by - hh + 30), (cx - w / 2 + 40 + i * 46, by - 26)], (90, 84, 80, 120), 3, seed=i)
    for k in range(3 if not mugs else 5):
        x = cx - 80 + k * 38
        L.poly([(x, by - 50), (x + 70, by - 72), (x + 74, by - 60), (x + 4, by - 38)], (232, 224, 208, 255), w=3, seed=50 + k)
        L.poly([(x, by - 50), (x + 22, by - 57), (x + 26, by - 45), (x + 4, by - 38)], (200, 142, 82, 255), line=None)
    # пачка (мятая, без марки — красная полоса)
    px0 = 900
    L.poly([(px0, top - 4), (px0 + 150, top - 22), (px0 + 160, top - 230), (px0 + 6, top - 214)], (232, 228, 220, 255), w=4, seed=9)
    L.poly([(px0 + 3, top - 120), (px0 + 155, top - 138), (px0 + 157, top - 176), (px0 + 4, top - 160)], (170, 40, 52, 255), w=3, seed=10)
    L.poly([(px0 + 6, top - 214), (px0 + 160, top - 230), (px0 + 150, top - 262), (px0 + 2, top - 246)], (210, 206, 198, 255), w=4, seed=11)
    for k in range(3):
        L.poly([(px0 + 30 + k * 34, top - 246), (px0 + 52 + k * 34, top - 248), (px0 + 54 + k * 34, top - 300 + k * 8),
                (px0 + 32 + k * 34, top - 298 + k * 8)], (236, 232, 224, 255), w=3, seed=60 + k)
        L.poly([(px0 + 30 + k * 34, top - 260), (px0 + 52 + k * 34, top - 262), (px0 + 53 + k * 34, top - 276 + k * 8 + 4),
                (px0 + 31 + k * 34, top - 274 + k * 8 + 4)], (204, 146, 84, 255), line=None)
    # зажигалка (розовая, полупрозрачная)
    lx, ly = 300, top - 10
    L.poly([(lx, ly), (lx + 78, ly - 8), (lx + 70, ly - 190), (lx - 6, ly - 182)], (236, 120, 160, 230), w=4, seed=12)
    L.poly([(lx - 6, ly - 182), (lx + 70, ly - 190), (lx + 68, ly - 236), (lx - 4, ly - 228)], (170, 170, 180, 255), w=4, seed=13)
    L.ell((lx + 10, ly - 262, lx + 50, ly - 222), (110, 104, 110, 255), w=3)
    if mugs:
        for k, (mx, col) in enumerate(((150, (220, 216, 206, 255)), (1180, (150, 40, 60, 255)))):
            L.poly([(mx - 70, top - 4 - k * 18), (mx + 70, top - 10 - k * 18), (mx + 64, top - 180 - k * 18), (mx - 64, top - 174 - k * 18)], col, w=4, seed=70 + k)
            L.ell((mx - 66, top - 194 - k * 18, mx + 66, top - 160 - k * 18), (90, 50, 30, 255), w=3)
            L.d.arc([(mx + 50) * SS, (top - 150 - k * 18) * SS, (mx + 110) * SS, (top - 60 - k * 18) * SS], -90, 90, fill=INK, width=8 * SS)
    im = Image.alpha_composite(v, L.done())
    if not mugs:
        im = glow(im, lx + 30, ly - 290, 70, (255, 170, 80), 170)
        F = Layer()
        F.poly([(lx + 30, ly - 340), (lx + 46, ly - 296), (lx + 30, ly - 262), (lx + 14, ly - 296)], (255, 220, 140, 255), line=(220, 110, 40, 255), w=2)
        im = Image.alpha_composite(im, F.done())
        for x in (cx - 80 + 74, cx - 42 + 74, cx - 4 + 74):
            im = smoke(im, x, by - 76, seed=int(x), length=360, alpha=70)
    else:
        for mx in (150, 1180):
            im = smoke(im, mx, top - 200, seed=mx, length=260, alpha=60, drift=0.4)
    im = rain(im, seed, n=180, snow=snow)
    return im


def finish(im, seed, vignette=0.35):
    im = grain(im, 6, seed)
    a = np.asarray(im).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    k = 1 - vignette * np.clip(d - 0.55, 0, 1)
    a[..., :3] *= k[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA").convert("RGB")


def scene(time="night", snow=False, people=None, seed=1, smoking=True):
    v = view(time)
    fg, top = balcony(time, snow, seed)
    im = Image.alpha_composite(v, fg)
    if time == "night":
        im = glow(im, 70, 330, 230, (255, 190, 120), 70)
    im = drips(im, top, seed)
    if people:
        im = compose_people(im, top, people, night=time == "night", snow=snow, seed=seed, smoking=smoking)
    else:
        L = Layer()
        can_ashtray(L, 640, top - 4, 2)
        im = Image.alpha_composite(im, L.done())
    im = rain(im, seed + 9, n=260 if not snow else 200, snow=snow)
    return finish(im, seed)


def closeup(im, cx, cy, z, flame=None):
    """Наезд на часть кадра (лица) + огонёк зажигалки, тёплый свет на лицах."""
    w, h = W / z, H / z
    x0, y0 = min(max(0, cx - w / 2), W - w), min(max(0, cy - h / 2), H - h)
    im = im.convert("RGBA").crop((int(x0), int(y0), int(x0 + w), int(y0 + h))).resize((W, H), Image.LANCZOS)
    if flame:
        fx, fy = (flame[0] - x0) * z, (flame[1] - y0) * z
        im = glow(im, fx, fy, 380, (255, 160, 80), 70)
        im = glow(im, fx, fy, 90, (255, 190, 110), 170)
        F = Layer()
        F.poly([(fx, fy - 46), (fx + 15, fy - 6), (fx, fy + 14), (fx - 15, fy - 6)], (255, 226, 150, 255), line=(230, 120, 40, 255), w=2)
        F.ell((fx - 6, fy - 2, fx + 6, fy + 12), (120, 170, 255, 220), line=None)
        # сигарета, которую прикуривают: тянется к огоньку сверху
        L = Layer()
        cigarette(L, fx - 70, fy - 40, 0.42, 64, ember=False)
        im = Image.alpha_composite(im, L.done(False))
        im = Image.alpha_composite(im, F.done(False))
    return finish(im, 9, 0.45)


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name + ".webp"), "WEBP", quality=90, method=6)
    print("ok", name)


if __name__ == "__main__":
    save(scene("night", people=None, seed=1), "balcony")
    save(scene("night", people=("soft", "soft"), seed=2), "cg_balcony1")
    raw = scene("night", people=("tease", "shy"), seed=3, smoking=False)
    save(closeup(raw, 690, 330, 1.7, flame=(668, 420)), "cg_balcony2")
    v = view("night")
    fg, top = balcony("night")
    im = Image.alpha_composite(v, fg)
    im = drips(im, top, 4)
    L = Layer()
    can_ashtray(L, 640, top - 4, 2)
    im = Image.alpha_composite(im, L.done())
    for x in (560, 760):
        C = Layer()
        ex, ey = cigarette(C, x - 30, top - 4, -0.25, 34)
        im = Image.alpha_composite(im, C.done(False))
        im = glow(im, ex, ey, 26, (255, 120, 60), 140)
        im = smoke(im, ex, ey - 4, seed=x, length=380, alpha=120)
    save(closeup(rain(im, 14, 240), 690, 330, 1.3), "cg_balcony3")
    save(scene("night", snow=True, people=("happy", "grin"), seed=5), "end_more1")
    save(scene("dawn", snow=True, people=None, seed=6), "end_more2")
    raw = scene("night", snow=True, people=("laugh", "soft"), seed=7)
    save(closeup(raw, 700, 300, 1.45), "end_more3")
