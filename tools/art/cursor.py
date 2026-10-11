"""Курсоры «банка энергетика» — набор как у обычной мыши: стрелка, рука-указатель (наведение),
нажатие, работа в фоне, ожидание, текст, запрет, перетаскивание. У каждого состояния — кадры анимации.
Рисуется векторно (pycairo) в лист 64×64 на кадр; игра режет лист и уменьшает под DPI экрана
(scripts/autoload/cursor.gd). Запуск: python3 tools/art/cursor.py → godot/art/ui/cursor_sheet.webp

Строки листа (порядок важен — совпадает с cursor.gd):
 0 arrow  — 8 кадров: покой (0) + блик по банке (1–7)
 1 point  — 8 кадров: стрелка наклоняется и «кивает», искорки
 2 click  — 6 кадров: сжатие и пузырьки газировки
 3 busy   — 8 кадров: стрелка + крутящаяся банка
 4 wait   — 8 кадров: крутящаяся банка
 5 ibeam  — 2 кадра: текстовый курсор-трубочка (мигание)
 6 forbid — 1 кадр: стрелка + знак «нельзя»
 7 drag   — 4 кадра: стрелка со стрелками во все стороны (пульс)
"""
import math
import os

import cairo
from PIL import Image

S = 64  # кадр
K = S / 32.0  # рисуем в координатах 32×32
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "art", "ui", "cursor_sheet.webp")
ROWS = 8
COLS = 8

OUTLINE = (0.97, 0.84, 0.93)
BODY0 = (0.05, 0.04, 0.06)
BODY1 = (0.17, 0.15, 0.2)
CLAW = (0.77, 0.24, 0.74)
CLAW_HI = (0.88, 0.44, 0.86)
SILVER = (0.86, 0.85, 0.9)
PINK = (1.0, 0.36, 0.62)

ARROW = [(0, 0), (0, 21.5), (5, 17), (8.6, 25), (12, 23.5), (8.4, 15.8), (15, 15.8)]


def arrow_path(c):
    c.move_to(*ARROW[0])
    for p in ARROW[1:]:
        c.line_to(*p)
    c.close_path()


def draw_arrow(c, ang=0.0, sc=1.0, shine=-1.0, glow=0.0, ox=1.6, oy=1.6):
    """Стрелка-банка, остриё в (ox, oy). ang — наклон (рад), sc — масштаб от острия,
    shine 0..1 — положение блика (−1 — без), glow 0..1 — розовое свечение."""
    c.save()
    c.translate(ox, oy)
    c.rotate(ang)
    c.scale(sc, sc)
    if glow > 0:
        for i in range(4, 0, -1):
            arrow_path(c)
            c.set_source_rgba(*PINK, 0.09 * glow)
            c.set_line_width(1.2 + i * 1.3)
            c.set_line_join(cairo.LINE_JOIN_ROUND)
            c.stroke()
    # тень
    c.save()
    c.translate(0.9, 1.3)
    arrow_path(c)
    c.set_source_rgba(0, 0, 0, 0.35)
    c.fill()
    c.restore()
    # тело
    arrow_path(c)
    g = cairo.LinearGradient(0, 0, 14, 14)
    g.add_color_stop_rgb(0, *BODY1)
    g.add_color_stop_rgb(0.55, *BODY0)
    g.add_color_stop_rgb(1, *BODY0)
    c.set_source(g)
    c.fill_preserve()
    c.save()
    c.clip()
    # серебряная крышка у острия
    c.move_to(-1, -1)
    c.line_to(-1, 6.6)
    c.line_to(6.0, 5.4)
    c.close_path()
    gs = cairo.LinearGradient(0, 0, 4, 4)
    gs.add_color_stop_rgb(0, 1, 1, 1)
    gs.add_color_stop_rgb(1, *SILVER)
    c.set_source(gs)
    c.fill()
    c.set_source_rgba(0.4, 0.38, 0.45, 1)
    c.set_line_width(0.6)
    c.move_to(-1, 6.9)
    c.line_to(6.4, 5.6)
    c.stroke()
    # когти
    c.set_line_cap(cairo.LINE_CAP_ROUND)
    for x0, top, bot in ((2.4, 8.0, 17.5), (5.2, 8.6, 14.8)):
        c.move_to(x0 + 0.7, top)
        c.curve_to(x0 + 0.1, top + 3, x0 + 0.9, bot - 4, x0 - 0.3, bot)
        c.set_source_rgb(*CLAW)
        c.set_line_width(0.95)
        c.stroke()
        c.move_to(x0 + 0.9, top + 0.3)
        c.line_to(x0 + 0.7, top + 2.2)
        c.set_source_rgb(*CLAW_HI)
        c.set_line_width(0.6)
        c.stroke()
    # блик
    if shine >= 0:
        x = -8 + shine * 30
        c.move_to(x, -2)
        c.line_to(x + 3.2, -2)
        c.line_to(x - 9, 28)
        c.line_to(x - 12.2, 28)
        c.close_path()
        c.set_source_rgba(1, 1, 1, 0.6)
        c.fill()
    c.restore()
    # обводка
    arrow_path(c)
    c.set_line_join(cairo.LINE_JOIN_ROUND)
    c.set_source_rgb(*OUTLINE)
    c.set_line_width(1.25)
    c.stroke()
    c.restore()


def draw_can(c, cx, cy, ang, h=13.0):
    """Маленькая банка с центром (cx, cy), повёрнута на ang."""
    w = h * 0.62
    c.save()
    c.translate(cx, cy)
    c.rotate(ang)
    c.translate(-w / 2, -h / 2)

    def body():
        r = 1.6
        c.new_sub_path()
        c.arc(w - r, r, r, -math.pi / 2, 0)
        c.arc(w - r, h - r, r, 0, math.pi / 2)
        c.arc(r, h - r, r, math.pi / 2, math.pi)
        c.arc(r, r, r, math.pi, 3 * math.pi / 2)
        c.close_path()

    body()
    c.set_source_rgb(*BODY0)
    c.fill_preserve()
    c.save()
    c.clip()
    c.rectangle(0, 0, w, 1.9)
    c.rectangle(0, h - 1.5, w, 1.5)
    c.set_source_rgb(*SILVER)
    c.fill()
    c.set_line_cap(cairo.LINE_CAP_ROUND)
    c.set_source_rgb(*CLAW)
    c.set_line_width(0.95)
    for i in range(2):
        x = w * (0.35 + i * 0.3)
        c.move_to(x + 0.3, 3.2)
        c.curve_to(x - 0.3, 5.5, x + 0.4, 7.5, x - 0.2, h - 3.2)
        c.stroke()
    c.rectangle(0.9, 2.2, 0.8, h - 4.2)
    c.set_source_rgba(1, 1, 1, 0.25)
    c.fill()
    c.restore()
    body()
    c.set_source_rgb(*OUTLINE)
    c.set_line_width(0.9)
    c.stroke()
    c.restore()


def star(c, x, y, r, a):
    c.save()
    c.translate(x, y)
    c.move_to(0, -r)
    for i in range(1, 8):
        rr = r if i % 2 == 0 else r * 0.32
        t = -math.pi / 2 + i * math.pi / 4
        c.line_to(math.cos(t) * rr, math.sin(t) * rr)
    c.close_path()
    c.set_source_rgba(1, 0.92, 0.97, a)
    c.fill()
    c.restore()


def bubble(c, x, y, r, a):
    c.arc(x, y, r, 0, 2 * math.pi)
    c.set_source_rgba(*OUTLINE, a)
    c.set_line_width(0.6)
    c.stroke()


def frame(fn):
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, S, S)
    c = cairo.Context(surf)
    c.scale(K, K)
    c.set_antialias(cairo.ANTIALIAS_BEST)
    fn(c)
    surf.flush()
    img = Image.frombuffer("RGBA", (S, S), bytes(surf.get_data()), "raw", "BGRa", 0, 1)
    return img


def rows():
    r = []
    r.append([frame(lambda c, i=i: draw_arrow(c, shine=-1 if i == 0 else (i - 1) / 6.0)) for i in range(8)])

    def point(c, i):
        t = i / 8.0 * 2 * math.pi
        draw_arrow(c, ang=-0.12 + 0.1 * math.sin(t), sc=1.06, glow=0.75 + 0.25 * math.sin(t))
        star(c, 19 + 1.5 * math.cos(t), 5, 2.4 * (0.5 + 0.5 * math.sin(t)), 0.95)
        star(c, 23, 11 + math.sin(t + 2), 1.6 * (0.5 + 0.5 * math.sin(t + 2.5)), 0.85)

    r.append([frame(lambda c, i=i: point(c, i)) for i in range(8)])

    def click(c, i):
        scs = [0.82, 0.86, 0.92, 0.97, 1.0, 1.0]
        draw_arrow(c, ang=-0.12, sc=scs[i] * 1.06, glow=1.0 - i / 6.0)
        for k, (bx, sp) in enumerate(((14, 1.0), (19, 1.4), (16.5, 0.8))):
            y = 22 - i * 2.6 * sp - k
            if 0 < y < 30:
                bubble(c, bx + math.sin(i + k) * 0.8, y, 0.9 + 0.25 * k, 1.0 - i / 6.5)

    r.append([frame(lambda c, i=i: click(c, i)) for i in range(6)])
    r.append([frame(lambda c, i=i: (draw_arrow(c, sc=0.92), draw_can(c, 21.5, 21.5, i / 8.0 * 2 * math.pi))) for i in range(8)])

    def wait(c, i):
        a = i / 8.0 * 2 * math.pi
        c.arc(16, 16, 11, a, a + 4.2)
        c.set_source_rgba(*PINK, 0.85)
        c.set_line_width(1.6)
        c.set_line_cap(cairo.LINE_CAP_ROUND)
        c.stroke()
        draw_can(c, 16, 16, a, h=15)

    r.append([frame(lambda c, i=i: wait(c, i)) for i in range(8)])

    def ibeam(c, i):
        c.set_line_cap(cairo.LINE_CAP_ROUND)
        for col, wdt in ((BODY0, 3.6), (OUTLINE, 1.6)):
            c.set_source_rgb(*col)
            c.set_line_width(wdt)
            c.move_to(16, 6)
            c.line_to(16, 26)
            c.move_to(12.5, 5.5)
            c.curve_to(14.5, 5.5, 16, 6, 16, 7.5)
            c.curve_to(16, 6, 17.5, 5.5, 19.5, 5.5)
            c.move_to(12.5, 26.5)
            c.curve_to(14.5, 26.5, 16, 26, 16, 24.5)
            c.curve_to(16, 26, 17.5, 26.5, 19.5, 26.5)
            c.stroke()
        if i == 1:
            c.arc(16, 16, 1.2, 0, 2 * math.pi)
            c.set_source_rgb(*PINK)
            c.fill()

    r.append([frame(lambda c, i=i: ibeam(c, i)) for i in range(2)])

    def forbid(c):
        draw_arrow(c, sc=0.92)
        c.arc(21.5, 21.5, 6, 0, 2 * math.pi)
        c.set_source_rgb(*BODY0)
        c.fill_preserve()
        c.set_source_rgb(0.95, 0.25, 0.35)
        c.set_line_width(1.6)
        c.stroke()
        c.move_to(17.3, 25.7)
        c.line_to(25.7, 17.3)
        c.stroke()

    r.append([frame(forbid)])

    def drag(c, i):
        draw_arrow(c, sc=0.92)
        d = 6.5 + 0.9 * math.sin(i / 4.0 * 2 * math.pi)
        cx, cy = 21.5, 21.5
        for ang in range(4):
            c.save()
            c.translate(cx, cy)
            c.rotate(ang * math.pi / 2)
            c.move_to(0, -d - 2.2)
            c.line_to(2.2, -d + 0.4)
            c.line_to(-2.2, -d + 0.4)
            c.close_path()
            c.set_source_rgb(*OUTLINE)
            c.fill_preserve()
            c.set_source_rgb(*BODY0)
            c.set_line_width(0.6)
            c.stroke()
            c.restore()
        c.arc(cx, cy, 1.6, 0, 2 * math.pi)
        c.set_source_rgb(*PINK)
        c.fill()

    r.append([frame(lambda c, i=i: drag(c, i)) for i in range(4)])
    return r


def main():
    sheet = Image.new("RGBA", (S * COLS, S * ROWS), (0, 0, 0, 0))
    for y, row in enumerate(rows()):
        for x, im in enumerate(row):
            sheet.paste(im, (x * S, y * S))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT, "WEBP", lossless=True, exact=True)
    big = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (60, 20, 45, 255))
    bg.alpha_composite(big)
    bg.save("/tmp/cur/preview.png")
    print("ok", sheet.size)


if __name__ == "__main__":
    main()
