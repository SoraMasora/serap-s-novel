"""Кадры концовки «Обочина» из фона street_rain (тот же художественный стиль):
end_car1 — слепящие фары на мокрой дороге; end_car2 — синие/красные всполохи на стенах;
end_car3 — скорая у обочины, двери закрыты. Запуск: python3 tools/art/end_car.py → godot/art/bg/end_car*.webp"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "godot", "assets", "bg", "street_rain.webp")
OUT = os.path.join(ROOT, "godot", "art", "bg")
FONT = "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf"


def night(im, k=0.42, tint=(0.75, 0.8, 1.0)):
    a = np.asarray(im.convert("RGB")).astype(np.float32) / 255
    a = a * k
    a *= np.array(tint, np.float32)
    return a


def glow(a, cx, cy, r, col, power=1.0, sy=1.0):
    h, w, _ = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - cx) / r) ** 2 + ((yy - cy) / (r * sy)) ** 2)
    g = np.exp(-d * d * 2.2) * power
    return a + g[..., None] * np.array(col, np.float32)


def streak(a, cx, y0, y1, wdt, col, power):
    """Отражение света в мокром асфальте — вертикальная дорожка."""
    h, w, _ = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    t = np.clip((yy - y0) / max(1, (y1 - y0)), 0, 1)
    m = (yy >= y0) & (yy <= y1)
    g = np.exp(-(((xx - cx) / (wdt * (0.6 + t))) ** 2)) * (1 - t) * power * m
    return a + g[..., None] * np.array(col, np.float32)


def rain(a, seed, n=900, alpha=0.25):
    rng = np.random.default_rng(seed)
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for _ in range(n):
        x, y = rng.uniform(0, im.width), rng.uniform(0, im.height)
        ln = rng.uniform(14, 40)
        d.line([(x, y), (x - ln * 0.12, y + ln)], fill=(210, 220, 245, int(255 * alpha * rng.uniform(0.4, 1))), width=1)
    im = Image.alpha_composite(im.convert("RGBA"), lay)
    return np.asarray(im.convert("RGB")).astype(np.float32) / 255


def vignette(a, k=0.55):
    h, w, _ = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    return a * (1 - k * np.clip(d - 0.35, 0, 1)[..., None])


def save(a, name):
    os.makedirs(OUT, exist_ok=True)
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    im.save(os.path.join(OUT, name + ".webp"), quality=90)


base = Image.open(SRC).convert("RGB")
W, H = base.size

# 1 — фары: камера низко у асфальта, свет бьёт в лицо, смазан
a = night(base, 0.32)
a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))).astype(np.float32) / 255
for cx in (560, 820):
    a = glow(a, cx, 520, 70, (1.0, 0.95, 0.8), 2.2)
    a = glow(a, cx, 520, 260, (1.0, 0.9, 0.7), 0.55)
    a = streak(a, cx, 540, H, 26, (1.0, 0.9, 0.7), 0.9)
a = glow(a, 690, 520, 700, (1.0, 0.92, 0.8), 0.35, sy=0.45)
a = rain(a, 1, 1400, 0.4)
a = vignette(a, 0.4)
save(a, "end_car1")

# 2 — всполохи скорой на мокрых стенах и лужах
a = night(base, 0.36, (0.7, 0.75, 1.0))
a = glow(a, 300, 360, 520, (0.15, 0.35, 1.0), 0.75, sy=0.7)
a = glow(a, 1100, 380, 480, (1.0, 0.12, 0.18), 0.55, sy=0.7)
a = glow(a, 300, 360, 120, (0.4, 0.6, 1.0), 0.6)
for cx, col in ((320, (0.3, 0.5, 1.0)), (1080, (1.0, 0.25, 0.3)), (700, (0.6, 0.6, 0.9))):
    a = streak(a, cx, 560, H, 40, col, 0.45)
a = rain(a, 2, 1100, 0.32)
a = vignette(a, 0.5)
save(a, "end_car2")

# 3 — скорая у обочины (вид сзади), двери закрыты, мигалка
a = night(base, 0.4)
im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
d = ImageDraw.Draw(lay)
ink = (34, 32, 40, 255)
x0, y0, x1, y1 = 520, 300, 880, 640  # кузов
d.rounded_rectangle([x0 - 6, y1 - 6, x1 + 6, y1 + 26], 10, fill=(20, 20, 26, 160))  # тень
d.rounded_rectangle([x0, y0, x1, y1], 18, fill=(214, 214, 206, 255), outline=ink, width=5)
d.rectangle([x0 + 4, y0 + 150, x1 - 4, y0 + 186], fill=(178, 34, 44, 255))  # красная полоса
mid = (x0 + x1) // 2
d.line([(mid, y0 + 40), (mid, y1 - 40)], fill=ink, width=4)  # створки
for wx in (x0 + 28, mid + 20):
    d.rounded_rectangle([wx, y0 + 46, wx + 132, y0 + 132], 8, fill=(40, 46, 62, 255), outline=ink, width=4)
    d.line([(wx + 14, y0 + 120), (wx + 50, y0 + 60)], fill=(120, 130, 160, 255), width=3)
f = ImageFont.truetype(FONT, 34)
for txt, cx in (("СКОРАЯ", mid), ):
    tw = d.textlength(txt, font=f)
    d.text((cx - tw / 2, y0 + 150), txt, font=f, fill=(250, 246, 240, 255))
f2 = ImageFont.truetype(FONT, 46)
d.text((mid - 60, y0 + 196), "03", font=f2, fill=(178, 34, 44, 255))
d.rectangle([mid - 8, y0 + 250, mid - 2, y0 + 290], fill=ink)
d.rectangle([mid + 2, y0 + 250, mid + 8, y0 + 290], fill=ink)
d.rounded_rectangle([mid - 70, y1 - 54, mid + 70, y1 - 22], 4, fill=(232, 232, 228, 255), outline=ink, width=3)  # номер
d.rectangle([x0 - 10, y1 - 20, x1 + 10, y1 + 6], fill=(46, 44, 50, 255), outline=ink, width=4)  # бампер
for lx in (x0 + 12, x1 - 52):
    d.rounded_rectangle([lx, y1 - 110, lx + 40, y1 - 60], 6, fill=(200, 40, 40, 255), outline=ink, width=3)
for wx in (x0 + 20, x1 - 100):
    d.rounded_rectangle([wx, y1, wx + 80, y1 + 34], 10, fill=(18, 18, 22, 255))
d.rounded_rectangle([mid - 90, y0 - 26, mid + 90, y0 + 2], 8, fill=(40, 70, 200, 255), outline=ink, width=4)  # мигалка
# кузов в ночи: приглушить и подсинить, снизу темнее (как остальная сцена)
la = np.asarray(lay).astype(np.float32)
ys = np.linspace(0, 1, la.shape[0])[:, None]
shade = 0.62 - 0.22 * np.clip((ys - y0 / H) / ((y1 - y0) / H), 0, 1)
la[..., :3] *= shade[..., None] * np.array([0.82, 0.88, 1.0], np.float32)
lay = Image.fromarray(la.astype(np.uint8), "RGBA")
im = Image.alpha_composite(im, lay)
a = np.asarray(im.convert("RGB")).astype(np.float32) / 255
a = glow(a, mid - 45, y0 - 12, 60, (0.3, 0.5, 1.0), 1.4)
a = glow(a, mid - 45, y0 - 12, 420, (0.15, 0.3, 1.0), 0.45, sy=0.6)
a = glow(a, x0 + 32, y1 - 85, 50, (1.0, 0.15, 0.15), 0.8)
a = glow(a, x1 - 32, y1 - 85, 50, (1.0, 0.15, 0.15), 0.8)
for cx, col in ((mid - 45, (0.3, 0.5, 1.0)), (x0 + 32, (1.0, 0.2, 0.2)), (x1 - 32, (1.0, 0.2, 0.2))):
    a = streak(a, cx, y1 + 30, H, 22, col, 0.5)
a = rain(a, 3, 1200, 0.33)
a = vignette(a, 0.5)
save(a, "end_car3")
print("ok")
