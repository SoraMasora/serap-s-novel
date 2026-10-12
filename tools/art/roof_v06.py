"""godot-0.6: крыша «Месяц 2» заново — дым идёт ровно от кончиков сигарет; некурящий вариант с чаем.

Исходники (не в git, бинарные): tools/art/src/m2/roofsit2.jpg (курят), tools/art/src/m2/rooftea.jpg (чай).
Выход: base64 в assets/x7.js — bg m2_rx0..3 (курят), assets/x8.js — m2_rt0..3 (чай); в Godot — BG_ANIM «m2_rx» / «m2_rt».
Старые m2_rs0..3 (godot/art) больше не используются: дым там висел отдельно от сигарет.
Запуск из корня: python3 tools/art/roof_v06.py
"""

import io
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import month2 as m  # noqa: E402
from setasset import set_asset  # noqa: E402

JS = {"m2_rx": os.path.join(m.ROOT, "assets", "x7.js"), "m2_rt": os.path.join(m.ROOT, "assets", "x8.js")}
# кончики сигарет и огонёк зажигалки на roofsit2 (1376×768)
SERA_TIP, HERO_TIP, LIGHTER = (708, 502), (917, 441), (981, 684)
# верх чашек на rooftea
SERA_CUP, HERO_CUP = (655, 494), (958, 624)


def frame(a, seed):
    a = m.grain(a, seed)
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


HEAD = "window.ASSETS=window.ASSETS||{bg:{},sprites:{}};ASSETS.bg=ASSETS.bg||{};ASSETS.sprites=ASSETS.sprites||{};\n"


def put(key, im):
    js = JS[key[:5]]
    if not os.path.exists(js) or not open(js).read().startswith("window.ASSETS"):
        open(js, "w").write(HEAD)
    set_asset(js, "bg", key, im, 80)


def main():
    rs = m.load("roofsit2")
    for i in range(4):
        ph = i * math.pi / 2
        a = m.screen(rs, m.smoke(SERA_TIP[0], SERA_TIP[1] - 2, ph, 5, 190, 7.0, 0.6), (0.86, 0.86, 0.92))
        a = m.screen(a, m.smoke(HERO_TIP[0], HERO_TIP[1] - 2, ph + 1.3, 9, 170, 6.0, 0.5), (0.86, 0.86, 0.92))
        for (x, y), r in ((SERA_TIP, 5), (HERO_TIP, 4)):  # тлеющие кончики
            a = m.screen(a, m.glow(x, y, r) * (0.55 + 0.25 * math.sin(ph + x)), (1.0, 0.45, 0.15))
        a = m.screen(a, m.glow(LIGHTER[0], LIGHTER[1], 22) * (0.25 + 0.2 * abs(math.sin(ph + 0.7))), (1.0, 0.7, 0.3))
        put("m2_rx%d" % i, frame(a, 140 + i))
    rt = m.load("rooftea")
    for i in range(4):
        ph = i * math.pi / 2
        a = rt
        for (x, y), s in ((SERA_CUP, 21), (HERO_CUP, 23)):  # пар: две широкие прозрачные струйки
            for dx, k in ((-6, 0), (6, 1)):
                a = m.screen(a, m.smoke(x + dx, y - 4, ph + k * 2.1, s + k, 80, 5.0, 0.42), (0.92, 0.92, 0.96))
        put("m2_rt%d" % i, frame(a, 150 + i))


if __name__ == "__main__":
    main()
