"""loop_art.py — v18 «петля»: арт смертей, Серафима и истинной концовки → assets/loopN.js (≤900 КБ на файл).
Исходники: /data/gen/src_<key>.jpg (Notion images_generate, 1376×768, стиль v17 — правки существующих фонов).
Запуск: python3 tools/loop_art.py [папка_исходников]"""
import sys, io, os, glob, base64
from PIL import Image
SRC = sys.argv[1] if len(sys.argv) > 1 else '/data/gen'
BG = ['d_room', 'd_store', 'd_road', 'd_train', 'd_cross', 'd_cliff', 'd_neck',   # 7 смертей (после — без людей)
      'x_scream', 'c_sketch', 'c_icon', 'h_snow',                                  # скример, улики, первый снег
      't_roof', 't_sky', 't_hand', 't_sky2', 't_landing', 't_angel']               # истинная концовка
TITLE = {'te': 'title_empty'}  # титул после смертей: пустая кровать, снег, глаза на картинах
def webp(p, q=80):
    im = Image.open(p).convert('RGB')
    if im.size != (1376, 768): im = im.resize((1376, 768), Image.LANCZOS)
    b = io.BytesIO(); im.save(b, 'WEBP', quality=q, method=6); return base64.b64encode(b.getvalue()).decode()
items = [('bg', k, webp(f'{SRC}/src_{k}.jpg')) for k in BG] + [('title', k, webp(f'{SRC}/src_{v}.jpg')) for k, v in TITLE.items()]
for f in glob.glob('assets/loop[0-9]*.js'): os.remove(f)
packs, cur, size = [], [], 0
for it in items:
    if cur and size + len(it[2]) > 900_000: packs.append(cur); cur, size = [], 0
    cur.append(it); size += len(it[2])
packs.append(cur)
for i, pk in enumerate(packs, 1):
    fn = f'assets/loop{i}.js'
    with open(fn, 'w') as o:
        o.write("window.ASSETS=window.ASSETS||{};['bg','sprites','title','ui'].forEach(k=>ASSETS[k]=ASSETS[k]||{});\n")
        for kind, k, s in pk: o.write(f"ASSETS.{kind}['{k}']='data:image/webp;base64,{s}';\n")
    print(fn, os.path.getsize(fn) // 1024, 'KB', [k for _, k, _ in pk])
