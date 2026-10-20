"""Птичка «Вряд ли» для портрета героя (полароид у окна реплик): хмурая синяя птица в стиле игры —
мягкая линия, приглушённая акварель, бумажное зерно, подпись «ВРЯД ЛИ».
Запуск из корня репо: python3 tools/art/bird.py → godot/art/sprites/side_bird.webp"""
import math
import os

import cairo
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
W, H = 512, 680
INK = (0.11, 0.09, 0.16)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def path(ctx, pts, close=True):
    ctx.move_to(*pts[0])
    i = 1
    while i + 2 < len(pts):
        ctx.curve_to(*pts[i], *pts[i + 1], *pts[i + 2])
        i += 3
    for p in pts[i:]:
        ctx.line_to(*p)
    if close:
        ctx.close_path()


def fill_stroke(ctx, fill, lw=4.0, ink=INK, grad=None):
    if grad is not None:
        ctx.set_source(grad)
    else:
        ctx.set_source_rgb(*fill)
    ctx.fill_preserve()
    ctx.set_source_rgba(*ink, 0.95)
    ctx.set_line_width(lw)
    ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    ctx.stroke()


def draw():
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    c = cairo.Context(s)
    # фон: тёмное мокрое окно (как ночь за стеклом в игре)
    g = cairo.LinearGradient(0, 0, 0, H)
    g.add_color_stop_rgb(0, *rgb("#2b2236"))
    g.add_color_stop_rgb(1, *rgb("#120c17"))
    c.set_source(g)
    c.paint()
    # тёплое пятно света сзади
    rg = cairo.RadialGradient(330, 250, 10, 330, 250, 330)
    rg.add_color_stop_rgba(0, *rgb("#7a4a6a"), 0.55)
    rg.add_color_stop_rgba(1, *rgb("#2b2236"), 0.0)
    c.set_source(rg)
    c.paint()
    # единый силуэт: голова, переходящая в грудку (птица сидит, нахохлилась)
    sil = cairo.RadialGradient(260, 230, 30, 280, 380, 400)
    sil.add_color_stop_rgb(0, *rgb("#7aa5dc"))
    sil.add_color_stop_rgb(0.45, *rgb("#4675b6"))
    sil.add_color_stop_rgb(1, *rgb("#1f3566"))
    path(c, [(20, 700), (0, 560), (60, 450), (120, 400), (96, 330), (100, 220), (160, 140),
             (220, 90), (330, 84), (400, 130), (440, 170), (452, 250), (448, 300),
             (446, 360), (430, 400), (470, 470), (510, 540), (512, 640), (512, 700)])
    fill_stroke(c, None, 4.5, grad=sil)
    # тень по правому краю — штриховка карандашом
    c.save()
    path(c, [(20, 700), (0, 560), (60, 450), (120, 400), (96, 330), (100, 220), (160, 140),
             (220, 90), (330, 84), (400, 130), (440, 170), (452, 250), (448, 300),
             (446, 360), (430, 400), (470, 470), (510, 540), (512, 640), (512, 700)])
    c.clip()
    c.set_source_rgba(*rgb("#142448"), 0.2)
    c.set_line_width(2)
    for i in range(40):
        x = 300 + i * 9
        c.move_to(x, 380 + (i % 4) * 6)
        c.line_to(x + 60, 700)
        c.stroke()
    shade = cairo.LinearGradient(0, 0, 512, 0)
    shade.add_color_stop_rgba(0, 0, 0, 0, 0.0)
    shade.add_color_stop_rgba(1, 0.05, 0.08, 0.2, 0.35)
    c.set_source(shade)
    c.paint()
    c.restore()
    # хохолок — взъерошенные мягкие перья, зачёсаны назад
    for (x0, y0, dx, dy) in ((170, 132, -46, -50), (212, 104, -30, -64), (258, 92, -6, -66), (304, 92, 22, -52)):
        path(c, [(x0 - 14, y0 + 10), (x0 - 10, y0 - 10), (x0 + dx * 0.6, y0 + dy * 0.7), (x0 + dx, y0 + dy),
                 (x0 + dx * 0.4, y0 + dy * 0.5), (x0 + 16, y0 - 8), (x0 + 18, y0 + 12)])
        fill_stroke(c, rgb("#5684c4"), 3.5)
    # крыло — чешуйки перьев
    path(c, [(30, 700), (24, 590), (70, 500), (160, 470), (240, 456), (300, 520), (320, 620), (330, 700)])
    wing = cairo.LinearGradient(60, 480, 260, 700)
    wing.add_color_stop_rgb(0, *rgb("#3a5f9c"))
    wing.add_color_stop_rgb(1, *rgb("#1b2e5a"))
    fill_stroke(c, None, 4, grad=wing)
    for row in range(4):
        for k in range(6):
            x = 60 + k * 44 + row * 12
            y = 520 + row * 44
            if x > 320 - row * 4:
                continue
            c.arc(x, y, 28, math.pi * 0.05, math.pi * 0.95)
            c.set_source_rgba(*INK, 0.6)
            c.set_line_width(2.6)
            c.stroke()
            c.arc(x, y - 6, 20, math.pi * 0.2, math.pi * 0.8)
            c.set_source_rgba(*rgb("#9cc0ea"), 0.35)
            c.set_line_width(2)
            c.stroke()
    # перышки на груди и щеке
    c.set_source_rgba(*INK, 0.4)
    c.set_line_width(2.4)
    for i in range(8):
        x = 150 + i * 30
        y = 380 + (i % 3) * 16
        c.move_to(x, y)
        c.curve_to(x + 8, y + 18, x + 18, y + 22, x + 26, y + 16)
        c.stroke()
    c.set_source_rgba(*rgb("#b0cff2"), 0.55)
    for i in range(5):
        c.move_to(170 + i * 30, 270 + (i % 2) * 18)
        c.curve_to(178 + i * 30, 282, 184 + i * 30, 286, 194 + i * 30, 278)
        c.stroke()
    # клюв — тёмный, загнутый вниз, вправо
    path(c, [(388, 258), (440, 246), (486, 268), (506, 348), (492, 330), (470, 318), (394, 318)])
    beak = cairo.LinearGradient(400, 270, 500, 330)
    beak.add_color_stop_rgb(0, *rgb("#4a4652"))
    beak.add_color_stop_rgb(1, *rgb("#16141c"))
    fill_stroke(c, None, 3.5, grad=beak)
    path(c, [(394, 318), (430, 320), (460, 326), (482, 336), (450, 350), (420, 346), (396, 334)])
    fill_stroke(c, rgb("#26232c"), 3)
    c.set_source_rgba(1, 1, 1, 0.25)
    c.set_line_width(3)
    c.move_to(410, 276)
    c.curve_to(440, 272, 462, 284, 478, 300)
    c.stroke()
    # глаз
    c.arc(352, 250, 27, 0, math.tau)
    fill_stroke(c, rgb("#0d0b12"), 3)
    c.arc(352, 250, 18, 0, math.tau)
    c.set_source_rgb(*rgb("#2a2440"))
    c.fill()
    c.arc(343, 241, 7, 0, math.tau)
    c.set_source_rgba(1, 1, 1, 0.95)
    c.fill()
    c.arc(360, 258, 3, 0, math.tau)
    c.fill()
    # сердитая бровь — пушистый гребень над глазом, вниз к клюву
    path(c, [(272, 200), (300, 170), (360, 182), (424, 238), (400, 236), (380, 246), (360, 232), (340, 240),
             (320, 222), (300, 230), (286, 214)])
    fill_stroke(c, rgb("#2a4a86"), 4)
    c.set_source_rgba(*INK, 0.85)
    c.set_line_width(3)
    for i in range(5):
        c.move_to(296 + i * 22, 214 + i * 5)
        c.line_to(306 + i * 22, 202 + i * 6)
        c.stroke()
    # нижнее веко — недовольный прищур
    c.set_source_rgba(*rgb("#2d4f8c"), 1)
    c.move_to(322, 268)
    c.curve_to(340, 284, 368, 284, 384, 262)
    c.set_line_width(7)
    c.stroke()
    # капли дождя на перьях
    for (x, y) in ((180, 170), (240, 300), (400, 380), (120, 450), (330, 470)):
        c.arc(x, y, 4, 0, math.tau)
        c.set_source_rgba(0.85, 0.92, 1.0, 0.85)
        c.fill()
    # дождь за спиной
    c.set_source_rgba(0.8, 0.85, 1, 0.12)
    c.set_line_width(1.5)
    rnd = np.random.default_rng(3)
    for _ in range(60):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H)
        c.move_to(x, y)
        c.line_to(x - 4, y + 24)
        c.stroke()
    buf = np.ndarray((H, W, 4), np.uint8, s.get_data()).copy()
    im = Image.fromarray(buf[..., [2, 1, 0, 3]], "RGBA")
    return im


def finish(im):
    a = np.asarray(im).astype(np.float32)
    rng = np.random.default_rng(7)
    n = rng.normal(0, 1, (H // 20 + 2, W // 20 + 2)).astype(np.float32)
    n = np.asarray(Image.fromarray(((n + 3) * 40).clip(0, 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(np.float32)
    a[..., :3] *= (1 + (n / 255 - 0.47) * 0.2)[..., None]
    a[..., :3] += rng.normal(0, 6, (H, W))[..., None]
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(0.5))
    # подпись — как мем, но шрифтом игры
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(os.path.join(ROOT, "godot", "assets", "fonts", "Comfortaa.ttf"), 84)
    try:
        f.set_variation_by_axes([700])
    except Exception:
        pass
    t = "ВРЯД ЛИ"
    bb = d.textbbox((0, 0), t, font=f)
    x = (W - (bb[2] - bb[0])) / 2 - bb[0]
    y = H - 132
    d.text((x, y), t, font=f, fill=(250, 246, 248, 255), stroke_width=7, stroke_fill=(24, 14, 26, 255))
    return im.convert("RGB")


if __name__ == "__main__":
    out = os.path.join(ROOT, "godot", "art", "sprites", "side_bird.webp")
    finish(draw()).save(out, "WEBP", quality=92, method=6)
    print("ok", out)
