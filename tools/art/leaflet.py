"""cg_leaflet1: крупный план листовки на двери Серы — фото пятнадцатилетней Серы (без пирсинга и чокера),
«ВЕРНИСЬ ДОМОЙ», текст общины «Свет Слова», свежий скотч крест-накрест.
Собирается из арта игры (фон cg_leaflet2, спрайт sera_cold). Запуск: python3 tools/art/leaflet.py"""
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
A = os.path.join(ROOT, "godot", "assets")
OUT = os.path.join(ROOT, "godot", "art", "bg", "cg_leaflet1.webp")
SERIF_B = "/usr/share/fonts/liberation-serif/LiberationSerif-Bold.ttf"
SERIF_I = "/usr/share/fonts/liberation-serif/LiberationSerif-Italic.ttf"
SERIF = "/usr/share/fonts/liberation-serif/LiberationSerif-Regular.ttf"
SANS_B = "/usr/share/fonts/msttcore/arialbd.ttf"
W, H = 1376, 768
rng = np.random.default_rng(15)

# ── фон: её дверь крупно, не в фокусе ──
bg = Image.open(os.path.join(A, "bg", "cg_leaflet2.webp")).convert("RGB")
door = bg.crop((120, 120, 620, 400)).resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(6))
door = ImageEnhance.Brightness(door).enhance(0.72)
canvas = door.convert("RGBA")

# ── фото: Сера в пятнадцать — без пирсинга, обрезано выше чокера ──
spr = cv2.imread(os.path.join(A, "sprites", "sera_cold.webp"), cv2.IMREAD_UNCHANGED)
mask = np.zeros(spr.shape[:2], np.uint8)
for x, y in ((700, 295), (697, 306), (691, 312), (680, 320), (684, 324), (702, 288)):
    cv2.circle(mask, (x, y), 6, 255, -1)
bgr = cv2.inpaint(spr[..., :3], mask, 5, cv2.INPAINT_TELEA)
spr = np.dstack([bgr, spr[..., 3]])
face = Image.fromarray(cv2.cvtColor(spr, cv2.COLOR_BGRA2RGBA)).crop((330, 30, 850, 426))
photo = Image.new("RGBA", face.size, (196, 200, 206, 255))  # фон школьного фото
photo = Image.alpha_composite(photo, face).convert("RGB")
photo = ImageEnhance.Color(photo).enhance(0.55)
photo = ImageEnhance.Contrast(photo).enhance(1.12)
photo = photo.filter(ImageFilter.GaussianBlur(0.8))
pw = 300
photo = photo.resize((pw, int(pw * photo.height / photo.width)), Image.LANCZOS)
# печать на принтере: лёгкий растр
pa = np.asarray(photo).astype(np.float32)
yy, xx = np.mgrid[0 : pa.shape[0], 0 : pa.shape[1]]
pa *= (0.94 + 0.06 * np.sin(yy * 1.9))[..., None]
photo = Image.fromarray(np.clip(pa, 0, 255).astype(np.uint8))

# ── лист ──
LW, LH = 500, 700
paper = np.full((LH, LW, 3), (238, 234, 224), np.float32)
paper += rng.normal(0, 4, paper.shape)
gy = np.linspace(0, 1, LH)[:, None, None]
paper *= 1.0 - 0.06 * gy
leaf = Image.fromarray(np.clip(paper, 0, 255).astype(np.uint8)).convert("RGBA")
d = ImageDraw.Draw(leaf)
ink = (40, 30, 34, 255)
red = (128, 18, 32, 255)


def center(txt, y, font, fill):
    w = d.textlength(txt, font=font)
    d.text(((LW - w) / 2, y), txt, font=font, fill=fill)


center("ВЕРНИСЬ ДОМОЙ", 34, ImageFont.truetype(SANS_B, 52), red)
d.line([(60, 104), (LW - 60, 104)], fill=red, width=3)
px0 = (LW - photo.width) // 2
d.rectangle([px0 - 6, 124, px0 + photo.width + 5, 130 + photo.height + 5], fill=(250, 250, 246, 255), outline=(150, 146, 140, 255))
leaf.paste(photo, (px0, 130))
y = 130 + photo.height + 22
center("Серафима,", y, ImageFont.truetype(SERIF_I, 26), ink)
center("мы молимся за тебя.", y + 32, ImageFont.truetype(SERIF_I, 26), ink)
center("Господь ждёт. Мы ждём.", y + 64, ImageFont.truetype(SERIF_I, 26), ink)
# крестик и подпись общины
cx0 = LW // 2
d.rectangle([cx0 - 2, y + 106, cx0 + 2, y + 132], fill=ink)
d.rectangle([cx0 - 10, y + 113, cx0 + 10, y + 117], fill=ink)
center("Община «Свет Слова»", y + 140, ImageFont.truetype(SERIF_B, 24), ink)
center("Воскресные собрания — ДК «Железнодорожник», 10:00", y + 170, ImageFont.truetype(SERIF, 18), ink)
# отрывные полоски с телефоном
ty = LH - 62
d.line([(0, ty), (LW, ty)], fill=(160, 156, 150, 255), width=1)
f_small = ImageFont.truetype(SERIF, 12)
for k in range(10):
    x = 10 + k * 48
    d.line([(x + 46, ty), (x + 46, LH)], fill=(170, 166, 160, 255), width=1)
    tab = Image.new("RGBA", (56, 16), (0, 0, 0, 0))
    ImageDraw.Draw(tab).text((0, 0), "8-9••-•••-17-09", font=f_small, fill=ink)
    tab = tab.rotate(90, expand=True)
    leaf.alpha_composite(tab, (x + 16, ty + 4))
# заломы бумаги
for _ in range(3):
    x = rng.integers(40, LW - 40)
    d.line([(x, 0), (x + rng.integers(-30, 30), LH)], fill=(228, 224, 214, 60), width=1)
leaf = leaf.rotate(-2.2, resample=Image.BICUBIC, expand=True)
leaf = leaf.resize((int(leaf.width * 0.93), int(leaf.height * 0.93)), Image.LANCZOS)

# тень и лист на двери
lx, ly = (W - leaf.width) // 2 + 20, (H - leaf.height) // 2 + 6
shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
sm = Image.new("L", leaf.size, 0)
sm.paste(leaf.getchannel("A"))
shadow.paste((10, 6, 8, 150), (lx + 14, ly + 18), sm)
shadow = shadow.filter(ImageFilter.GaussianBlur(14))
canvas = Image.alpha_composite(canvas, shadow)
canvas.alpha_composite(leaf, (lx, ly))

# ── скотч крест-накрест: свежий, блестит ──
tape = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
td = ImageDraw.Draw(tape)
cxl, cyl = lx + leaf.width / 2, ly + leaf.height / 2
for ang in (np.deg2rad(52), np.deg2rad(-52)):
    dx, dy = np.cos(ang), np.sin(ang)
    nx, ny = -dy, dx
    L, w = 430, 24
    pts = [(cxl - dx * L + nx * w, cyl - dy * L + ny * w), (cxl + dx * L + nx * w, cyl + dy * L + ny * w),
           (cxl + dx * L - nx * w, cyl + dy * L - ny * w), (cxl - dx * L - nx * w, cyl - dy * L - ny * w)]
    td.polygon(pts, fill=(236, 232, 214, 80), outline=(255, 255, 250, 110))
    # блик
    hl = [(cxl - dx * L + nx * 8, cyl - dy * L + ny * 8), (cxl + dx * L + nx * 8, cyl + dy * L + ny * 8),
          (cxl + dx * L + nx * 2, cyl + dy * L + ny * 2), (cxl - dx * L + nx * 2, cyl - dy * L + ny * 2)]
    td.polygon(hl, fill=(255, 255, 255, 60))
tape = tape.filter(ImageFilter.GaussianBlur(0.6))
canvas = Image.alpha_composite(canvas, tape)

# свет лампочки сверху, виньетка, зерно — как в остальных CG
a = np.asarray(canvas.convert("RGB")).astype(np.float32) / 255
yy, xx = np.mgrid[0:H, 0:W]
light = np.exp(-(((xx - W * 0.55) / (W * 0.6)) ** 2 + ((yy + 120) / (H * 0.9)) ** 2))
a *= (0.72 + 0.38 * light)[..., None] * np.array([1.04, 1.0, 0.92])
d2 = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
a *= (1 - 0.45 * np.clip(d2 - 0.45, 0, 1))[..., None]
a += rng.normal(0, 0.012, a.shape)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(OUT, quality=90)
print("ok", OUT)
