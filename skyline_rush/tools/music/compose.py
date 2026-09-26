#!/usr/bin/env python3
"""Skyline Rush soundtrack generator.

Renders a menu song plus one song per track to res://music/*.ogg. Every song
is built on the SAME melody ("the Skyline theme") over the same Am-F-C-G
progression, re-arranged in its own style: lo-fi, synthwave, Chinese festival,
pop-punk, drum & bass, city-pop funk, tropical house, Japanese lo-fi,
chiptune circus and outrun electro-rock.

Everything is synthesised from scratch (no samples): band-limited oscillators,
FM, Karplus-Strong plucks, modal percussion, noise drums, convolution reverb,
delays, sidechain pumping and a mastering chain. Songs loop seamlessly (the
reverb/delay tails are wrapped back to the start).

    pip install numpy scipy soundfile
    python3 tools/music/compose.py            # all songs
    python3 tools/music/compose.py menu sky   # just some
"""
import os
import sys
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "music")
rng = np.random.default_rng(7)

# ---------------------------------------------------------------- the theme
# (start beat within the bar, length in beats, MIDI note). Key: A minor.
THEME = [
    [(0, 1, 76), (1, .5, 74), (1.5, .5, 72), (2, 1, 74), (3, 1, 76)],
    [(0, 1.5, 77), (1.5, .5, 76), (2, 2, 72)],
    [(0, 1, 79), (1, .5, 77), (1.5, .5, 76), (2, 1, 77), (3, 1, 79)],
    [(0, 1.5, 81), (1.5, .5, 79), (2, 1, 74), (3, 1, 71)],
    [(0, 1, 76), (1, .5, 74), (1.5, .5, 72), (2, 1, 74), (3, 1, 76)],
    [(0, 1, 77), (1, 1, 81), (2, 1, 79), (3, 1, 77)],
    [(0, 1, 76), (1, .5, 74), (1.5, .5, 72), (2, 1, 71), (3, 1, 72)],
    [(0, 1.5, 71), (1.5, .5, 72), (2, 1, 71), (3, 1, 68)],
]
# chords per bar (voicing around middle C) and bass roots
CHORDS = [[57, 60, 64], [57, 60, 65], [55, 60, 64], [55, 59, 62], [57, 60, 64], [57, 60, 65], [55, 60, 64], [56, 59, 64]]
ROOTS = [45, 41, 48, 43, 45, 41, 48, 40]
PENTA = [57, 60, 62, 64, 67]  # A minor pentatonic (A C D E G)


def mix(*xs):
    """Sum signals of different lengths."""
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[:len(x)] += x
    return out


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def to_penta(m):
    pc = [p % 12 for p in PENTA]
    best = min(range(-2, 3), key=lambda d: (0 if (m + d) % 12 in pc else 9) + abs(d) * 0.1)
    return m + best


# ---------------------------------------------------------------- oscillators
def ns(dur):
    """Sample count for a duration (one rounding rule everywhere)."""
    return int(round(dur * SR))


def t_axis(dur):
    return np.arange(ns(dur)) / SR


def _blep(ph, dt):
    dt = np.broadcast_to(dt, ph.shape)
    out = np.zeros_like(ph)
    a = ph < dt
    x = ph[a] / dt[a]
    out[a] = x + x - x * x - 1.0
    b = ph > 1.0 - dt
    x = (ph[b] - 1.0) / dt[b]
    out[b] = x * x + x + x + 1.0
    return out


def saw(f, dur, phase=0.0, vib=0.0, vib_rate=5.5):
    t = t_axis(dur)
    fr = f * (1.0 + vib * np.sin(2 * np.pi * vib_rate * t)) if vib else np.full_like(t, f)
    ph = (np.cumsum(fr) / SR + phase) % 1.0
    dt = fr / SR
    return 2.0 * ph - 1.0 - _blep(ph, dt)


def square(f, dur, duty=0.5, vib=0.0):
    a = saw(f, dur, 0.0, vib)
    b = saw(f, dur, duty, vib)
    return (a - b) * 0.5


def tri(f, dur):
    t = t_axis(dur)
    return 2.0 * np.abs(2.0 * ((f * t) % 1.0) - 1.0) - 1.0


def sine(f, dur, vib=0.0, vib_rate=5.0):
    t = t_axis(dur)
    if vib:
        ph = np.cumsum(f * (1.0 + vib * np.sin(2 * np.pi * vib_rate * t))) / SR
        return np.sin(2 * np.pi * ph)
    return np.sin(2 * np.pi * f * t)


def noise(dur):
    return rng.uniform(-1, 1, ns(dur))


def env(n, a=0.005, d=0.1, s=0.7, r=0.1, gate=None):
    """ADSR over n samples; gate = seconds before release (default n - r)."""
    a_n = max(1, min(int(a * SR), n // 3 + 1))
    d_n = max(1, int(d * SR))
    r_n = max(1, min(int(r * SR), n // 2 + 1))
    g_n = n - r_n if gate is None else min(n, int(gate * SR))
    g_n = max(0, g_n)
    e = np.full(n, s, dtype=np.float64)
    e[:min(a_n, n)] = np.linspace(0, 1, a_n)[:min(a_n, n)]
    if a_n < n:
        seg = e[a_n:a_n + d_n]
        e[a_n:a_n + d_n] = np.linspace(1, s, d_n)[:len(seg)]
    if g_n < n:
        e[g_n:] = np.linspace(e[max(g_n - 1, 0)], 0, n - g_n)
    return e


def decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def lp(x, fc, order=2):
    fc = min(fc, SR * 0.45)
    sos = signal.butter(order, fc, "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def hp(x, fc, order=2):
    sos = signal.butter(order, fc, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def filter_env(x, lo, hi, e):
    """Cheap filter envelope: crossfade a dark and a bright copy."""
    return lp(x, lo) * (1 - e) + lp(x, hi) * e


# ---------------------------------------------------------------- instruments
def inst_supersaw(f, dur, bright=4000):
    n = ns(dur)
    x = sum(saw(f * (1 + d), dur, rng.random()) for d in (-0.012, -0.006, 0, 0.006, 0.012)) / 3.0
    return lp(x, bright) * env(n, 0.02, 0.3, 0.8, 0.25)


def inst_pad(f, dur, bright=1800):
    n = ns(dur)
    x = sum(saw(f * (1 + d), dur, rng.random()) for d in (-0.008, 0, 0.008)) / 2.5
    x = x + 0.3 * sine(f / 2, dur)
    return lp(x, bright) * env(n, 0.35, 0.5, 0.85, 0.6)


def inst_lead(f, dur, bright=5000, vib=0.004):
    n = ns(dur)
    x = saw(f, dur, 0, vib) * 0.6 + square(f * 1.003, dur, 0.5, vib) * 0.4
    e = env(n, 0.01, 0.15, 0.75, 0.12)
    return filter_env(x, 900, bright, decay(n, 0.25) * 0.7 + 0.3) * e


def inst_epiano(f, dur):
    """FM Rhodes-like electric piano."""
    n = int(dur + 1.2) * 0 + int((dur + 0.8) * SR)
    t = np.arange(n) / SR
    idx = 1.8 * decay(n, 0.35) + 0.25
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t))
    x += 0.25 * np.sin(2 * np.pi * f * 14 * t) * decay(n, 0.02)  # tine
    return x * decay(n, 1.4) * env(n, 0.002, 0.05, 1.0, 0.25, gate=dur + 0.2)


def inst_piano(f, dur):
    n = int((dur + 1.5) * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(1, 9):
        fk = f * k * np.sqrt(1 + 0.0004 * k * k)
        if fk > SR * 0.45:
            break
        x += np.sin(2 * np.pi * fk * t + rng.random()) * decay(n, 2.2 / k ** 0.7) / k ** 1.1
    x += 0.2 * lp(noise(n / SR), 3000) * decay(n, 0.01)
    return x * env(n, 0.002, 0.05, 1.0, 0.3, gate=dur + 0.4) * 0.6


def inst_pluck(f, dur, bright=0.5, damp=0.996, body=None):
    """Karplus-Strong string (guitar / guzheng / koto)."""
    n = int((dur + 0.8) * SR)
    p = max(2, int(SR / f))
    exc = lp(noise(p / SR + 0.001)[:p], 2000 + bright * 9000)
    x = np.zeros(n)
    x[:p] = exc
    a = np.zeros(p + 2)
    a[0] = 1.0
    a[p] = -damp * 0.5
    a[p + 1] = -damp * 0.5
    y = signal.lfilter([1.0], a, x)
    y = y / (np.max(np.abs(y)) + 1e-9)
    if body:
        y = y + 0.4 * bp(y, body * 0.7, body * 1.4)
    return y * env(n, 0.001, 0.05, 1.0, 0.15, gate=dur + 0.3)


def inst_marimba(f, dur):
    n = int((dur + 0.6) * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * decay(n, 0.45)
    x += 0.35 * np.sin(2 * np.pi * f * 3.93 * t) * decay(n, 0.08)
    x += 0.12 * np.sin(2 * np.pi * f * 9.2 * t) * decay(n, 0.03)
    return x * env(n, 0.001, 0.02, 1.0, 0.05)


def inst_steelpan(f, dur):
    n = int((dur + 0.8) * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k, (r, a, tau) in enumerate([(1, 1, .7), (2, .5, .5), (3.01, .3, .3), (4.02, .18, .2), (5.1, .08, .1)]):
        x += a * np.sin(2 * np.pi * f * r * t) * decay(n, tau)
    return x * env(n, 0.003, 0.05, 1.0, 0.1) * 0.6


def inst_flute(f, dur, vib=0.006):
    n = ns(dur)
    x = sine(f, dur, vib, 5.2) + 0.15 * sine(2 * f, dur, vib, 5.2) + 0.05 * sine(3 * f, dur)
    breath = bp(noise(dur), f * 0.8, f * 3.0) * 0.35
    return (x + breath) * env(n, 0.06, 0.1, 0.85, 0.1)


def inst_erhu(f, dur):
    n = ns(dur)
    x = saw(f, dur, 0, 0.012, 6.0)
    x = bp(x, f * 0.9, f * 6) + 0.3 * bp(x, 900, 1600)
    return x * env(n, 0.08, 0.1, 0.9, 0.12) * 0.8


def inst_guitar_dist(freqs, dur, palm=False):
    """Distorted power chord (root, fifth, octave)."""
    n = int((dur + 0.2) * SR)
    x = np.zeros(n)
    for f in freqs:
        s = inst_pluck(f, dur, 0.9, 0.998)[:n]
        x[:len(s)] += s
    x = np.tanh(x * (6 if not palm else 4))
    x = lp(hp(x, 90), 3800 if not palm else 1600)
    e = env(n, 0.002, 0.1, 0.9, 0.05, gate=dur) * (decay(n, 0.12) if palm else 1.0)
    return x * e * 0.5


def inst_bass(f, dur, kind="synth"):
    n = ns(dur)
    if kind == "sub":
        x = sine(f, dur) + 0.2 * sine(2 * f, dur)
        return x * env(n, 0.005, 0.1, 0.9, 0.05)
    if kind == "slap":
        x = inst_pluck(f, dur, 0.95, 0.994)[:n]
        x = np.tanh(x * 2.0) + 0.6 * sine(f, dur)[:len(x)] * decay(len(x), 0.4)
        return x * env(len(x), 0.001, 0.05, 1.0, 0.05)
    if kind == "reese":
        x = saw(f, dur, 0) + saw(f * 1.01, dur, 0.3)
        x = lp(x, 700) + 0.6 * sine(f, dur)
        return np.tanh(x * 1.3) * env(n, 0.01, 0.1, 0.9, 0.05)
    if kind == "tri":
        return tri(f, dur) * env(n, 0.002, 0.05, 0.9, 0.02)
    x = saw(f, dur) * 0.7 + sine(f, dur) * 0.6
    return filter_env(x, 300, 2200, decay(n, 0.12)) * env(n, 0.003, 0.1, 0.8, 0.05)


def inst_brass(f, dur):
    n = ns(dur)
    x = saw(f, dur, 0, 0.003) + saw(f * 1.004, dur, 0.5, 0.003)
    return filter_env(x, 700, 4000, env(n, 0.05, 0.2, 0.6, 0.1)) * env(n, 0.03, 0.1, 0.85, 0.08) * 0.5


def inst_chip(f, dur, duty=0.25):
    n = ns(dur)
    return square(f, dur, duty, 0.004) * env(n, 0.002, 0.05, 0.8, 0.03) * 0.7


def inst_bell(f, dur):
    n = int((dur + 1.0) * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t + 2.5 * decay(n, 0.6) * np.sin(2 * np.pi * f * 3.5 * t))
    return x * decay(n, 1.1) * env(n, 0.001, 0.02, 1.0, 0.1)


# ---------------------------------------------------------------- drums
def kick(punch=1.0, tone=50.0, length=0.45):
    n = ns(length)
    t = np.arange(n) / SR
    f = tone + 110 * np.exp(-t * 30) * punch
    ph = np.cumsum(f) / SR
    x = np.sin(2 * np.pi * ph) * decay(n, 0.16 * length / 0.45)
    x += 0.4 * lp(noise(length), 4000) * decay(n, 0.004)
    return np.tanh(x * 1.6)


def snare(tone=190, length=0.3, snap=1.0):
    n = ns(length)
    body = sine(tone, length) * decay(n, 0.05)
    nz = bp(noise(length), 1200, 6500) * decay(n, 0.09 * snap)
    return (body * 0.9 + nz * 0.8) * 0.8


def clap():
    n = int(0.35 * SR)
    x = np.zeros(n)
    for k in range(3):
        o = int(k * 0.011 * SR)
        m = n - o
        x[o:] += bp(noise(m / SR), 900, 3500)[:m] * decay(m, 0.012 if k < 2 else 0.12)
    return x * 0.8


def hat(open_=False):
    length = 0.35 if open_ else 0.06
    n = ns(length)
    t = np.arange(n) / SR
    metal = sum(np.sign(np.sin(2 * np.pi * f * t)) for f in (205, 304, 369, 522, 540, 800))
    x = lp(hp(metal * 0.3 + noise(length), 6500), 11000) * decay(n, 0.12 if open_ else 0.015)
    return x * 0.2


def crash(length=2.0):
    n = ns(length)
    t = np.arange(n) / SR
    metal = sum(np.sign(np.sin(2 * np.pi * f * t)) for f in (263, 347, 431, 588, 791, 1063))
    return lp(hp(metal * 0.2 + noise(length), 3500), 10000) * decay(n, 0.6) * 0.3


def tom(f=110, length=0.5):
    n = ns(length)
    t = np.arange(n) / SR
    fr = f * (1 + 0.5 * np.exp(-t * 25))
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * decay(n, 0.18) * 0.9


def taiko():
    x = tom(62, 0.9) * 1.3 + lp(noise(0.9), 400) * decay(int(0.9 * SR), 0.05) * 0.6
    return np.tanh(x * 1.2)


def gong(length=4.0):
    n = ns(length)
    t = np.arange(n) / SR
    x = sum(a * np.sin(2 * np.pi * f * t + 3 * np.sin(2 * np.pi * 0.7 * t)) * decay(n, tau)
            for f, a, tau in [(98, 1, 2.5), (151, .7, 2.0), (220, .5, 1.5), (311, .35, 1.2), (467, .25, .8)])
    return x * env(n, 0.03, 0.2, 1.0, 0.5) * 0.35


def woodblock(f=900):
    n = int(0.12 * SR)
    return bp(noise(0.12), f * 0.8, f * 1.3) * decay(n, 0.02) * 2 + sine(f, 0.12) * decay(n, 0.03)


def shaker():
    n = int(0.08 * SR)
    return lp(hp(noise(0.08), 5000), 10000) * env(n, 0.02, 0.02, 0.4, 0.03) * 0.2


def chip_noise(length=0.1, hi=True):
    n = ns(length)
    x = np.repeat(rng.choice([-1.0, 1.0], n // 8 + 1), 8)[:n]
    return (hp(x, 3000) if hi else lp(x, 2500)) * decay(n, length * 0.3) * 0.6


def snap():
    n = int(0.1 * SR)
    return bp(noise(0.1), 1800, 6000) * decay(n, 0.012) * 1.2


def vinyl(dur):
    n = ns(dur)
    x = lp(noise(dur), 3000) * 0.015
    pops = (rng.random(n) > 0.9997) * rng.uniform(-0.4, 0.4, n)
    return x + lp(pops, 5000)


# ---------------------------------------------------------------- mixing
class Song:
    def __init__(self, bpm, bars, tail=3.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.length = bars * 4 * self.beat
        self.n = int(self.length * SR)
        self.tail = int(tail * SR)
        self.buses = {}
        self.kick_times = []

    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = np.zeros((self.n + self.tail + SR * 2, 2))
        return self.buses[name]

    def add(self, name, beat_pos, x, gain=1.0, pan=0.0, humanize=0.004):
        s = int((beat_pos * self.beat + rng.normal(0, humanize)) * SR)
        s = max(0, s)
        b = self.bus(name)
        e = min(len(b), s + len(x))
        if e <= s:
            return
        l = np.cos((pan + 1) * np.pi / 4) * gain
        r = np.sin((pan + 1) * np.pi / 4) * gain
        b[s:e, 0] += x[:e - s] * l
        b[s:e, 1] += x[:e - s] * r

    def mixdown(self, fx):
        total = np.zeros((self.n + self.tail + SR * 2, 2))
        for name, b in self.buses.items():
            cfg = fx.get(name, {})
            y = b
            if cfg.get("pump"):
                y = y * self._pump(cfg["pump"])[:, None]
            if cfg.get("delay"):
                y = self._delay(y, *cfg["delay"])
            if cfg.get("reverb"):
                y = y + self._reverb(y, *cfg["reverb"])
            total += y * cfg.get("gain", 1.0)
        # wrap the tail to the start so the loop is seamless
        out = total[:self.n].copy()
        rest = total[self.n:self.n + self.tail]
        out[:len(rest)] += rest
        return self._master(out)

    def _pump(self, depth):
        g = np.ones(self.n + self.tail + SR * 2)
        rel = int(self.beat * 0.9 * SR)
        shape = 1 - depth * np.exp(-np.arange(rel) / (rel * 0.28))
        for kt in self.kick_times:
            s = int(kt * self.beat * SR)
            for k in (s, s + self.n):
                e = min(len(g), k + rel)
                if k < len(g):
                    g[k:e] = np.minimum(g[k:e], shape[:e - k])
        return g

    def _delay(self, y, beats, fb, mix):
        d = int(beats * self.beat * SR)
        out = y.copy()
        tap = y.copy()
        for k in range(1, 6):
            tap = tap * fb
            tap = np.column_stack([lp(tap[:, 0], 5000), lp(tap[:, 1], 5000)])
            sh = d * k
            if sh >= len(y):
                break
            ch = k % 2  # ping-pong
            out[sh:, ch] += tap[:len(y) - sh, 0 if ch == 0 else 1] * mix
        return out

    def _reverb(self, y, size, mix):
        n = int(size * SR)
        irs = []
        for ch in range(2):
            ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / (size * SR / 6.5))
            ir = lp(ir, 7000)
            ir[:int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
            irs.append(ir / np.sqrt(np.sum(ir ** 2)))
        wet = np.column_stack([signal.fftconvolve(y[:, c], irs[c])[:len(y)] for c in range(2)])
        return wet * mix

    def _master(self, x):
        x = x - np.mean(x, axis=0)
        # gentle top-end roll-off + a touch of low-mid warmth
        x = np.column_stack([lp(x[:, c], 13000, 1) * 0.85 + lp(x[:, c], 3000, 1) * 0.25 for c in range(2)])
        # gentle glue compression (RMS envelope follower, vectorised)
        rms = np.sqrt(np.maximum(lp(np.mean(x ** 2, axis=1), 8), 0.0) + 1e-9)
        thr = np.percentile(rms, 70)
        gain = np.where(rms > thr, (thr / rms) ** 0.35, 1.0)
        x = x * gain[:, None]
        x = x / (np.max(np.abs(x)) + 1e-9) * 1.25
        x = np.tanh(x) / np.tanh(1.25)
        return (x * 0.93).astype(np.float32)


# ---------------------------------------------------------------- arrangement helpers
def melody(song, bus, inst, bars, start_bar, gain, pan=0.0, octave=0, transform=None, half=False, swing=0.0):
    for bi in range(bars):
        notes = THEME[bi % 8]
        for (b, d, m) in notes:
            m = m + 12 * octave
            if transform:
                m = transform(m)
            beat = (start_bar + bi) * 4 + b
            dur = d * song.beat
            if half:
                beat = (start_bar + bi * 2) * 4 + b * 2
                dur *= 2
            if swing and (b * 2) % 2 == 1:
                beat += swing
            song.add(bus, beat, inst(mtof(m), dur * 0.95), gain * rng.uniform(0.9, 1.0), pan)


def chords(song, bus, inst, bars, start_bar, gain, rhythm=((0, 4),), octave=0, spread=0.3, transform=None):
    for bi in range(bars):
        ch = CHORDS[bi % 8]
        for (b, d) in rhythm:
            for i, m in enumerate(ch):
                m = m + 12 * octave
                if transform:
                    m = transform(m)
                song.add(bus, (start_bar + bi) * 4 + b, inst(mtof(m), d * song.beat), gain / len(ch) * 1.6, (i - 1) * spread)


def bassline(song, bus, kind, bars, start_bar, gain, pattern=((0, 1), (1, 1), (2, 1), (3, 1)), octave=0):
    for bi in range(bars):
        r = ROOTS[bi % 8] + 12 * octave
        for (b, d, *iv) in pattern:
            m = r + (iv[0] if iv else 0)
            song.add(bus, (start_bar + bi) * 4 + b, inst_bass(mtof(m), d * song.beat * 0.95, kind), gain)


def arp(song, bus, inst, bars, start_bar, gain, step=0.25, octave=1, pattern=(0, 1, 2, 1), pan=0.0):
    for bi in range(bars):
        ch = CHORDS[bi % 8]
        k = 0
        b = 0.0
        while b < 4:
            m = ch[pattern[k % len(pattern)]] + 12 * octave
            song.add(bus, (start_bar + bi) * 4 + b, inst(mtof(m), step * song.beat), gain, pan + 0.3 * np.sin(k))
            b += step
            k += 1


def drums(song, bars, start_bar, pat, kit, gain=1.0, fill=True):
    """pat: dict of voice -> 16-step string ('x' hit, 'o' accent / open)."""
    for bi in range(bars):
        bar = start_bar + bi
        last = fill and (bi == bars - 1)
        for voice, steps in pat.items():
            if last and voice in ("snare", "clap") and "fill" in kit:
                continue
            for i, ch in enumerate(steps):
                if ch == ".":
                    continue
                beat = bar * 4 + i * 0.25
                if voice == "kick":
                    song.kick_times.append(beat)
                v = 1.0 if ch == "x" else (1.25 if ch == "X" else 0.8)
                smp = kit[voice](ch)
                song.add(kit.get("_bus", {}).get(voice, "drums"), beat, smp, gain * v * rng.uniform(0.88, 1.0),
                         kit.get("_pan", {}).get(voice, 0.0), 0.002)
        if last and "fill" in kit:
            for i in range(8):
                song.add("drums", bar * 4 + 2 + i * 0.25, kit["fill"](i), gain * (0.7 + i * 0.05), -0.4 + i * 0.1, 0.002)


def standard_kit(**kw):
    kit = {
        "kick": lambda c: kick(**kw.get("kick", {})),
        "snare": lambda c: snare(**kw.get("snare", {})),
        "clap": lambda c: clap(),
        "hat": lambda c: hat(c == "o"),
        "crash": lambda c: crash(),
        "shaker": lambda c: shaker(),
        "snap": lambda c: snap(),
        "_pan": {"hat": 0.25, "shaker": -0.3},
    }
    kit["fill"] = lambda i: tom(160 - i * 12)
    return kit


# ---------------------------------------------------------------- the songs
def song_menu():
    """'Skyline Dreams' - warm lo-fi: Rhodes, soft piano theme, boom-bap."""
    s = Song(88, 16)
    chords(s, "keys", inst_epiano, 16, 0, 0.5, rhythm=((0, 1.5), (1.75, 2.25)))
    melody(s, "lead", inst_piano, 8, 4, 0.55, pan=0.1)
    melody(s, "lead", inst_bell, 4, 12, 0.25, pan=-0.2, octave=1)
    bassline(s, "bass", "sub", 16, 0, 0.55, pattern=((0, 1.5), (1.75, 0.75), (2.5, 1.5)))
    kit = standard_kit(kick={"punch": 0.6, "tone": 48}, snare={"tone": 210, "snap": 0.6})
    drums(s, 4, 0, {"hat": "x.x.x.x.x.x.x.xo"}, kit, 0.6, fill=False)
    drums(s, 12, 4, {"kick": "x.....x...x.....", "snare": "....x.......x...", "hat": "x.xxx.x.x.xxx.x."}, kit, 0.8)
    s.add("amb", 0, vinyl(s.length), 1.0)
    s.buses["drums"] = np.column_stack([lp(s.buses["drums"][:, c], 5000) for c in range(2)])
    return s, {"keys": {"reverb": (2.2, 0.35)}, "lead": {"reverb": (2.5, 0.4), "delay": (0.75, 0.35, 0.3)},
               "drums": {"gain": 0.9, "reverb": (0.8, 0.12)}, "bass": {"gain": 1.0}, "amb": {"gain": 1.0}}


def song_sky():
    """Sky Roads - synthwave: supersaw pads, 16th arps, gated snare."""
    s = Song(118, 28)
    chords(s, "pad", inst_pad, 28, 0, 0.45)
    arp(s, "arp", lambda f, d: mix(inst_pluck(f, d, 0.7) * 0.7, inst_lead(f, d, 6000) * 0.3), 24, 4, 0.22, 0.25, 1, (0, 1, 2, 1))
    melody(s, "lead", inst_lead, 8, 4, 0.5)
    melody(s, "lead", lambda f, d: inst_supersaw(f, d, 6000), 8, 12, 0.45, octave=0)
    melody(s, "lead", inst_lead, 8, 20, 0.5, octave=1)
    bassline(s, "bass", "synth", 24, 4, 0.5, pattern=tuple((i * 0.5, 0.45) for i in range(8)))
    kit = standard_kit(kick={"punch": 1.0}, snare={"tone": 180, "length": 0.5, "snap": 1.4})
    drums(s, 4, 0, {"kick": "x...x...x...x...", "hat": "..x...x...x...x."}, kit, 0.8)
    drums(s, 24, 4, {"kick": "x...x...x...x...", "snare": "....X.......X...", "hat": "..x...x...x...xo", "crash": "x..............." if False else "................"}, kit, 0.95)
    for b in (4, 12, 20):
        s.add("drums", b * 4, crash(), 0.7)
    return s, {"pad": {"reverb": (3.0, 0.4), "pump": 0.35}, "arp": {"delay": (0.75, 0.4, 0.35), "reverb": (2.0, 0.25), "pump": 0.3},
               "lead": {"reverb": (2.5, 0.35), "delay": (0.5, 0.3, 0.25)}, "bass": {"pump": 0.4}, "drums": {"reverb": (1.2, 0.3)}}


def song_festival():
    """Lantern Festival - guzheng, erhu, dizi, taiko, woodblock, gong."""
    s = Song(124, 24)
    P = to_penta
    melody(s, "lead", lambda f, d: inst_pluck(f, d, 0.8, 0.997, 700), 8, 4, 0.6, transform=P, pan=-0.15)
    melody(s, "lead2", inst_erhu, 8, 12, 0.45, transform=P, pan=0.15)
    melody(s, "lead", lambda f, d: inst_flute(f, d), 4, 20, 0.45, octave=1, transform=P)
    arp(s, "arp", lambda f, d: inst_pluck(f, d, 0.6, 0.995), 20, 4, 0.2, 0.5, 0, (0, 2, 1, 2), pan=0.3)
    chords(s, "pad", lambda f, d: inst_pad(f, d, 1200), 24, 0, 0.3, transform=P)
    bassline(s, "bass", "sub", 20, 4, 0.45, pattern=((0, 1.5), (1.5, 0.5), (2, 2)))
    kit = {"kick": lambda c: taiko(), "snare": lambda c: woodblock(1100 if c == "x" else 700),
           "hat": lambda c: hat(False) * 0.6, "shaker": lambda c: shaker(), "crash": lambda c: crash(),
           "fill": lambda i: taiko() * (0.6 + i * 0.05)}
    drums(s, 4, 0, {"kick": "x.......x.x.....", "snare": "..x...x...x...x."}, kit, 0.8)
    drums(s, 20, 4, {"kick": "x..x..x.x.......", "snare": "..x..x.xx.x..x.x", "shaker": "xxxxxxxxxxxxxxxx"}, kit, 0.85)
    for b in (0, 4, 12, 20):
        s.add("fx", b * 4, gong(), 0.9)
    return s, {"lead": {"reverb": (2.2, 0.35)}, "lead2": {"reverb": (2.5, 0.35)}, "arp": {"delay": (0.75, 0.3, 0.25)},
               "pad": {"reverb": (3.0, 0.4)}, "drums": {"reverb": (1.5, 0.25)}, "fx": {"reverb": (3.0, 0.3)}, "bass": {}}


def song_skate():
    """Skate Park - pop-punk: power chords, punchy drums, lead guitar theme (half time)."""
    s = Song(168, 32)
    for bi in range(28):
        r = ROOTS[bi % 8] + 12
        freqs = [mtof(r), mtof(r + 7), mtof(r + 12)]
        for k in range(8):
            palm = bi < 4 or (bi >= 20 and bi < 24)
            s.add("gtr_l", (4 + bi) * 4 + k * 0.5 if bi >= 4 else bi * 4 + k * 0.5, inst_guitar_dist(freqs, 0.5 * s.beat, palm), 0.35, -0.6)
            s.add("gtr_r", (4 + bi) * 4 + k * 0.5 if bi >= 4 else bi * 4 + k * 0.5, inst_guitar_dist([f * 1.002 for f in freqs], 0.5 * s.beat, palm), 0.35, 0.6)
    lead = lambda f, d: lp(np.tanh(inst_lead(f, d, 5000, 0.006) * 4), 4500) * 0.5
    melody(s, "lead", lead, 8, 4, 0.55, half=True)
    melody(s, "lead", lead, 8, 20, 0.55, half=True, octave=1)
    bassline(s, "bass", "slap", 32, 0, 0.45, pattern=tuple((i * 0.5, 0.45) for i in range(8)), octave=0)
    kit = standard_kit(kick={"punch": 1.2, "tone": 55, "length": 0.3}, snare={"tone": 200, "snap": 1.2})
    drums(s, 4, 0, {"kick": "x.......x.......", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x."}, kit, 0.9)
    drums(s, 28, 4, {"kick": "x.x...x.x.x...x.", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."}, kit, 1.0)
    for b in (4, 12, 20, 28):
        s.add("drums", b * 4, crash(), 0.8)
    return s, {"gtr_l": {"reverb": (0.8, 0.15)}, "gtr_r": {"reverb": (0.8, 0.15)}, "lead": {"reverb": (1.5, 0.3), "delay": (0.5, 0.25, 0.2)},
               "bass": {}, "drums": {"reverb": (0.9, 0.2)}}


def song_rain():
    """Neon Rain Alley - drum & bass: breakbeats, reese bass, glassy bells, rain."""
    s = Song(174, 32)
    chords(s, "pad", lambda f, d: inst_pad(f, d, 1100), 32, 0, 0.4)
    melody(s, "lead", inst_bell, 8, 8, 0.4, half=True, pan=0.2)
    melody(s, "lead", lambda f, d: inst_flute(f, d, 0.004), 8, 24, 0.35, half=True, octave=1)
    for bi in range(24):
        r = ROOTS[(bi // 2) % 8]
        s.add("bass", (8 + bi) * 4, inst_bass(mtof(r), 2.5 * s.beat, "reese"), 0.5)
        s.add("bass", (8 + bi) * 4 + 2.75, inst_bass(mtof(r + 12 if bi % 2 else r), 1.0 * s.beat, "reese"), 0.4)
    kit = standard_kit(kick={"punch": 1.1, "tone": 52, "length": 0.35}, snare={"tone": 220, "snap": 1.1})
    drums(s, 8, 0, {"hat": "x.x.x.x.x.x.x.xo", "shaker": "xxxxxxxxxxxxxxxx"}, kit, 0.6, fill=False)
    drums(s, 24, 8, {"kick": "x.........x.....", "snare": "....x..x.x..x...", "hat": "x.xxx.xxx.xxx.xo"}, kit, 1.0)
    rain = lp(hp(noise(s.length), 1200), 7000) * 0.05
    s.add("amb", 0, rain, 1.0)
    return s, {"pad": {"reverb": (3.5, 0.45)}, "lead": {"reverb": (3.0, 0.45), "delay": (0.75, 0.45, 0.35)},
               "bass": {"gain": 0.9}, "drums": {"reverb": (1.0, 0.18)}, "amb": {}}


def song_market():
    """Neon Market - city-pop funk: slap bass, Rhodes, clav stabs, brass theme."""
    s = Song(112, 24)
    chords(s, "keys", inst_epiano, 24, 0, 0.45, rhythm=((0, 0.5), (0.75, 0.5), (2, 0.5), (2.75, 1.0)))
    clav = lambda f, d: lp(square(f, d, 0.2) * decay(int(d * SR), 0.08), 3500) * 0.7
    chords(s, "clav", clav, 20, 4, 0.3, rhythm=((0.5, 0.25), (1.5, 0.25), (2.5, 0.25), (3.5, 0.25)), octave=1)
    melody(s, "lead", inst_brass, 8, 4, 0.55)
    melody(s, "lead", lambda f, d: inst_lead(f, d, 4000, 0.005), 8, 12, 0.5, octave=1)
    melody(s, "lead", inst_brass, 4, 20, 0.55)
    bassline(s, "bass", "slap", 24, 0, 0.55, pattern=((0, .5), (.75, .25, 12), (1.5, .5), (2, .25, 7), (2.5, .5, 12), (3.25, .5)))
    kit = standard_kit(kick={"punch": 0.9}, snare={"tone": 200})
    drums(s, 4, 0, {"kick": "x...x...x...x...", "hat": "x.x.x.x.x.x.x.x."}, kit, 0.8)
    drums(s, 20, 4, {"kick": "x...x...x...x...", "snare": "....x.......x...", "clap": "....x.......x...", "hat": "xxoxxxoxxxoxxxox"}, kit, 0.9)
    return s, {"keys": {"reverb": (2.0, 0.3)}, "clav": {"delay": (0.25, 0.2, 0.15)}, "lead": {"reverb": (2.0, 0.3)},
               "bass": {}, "drums": {"reverb": (1.0, 0.18)}}


def song_harbor():
    """Hover Harbor - tropical house: steel pan theme, marimba, pumping pads."""
    s = Song(104, 24)
    chords(s, "pad", inst_pad, 24, 0, 0.4)
    chords(s, "pluck", lambda f, d: inst_pluck(f, d, 0.5, 0.993), 20, 4, 0.35, rhythm=tuple((0.5 + i, 0.4) for i in range(4)), octave=1)
    melody(s, "lead", inst_steelpan, 8, 4, 0.6)
    melody(s, "lead", inst_marimba, 8, 12, 0.6, octave=1)
    melody(s, "lead", inst_steelpan, 4, 20, 0.6, octave=1)
    bassline(s, "bass", "sub", 20, 4, 0.55, pattern=((0, 0.75), (1.5, 0.5), (2, 0.75), (3.5, 0.5)))
    kit = standard_kit(kick={"punch": 0.9, "tone": 48})
    drums(s, 4, 0, {"shaker": "x.x.x.x.x.x.x.x.", "snap": "....x.......x..."}, kit, 0.7, fill=False)
    drums(s, 20, 4, {"kick": "x...x...x...x...", "snap": "....x.......x...", "hat": "..x...x...x...x.", "shaker": "xxxxxxxxxxxxxxxx"}, kit, 0.9)
    return s, {"pad": {"reverb": (3.0, 0.4), "pump": 0.55}, "pluck": {"pump": 0.5, "delay": (0.75, 0.35, 0.3)},
               "lead": {"reverb": (2.2, 0.35), "delay": (0.5, 0.3, 0.25)}, "bass": {"pump": 0.35}, "drums": {"reverb": (1.0, 0.2)}}


def song_sakura():
    """Sakura Heights - Japanese lo-fi: koto theme, shakuhachi, soft piano, lazy beat."""
    s = Song(84, 16)
    P = to_penta
    chords(s, "keys", inst_piano, 16, 0, 0.4, rhythm=((0, 2), (2, 2)))
    melody(s, "lead", lambda f, d: inst_pluck(f, d, 0.6, 0.9975, 500), 8, 4, 0.6, transform=P, pan=-0.1)
    melody(s, "lead2", lambda f, d: inst_flute(f, d, 0.01), 4, 12, 0.45, transform=P, pan=0.15)
    bassline(s, "bass", "sub", 16, 0, 0.5, pattern=((0, 1.5), (2.5, 1.5)))
    kit = standard_kit(kick={"punch": 0.5, "tone": 46}, snare={"tone": 230, "snap": 0.5})
    drums(s, 4, 0, {"hat": "x...x...x...x..."}, kit, 0.5, fill=False)
    drums(s, 12, 4, {"kick": "x......x..x.....", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x."}, kit, 0.7)
    s.add("amb", 0, vinyl(s.length), 0.8)
    s.buses["drums"] = np.column_stack([lp(s.buses["drums"][:, c], 5500) for c in range(2)])
    return s, {"keys": {"reverb": (2.5, 0.4)}, "lead": {"reverb": (2.8, 0.4), "delay": (0.75, 0.3, 0.25)},
               "lead2": {"reverb": (3.0, 0.45)}, "bass": {}, "drums": {"reverb": (0.9, 0.15)}, "amb": {}}


def song_carnival():
    """Candy Carnival - chiptune circus: square leads, triangle bass, noise drums."""
    s = Song(140, 24)
    melody(s, "lead", lambda f, d: inst_chip(f, d, 0.25), 8, 4, 0.5)
    melody(s, "lead", lambda f, d: inst_chip(f, d, 0.125), 8, 12, 0.45, octave=1)
    melody(s, "lead", lambda f, d: inst_chip(f, d, 0.5), 4, 20, 0.5)
    arp(s, "arp", lambda f, d: inst_chip(f, d, 0.5) * 0.6, 24, 0, 0.18, 0.125, 1, (0, 1, 2, 1, 0, 2))
    for bi in range(24):
        r = ROOTS[bi % 8] + 12
        for k in range(4):   # oom-pah
            s.add("bass", bi * 4 + k, inst_bass(mtof(r if k % 2 == 0 else r + 7), 0.45 * s.beat, "tri"), 0.55)
    kit = {"kick": lambda c: chip_noise(0.12, False) * 1.4, "snare": lambda c: chip_noise(0.15, True) * 1.2,
           "hat": lambda c: chip_noise(0.03, True) * 0.6}
    drums(s, 24, 0, {"kick": "x.......x.......", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x."}, kit, 0.9, fill=False)
    return s, {"lead": {"delay": (0.75, 0.25, 0.2), "reverb": (1.2, 0.15)}, "arp": {"reverb": (1.0, 0.1)}, "bass": {}, "drums": {}}


def song_highway():
    """Turbo Highway - outrun electro-rock: pumping supersaws, guitar chugs, big drums."""
    s = Song(128, 28)
    chords(s, "pad", lambda f, d: inst_supersaw(f, d, 3500), 28, 0, 0.4, rhythm=((0, 4),))
    for bi in range(20):
        r = ROOTS[bi % 8] + 12
        for k in range(16):
            s.add("gtr", (8 + bi) * 4 + k * 0.25, inst_guitar_dist([mtof(r), mtof(r + 7)], 0.22 * s.beat, True), 0.25, 0.5 if k % 2 else -0.5)
    melody(s, "lead", lambda f, d: inst_supersaw(f, d, 7000) * 0.8, 8, 4, 0.5)
    melody(s, "lead", inst_brass, 8, 12, 0.5)
    melody(s, "lead", lambda f, d: inst_supersaw(f, d, 8000) * 0.8, 8, 20, 0.5, octave=1)
    bassline(s, "bass", "synth", 28, 0, 0.5, pattern=tuple((i * 0.25, 0.22) for i in range(16)))
    kit = standard_kit(kick={"punch": 1.3, "tone": 50}, snare={"tone": 185, "length": 0.45, "snap": 1.4})
    drums(s, 4, 0, {"kick": "x...x...x...x...", "hat": "..x...x...x...x."}, kit, 0.85)
    drums(s, 24, 4, {"kick": "x...x...x...x...", "snare": "....X.......X...", "clap": "....x.......x...", "hat": "..x...x...x...xo"}, kit, 1.0)
    for b in (4, 12, 20):
        s.add("drums", b * 4, crash(), 0.8)
    return s, {"pad": {"reverb": (2.5, 0.35), "pump": 0.6}, "gtr": {"reverb": (0.8, 0.15), "pump": 0.3},
               "lead": {"reverb": (2.5, 0.35), "delay": (0.75, 0.3, 0.25)}, "bass": {"pump": 0.45}, "drums": {"reverb": (1.2, 0.25)}}


SONGS = {
    "menu": song_menu, "sky": song_sky, "festival": song_festival, "skate": song_skate, "rain": song_rain,
    "market": song_market, "harbor": song_harbor, "sakura": song_sakura, "carnival": song_carnival, "highway": song_highway,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(SONGS)
    for name in names:
        s, fx = SONGS[name]()
        audio = s.mixdown(fx)
        path = os.path.join(OUT, name + ".ogg")
        # libsndfile's vorbis encoder crashes on one huge write: stream in blocks
        with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS", compression_level=0.55) as f:
            for i in range(0, len(audio), SR):
                f.write(audio[i:i + SR])
        print("%-9s %5.1f s  %3d bpm  %6.0f KB" % (name, s.length, s.bpm, os.path.getsize(path) / 1024))


if __name__ == "__main__":
    main()
