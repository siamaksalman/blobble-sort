#!/usr/bin/env python3
"""Synthesize the game's sound effects into assets/sfx/*.wav.

Everything is procedural and seeded, so the set is reproducible:
    python3 tools/make_sfx.py            # needs numpy

Mobile audio choices baked in here:
- 48 kHz mono 16-bit: phones mix natively at 48 kHz (no resampling cost) and their
  speakers are mono in practice.
- Energy lives above ~300 Hz. Phone speakers can't reproduce bass, so "weight" comes
  from harmonics and transients instead of low fundamentals.
- UI sounds are short (40-300 ms) and quieter than gameplay sounds. Every clip is
  normalized to a target loudness (max momentary LUFS, ITU BS.1770 K-weighting) with
  a -1 dBFS peak ceiling, so levels are consistent without needing a mixer pass.
- Every pitched sound is in C major pentatonic (C D E G A), the scale the game
  also uses to repitch bottle taps, so anything that overlaps is consonant.
- The pour loop has no seam (built with circular filtering and wrapped bubbles), so
  the game can repitch it live as the bottle fills.
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 48000
# C major pentatonic note frequencies (equal temperament, A4 = 440 Hz).
C4, E4, G4, A4 = 261.63, 329.63, 392.00, 440.00
C5, D5, E5, G5, A5 = 523.25, 587.33, 659.26, 783.99, 880.00
C6, E6, G6 = 1046.50, 1318.51, 1567.98
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ building blocks

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_ad(n, attack, decay):
    """Attack in seconds, then exponential decay with time constant `decay`."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def place(buf, clip, at):
    i = int(at * SR)
    end = min(len(buf), i + len(clip))
    buf[i:end] += clip[: end - i]


def band_noise(n, lo, hi, circular=False):
    """White noise shaped to [lo, hi] Hz in the frequency domain (seamless if circular)."""
    spec = np.fft.rfft(rng.standard_normal(n if circular else n * 2))
    f = np.fft.rfftfreq(n if circular else n * 2, 1 / SR)
    # Soft band edges avoid ringing.
    gain = 1 / (1 + (lo / np.maximum(f, 1)) ** 4) / (1 + (f / hi) ** 4)
    out = np.fft.irfft(spec * gain)
    out = out[:n]
    return out / (np.abs(out).max() + 1e-9)


def lowpass(x, fc):
    """Gentle (12 dB/oct-ish) low-pass in the frequency domain; rounds off harsh highs."""
    n = len(x) * 2
    f = np.fft.rfftfreq(n, 1 / SR)
    y = np.fft.irfft(np.fft.rfft(x, n) / (1 + (f / fc) ** 2), n)
    return y[: len(x)]


def bottle(f0, dur, decay=0.16, attack=0.004, brightness=1.0):
    """Mellow tapped bottle: a round fundamental with soft, near-harmonic overtones
    (a finger on thick glass rather than a metal spoon), eased-in attack, no tick."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for r, g, dk in ((1, 1.0, 1.0), (2.0, 0.22, 0.55), (3.0, 0.07, 0.35), (0.5, 0.12, 0.8)):
        f = f0 * r * (1 + rng.uniform(-0.002, 0.002))
        out += g * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / (decay * dk))
    # Faint "knock" of the finger: low-passed noise, not a bright click.
    out += 0.12 * lowpass(band_noise(len(t), 200, 2000), 1200) * np.exp(-t / 0.006)
    out *= 0.5 - 0.5 * np.cos(np.pi * np.clip(t / attack, 0, 1))
    return lowpass(out, 2600 * brightness)


def bubble(f0, amp=1.0, rise=0.4):
    """Minnaert-style bubble: a sine whose pitch rises as it decays (van den Doel)."""
    d = 0.13 * f0 + 0.0072 * f0 ** 1.5
    dur = min(6 / d, 0.08)
    t = t_axis(dur)
    freq = f0 * (1 + rise * t / dur)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return amp * np.sin(phase) * np.exp(-d * t) * np.clip(t / 0.0006, 0, 1)


def room(x, amount=0.18):
    """A few early reflections: enough to sound 'in a space' without a reverb tail."""
    out = x.copy()
    for ms, g in ((23, 0.6), (37, 0.45), (53, 0.33), (71, 0.22), (97, 0.14)):
        k = int(ms * SR / 1000)
        out[k:] += amount * g * x[:-k]
    return out


def fade(x, fin=0.002, fout=0.02):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


# ------------------------------------------------------------------ loudness (BS.1770)

def _biquad(x, b, a):
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b
    _, a1, a2 = a
    for i, xi in enumerate(x):
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def momentary_max_lufs(x):
    """Loudest 400 ms window, K-weighted (the usual way to level short SFX)."""
    k = _biquad(x, (1.53512485958697, -2.69169618940638, 1.19839281085285),
                (1.0, -1.69065929318241, 0.73248077421585))
    k = _biquad(k, (1.0, -2.0, 1.0), (1.0, -1.99004745483398, 0.99007225036621))
    win = int(0.4 * SR)
    k = np.concatenate([k ** 2, np.zeros(win)])
    c = np.concatenate([[0], np.cumsum(k)])
    ms = (c[win:] - c[:-win]) / win
    return -0.691 + 10 * np.log10(ms.max() + 1e-12)


def normalize(x, target_lufs, ceiling_db=-1.0):
    x = x * 10 ** ((target_lufs - momentary_max_lufs(x)) / 20)
    peak = np.abs(x).max()
    ceiling = 10 ** (ceiling_db / 20)
    if peak > ceiling:
        x *= ceiling / peak
    return x


def write(name, x, target, loop=False):
    x = normalize(x, target)
    # TPDF dither to 16 bit.
    d = (rng.uniform(-0.5, 0.5, len(x)) + rng.uniform(-0.5, 0.5, len(x))) / 32768
    pcm = np.clip(np.round((x + d) * 32767), -32768, 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"{name:10s} {len(x) / SR * 1000:6.0f} ms  {momentary_max_lufs(x):6.1f} LUFS(M max)  "
          f"peak {20 * np.log10(np.abs(x).max()):5.1f} dBFS{'  loop' if loop else ''}")


# ------------------------------------------------------------------ the sounds

def pour_loop():
    """1.6 s seamless water stream: a noise bed plus a cloud of bubbles."""
    dur = 1.6
    n = int(dur * SR)
    t = np.arange(n) / SR
    # Noise bed, filtered circularly so the loop point is invisible.
    bed = band_noise(n, 350, 4200, circular=True)
    # Slow "gurgle" wobble; whole cycles over the loop keep it seamless.
    wob = 1 + 0.25 * np.sin(2 * np.pi * 5 / dur * t) + 0.15 * np.sin(2 * np.pi * 13 / dur * t + 1)
    out = 0.35 * bed * wob
    for _ in range(int(95 * dur)):
        f0 = float(np.clip(rng.lognormal(np.log(950), 0.38), 380, 2600))
        b = bubble(f0, rng.uniform(0.25, 1.0), rng.uniform(0.2, 0.7))
        i = rng.integers(0, n)
        idx = (i + np.arange(len(b))) % n  # wrap the tail round to the start
        np.add.at(out, idx, b)
    return out


def splash():
    """Stream hitting the liquid: a short soft burst with a flurry of bubbles."""
    n = int(0.26 * SR)
    out = band_noise(n, 400, 3500) * env_ad(n, 0.006, 0.045) * 0.7
    for _ in range(18):
        at = abs(rng.normal(0, 0.035))
        place(out, bubble(rng.uniform(500, 1600), rng.uniform(0.3, 0.9)), at)
    return fade(lowpass(out, 3500))


# Bottle taps are recorded on C5; the game repitches them to the scale note that
# matches how full the bottle is.
def select():
    """Lift a bottle: warm rounded 'tunk'."""
    return fade(bottle(C5, 0.3, decay=0.1), fout=0.05)


def deselect():
    """Put it back: duller and shorter (the game plays it a scale step lower)."""
    return fade(bottle(C5, 0.26, decay=0.07, brightness=0.8), fout=0.05)


def place_down():
    """Bottle lands back on the wooden shelf: a soft, woody 'tock'."""
    n = int(0.14 * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * C5 * t) * np.exp(-t / 0.02)
    body += 0.3 * np.sin(2 * np.pi * C6 * t) * np.exp(-t / 0.012)
    thump = lowpass(band_noise(n, 200, 1500), 900) * np.exp(-t / 0.008)
    x = body + 0.4 * thump
    x *= 0.5 - 0.5 * np.cos(np.pi * np.clip(t / 0.003, 0, 1))
    return fade(lowpass(x, 2000))


def invalid():
    """Can't do that: two soft muted knocks falling a fourth, A4 -> E4 (falling = negative)."""
    out = np.zeros(int(0.24 * SR))
    for at, f in ((0.0, A4), (0.09, E4)):
        n = int(0.12 * SR)
        t = np.arange(n) / SR
        k = sum(g * np.sin(2 * np.pi * f * h * t) for h, g in ((1, 1), (2, 0.45), (3, 0.25)))
        k *= env_ad(n, 0.002, 0.03)
        place(out, k, at)
    return fade(out)


def tap():
    """UI button: a soft rounded blip on a steady G5."""
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    blip = np.sin(2 * np.pi * G5 * t) * env_ad(n, 0.003, 0.018)
    blip += 0.25 * np.sin(2 * np.pi * 2 * G5 * t) * env_ad(n, 0.003, 0.008)
    return fade(lowpass(blip, 2500), fout=0.015)


def cork():
    """Bottle finished: cork 'pop', then G5 -> C6, dominant resolving to the tonic."""
    out = np.zeros(int(0.7 * SR))
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    freq = C4 + 600 * np.exp(-t / 0.008)
    pop = np.sin(2 * np.pi * np.cumsum(freq) / SR) * env_ad(n, 0.002, 0.02)
    pop += 0.25 * lowpass(band_noise(n, 800, 4000), 2500) * np.exp(-t / 0.004)
    place(out, pop, 0)
    place(out, 0.55 * bottle(G5, 0.6, decay=0.22), 0.06)
    place(out, 0.6 * bottle(C6, 0.6, decay=0.25), 0.13)
    return fade(room(out))


def hint():
    """Hint: three soft rising notes in open fourths, A4 D5 G5 (a 'look here' question)."""
    out = np.zeros(int(0.55 * SR))
    for i, f in enumerate((A4, D5, G5)):
        place(out, (0.7 + 0.15 * i) * bottle(f, 0.45, decay=0.16), i * 0.065)
    return fade(room(out))


def marimba(f, dur=1.0):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.45)
    x += 0.35 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t / 0.07)
    x += 0.12 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t / 0.02)
    # Octave harmonic keeps low notes audible on phone speakers.
    x += 0.3 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / 0.25)
    return x * np.clip(t / 0.002, 0, 1)


def win():
    """Level complete: C major arpeggio up to a ringing chord, with glass shimmer."""
    out = np.zeros(int(1.7 * SR))
    for i, f in enumerate((C5, E5, G5, C6)):
        place(out, marimba(f, 1.2), i * 0.09)
    for f in (C6, E6, G6):
        place(out, 0.3 * marimba(f, 1.3), 0.36)
    place(out, 0.3 * bottle(C6, 1.0, decay=0.4), 0.36)
    return fade(lowpass(room(out, 0.25), 4000), fout=0.15)


# ------------------------------------------------------------------ targets
# Gameplay moments sit louder than UI; the looping pour is kept moderate so it
# doesn't fatigue over hundreds of moves.
SOUNDS = [
    ("pour_loop", pour_loop, -20, True),
    ("splash", splash, -21, False),
    ("select", select, -21, False),
    ("deselect", deselect, -24, False),
    ("place", place_down, -26, False),
    ("invalid", invalid, -22, False),
    ("tap", tap, -24, False),
    ("cork", cork, -17, False),
    ("hint", hint, -20, False),
    ("win", win, -16, False),
]

if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, fn, target, loop in SOUNDS:
        if not only or name in only:
            write(name, fn(), target, loop)
