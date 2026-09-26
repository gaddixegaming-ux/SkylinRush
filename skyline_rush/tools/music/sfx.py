#!/usr/bin/env python3
"""Skyline Rush sound effects: renders res://sfx/*.ogg with the same synthesis
engine as the soundtrack (compose.py). Run: python3 tools/music/sfx.py"""
import os
import numpy as np
import soundfile as sf
from compose import (SR, ns, noise, sine, saw, square, lp, hp, bp, decay, env, kick, snare, crash, tom,
                     inst_bell, inst_marimba, inst_pluck, mix, mtof)

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "sfx")
rng = np.random.default_rng(3)


def sweep(f0, f1, dur, shape="sine", curve=2.0):
    n = ns(dur)
    t = np.linspace(0, 1, n)
    f = f0 + (f1 - f0) * t ** curve if f1 > f0 else f1 + (f0 - f1) * (1 - t) ** curve
    ph = np.cumsum(f) / SR
    if shape == "saw":
        return 2 * (ph % 1.0) - 1
    if shape == "square":
        return np.sign(np.sin(2 * np.pi * ph))
    return np.sin(2 * np.pi * ph)


def whoosh(dur, lo=300, hi=3000, rise=True):
    n = ns(dur)
    x = noise(dur)
    t = np.linspace(0, 1, n)
    shape = np.sin(np.pi * t) ** 1.5
    # moving band-pass via crossfade of three bands
    bands = [bp(x, lo, lo * 3), bp(x, lo * 2, hi * 0.6), bp(x, hi * 0.4, hi)]
    w = t if rise else 1 - t
    y = bands[0] * (1 - w) ** 2 + bands[1] * 2 * w * (1 - w) + bands[2] * w ** 2
    return y * shape


def pad(*xs):
    return mix(*xs)


def fade(x, ms=8):
    k = min(len(x), int(ms * SR / 1000))
    x = x.copy()
    x[-k:] *= np.linspace(1, 0, k)
    return x


def norm(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def coin():
    """Classic endless-runner coin: a quick two-note square 'bl-ING' (B5 -> E6)."""
    def note(f, dur, tau):
        n = ns(dur)
        x = square(f, dur, 0.5) * 0.55 + sine(f, dur) * 0.45
        return lp(x, 7000) * decay(n, tau) * env(n, 0.001, 0.01, 1.0, 0.01)
    a = note(987.77, 0.07, 0.2)
    b = note(1318.51, 0.38, 0.12)
    out = np.zeros(len(a) + len(b))
    out[:len(a)] += a
    out[len(a):] += b
    return out


def jump():
    return pad(whoosh(0.22, 400, 4000, True) * 0.5, sweep(220, 520, 0.12) * decay(ns(0.12), 0.05) * 0.6)


def djump():
    s = pad(whoosh(0.3, 600, 6000) * 0.4, sweep(400, 1200, 0.25, "square", 1.2) * decay(ns(0.25), 0.1) * 0.15)
    for k, m in enumerate([84, 88, 91]):
        b = np.zeros(ns(0.45))
        o = ns(0.04 * k)
        bb = inst_bell(mtof(m), 0.1)[:len(b) - o]
        b[o:o + len(bb)] = bb * 0.3
        s = pad(s, b)
    return s


def land():
    return pad(kick(0.5, 55, 0.25) * 0.8, lp(noise(0.15), 1200) * decay(ns(0.15), 0.03) * 0.5)


def slide():
    return pad(bp(noise(0.45), 800, 5000) * env(ns(0.45), 0.02, 0.1, 0.6, 0.2) * 0.5, whoosh(0.45, 200, 2000, False) * 0.4)


def dash():
    return pad(whoosh(0.5, 200, 5000, True) * 0.8, sweep(160, 50, 0.4) * decay(ns(0.4), 0.15) * 0.7)


def airdash():
    return pad(whoosh(0.35, 500, 7000, True) * 0.8, sweep(600, 1400, 0.2, "saw") * decay(ns(0.2), 0.06) * 0.12)


def crash_sfx():
    boom = kick(1.4, 40, 0.8) * 0.9
    debris = np.zeros(ns(1.2))
    for k in range(18):
        o = ns(rng.uniform(0, 0.6))
        d = bp(noise(0.08), rng.uniform(1500, 6000), 9000) * decay(ns(0.08), 0.015) * rng.uniform(0.1, 0.35)
        debris[o:o + len(d)] += d[:len(debris) - o]
    return pad(boom, debris, crash(1.2) * 0.35, lp(noise(0.5), 600) * decay(ns(0.5), 0.12) * 0.6)


def smash():
    crack = bp(noise(0.3), 300, 4000) * decay(ns(0.3), 0.04)
    wood = sum(sine(f, 0.3) * decay(ns(0.3), 0.05) for f in (180, 260, 410)) * 0.3
    return pad(crack, wood, kick(0.8, 60, 0.3) * 0.5)


def stumble():
    return pad(bp(noise(0.3), 300, 2000) * decay(ns(0.3), 0.06) * 0.7, tom(95, 0.3) * 0.5)


def close():
    return pad(whoosh(0.28, 800, 8000, True), sweep(900, 1700, 0.2) * decay(ns(0.2), 0.08) * 0.25)


def deny():
    x = pad(square(140, 0.14) * 0.3, square(147, 0.14) * 0.3)
    return lp(x, 1500) * env(ns(0.14), 0.005, 0.03, 0.7, 0.04)


def ready():
    return pad(inst_bell(mtof(91), 0.08)[:ns(0.3)] * 0.5, inst_bell(mtof(96), 0.12)[:ns(0.3)] * 0.3)


def click():
    return pad(bp(noise(0.03), 2000, 8000) * decay(ns(0.03), 0.004), sine(1800, 0.03) * decay(ns(0.03), 0.006) * 0.4)


def shield():
    return pad(sweep(200, 800, 0.5, "saw") * env(ns(0.5), 0.05, 0.2, 0.6, 0.2) * 0.15, inst_bell(mtof(79), 0.3)[:ns(0.6)] * 0.4,
               hp(noise(0.5), 5000) * env(ns(0.5), 0.1, 0.2, 0.3, 0.2) * 0.1)


def shield_break():
    shards = np.zeros(ns(0.9))
    for k in range(24):
        o = ns(rng.uniform(0, 0.25))
        d = sine(rng.uniform(2500, 7000), 0.3) * decay(ns(0.3), rng.uniform(0.03, 0.12)) * rng.uniform(0.1, 0.3)
        shards[o:o + len(d)] += d[:len(shards) - o]
    return pad(shards, hp(noise(0.4), 3000) * decay(ns(0.4), 0.06) * 0.5, kick(0.8, 70, 0.3) * 0.4)


def orb():
    s = np.zeros(ns(0.7))
    for k, m in enumerate([79, 83, 86, 91, 95]):
        o = ns(0.045 * k)
        b = inst_bell(mtof(m), 0.1)[:len(s) - o]
        s[o:o + len(b)] += b * (0.35 - k * 0.03)
    return pad(s, hp(noise(0.7), 7000) * env(ns(0.7), 0.05, 0.2, 0.4, 0.3) * 0.12)


def magnet():
    n = ns(0.6)
    t = np.arange(n) / SR
    x = sine(180, 0.6) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t)) + saw(90, 0.6) * 0.2
    return lp(x, 1800) * env(n, 0.05, 0.2, 0.7, 0.2)


def portal():
    return pad(whoosh(1.0, 150, 6000, True), sweep(120, 900, 1.0, "saw", 2.5) * env(ns(1.0), 0.3, 0.3, 0.6, 0.3) * 0.2,
               inst_bell(mtof(84), 0.4)[:ns(1.0)] * 0.2)


def warp():
    return pad(sweep(1200, 150, 0.9, "saw", 0.5) * env(ns(0.9), 0.02, 0.3, 0.6, 0.3) * 0.2, whoosh(0.9, 200, 3000, False) * 0.6)


def shock():
    return pad(kick(1.6, 38, 1.0), lp(noise(0.8), 900) * decay(ns(0.8), 0.2) * 0.6, crash(1.0) * 0.2)


def grapple():
    x = pad(sweep(2400, 600, 0.3, "saw", 0.6) * decay(ns(0.3), 0.1) * 0.25, hp(noise(0.3), 3000) * decay(ns(0.3), 0.05) * 0.4)
    return pad(x, sine(90, 0.2) * decay(ns(0.2), 0.04) * 0.6)


def wall():
    return pad(bp(noise(0.5), 400, 3500) * env(ns(0.5), 0.02, 0.1, 0.6, 0.2) * 0.5, whoosh(0.5, 300, 3000, True) * 0.4)


def overdrive():
    return pad(sweep(110, 880, 1.0, "saw", 1.5) * env(ns(1.0), 0.1, 0.3, 0.7, 0.3) * 0.25, orb() * 0.8)


def phase():
    return pad(sweep(300, 1600, 0.6, "sine", 0.7) * env(ns(0.6), 0.05, 0.2, 0.6, 0.2) * 0.4, whoosh(0.6, 500, 6000) * 0.4)


def hover():
    n = ns(0.6)
    t = np.arange(n) / SR
    x = saw(110, 0.6) * (1 + 0.3 * np.sin(2 * np.pi * 7 * t))
    return lp(x, 900) * env(n, 0.1, 0.2, 0.7, 0.2) * 0.5


def trick():
    """board flick: tail pop + wheel spin whir."""
    pop = pad(bp(noise(0.06), 800, 5000) * decay(ns(0.06), 0.01), sine(420, 0.06) * decay(ns(0.06), 0.015) * 0.6)
    whir = bp(noise(0.3), 1500, 4000) * env(ns(0.3), 0.02, 0.1, 0.5, 0.1) * 0.3
    return pad(pop, np.concatenate([np.zeros(ns(0.04)), whir]))


def grind():
    n = ns(0.35)
    t = np.arange(n) / SR
    metal = sum(np.sin(2 * np.pi * f * t) for f in (1320, 2210, 3150)) * 0.15
    return (metal + bp(noise(0.35), 2000, 8000) * 0.5) * env(n, 0.01, 0.1, 0.8, 0.1)


def engine():
    """vehicle mount: starter + rev."""
    n = ns(1.0)
    t = np.linspace(0, 1, n)
    f = 45 + 90 * np.sin(np.pi * np.clip(t * 1.4, 0, 1)) ** 2
    ph = np.cumsum(f) / SR
    x = np.sign(np.sin(2 * np.pi * ph)) * 0.4 + np.sin(2 * np.pi * ph * 2) * 0.4
    x = lp(np.tanh(x * 2), 1500) * env(n, 0.05, 0.2, 0.8, 0.3)
    return pad(x, whoosh(1.0, 200, 2000) * 0.2)


def powerdown():
    return sweep(900, 200, 0.5, "square", 0.8) * env(ns(0.5), 0.01, 0.2, 0.5, 0.2) * 0.2


def step():
    return pad(lp(noise(0.06), 1500) * decay(ns(0.06), 0.012) * 0.6, sine(90, 0.05) * decay(ns(0.05), 0.01) * 0.4)


SFX = {
    "coin": coin, "jump": jump, "djump": djump, "land": land, "slide": slide, "dash": dash, "airdash": airdash,
    "crash": crash_sfx, "smash": smash, "stumble": stumble, "close": close, "deny": deny, "ready": ready,
    "click": click, "shield": shield, "shield_break": shield_break, "orb": orb, "magnet": magnet,
    "portal": portal, "warp": warp, "shock": shock, "grapple": grapple, "wall": wall, "overdrive": overdrive,
    "phase": phase, "hover": hover, "trick": trick, "grind": grind, "engine": engine, "powerdown": powerdown,
    "step": step,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for name, fn in SFX.items():
        x = fade(norm(fn(), 0.85)).astype(np.float32)
        path = os.path.join(OUT, name + ".ogg")
        with sf.SoundFile(path, "w", SR, 1, format="OGG", subtype="VORBIS", compression_level=0.4) as f:
            for i in range(0, len(x), SR):
                f.write(x[i:i + SR])
        total += os.path.getsize(path)
    print("%d sfx, %.0f KB" % (len(SFX), total / 1024))


if __name__ == "__main__":
    main()
