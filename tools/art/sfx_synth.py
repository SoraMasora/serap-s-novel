"""Синтез SFX для концовки «Обочина»: brake (визг шин + глухой удар), siren (двухтональная сирена скорой).
Запуск: python3 tools/art/sfx_synth.py → godot/art/sfx/{brake,siren}.ogg"""
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
print("ok")
