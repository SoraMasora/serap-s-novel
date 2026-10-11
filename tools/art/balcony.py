"""Балкон героя (ветка «Дальше больше») — в стилистике фонов/CG игры: тонкая тушь, приглушённые
краски, облупленная краска с обводкой, зерно. Вид — roof.webp (ТЭЦ, дома) и yard.webp (двор внизу),
персонажи со спины — вырезаны из cg_roof.webp (GrabCut) и доработаны: руки, сигареты, зажигалка,
дым дорисованы кодом.

Выход (godot/art/bg/):
  balcony                 — пустой балкон (фон для диалогов со спрайтами)
  bal_s0                  — стоят у перил
  bal_p0..p4              — Сера достаёт пачку и передаёт сигарету, Кир берёт её в зубы
  bal_l0..l2              — зажигалка: прикуривает Киру, потом себе
  bal_i0..i4              — затяжка и выдох дыма
  bal_t0..t3              — стоят, курят и разговаривают (цикл, фон «bal_talk»)
  end_more1..3            — кадры концовки «Дальше больше»
Запуск из корня репо: python3 tools/art/balcony.py   (BAL_QUICK=1 — только фон и bal_s0)"""
import math
import os
import random

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
A = os.path.join(ROOT, "godot", "assets", "bg")
OUT = os.path.join(ROOT, "godot", "art", "bg")
W, H = 1376, 768
SS = 2
INK = (38, 30, 36)
# кадр персонажей: область cg_roof (x0, y0) масштабируется в K раз
CX0, CY0, K = 238.0, 262.0, 1.864
KIR_SHIFT = -25  # Кир ближе к Сере (в пикселях cg_roof)
RAIL_Y = 505  # верх перил
WALL_L, WALL_R, SLAB_Y = 112, 1264, 44


def noise(seed, cell, w=W, h=H):
    r = np.random.default_rng(seed)
    n = r.standard_normal((h // cell + 3, w // cell + 3)).astype(np.float32)
    n = cv2.resize(n, (w + 3 * cell, h + 3 * cell), interpolation=cv2.INTER_CUBIC)[:h, :w]
    return n / (np.abs(n).max() + 1e-6)


def arr(im):
    return np.asarray(im).astype(np.float32)


def img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def poly_mask(pts, blur=0.0):
    m = Image.new("L", (W * SS, H * SS), 0)
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    m = m.resize((W, H), Image.LANCZOS)
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(m).astype(np.float32)[..., None] / 255.0


def paint(base, color, mask, mottle=0.08, seed=0, streaks=0.0):
    """Залить маску «краской»: цвет + акварельные пятна + вертикальные подтёки."""
    c = np.ones((H, W, 3), np.float32) * np.array(color, np.float32)
    c *= (1 + mottle * noise(seed, 40)[..., None] + mottle * 0.5 * noise(seed + 1, 9)[..., None])
    if streaks:
        r = np.random.default_rng(seed + 5)
        s = r.standard_normal((1, W)).astype(np.float32)
        s = cv2.GaussianBlur(s, (0, 0), 2.2)
        s = np.repeat(s, H, 0) * (0.6 + 0.4 * noise(seed + 7, 60))
        c *= (1 + streaks * s[..., None])
    base[..., :3] = base[..., :3] * (1 - mask) + c * mask
    return base


class Ink:
    """Тушь поверх картинки (суперсэмплинг ×2, лёгкое дрожание линии)."""

    def __init__(self):
        self.im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.r = random.Random(3)

    def line(self, pts, w=1.6, col=INK, wob=0.6, alpha=230):
        pts = [(x + self.r.uniform(-wob, wob), y + self.r.uniform(-wob, wob)) for x, y in pts]
        self.d.line([(x * SS, y * SS) for x, y in pts], fill=col + (alpha,), width=max(1, int(w * SS)), joint="curve")

    def seg(self, a, b, w=1.6, n=6, **kw):
        pts = [(a[0] + (b[0] - a[0]) * t / n, a[1] + (b[1] - a[1]) * t / n) for t in range(n + 1)]
        self.line(pts, w, **kw)

    def poly(self, pts, w=1.5, fill=None, **kw):
        if fill:
            self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill)
        self.line(pts + [pts[0]], w, **kw)

    def ellipse(self, box, w=1.4, fill=None, col=INK):
        x0, y0, x1, y1 = box
        self.d.ellipse((x0 * SS, y0 * SS, x1 * SS, y1 * SS), fill=fill, outline=col + (230,), width=int(w * SS))

    def comp(self, base):
        lay = self.im.resize((W, H), Image.LANCZOS)
        return Image.alpha_composite(base, lay)


def peel(ink, cx, cy, s, seed, col):
    """Пятно облупленной краски с обводкой (как в подъезде из stairs.webp)."""
    r = random.Random(seed)
    n = 16
    pts = []
    for i in range(n):
        a = i / n * 2 * math.pi
        rr = s * (r.uniform(0.6, 0.95) if i % 2 else r.uniform(0.85, 1.1))
        pts.append((cx + math.cos(a) * rr * 1.25, cy + math.sin(a) * rr))
    ink.poly(pts, 1.0, fill=col + (255,), alpha=170)


# ── вид ──
def view():
    src = Image.open(os.path.join(A, "roof.webp")).convert("RGBA")
    sc = 1.376
    v = src.crop((0, 0, 1000, 558)).resize((W, round(558 * sc)), Image.LANCZOS)
    can = Image.new("RGBA", (W, H), (36, 32, 48, 255))
    y0 = round(RAIL_Y + 15 - 545 * sc)  # линия парапета roof.webp прячется под перилами
    can.paste(v, (0, y0))
    can = can.filter(ImageFilter.GaussianBlur(1.1))
    a = arr(can)
    a[..., :3] = a[..., :3] * np.array([0.82, 0.8, 0.92])  # вечер, чуть темнее и холоднее
    return img(a)


def balcony_bg():
    base = arr(view())
    ink = Ink()
    # потолок — плита соседского балкона сверху
    m = poly_mask([(0, 0), (W, 0), (WALL_R, SLAB_Y), (WALL_L, SLAB_Y)])
    base = paint(base, (52, 50, 58), m, 0.12, 21)
    m = poly_mask([(WALL_L, SLAB_Y), (WALL_R, SLAB_Y), (WALL_R, SLAB_Y + 20), (WALL_L, SLAB_Y + 22)])
    base = paint(base, (88, 86, 94), m, 0.1, 22, streaks=0.15)
    # стены по бокам (перегородки балкона)
    wl = [(0, 0), (WALL_L, SLAB_Y), (WALL_L, H), (0, H)]
    wr = [(W, 0), (WALL_R, SLAB_Y), (WALL_R, H), (W, H)]
    base = paint(base, (118, 128, 122), poly_mask(wl), 0.1, 23, streaks=0.1)
    base = paint(base, (104, 114, 110), poly_mask(wr), 0.1, 24, streaks=0.1)
    # под поручнем — двор внизу (yard.webp, ночь), сквозь стойки ограждения
    yard = Image.open(os.path.join(A, "yard.webp")).convert("RGBA").crop((0, 400, 940, 740))
    yard = yard.resize((WALL_R - WALL_L, H - RAIL_Y - 14), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.4))
    ya = arr(yard)
    ya[..., :3] = ya[..., :3] * np.array([0.34, 0.33, 0.46])
    gy = np.zeros(ya.shape[:2], np.float32)
    rr0 = np.random.default_rng(4)
    for _ in range(9):  # тёплые окна первых этажей и фонарь
        cv2.circle(gy, (int(rr0.uniform(0, ya.shape[1])), int(rr0.uniform(0, ya.shape[0] * 0.5))), 3, 1.0, -1)
    gy = cv2.GaussianBlur(gy, (0, 0), 7)
    ya[..., :3] += np.array([255, 190, 110]) * (gy / (gy.max() + 1e-6))[..., None] * 0.35
    base[RAIL_Y + 14:, WALL_L:WALL_R, :3] = ya[..., :3]
    # нижняя полоса ограждения и стойки (крашеный металл)
    pm = poly_mask([(WALL_L, H - 34), (WALL_R, H - 34), (WALL_R, H - 20), (WALL_L, H - 20)])
    base = paint(base, (58, 70, 64), pm, 0.12, 25)
    for x in np.arange(WALL_L + 22, WALL_R - 10, 38):
        pm = poly_mask([(x - 3.5, RAIL_Y + 14), (x + 3.5, RAIL_Y + 14), (x + 3.5, H), (x - 3.5, H)])
        base = paint(base, (54, 64, 60), pm, 0.15, int(x))
    # поручень — деревянный, крашенный коричневым
    hm = poly_mask([(WALL_L - 4, RAIL_Y - 8), (WALL_R + 4, RAIL_Y - 8), (WALL_R + 4, RAIL_Y + 14), (WALL_L - 4, RAIL_Y + 14)])
    base = paint(base, (92, 62, 46), hm, 0.14, 26)
    hm2 = poly_mask([(WALL_L - 4, RAIL_Y - 8), (WALL_R + 4, RAIL_Y - 8), (WALL_R + 4, RAIL_Y - 2), (WALL_L - 4, RAIL_Y - 2)])
    base = paint(base, (128, 92, 70), hm2, 0.1, 27)  # верхняя грань светлее
    # свет: стены темнеют к улице и к потолку, в углах тень; снизу-сзади тёплый свет из комнаты
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    side = np.clip(np.minimum(xx / WALL_L, (W - xx) / (W - WALL_R)), 0, 1)
    wall = (xx < WALL_L) | (xx > WALL_R) | (yy < SLAB_Y)
    shade = np.where(wall, 0.55 + 0.45 * (1 - side) * (0.6 + 0.4 * yy / H), 1.0)
    base[..., :3] *= shade[..., None]
    ao = np.exp(-np.minimum(np.abs(xx - WALL_L), np.abs(xx - WALL_R)) / 26) * wall
    base[..., :3] *= (1 - 0.35 * ao)[..., None]
    warm = np.exp(-(((xx - W / 2) / (W * 0.55)) ** 2 + ((yy - H * 1.1) / (H * 0.6)) ** 2))
    base[..., :3] += np.array([70, 42, 16]) * (warm * np.where(wall, 1.0, 0.45))[..., None]
    im = img(base)

    # тушь: края плит, стен, перил
    ink.seg((0, 0), (WALL_L, SLAB_Y), 2.0)
    ink.seg((W, 0), (WALL_R, SLAB_Y), 2.0)
    ink.seg((WALL_L, SLAB_Y), (WALL_R, SLAB_Y), 1.6, n=30)
    ink.seg((WALL_L, SLAB_Y + 22), (WALL_R, SLAB_Y + 20), 1.8, n=30)
    ink.seg((WALL_L, SLAB_Y), (WALL_L, H), 2.0, n=20)
    ink.seg((WALL_R, SLAB_Y), (WALL_R, H), 2.0, n=20)
    ink.seg((WALL_L - 4, RAIL_Y - 8), (WALL_R + 4, RAIL_Y - 8), 1.8, n=40)
    ink.seg((WALL_L - 4, RAIL_Y - 2), (WALL_R + 4, RAIL_Y - 2), 0.9, n=40, alpha=150)
    ink.seg((WALL_L - 4, RAIL_Y + 14), (WALL_R + 4, RAIL_Y + 14), 1.6, n=40)
    for k in range(14):  # волокна и сколы краски на поручне
        x0 = WALL_L + (WALL_R - WALL_L) * k / 14 + 20
        ink.seg((x0, RAIL_Y + 4 + (k % 3) * 3), (x0 + 50 + (k % 4) * 12, RAIL_Y + 5 + (k % 3) * 3), 0.7, n=3, col=(60, 40, 30), alpha=140)
    for x in np.arange(WALL_L + 22, WALL_R - 10, 38):
        ink.seg((x - 3.5, RAIL_Y + 14), (x - 3.5, H), 1.1, n=8, alpha=200)
        ink.seg((x + 3.5, RAIL_Y + 14), (x + 3.5, H), 1.1, n=8, alpha=200)
        ink.seg((x - 1.5, RAIL_Y + 16), (x - 1.5, H), 0.8, n=8, col=(120, 136, 128), alpha=150)
    ink.seg((WALL_L, H - 34), (WALL_R, H - 34), 1.3, n=40)
    ink.seg((WALL_L, H - 20), (WALL_R, H - 20), 1.3, n=40)
    # капли на краю плиты
    rr = random.Random(5)
    for _ in range(26):
        x = rr.uniform(WALL_L + 8, WALL_R - 8)
        ink.ellipse((x - 2, SLAB_Y + 22, x + 2, SLAB_Y + 28), 0.8, fill=(190, 200, 220, 200), col=(70, 70, 90))
    # облупленная краска на стенах — крупные рваные пятна у углов, трещины
    for i, (cx, cy, sz) in enumerate(((60, 120, 30), (90, 420, 22), (40, 640, 34))):
        peel(ink, cx, cy, sz, 40 + i, (128, 136, 126))
    for i, (cx, cy, sz) in enumerate(((W - 50, 300, 28), (W - 90, 560, 24), (W - 30, 700, 30))):
        peel(ink, cx, cy, sz, 60 + i, (116, 124, 116))
    for (x0, y0) in ((96, 230), (W - 104, 380)):
        pts = [(x0, y0)]
        for k in range(6):
            pts.append((pts[-1][0] + rr.uniform(-9, 9), pts[-1][1] + rr.uniform(10, 22)))
        ink.line(pts, 1.0, alpha=170)
    # бельевая верёвка, прищепки и полотенце «с августа»
    rope = [(WALL_L, 108)] + [(WALL_L + (WALL_R - WALL_L) * t / 20, 108 + 26 * math.sin(math.pi * t / 20)) for t in range(1, 20)] + [(WALL_R, 104)]
    ink.line(rope, 2.0, col=(40, 34, 34), wob=0.2, alpha=255)
    tx = 300
    ty = 108 + 26 * math.sin(math.pi * (tx - WALL_L) / (WALL_R - WALL_L))
    towel = [(tx - 34, ty), (tx + 34, ty + 2), (tx + 31, ty + 120), (tx + 2, ty + 108), (tx - 30, ty + 122)]
    ink.poly(towel, 1.5, fill=(152, 140, 118, 255))
    for k in range(4):
        yy_ = ty + 26 + k * 20
        ink.seg((tx - 31, yy_), (tx + 32, yy_ + 1), 2.2, col=(176, 70, 78), wob=0.3, alpha=200)
    for px in (tx - 26, tx + 24, 860):
        py = 108 + 26 * math.sin(math.pi * (px - WALL_L) / (WALL_R - WALL_L))
        ink.poly([(px - 4, py - 8), (px + 4, py - 8), (px + 4, py + 8), (px - 4, py + 8)], 1.0, fill=(214, 120, 132, 255))
    # лыжи у левой стены: широкие, загнутые носы, крепления
    for dx, col, top in ((14, (112, 128, 150), 150), (50, (150, 92, 86), 176)):
        ink.poly([(dx, H + 6), (dx + 24, H + 6), (dx + 62, top + 22), (dx + 60, top), (dx + 46, top + 6), (dx + 40, top + 24)], 1.6, fill=col + (255,))
        ink.seg((dx + 12, H), (dx + 50, top + 26), 0.9, col=(230, 226, 220), alpha=150)
        by = top + (H - top) * 0.55
        bx = dx + 24 - (by - top) * 0.06 + 10
        ink.poly([(bx - 14, by - 10), (bx + 10, by - 12), (bx + 12, by + 10), (bx - 12, by + 12)], 1.3, fill=(48, 44, 50, 255))
    # трубы по правой стене
    for xx_, col in ((WALL_R + 40, (150, 60, 62)), (WALL_R + 70, (60, 80, 140))):
        ink.poly([(xx_, 40), (xx_ + 12, 40), (xx_ + 12, H), (xx_, H)], 1.3, fill=col + (255,))
        ink.seg((xx_ + 3, 44), (xx_ + 3, H), 1.2, col=(235, 230, 230), alpha=140)
    # банка-пепельница и цветок в горшке на поручне
    bx = 640
    ink.poly([(bx - 26, RAIL_Y - 8), (bx - 22, RAIL_Y - 16), (bx + 22, RAIL_Y - 16), (bx + 26, RAIL_Y - 8)], 1.3, fill=(170, 168, 160, 255))
    ink.seg((bx - 12, RAIL_Y - 14), (bx + 6, RAIL_Y - 13), 2, col=(220, 150, 80), alpha=200)
    gx = 1170
    ink.poly([(gx - 22, RAIL_Y - 8), (gx - 26, RAIL_Y - 44), (gx + 26, RAIL_Y - 44), (gx + 22, RAIL_Y - 8)], 1.5, fill=(150, 84, 62, 255))
    for a in (-1.2, -0.7, -0.2, 0.3, 0.8, 1.25):
        ink.line([(gx, RAIL_Y - 44), (gx + 30 * math.sin(a), RAIL_Y - 70 - 30 * math.cos(a)), (gx + 50 * math.sin(a), RAIL_Y - 64 - 20 * math.cos(a))], 1.6, col=(70, 82, 56), wob=0.4)
    return ink.comp(im)


# ── персонажи ──
def cutouts():
    src = cv2.imread(os.path.join(A, "cg_roof.webp"))
    figs = {}
    for name, (x0, y0, x1, y1) in {"sera": (445, 335, 650, 752), "kir": (672, 282, 815, 748)}.items():
        mask = np.zeros(src.shape[:2], np.uint8)
        bg = np.zeros((1, 65), np.float64)
        fg = np.zeros((1, 65), np.float64)
        cv2.grabCut(src, mask, (x0, y0, x1 - x0, y1 - y0), bg, fg, 8, cv2.GC_INIT_WITH_RECT)
        m = np.where((mask == 1) | (mask == 3), 255, 0).astype(np.uint8)
        if name == "sera":  # ноги в чулках GrabCut теряет — добавить по контуру
            cv2.fillPoly(m, [np.array([(517, 596), (541, 596), (538, 640), (534, 700), (515, 700), (512, 640)])], 255)
            cv2.fillPoly(m, [np.array([(553, 596), (578, 596), (576, 640), (572, 700), (556, 700), (552, 640)])], 255)
        n, lab, stats, _ = cv2.connectedComponentsWithStats(m)
        big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        m = np.where(lab == big, 255, 0).astype(np.uint8)
        m = cv2.GaussianBlur(m, (3, 3), 0)
        rgba = cv2.cvtColor(src, cv2.COLOR_BGR2RGBA)
        rgba[..., 3] = m
        gray = cv2.cvtColor(src, cv2.COLOR_BGR2GRAY)
        if name == "kir":
            # левое предплечье Кира (светлое, у кармана) — закрасить футболкой/штанами
            arm = np.zeros(m.shape, np.uint8)
            cv2.fillPoly(arm, [np.array([(694, 474), (714, 474), (714, 528), (694, 528)])], 255)
            arm = ((arm > 0) & (gray > 70)).astype(np.uint8) * 255
            arm = cv2.dilate(arm, np.ones((3, 3), np.uint8), 2)
            figs["kir_noarm"] = rgba.copy()
            figs["kir_noarm"][..., :3] = cv2.inpaint(cv2.cvtColor(src, cv2.COLOR_BGR2RGB), arm, 5, cv2.INPAINT_TELEA)
        if name == "sera":
            # правая кисть Серы на плече — закрасить курткой
            hand_m = np.zeros(m.shape, np.uint8)
            cv2.circle(hand_m, (622, 441), 10, 255, -1)
            hand_m = ((hand_m > 0) & (gray > 90)).astype(np.uint8) * 255
            hand_m = cv2.dilate(hand_m, np.ones((3, 3), np.uint8), 2)
            figs["sera_nohand"] = rgba.copy()
            figs["sera_nohand"][..., :3] = cv2.inpaint(cv2.cvtColor(src, cv2.COLOR_BGR2RGB), hand_m, 4, cv2.INPAINT_TELEA)
        figs[name] = rgba
    return figs


def place(base, rgba, kir=False):
    """Наложить фигуру (полный кадр cg_roof RGBA) с масштабом и сдвигом; тёплый свет из комнаты."""
    dx = (KIR_SHIFT if kir else 0)
    M = np.float32([[K, 0, (dx - CX0) * K], [0, K, -CY0 * K]])
    warped = cv2.warpAffine(rgba, M, (W, H), flags=cv2.INTER_LANCZOS4, borderValue=(0, 0, 0, 0))
    f = warped.astype(np.float32)
    blur = cv2.GaussianBlur(f[..., :3], (0, 0), 1.2)
    f[..., :3] = np.clip(f[..., :3] * 1.35 - blur * 0.35, 0, 255)  # лёгкая резкость после увеличения
    yy = np.linspace(0, 1, H)[:, None, None]
    f[..., :3] = f[..., :3] * 0.97 + np.array([16, 9, 3]) * yy
    a = f[..., 3:4] / 255.0
    base = arr(base)
    base[..., :3] = base[..., :3] * (1 - a) + f[..., :3] * a
    return img(base)


SKIN = (164, 154, 158)
SKIN_SH = (120, 112, 118)
JACKET = (36, 32, 35)
SHIRT = (31, 31, 34)
CIG = (236, 232, 226)


def spline(pts, n=10):
    """Catmull-Rom через точки — плавная линия руки."""
    if len(pts) < 3:
        return [(pts[0][0] + (pts[1][0] - pts[0][0]) * t / n, pts[0][1] + (pts[1][1] - pts[0][1]) * t / n) for t in range(n + 1)]
    q = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(q) - 2):
        p0, p1, p2, p3 = q[i - 1], q[i], q[i + 1], q[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    out.append(pts[-1])
    return out


def limb(ink, pts, w0, w1, fill, folds=True, cap=True, shade=None):
    """Рука/рукав: плавная трубка с сужением, тушь по контуру, складки ткани."""
    c = spline(pts)
    n = len(c)
    L, R = [], []
    for i, (x, y) in enumerate(c):
        j0, j1 = max(0, i - 1), min(n - 1, i + 1)
        dx, dy = c[j1][0] - c[j0][0], c[j1][1] - c[j0][1]
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        t = i / (n - 1)
        w = (w0 + (w1 - w0) * t) / 2 * (1 + 0.08 * math.sin(t * 9))  # ткань чуть «дышит»
        L.append((x + nx * w, y + ny * w))
        R.append((x - nx * w, y - ny * w))
    endc = []
    if cap:
        x, y = c[-1]
        dx, dy = c[-1][0] - c[-2][0], c[-1][1] - c[-2][1]
        a0 = math.atan2(dy, dx)
        for k in range(1, 6):
            a = a0 + math.pi / 2 - k * math.pi / 6
            endc.append((x + math.cos(a) * w1 / 2, y + math.sin(a) * w1 / 2))
    shape = L + endc + R[::-1]
    ink.d.polygon([(x * SS, y * SS) for x, y in shape], fill=fill + (255,))
    if shade:  # теневая сторона
        sh = [((l[0] * 0.55 + r[0] * 0.45), (l[1] * 0.55 + r[1] * 0.45)) for l, r in zip(L, R)]
        ink.d.polygon([(x * SS, y * SS) for x, y in sh + R[::-1]], fill=shade + (255,))
    ink.line(shape, 1.7, wob=0.25)
    if folds:
        r = random.Random(int(pts[0][0] * 7 + pts[-1][1]))
        for k in range(3):
            i = int(n * (0.3 + 0.22 * k))
            if 0 < i < n - 1:
                x, y = c[i]
                l, rr_ = L[i], R[i]
                ink.line([(l[0] * 0.8 + x * 0.2, l[1] * 0.8 + y * 0.2), (x + r.uniform(-2, 2), y + r.uniform(-2, 2)),
                          (rr_[0] * 0.5 + x * 0.5, rr_[1] * 0.5 + y * 0.5)], 0.9, col=(96, 92, 108), wob=0.4, alpha=200)
    return c


def cig(ink, a, b, lit=0.0):
    """Сигарета от a (фильтр) к b (кончик); lit 0..1 — тлеет."""
    ink.seg(a, b, 4.4, n=2, col=INK, wob=0)
    ink.seg(a, b, 2.8, n=2, col=CIG, wob=0, alpha=255)
    fx = (a[0] + (b[0] - a[0]) * 0.3, a[1] + (b[1] - a[1]) * 0.3)
    ink.seg(a, fx, 2.8, n=1, col=(206, 140, 84), wob=0, alpha=255)
    if lit:
        ink.ellipse((b[0] - 2.6, b[1] - 2.6, b[0] + 2.6, b[1] + 2.6), 0.6, fill=(255, 110 + int(80 * lit), 50, 255), col=(110, 40, 20))


def glow(im, pts, rad, col=(255, 150, 70), amt=0.6):
    g = np.zeros((H, W), np.float32)
    for (x, y), s_ in pts:
        cv2.circle(g, (int(x), int(y)), 2, s_, -1)
    g = cv2.GaussianBlur(g, (0, 0), rad)
    g = g / (g.max() + 1e-6)
    a = arr(im)
    a[..., :3] = a[..., :3] + np.array(col) * g[..., None] * amt
    return img(a)


def blob(ink, pts, w=1.4, fill=SKIN):
    """Замкнутый плавный контур (кисть) — сплайн по опорным точкам."""
    c = spline(pts + pts[:3], 6)[6:-7]
    ink.poly(c, w, fill=fill + (255,), wob=0.1)


def hand(ink, c, ang, s=1.3, pose="fist"):
    """Кисть (вид сзади/сбоку): ладонь + пальцы; ang — куда смотрят пальцы. Возвращает T(локальные→кадр)."""
    x, y = c
    ca, sa = math.cos(ang), math.sin(ang)

    def T(px, py):
        return (x + (px * ca - py * sa) * s, y + (px * sa + py * ca) * s)

    if pose == "fist":
        blob(ink, [T(-6, -6), T(2, -8), T(8, -6), T(11, -1), T(10, 5), T(4, 8), T(-5, 7), T(-8, 1)])
        for k in (-4, -0.5, 3):
            ink.line([T(6, k - 1), T(9.5, k), T(8.5, k + 2)], 0.8, wob=0.1, alpha=170)
        ink.line([T(-2, -7), T(4, -10), T(8, -9)], 1.2, wob=0.1)
    elif pose == "cup":  # ладонь лодочкой вокруг огня
        blob(ink, [T(-6, -5), T(4, -9), T(12, -7), T(14, 0), T(10, 7), T(-4, 7), T(-8, 1)])
        ink.line([T(4, -9), T(8, -2), T(10, 7)], 0.8, wob=0.1, alpha=170)
    else:  # pinch — держит сигарету двумя пальцами
        blob(ink, [T(-6, -6), T(3, -7), T(9, -4), T(10, 2), T(4, 7), T(-6, 6), T(-8, 0)])
        ink.poly([T(8, -4), T(15, -4.5), T(15.5, -1.5), T(8.5, -0.5)], 1.0, fill=SKIN + (255,), wob=0.1)
        ink.poly([T(8, 0), T(14, 0.5), T(14, 3), T(8, 3.5)], 1.0, fill=SKIN + (255,), wob=0.1)
    return T


def smoke(im, paths, seed, alpha=0.5):
    """Дым: мягкие клубы вдоль кривых [(x, y, r), ...]."""
    lay = np.zeros((H, W), np.float32)
    r = np.random.default_rng(seed)
    for path in paths:
        for x, y, rad in path:
            cv2.circle(lay, (int(x + r.normal(0, 1.5)), int(y)), max(1, int(rad)), float(r.uniform(0.5, 1.0)), -1)
    lay = cv2.GaussianBlur(lay, (0, 0), 4.5)
    lay *= 0.7 + 0.5 * noise(seed, 14)
    lay = np.clip(lay, 0, 1)[..., None] * alpha
    a = arr(im)
    a[..., :3] = a[..., :3] * (1 - lay) + np.array([212, 208, 218]) * lay
    return img(a)


def trail(x, y, h, seed, phase=0.0, wide=1.0):
    """Тонкая струйка дыма вверх, извивается."""
    pts = []
    for i in range(int(h / 3)):
        t = i / (h / 3)
        pts.append((x + math.sin(t * 7 + phase + seed) * (3 + 22 * t) * wide, y - i * 3, 1.2 + 9 * t ** 1.4))
    return pts


def puff(x, y, s, seed, rise=0.0):
    """Клуб выдоха: несколько расширяющихся шаров."""
    r = random.Random(seed)
    pts = []
    for i in range(14):
        t = i / 13
        pts.append((x - 40 * t * s + r.uniform(-6, 6) * s, y - (20 + 80 * t) * s - rise, (6 + 22 * t) * s))
    return pts


def post(im, seed):
    a = arr(im)
    r = np.random.default_rng(seed)
    a[..., :3] += r.normal(0, 6.5, a.shape[:2])[..., None]
    v = noise(seed + 3, 24) * 0.05
    a[..., :3] *= (1 + v[..., None])
    yy, xx = np.mgrid[0:H, 0:W]
    d = ((xx - W / 2) / (W / 1.6)) ** 2 + ((yy - H / 2) / (H / 1.4)) ** 2
    a[..., :3] *= (1 - 0.28 * np.clip(d, 0, 1))[..., None]
    return img(a).convert("RGB")


def rain(im, seed, n=260, a=0.22):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    r = random.Random(seed)
    for _ in range(n):
        x = r.uniform(WALL_L, WALL_R)
        y = r.uniform(SLAB_Y + 20, RAIL_Y - 10)
        ln = r.uniform(10, 26)
        d.line((x, y, x - 2, y + ln), fill=(210, 215, 235, int(255 * a)), width=1)
    return Image.alpha_composite(im, lay)


def save(im, name, seed=1):
    os.makedirs(OUT, exist_ok=True)
    post(im, seed).save(os.path.join(OUT, name + ".webp"), "WEBP", quality=88, method=6)


def main():
    bg = balcony_bg()
    save(rain(bg, 1), "balcony", 1)
    figs = cutouts()

    def scene(sera="sera", kir="kir"):
        return place(place(bg, figs[sera]), figs[kir], kir=True)

    if os.environ.get("BAL_QUICK"):
        save(rain(scene(), 3, 140, 0.16), "bal_s0", 3)
        return

    # ключевые точки в кадре (сняты по сетке с bal_s0)
    s_hand0 = (716, 338)  # правая кисть Серы на плече
    s_sh = (712, 352)  # её правое плечо
    k_elb = (806, 396)  # конец рукава Кира / локоть
    k_mouth = (812, 190)  # левый край лица Кира
    s_mouth = (640, 238)
    frames = {"bal_s0": scene()}
    # край головы Кира на уровне рта — сигарета выходит ровно из-за щеки
    M = np.float32([[K, 0, (KIR_SHIFT - CX0) * K], [0, K, -CY0 * K]])
    ka = cv2.warpAffine(figs["kir"][..., 3], M, (W, H))
    row = np.where(ka[k_mouth[1], 760:900] > 140)[0]
    k_mouth = (760 + int(row[0]) + 3 if len(row) else k_mouth[0], k_mouth[1])

    def kir_cig_mouth(ink, lit):
        # локоть прижат, кисть у рта скрыта головой — из-за щеки виден кончик сигареты
        cig(ink, (k_mouth[0], k_mouth[1]), (k_mouth[0] - 15, k_mouth[1] + 3), lit)
        return (k_mouth[0] - 15, k_mouth[1] + 3)

    # 1) достаёт пачку и передаёт сигарету
    im = scene("sera_nohand")
    ink = Ink()
    limb(ink, [(722, 372), (744, 410), (742, 452)], 46, 40, JACKET)  # рука опущена к карману
    frames["bal_p0"] = ink.comp(im)

    im = scene("sera_nohand")
    ink = Ink()
    limb(ink, [(722, 372), (748, 414), (768, 446)], 46, 38, JACKET)
    T = hand(ink, (776, 452), -0.6, 1.3)
    ink.poly([T(0, -16), T(14, -18), T(16, 6), T(2, 8)], 1.4, fill=(228, 224, 216, 255))  # мятая пачка
    ink.poly([T(0, -16), T(14, -18), T(14.5, -10), T(0.5, -8)], 1.0, fill=(158, 42, 52, 255))
    frames["bal_p1"] = ink.comp(im)

    im = scene("sera_nohand")
    ink = Ink()
    limb(ink, [(722, 372), (752, 410), (776, 432)], 46, 38, JACKET)
    T = hand(ink, (784, 436), -0.35, 1.3, "pinch")
    cig(ink, T(12, -1), T(34, -5))
    frames["bal_p2"] = ink.comp(im)

    im = scene("sera_nohand", "kir_noarm")
    ink = Ink()
    limb(ink, [(722, 372), (752, 410), (776, 432)], 46, 38, JACKET)
    T = hand(ink, (784, 436), -0.35, 1.3, "pinch")
    limb(ink, [k_elb, (812, 418), (812, 432)], 17, 15, SKIN, folds=False, shade=SKIN_SH)
    hand(ink, (808, 434), math.pi - 0.2, 1.3, "pinch")
    cig(ink, T(12, -1), T(34, -5))
    frames["bal_p3"] = ink.comp(im)

    im = scene("sera", "kir_noarm")
    ink = Ink()
    kir_cig_mouth(ink, 0.0)  # взял в зубы — рука у лица скрыта
    st = (s_hand0[0] + 24, s_hand0[1] - 12)
    cig(ink, (s_hand0[0] + 4, s_hand0[1] - 3), st)  # у Серы — своя, в руке на плече
    frames["bal_p4"] = ink.comp(im)

    # 2) зажигалка: Сера подносит огонь к лицу Кира, потом прикуривает себе
    def lighter(stage):
        im = scene("sera_nohand", "kir_noarm")
        ink = Ink()
        tip = kir_cig_mouth(ink, 0.0 if stage == 0 else 1.0)
        if stage < 2:
            fl = (tip[0] + 1, tip[1] + 1)
            wr = (fl[0] - 22, fl[1] + 22)
            limb(ink, [s_sh, (748, 318), (wr[0] - 20, wr[1] + 40), wr], 46, 34, JACKET)
            hand(ink, (fl[0] - 12, fl[1] + 12), -0.75, 1.3, "cup")
        else:
            fl = (s_mouth[0] + 4, s_mouth[1] - 4)  # рука у её лица скрыта хвостиком, виден огонёк
        im = ink.comp(im)
        im = glow(im, [(fl, 1.0)], 40, amt=0.75 if stage != 1 else 0.6)
        im = glow(im, [(fl, 1.0)], 9, col=(255, 200, 120), amt=0.5)
        ink2 = Ink()
        h = 13 if stage != 1 else 9
        ink2.poly([(fl[0], fl[1] - h), (fl[0] + 4.5, fl[1] - 2), (fl[0], fl[1] + 3), (fl[0] - 4.5, fl[1] - 2)], 0.6,
                  fill=(255, 214, 130, 255), col=(170, 80, 30))
        ink2.poly([(fl[0], fl[1] - h * 0.5), (fl[0] + 2, fl[1] - 1), (fl[0], fl[1] + 2), (fl[0] - 2, fl[1] - 1)], 0.3,
                  fill=(110, 170, 255, 255), col=(80, 120, 200))
        return ink2.comp(im)

    for i in range(3):
        frames["bal_l%d" % i] = lighter(i)

    # 3) затяжка (огонёк разгорается) и выдох — облака дыма у голов
    def smoke_frame(stage):
        im = scene("sera_nohand", "kir_noarm")
        ink = Ink()
        lit = 1.0 if stage <= 1 else 0.5
        kt = kir_cig_mouth(ink, lit)
        im = ink.comp(im)
        im = glow(im, [(kt, 1.0)], 12 if stage <= 1 else 6, amt=0.6 if stage <= 1 else 0.3)
        if stage >= 2:
            k = stage - 2
            im = smoke(im, [puff(k_mouth[0] - 18, k_mouth[1] + 10, 1.1 + 0.45 * k, 3, 34 * k),
                            puff(s_mouth[0] + 16, s_mouth[1] + 8, 1.0 + 0.45 * k, 4, 34 * k)],
                       10 + stage, alpha=0.8 - 0.18 * k)
        return smoke(im, [trail(kt[0], kt[1], 50 + 20 * stage, 1, stage)], 30 + stage, 0.35)

    for i in range(5):
        frames["bal_i%d" % i] = smoke_frame(i)

    # 4) стоят, курят и разговаривают (цикл): у Серы сигарета в руке на плече, у Кира — у кармана
    def talk(ph):
        im = scene("sera", "kir")
        ink = Ink()
        T = hand(ink, (830, 482), 0.9, 1.3, "pinch")
        kt = T(30, -4)
        cig(ink, T(12, -1), kt, 0.8)
        st = (s_hand0[0] + 24, s_hand0[1] - 12)
        cig(ink, (s_hand0[0] + 4, s_hand0[1] - 3), st, 0.8)
        im = ink.comp(im)
        im = glow(im, [(kt, 1.0), (st, 1.0)], 6, amt=0.35)
        return smoke(im, [trail(kt[0], kt[1], 170, 1, ph), trail(st[0], st[1], 150, 2, ph + 1.3)], 50 + int(ph * 10), 0.42)

    for i in range(4):
        frames["bal_t%d" % i] = talk(i * math.pi / 2)

    seeds = {k: i + 3 for i, k in enumerate(frames)}
    for k, im in frames.items():
        save(rain(im, seeds[k], 140, 0.16), k, seeds[k])
    # концовка: курят / просто стоят / снег
    save(rain(frames["bal_t1"], 90, 140, 0.16), "end_more1", 90)
    save(rain(scene(), 91, 220, 0.2), "end_more2", 91)
    sn = scene()
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    r = random.Random(9)
    for _ in range(420):
        x, y, s_ = r.uniform(0, W), r.uniform(0, H), r.uniform(1.2, 3.4)
        d.ellipse((x - s_, y - s_, x + s_, y + s_), fill=(245, 245, 255, int(r.uniform(120, 230))))
    save(Image.alpha_composite(sn, lay.filter(ImageFilter.GaussianBlur(0.6))), "end_more3", 92)
    print("ok", len(frames) + 4)


if __name__ == "__main__":
    main()
