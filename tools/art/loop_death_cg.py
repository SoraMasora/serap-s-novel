"""0.7.4 · CG смертей Серы (dm_*) и лица скримера (x_face, x_smile) — постобработка и упаковка.

Исходники — ИИ-иллюстрации 1376×768 по референсу стиля игры (крыша/дождь/сепия), лежат вне git
(в архиве проекта: art_sources/0.7.4-death-cg/). Скрипт приводит их к палитре кадров петли:
частичный перенос цвета (Lab, Рейнхард) к парному кадру d_*, лёгкая десатурация, «матовые» чёрные,
зерно плёнки, виньетка; у train/road — ореол фар. Лица скримера — дополнительная деформация
(вытянутая челюсть, расширенные чёрные глаза) и жёсткий контраст.
Результат: assets/loop4.js · loop5.js · loop6.js (base64 WebP, как loop1–3.js) →
node tools/godot/add_loop_assets.cjs → godot/assets/bg/ + манифест.

Запуск из корня: python3 tools/art/loop_death_cg.py art_sources/0.7.4-death-cg
(старые кадры d_* берутся из godot/assets/bg/, т.е. после export_data.cjs --assets)
"""
import base64, cv2, numpy as np, sys, os
rng = np.random.default_rng(73)
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OLD = os.path.join(ROOT, 'godot', 'assets', 'bg')
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'art_sources', '0.7.4-death-cg')
OUT = os.environ.get('OUT') or os.path.join(ROOT, 'shots', 'loop074_art')
W, H = 1376, 768
PACKS = {'loop4.js': ['dm_room', 'dm_store', 'dm_road'],
         'loop5.js': ['dm_train', 'dm_cross', 'dm_cliff'],
         'loop6.js': ['dm_neck', 'x_face', 'x_smile']}

def lab_stats(im):
    lab = cv2.cvtColor(im, cv2.COLOR_BGR2LAB).astype(np.float32)
    return lab, lab.reshape(-1, 3).mean(0), lab.reshape(-1, 3).std(0)

def transfer(im, ref, a_mean=0.55, a_std=0.35, a_lum=None):
    lab, ms, ss = lab_stats(im)
    _, mt, st = lab_stats(ref)
    out = lab.copy()
    for c in range(3):
        am = a_mean if (c > 0 or a_lum is None) else a_lum
        asd = a_std if (c > 0 or a_lum is None) else 0.0
        k = 1.0 + asd * (st[c] / max(ss[c], 1e-3) - 1.0)
        out[..., c] = (lab[..., c] - ms[c]) * k + ms[c] + am * (mt[c] - ms[c])
    out = np.clip(out, 0, 255).astype(np.uint8)
    return cv2.cvtColor(out, cv2.COLOR_LAB2BGR)

def bloom(im, thr=225, sigma=38, gain=0.75):
    x = im.astype(np.float32)
    lum = x.mean(2)
    m = np.clip((lum - thr) / (255 - thr), 0, 1)[..., None] * x
    g = cv2.GaussianBlur(m, (0, 0), sigma)
    return np.clip(x + gain * g, 0, 255).astype(np.uint8)

def desat(im, f):
    hsv = cv2.cvtColor(im, cv2.COLOR_BGR2HSV).astype(np.float32)
    hsv[..., 1] *= f
    return cv2.cvtColor(np.clip(hsv, 0, 255).astype(np.uint8), cv2.COLOR_HSV2BGR)

def matte(im, lift=10, roll=0.96):
    x = im.astype(np.float32)
    x = lift + x * (roll * 255 - lift) / 255
    return np.clip(x, 0, 255).astype(np.uint8)

def grain(im, sigma=5.0, paper=2.5):
    h, w = im.shape[:2]
    n = rng.normal(0, sigma, (h, w)).astype(np.float32)
    n = cv2.GaussianBlur(n, (0, 0), 0.6)
    low = cv2.resize(rng.normal(0, 1, (h // 24 + 1, w // 24 + 1)).astype(np.float32), (w, h), interpolation=cv2.INTER_CUBIC)
    x = im.astype(np.float32) + n[..., None] + paper * low[..., None]
    return np.clip(x, 0, 255).astype(np.uint8)

def vignette(im, strength=0.28, power=2.2, tint=(0, 0, 0)):
    h, w = im.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / np.sqrt(2)
    m = (strength * r ** power)[..., None]
    t = np.array(tint, np.float32)[None, None, :]
    return np.clip(im.astype(np.float32) * (1 - m) + t * m, 0, 255).astype(np.uint8)

def magnify(mx, my, cx, cy, rx, ry, ax, ay):
    """Inverse map: magnify area around (cx,cy). amplitude a<1."""
    dx = (mx - cx) / rx
    dy = (my - cy) / ry
    g = np.exp(-(dx * dx + dy * dy))
    return cx + (mx - cx) * (1 - ax * g), cy + (my - cy) * (1 - ay * g)

def warp(im, ops):
    h, w = im.shape[:2]
    my, mx = np.mgrid[0:h, 0:w].astype(np.float32)
    sx, sy = mx.copy(), my.copy()
    for op in ops:
        sx, sy = magnify(sx, sy, *op)
    return cv2.remap(im, sx.astype(np.float32), sy.astype(np.float32), cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT)

def load(name):
    im = cv2.imread(os.path.join(SRC, name))
    if im.shape[1] != W or im.shape[0] != H:
        im = cv2.resize(im, (W, H), interpolation=cv2.INTER_AREA)
    return im

def old(key):
    return cv2.imread(os.path.join(OLD, key + '.webp'))

def save(key, im, q=86):
    cv2.imwrite(os.path.join(OUT, key + '.webp'), im, [cv2.IMWRITE_WEBP_QUALITY, q])


def pack():
    head = "window.ASSETS=window.ASSETS||{};['bg','sprites','title','ui'].forEach(k=>ASSETS[k]=ASSETS[k]||{});\n"
    for name, keys in PACKS.items():
        lines = [head]
        for k in keys:
            with open(os.path.join(OUT, k + '.webp'), 'rb') as f:
                lines.append("ASSETS.bg['%s']='data:image/webp;base64,%s';\n" % (k, base64.b64encode(f.read()).decode()))
        with open(os.path.join(ROOT, 'assets', name), 'w') as f:
            f.write(''.join(lines))
        print(name, keys)

# key: (source, old frame for palette, mean strength, std strength, desat)
DEATHS = {
    'dm_room':  ('room_a.jpg',  'd_room',  0.45, 0.25, 0.86),
    'dm_store': ('store_a.jpg', 'd_store', 0.45, 0.25, 0.86),
    'dm_road':  ('road_a.jpg',  'd_road',  0.65, 0.35, 0.80),
    'dm_train': ('train_a.jpg', 'd_train', 0.55, 0.20, 0.86),
    'dm_cross': ('cross_a.jpg', 'd_cross', 0.45, 0.25, 0.92),
    'dm_cliff': ('cliff_a.jpg', 'd_cliff', 0.45, 0.25, 0.90),
    'dm_neck':  ('neck_a.jpg',  'd_neck',  0.60, 0.30, 1.00),
}

LUM = {'dm_train': 0.05, 'dm_road': 0.25}
BLOOM = {'dm_train': (232, 30, 0.5), 'dm_road': (225, 30, 0.55)}

def death(key):
    src, ref, am, asd, ds = DEATHS[key]
    im = transfer(load(src), old(ref), am, asd, LUM.get(key))
    im = desat(im, ds)
    if key in BLOOM:
        im = bloom(im, *BLOOM[key])
    im = matte(im, 8, 0.97 if key not in BLOOM else 1.0)
    im = vignette(im, 0.30)
    return grain(im, 4.6, 2.0)

def face():
    im = load('face_a.jpg')
    im = warp(im, [
        (693, 552, 115, 120, 0.20, 0.46),   # mouth: stretched jaw
        (575, 345, 70, 66, 0.24, 0.24),     # left eye pit
        (800, 345, 70, 66, 0.24, 0.24),     # right eye pit
    ])
    hsv = cv2.cvtColor(im, cv2.COLOR_BGR2HSV).astype(np.float32)
    red = ((hsv[..., 0] < 12) | (hsv[..., 0] > 160)).astype(np.float32)
    hsv[..., 1] *= 0.55 + 0.6 * red
    im = cv2.cvtColor(np.clip(hsv, 0, 255).astype(np.uint8), cv2.COLOR_HSV2BGR)
    x = im.astype(np.float32) / 255
    x = np.clip((x - 0.5) * 1.28 + 0.47, 0, 1)            # harsher contrast
    x[..., 0] *= 1.04; x[..., 2] *= 0.97                    # cold
    im = (np.clip(x, 0, 1) * 255).astype(np.uint8)
    im = vignette(im, 0.62, 1.6, (8, 0, 18))
    return grain(im, 7.0, 3.0)

def smile():
    im = load('smile_a.jpg')
    im = warp(im, [(718, 512, 120, 60, 0.22, 0.10), (712, 300, 64, 64, 0.18, 0.18)])
    im = desat(im, 0.9)
    im = vignette(im, 0.55, 1.8, (0, 0, 6))
    return grain(im, 6.0, 2.5)

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for k in DEATHS:
        save(k, death(k))
    save('x_face', face(), 88)
    save('x_smile', smile(), 88)
    pack()
