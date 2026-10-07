#!/usr/bin/env python3
"""Хромакей #00FF00 без ореола: мягкая альфа + восстановление цвета кромки
(un-premultiply по зелёному) + despill + эрозия + удаление мусора.
python3 key3.py in.jpg out.png [scale]"""
import sys, numpy as np, cv2
from PIL import Image

def key(path, scale=1.0, lo=12, hi=70, erode=1, strict=True):
    im = np.array(Image.open(path).convert('RGB')).astype(np.float32)
    if scale != 1.0:
        h, w = im.shape[:2]
        im = cv2.resize(im, (round(w*scale), round(h*scale)), interpolation=cv2.INTER_LANCZOS4)
        im = np.clip(im, 0, 255)
    r, g, b = im[...,0], im[...,1], im[...,2]
    d = g - np.maximum(r, b)                      # «зелёность»
    a = np.clip((hi - d) / (hi - lo), 0, 1)       # 1 — персонаж, 0 — фон
    # мусор: оставить только крупную связную фигуру
    m = (a > 0.5).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    keep = np.zeros(n, bool); keep[1:] = stats[1:, cv2.CC_STAT_AREA] > 400
    fig = keep[lab]
    # заполнить дыры внутри фигуры, где a мала по ошибке, не трогаем (просветы между волос — настоящие)
    near = cv2.dilate(fig.astype(np.uint8), np.ones((5,5),np.uint8)) > 0
    a = np.where(near, a, 0)
    # эрозия кромки на erode px
    if erode:
        ae = cv2.erode(a, np.ones((3,3),np.float32), iterations=erode)
        a = np.minimum(a, ae*0.6 + a*0.4)
    a = cv2.GaussianBlur(a, (0,0), 0.6)
    a = np.where(a < 0.04, 0, np.where(a > 0.97, 1, a))
    # цвет кромки берём от ближайших «чистых» пикселей фигуры (без зелёного и без пурпурного ореола)
    core = ((a > 0.985) & (d < lo)).astype(np.float32)
    F = im.copy()
    acc = np.zeros_like(im); w = np.zeros_like(a)
    for k in (3, 7, 15):
        cb = cv2.blur(core, (k, k)); ib = cv2.blur(im * core[...,None], (k, k))
        fill = (w == 0) & (cb > 0.01)
        acc[fill] = ib[fill] / cb[fill][...,None]; w[fill] = 1
    edge = (a < 0.985) | (d >= lo)
    F = np.where((edge & (w > 0))[...,None], acc, im)
    F = np.clip(F, 0, 255)
    # despill на всякий случай
    F[...,1] = np.minimum(F[...,1], np.maximum(F[...,0], F[...,2]) + 2)
    if strict:  # у Серы нет жёлто-зелёных цветов: g не выше b заметно (кроме тёплых светлых)
        F[...,1] = np.minimum(F[...,1], F[...,2] + 10)
    out = np.dstack([F, a*255]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')

if __name__ == '__main__':
    s = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
    strict = not (len(sys.argv) > 4 and sys.argv[4] == 'soft')
    key(sys.argv[1], s, strict=strict).save(sys.argv[2])
