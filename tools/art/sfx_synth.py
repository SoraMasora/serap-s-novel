"""Синтез SFX: brake (визг шин + удар), siren (сирена скорой) — «Обочина»;
swing_fwd/back 1–3 (скрип качелей), lighter (кремень + пламя) — качели и «Ленивый идиот».
Запуск: python3 tools/art/sfx_synth.py → godot/art/sfx/*.ogg"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "art", "sfx")


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    x = x / max(1e-6, np.max(np.abs(x))) * 0.85
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5",
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


rng = np.random.default_rng(7)
# brake: визг (несколько гармоник с дрожанием) + шипение шин, затем удар
d = 1.25
t = np.arange(int(SR * d)) / SR
f = 1850 - 350 * t / d + 40 * np.sin(2 * np.pi * 23 * t)
ph = 2 * np.pi * np.cumsum(f) / SR
squeal = np.sin(ph) + 0.45 * np.sin(2 * ph + 0.3) + 0.2 * np.sin(3.01 * ph)
squeal *= (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t)) * np.minimum(1, t / 0.05) * np.exp(-0.3 * t)
hiss = rng.standard_normal(len(t))
hiss = hiss - lowpass(hiss, 0.25)
hiss *= 0.35 * np.minimum(1, t / 0.03)
brake = squeal * 0.6 + hiss
ti = np.arange(int(SR * 0.6)) / SR
thud = np.sin(2 * np.pi * (70 - 30 * ti) * ti) * np.exp(-9 * ti)
crack = rng.standard_normal(len(ti)) * np.exp(-40 * ti)
impact = thud * 1.3 + lowpass(crack, 0.3) * 0.9
x = np.concatenate([brake, impact, np.zeros(int(SR * 0.3))])
x[: len(brake)] *= np.linspace(1, 0.7, len(brake))
save("brake", x)

# siren: двухтональная «скорая» (≈ 650 / 870 Гц), приближается и удаляется
d = 4.6
t = np.arange(int(SR * d)) / SR
tone = np.where((t // 0.55) % 2 == 0, 650.0, 870.0)
tone = lowpass(tone, 0.004)
dop = 1 + 0.03 * np.tanh((d / 2 - t) * 1.5)
ph = 2 * np.pi * np.cumsum(tone * dop) / SR
sq = np.sign(np.sin(ph)) * 0.35 + np.sin(ph) * 0.65
sq = lowpass(sq, 0.35)
env = np.exp(-((t - d * 0.45) ** 2) / (2 * 1.3 ** 2))
save("siren", sq * env * 0.9)

# swing_fwd1..3 / swing_back1..3: скрип качелей — как у настоящих: трение «прилипание-срыв»
# в шарнире (серия коротких импульсов, частота которых и даёт высоту скрипа) возбуждает
# металлические резонансы подвеса. Вперёд — выше «и-и», назад — ниже «э-э»; плюс тихий звяк цепи.
def resonate(x, f, q):
    """Двухполюсный резонатор (металлический призвук) на частоте f, добротность q."""
    r = np.exp(-np.pi * f / (q * SR))
    c1, c2 = 2 * r * np.cos(2 * np.pi * f / SR), -r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i in range(len(x)):
        y0 = x[i] + c1 * y1 + c2 * y2
        y[i] = y0
        y2, y1 = y1, y0
    return y * (1 - r)


def creak(seed, d, rate, modes, clink):
    r = np.random.default_rng(seed)
    n = int(SR * d)
    t = np.arange(n) / SR
    u = t / d
    # высота скрипа: подъём и спад по ходу движения + «дрожание» трения
    hz = rate[0] + (rate[1] - rate[0]) * np.sin(np.pi * np.clip(u * 1.15, 0, 1)) ** 0.8
    hz = hz * (1 + 0.035 * np.sin(2 * np.pi * r.uniform(5, 9) * t) + 0.02 * r.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)))
    pulses = np.zeros(n)
    ph = 0.0
    for i in range(n):
        ph += hz[i] / SR * (1 + 0.12 * r.standard_normal())
        if ph >= 1.0:
            ph -= 1.0
            pulses[i] = 1.0 + 0.35 * r.standard_normal()
    # трение то «схватывает», то проскальзывает — местами скрип рвётся
    grip = np.clip(np.convolve(r.standard_normal(n), np.ones(900) / 30, "same") + 0.9, 0, 1)
    pulses *= grip
    out = np.zeros(n)
    for f, q, g in modes:
        out += resonate(pulses, f * r.uniform(0.97, 1.03), q) * g
    env = np.clip(u / 0.12, 0, 1) * np.clip((1 - u) / 0.45, 0, 1) ** 1.3
    out *= env
    if clink:  # звяк цепи в мёртвой точке
        k = np.zeros(n)
        for t0 in (0.0, r.uniform(0.03, 0.06)):
            k[int(t0 * SR)] = r.uniform(0.5, 1.0)
        out += (resonate(k, 3900, 60) + resonate(k, 5600, 50) * 0.6) * 1.6
    out = out - lowpass(out, 0.02)  # убрать гул ниже ~150 Гц
    out = lowpass(lowpass(out, 0.45), 0.45)  # срезать «песок» выше ~5 кГц
    return out


for i in range(3):
    save("swing_fwd%d" % (i + 1), creak(40 + i, 0.42 + 0.05 * i, (300, 420 + 25 * i),
                                       ((1650, 38, 1.0), (2750, 34, 0.55), (4200, 30, 0.25)), i != 1))
    save("swing_back%d" % (i + 1), creak(50 + i, 0.48 + 0.04 * i, (190, 260 + 15 * i),
                                        ((1180, 34, 1.0), (2150, 30, 0.6), (3500, 28, 0.25)), i != 2))

# lighter: щелчок колёсика, искры, мягкое «пф» пламени
d = 0.9
t = np.arange(int(SR * d)) / SR
x = np.zeros(len(t))
for k, (t0, a) in enumerate(((0.02, 1.0), (0.055, 0.6), (0.09, 0.35))):
    i0 = int(t0 * SR)
    n = int(0.012 * SR)
    x[i0:i0 + n] += rng.standard_normal(n) * a * np.exp(-np.arange(n) / (0.002 * SR))
i0 = int(0.12 * SR)
fl = rng.standard_normal(len(t) - i0)
fl = lowpass(fl, 0.06)
tt = np.arange(len(fl)) / SR
x[i0:] += fl * 3.2 * np.minimum(1, tt / 0.04) * np.exp(-2.6 * tt)
save("lighter", x)

# pop: мультяшный «чпок» — птичка выскакивает вместо портрета
d = 0.22
t = np.arange(int(SR * d)) / SR
f = 380 + 900 * np.exp(-t / 0.03)
ph = 2 * np.pi * np.cumsum(f) / SR
save("pop", np.sin(ph) * np.exp(-t / 0.06) * np.minimum(1, t / 0.004))
print("ok")
