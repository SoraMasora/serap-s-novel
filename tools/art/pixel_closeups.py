"""Пиксельные крупные кадры для прогулки (Godot): Сера на качелях под дождём, ларёк «ШАУРМА».
Рисуется кодом на сетке 160×90 (в игре ×2 до 320×180 — тот же пиксель, что и мир).
Запуск: python3 tools/art/pixel_closeups.py → godot/art/pixel/closeup_*.webp (lossless)."""
import math
import os
import random

from PIL import Image, ImageDraw

W, H = 160, 90
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "art", "pixel")
# Мини-шрифты (битмап): 3×5 для мелкой вывески, 5×7 для «ШАУРМА»
G3 = {
    "К": ["X.X", "XX.", "X..", "XX.", "X.X"], "О": [".X.", "X.X", "X.X", "X.X", ".X."],
    "Ф": [".X.", "XXX", "XXX", ".X.", ".X."], "Е": ["XXX", "X..", "XX.", "X..", "XXX"],
    "Ч": ["X.X", "X.X", ".XX", "..X", "..X"], "А": [".X.", "X.X", "XXX", "X.X", "X.X"],
    "Й": ["X.X", "X.X", "X.X", "XXX", "X.X"], "Т": ["XXX", ".X.", ".X.", ".X.", ".X."],
    "Б": ["XXX", "X..", "XX.", "X.X", "XX."], "К2": [], "·": ["...", "...", ".X.", "...", "..."],
    " ": ["...", "...", "...", "...", "..."],
}
G5 = {
    "Ш": ["X.X.X", "X.X.X", "X.X.X", "X.X.X", "X.X.X", "X.X.X", "XXXXX"],
    "А": [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
    "У": ["X...X", "X...X", "X...X", ".XXXX", "....X", "....X", "XXXX."],
    "Р": ["XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."],
    "М": ["X...X", "XX.XX", "X.X.X", "X.X.X", "X...X", "X...X", "X...X"],
}


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


class P:
    def __init__(self):
        self.im = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        self.d = ImageDraw.Draw(self.im)

    def r(self, x, y, w, h, c):
        if w > 0 and h > 0:
            self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=hexc(c) if isinstance(c, str) else c)

    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.im.putpixel((int(x), int(y)), hexc(c) if isinstance(c, str) else c)

    def blend(self, x, y, c, a):
        if 0 <= x < W and 0 <= y < H:
            o = self.im.getpixel((int(x), int(y)))
            c = hexc(c) if isinstance(c, str) else c
            self.im.putpixel((int(x), int(y)), tuple(int(o[i] * (1 - a) + c[i] * a) for i in range(3)) + (255,))

    def ell(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            self.px(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c)

    def rows(self, rs, x, y, pal):
        for j, row in enumerate(rs):
            for i, ch in enumerate(row):
                if ch != ".":
                    self.px(x + i, y + j, pal[ch])

    def glow(self, cx, cy, r, c, a):
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                d = math.hypot(x - cx, y - cy) / r
                if d < 1:
                    # ступенчатый (пиксельный) спад, без мыла
                    k = a * (1 - math.floor(d * 4) / 4)
                    self.blend(x, y, c, k)

    def text(self, x, y, s, font, c, outline=None, gap=1):
        pts = []
        cx = x
        for ch in s:
            g = font.get(ch, font.get(" "))
            for j, row in enumerate(g):
                for i, v in enumerate(row):
                    if v == "X":
                        pts.append((cx + i, y + j))
            cx += len(g[0]) + gap
        if outline:
            ps = set(pts)
            for i, j in pts:
                for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
                    if (i + di, j + dj) not in ps:
                        self.px(i + di, j + dj, outline)
        for i, j in pts:
            self.px(i, j, c)
        return cx - x

    def rain(self, seed, phase, n=70, col=(200, 214, 240), a=0.55):
        rnd = random.Random(seed)
        for _ in range(n):
            x = rnd.random() * (W + 20) - 10
            y = (rnd.random() * H + phase * 7) % (H + 10) - 5
            ln = 3 + int(rnd.random() * 4)
            for k in range(ln):
                self.blend(x - k * 0.35, y + k, col, a * (0.5 + 0.5 * k / ln))


def night_yard(p, seed):
    rnd = random.Random(seed)
    for y in range(H):
        t = min(1, y / 60)
        c = tuple(int(a + (b - a) * t) for a, b in zip((11, 10, 24), (38, 32, 64))) + (255,)
        p.r(0, y, W, 1, c)
    # дальняя панелька
    p.r(0, 6, 160, 58, "#25213a")
    p.r(0, 5, 160, 1, "#1a1724")
    for y in range(10, 58, 7):
        for x in range(4, 156, 7):
            on = rnd.random() < 0.22
            p.r(x, y, 4, 4, ("#d8a860" if rnd.random() < 0.5 else "#c08850") if on else "#2a2640")
    for y in range(15, 60, 7):
        p.r(0, y, 160, 1, (0, 0, 0, 255) if False else "#211d33")
    # земля
    p.r(0, 64, 160, 26, "#34323d")
    p.r(0, 64, 160, 1, "#4a4756")
    for _ in range(90):
        p.px(rnd.randrange(W), 65 + rnd.randrange(25), "#2a2832" if rnd.random() < 0.6 else "#403d4a")
    # лужи
    for x, y, rx in ((28, 80, 14), (128, 84, 18), (84, 87, 10)):
        p.ell(x, y, rx, 2.2, "#3e4866")
        p.r(x - rx // 3, y - 1, rx // 2, 1, "#56628a")


SERA = {
    "P": "#7a1d30", "p": "#561526", "q": "#9b2a40", "b": "#f2f2f2", "B": "#cfcfd8",
    "S": "#f6e6e0", "s": "#e8cfc8", "E": "#c2203a", "e": "#5a0f1e", "w": "#ffffff",
    "c": "#f0a0b0", "t": "#e8607e", "m": "#7a2a3a",
    "G": "#8c8c98", "g": "#6e6e7a", "h": "#a4a4b0", "k": "#2e2d33", "K": "#1f1e24",
    "L": "#1d1c22", "l": "#2c2b33", "O": "#121116", "D": "#cfe0ff",
}


def draw_sera_swing(p, cx, seat_y, phase):
    """Чиби-Сера на сиденье качелей (≈57 px): мокрые бордовые хвосты, белые банты, показывает язык."""
    c = SERA
    cy = seat_y - 27  # центр головы
    # хвосты: тяжёлые от воды, свисают почти до сиденья
    for side in (-1, 1):
        for j in range(36):
            x0 = cx + side * (17 + min(j, 12) * 0.3)
            w = 6 if j < 24 else (4 if j < 31 else 2)
            for i in range(w):
                xx = round(x0 + side * (i - w / 2))
                col = c["p"] if i in (0, w - 1) else (c["q"] if (i == 2 and j % 7 < 3) else c["P"])
                p.px(xx, cy - 6 + j, col)
        p.px(round(cx + side * 17), cy + 31, c["D"])
        p.px(round(cx + side * 17), cy + 33 + phase % 2, c["D"])
    # затылок
    p.ell(cx, cy - 1, 15, 14, c["P"])
    p.ell(cx - 4, cy - 9, 6, 3, c["q"])
    # лицо
    p.ell(cx, cy + 3, 11, 9.5, c["S"])
    for x in range(cx - 10, cx + 11):
        p.px(x, cy + 11, c["s"]) if abs(x - cx) < 7 else None
    # чёлка — мокрые острые пряди
    for x in range(cx - 12, cx + 13):
        k = (x - cx) % 5
        depth = [5, 3, 1, 2, 4][k] if abs(x - cx) < 11 else 9
        for y in range(cy - 8, cy - 4 + depth):
            p.px(x, y, c["P"] if k != 2 else c["p"])
    # глаза (крупные, красные, с бликом)
    for ex in (cx - 6, cx + 3):
        p.r(ex, cy + 1, 4, 1, c["e"])
        p.r(ex, cy + 2, 4, 4, c["E"])
        p.r(ex, cy + 5, 4, 1, c["e"])
        p.px(ex + 1, cy + 2, c["w"])
        p.px(ex + 2, cy + 3, c["w"]) if phase % 2 else None
    # румянец, рот с высунутым языком
    p.r(cx - 8, cy + 7, 2, 1, c["c"])
    p.r(cx + 7, cy + 7, 2, 1, c["c"])
    p.r(cx - 1, cy + 8, 3, 1, c["m"])
    p.r(cx - 1, cy + 9, 3, 1, c["t"])
    p.px(cx, cy + 10, c["t"])
    # банты
    for side in (-1, 1):
        bx = cx + side * 13
        for j in range(5):
            w = [2, 3, 4, 3, 2][j]
            for i in range(w):
                p.px(bx + side * (1 + i), cy - 12 + j, c["b"])
                p.px(bx - side * (1 + i) + side * 0, cy - 12 + j, c["b"]) if i < w - 1 else None
        p.r(bx - 1, cy - 11, 2, 2, c["B"])
        p.px(bx + side * 2, cy - 7, c["b"])
        p.px(bx + side * 3, cy - 6, c["b"])
    # шея, чокер
    p.r(cx - 3, cy + 12, 7, 2, c["S"])
    p.r(cx - 4, cy + 13, 9, 1, c["K"])
    p.px(cx, cy + 13, "#c8c8d0")
    # свитер (мокрый — тёмные пятна), рукава тянутся к цепям
    for j in range(14):
        hw = 9 + j * 0.35
        for x in range(round(cx - hw), round(cx + hw) + 1):
            col = c["G"]
            if (x * 3 + j * 5) % 11 == 0 or j > 11:
                col = c["g"]
            if j == 0 and abs(x - cx) < 4:
                col = c["h"]
            p.px(x, cy + 14 + j, col)
    for side in (-1, 1):
        for j in range(12):
            x = round(cx + side * (10 + j * 0.4))
            p.r(x - (2 if side > 0 else 0), cy + 25 - j, 3, 1, c["G"] if j < 9 else c["g"])
        p.r(round(cx + side * 15) - 1, cy + 12, 3, 2, c["S"])
    # юбка на сиденье
    p.r(cx - 12, seat_y - 3, 25, 3, c["k"])
    p.r(cx - 12, seat_y - 1, 25, 1, c["K"])
    # ноги в чулках — болтаются вперёд-назад с качелями
    sw = [0, 1, 0, -1][phase % 4]
    for lx in (cx - 6, cx + 3):
        for j in range(13):
            x = lx + round(sw * j / 12)
            p.r(x, seat_y + 2 + j, 4, 1, c["L"] if j % 6 else c["l"])
        p.r(lx + sw - 1, seat_y + 15, 5, 2, c["O"])
    # капли на волосах и плечах
    for x, y in ((cx - 9, cy - 3), (cx + 8, cy - 5), (cx - 12, cy + 9), (cx + 11, cy + 14), (cx - 4, cy + 18)):
        p.px(x, y, c["D"])


def slant(p, x0, y0, x1, y1, c, dark):
    for y in range(y0, y1 + 1):
        x = round(x0 + (x1 - x0) * (y - y0) / max(1, y1 - y0))
        p.r(x, y, 2, 1, c)
        p.px(x + 2, y, dark)


def swing_frame(phase):
    p = P()
    night_yard(p, 7)
    # фонарь слева — тёплое пятно света
    p.r(10, 4, 2, 62, "#2a2a30")
    p.r(6, 4, 9, 2, "#2a2a30")
    p.r(7, 6, 7, 1, "#ffe2a0")
    p.glow(11, 30, 34, (255, 214, 150), 0.14)
    # каркас качелей (А-образные стойки, перекладина у верхнего края)
    red, dred = "#8a2f33", "#5e1e22"
    for x in (34, 126):
        slant(p, x, 3, x - 9, 78, red, dred)
        slant(p, x, 3, x + 9, 78, red, dred)
    p.r(28, 2, 105, 3, red)
    p.r(28, 5, 105, 1, dred)
    # маятник
    ang = math.sin(phase * math.pi / 2) * 0.09
    piv_y, ln = 5, 62
    sx = 80 + math.sin(ang) * ln
    sy = piv_y + math.cos(ang) * ln
    for cx0 in (62, 98):
        ex = cx0 + math.sin(ang) * ln
        for k in range(0, ln):
            t = k / ln
            col = "#9a9aa6" if k % 3 else "#6a6a76"
            p.px(round(cx0 + (ex - cx0) * t), round(piv_y + (sy - piv_y) * t), col)
    draw_sera_swing(p, int(round(sx)), int(round(sy)), phase)
    # сиденье
    p.r(int(round(sx - 19)), int(round(sy)), 38, 2, "#6a4426")
    p.r(int(round(sx - 19)), int(round(sy + 2)), 38, 1, "#3a2414")
    p.ell(80, 84, 20, 1.6, "#2a2832")
    p.rain(11, phase, n=90)
    rnd = random.Random(phase)
    for _ in range(5):
        p.px(int(sx - 17 + rnd.random() * 34), int(sy - 1 - rnd.random() * 2), "#cfe0ff")
    return p.im


def hero_back(p, ox, oy):
    """Герой со спины (крупнее, 3/4): лохматые чёрные волосы, чёрная футболка, серые штаны."""
    pal = {"K": "#121018", "k": "#2e2a3a", "h": "#4a4560", "T": "#19181f", "t": "#2f2d3a",
           "S": "#f3e3db", "s": "#c8b0a8", "J": "#80808c", "j": "#5e5e6b", "B": "#0c0c10", "W": "#cfcfd6", "D": "#cfe0ff"}
    rs = [
        "....kKKKKk....",
        "..kKKhKKKKKk..",
        ".kKKKKKKhKKKk.",
        ".KKKKKKKKKKKK.",
        "KKKKKKKKKKKKKK",
        "KKKKhKKKKKKKKK",
        "KKKKKKKKKKKKKK",
        ".KKKKKKKKKKKKS",
        ".kKKKKKKKKKKK.",
        "...KKKKKKKK...",
        ".....ssss.....",
        "..TTTTTTTTTT..",
        ".TTTTTTTTTTTT.",
        "TTTTTtTTTTTTTT",
        "TTTTTTTTTTTTTT",
        "TTTTTTTTTtTTTT",
        "TTTTTTTTTTTTTT",
        "STTTTTTTTTTTTS",
        "STTTTTTTTTTTTS",
        ".TTTTTTTTTTTT.",
        "..JJJJJJJJJJ..",
        "..JJJJJJJJJJ..",
        "..JJJJ..JJJJ..",
        "..JJJJ..JJJJ..",
        "..jJJJ..JJJj..",
        "..jjjj..jjjj..",
        ".BBBBB..BBBBB.",
    ]
    p.rows(rs, ox, oy, pal)


def sera_small(p, ox, oy, tongue=True):
    pal = SERA
    rs = [
        ".b.PPPP.b..",
        "bbPPPPPPbb.",
        ".PPPPPPPP..",
        "PPSSSSSSPP.",
        "PPSESSESPP.",
        "PP.SStSS.PP" if tongue else "PP.SSSS.PP.",
        "PPGGGGGGPP.",
        "PGGGGGGGGP.",
        "PGGGGGGGGP.",
        "PSGGGGGGSP.",
        "P.kkkkkk.P.",
        "P.kkkkkk.P.",
        "p..LL.LL.p.",
        "p..LL.LL...",
        "...LL.LL...",
        "..OOO.OOO..",
    ]
    p.rows(rs, ox, oy, pal)


def kiosk_frame(phase, with_sera=False):
    p = P()
    rnd = random.Random(3)
    for y in range(H):
        t = min(1, y / 55)
        p.r(0, y, W, 1, tuple(int(a + (b - a) * t) for a, b in zip((10, 9, 22), (34, 28, 56))) + (255,))
    # гаражи/стена за ларьком
    p.r(0, 30, 160, 36, "#24212f")
    for x in range(0, 160, 22):
        p.r(x + 1, 34, 20, 32, "#2c2938")
        p.r(x + 1, 34, 20, 1, "#38344a")
    # асфальт
    p.r(0, 66, 160, 24, "#2a2832")
    p.r(0, 66, 160, 1, "#3c3946")
    for _ in range(60):
        p.px(rnd.randrange(W), 67 + rnd.randrange(23), "#33303c")
    # ларёк
    kx, ky, kw, kh = 70, 14, 84, 56
    p.r(kx, ky, kw, kh, "#c8c4b8")
    p.r(kx, ky + kh - 10, kw, 10, "#1c1a20")
    # верхняя вывеска «РУССКИЙ БОГАТЫРЬ» — красная полоса с золотым текстом
    p.r(kx - 2, ky - 8, kw + 4, 9, "#b3202a")
    p.r(kx - 2, ky - 8, kw + 4, 1, "#d84a4a")
    p.text(kx + 14, ky - 6, "КОФЕ · ЧАЙ · ТАБАК", G3, "#ffd34a")
    # боковой баннер «ШАУРМА» (жёлтый, вертикальный)
    p.r(kx - 2, ky + 1, 18, kh - 11, "#f2c418")
    p.r(kx - 2, ky + 1, 1, kh - 11, "#c99a10")
    # картинки еды на баннере
    for y0 in (ky + 6, ky + 20, ky + 32):
        p.ell(kx + 7, y0 + 3, 5, 3, "#c87a3a")
        p.r(kx + 4, y0 + 2, 6, 1, "#5aa040")
        p.r(kx + 5, y0 + 4, 5, 1, "#e8d0a0")
    # окно выдачи (тёплый свет), продавщица
    wx, wy = kx + 22, ky + 6
    p.r(wx, wy, 34, 30, "#ffd98a")
    p.r(wx, wy, 34, 1, "#fff0c0")
    p.r(wx + 16, wy, 1, 30, "#c8a060")
    p.r(wx + 2, wy + 14, 6, 12, "#c87a3a")  # ценник/меню
    p.r(wx + 3, wy + 16, 4, 1, "#7a3a1a")
    p.r(wx + 3, wy + 19, 4, 1, "#7a3a1a")
    # продавщица (силуэт с косынкой)
    p.ell(wx + 26, wy + 12, 5, 5, "#e8b898")
    p.r(wx + 21, wy + 7, 11, 4, "#b3202a")
    p.r(wx + 20, wy + 17, 13, 13, "#5a7aa0")
    p.px(wx + 24, wy + 12, "#2a1a1a")
    p.px(wx + 28, wy + 12, "#2a1a1a")
    # меню справа
    p.r(wx + 38, wy, 20, 30, "#f6f0e0")
    for j in range(5):
        p.r(wx + 40, wy + 3 + j * 5, 12, 1, "#7a6a5a")
        p.r(wx + 54, wy + 3 + j * 5, 3, 1, "#b3202a")
    # прилавок
    p.r(kx + 18, wy + 30, kw - 18, 3, "#8a8478")
    # нижний баннер «ШАУРМА» — крупно
    p.r(kx + 16, ky + kh - 10, kw - 16, 10, "#1c1a20")
    p.text(kx + 28, ky + kh - 9, "ШАУРМА", G5, "#ff3a3a", outline="#5a0a10", gap=2)
    # пар из окошка
    for k in range(5):
        yy = wy - 2 - ((phase * 3 + k * 4) % 14)
        p.blend(wx + 10 + (k % 2) * 3 + int(math.sin((phase + k) * 1.3) * 2), yy, (230, 230, 240), 0.35)
        p.blend(wx + 11 + (k % 2) * 3, yy - 1, (230, 230, 240), 0.25)
    # свет от ларька на асфальте
    p.glow(kx + 40, 74, 50, (255, 210, 120), 0.18)
    # отражение в луже
    p.ell(100, 80, 26, 3, "#3a3550")
    p.r(88, 79, 16, 1, "#b39a5a")
    p.r(96, 81, 10, 1, "#a8202a")
    # герой со спины
    hero_back(p, 30, 46)
    p.ell(37, 74, 9, 1.5, "#1a1820")
    if with_sera:
        sera_small(p, 50, 57, tongue=phase % 4 < 3)
    p.rain(5, phase, n=60)
    return p.im


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name + ".webp"), lossless=True)


if __name__ == "__main__":
    for i in range(4):
        save(swing_frame(i), "closeup_swing_%d" % i)
        save(kiosk_frame(i), "closeup_kiosk_%d" % i)
        save(kiosk_frame(i, True), "closeup_kiosk_sera_%d" % i)
    print("ok")
