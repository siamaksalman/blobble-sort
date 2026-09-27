"""Generate original sound effects; runtime levels live in level_generator.gd.

Every cue is synthesized from scratch (sine partials, filtered noise and bubble
chirps), so the audio needs no third-party samples or licences. Output is
deterministic: the same script always writes the same files.

All pitched cues are tuned to C major, with their main notes on the C major
pentatonic (C D E G A), so any sounds that overlap stay consonant. The game
transposes cues only by pentatonic steps (see sound_bank.gd).
"""
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
SEMITONES = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}


def note(name):
    """Equal-tempered frequency of a note like 'C5' (A4 = 440 Hz)."""
    return 440.0 * 2 ** ((SEMITONES[name[0]] + 12 * (int(name[1:]) - 4)) / 12)


def timeline(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def envelope(t, attack, decay):
    """Fast linear attack, exponential decay."""
    return np.minimum(1.0, t / max(attack, 1e-6)) * np.exp(-t / decay)


def tone(frequency, t):
    """Sine whose frequency may vary over time (phase is integrated)."""
    frequency = np.broadcast_to(frequency, t.shape)
    return np.sin(2 * np.pi * np.cumsum(frequency) / RATE)


def glide(target, t, start_ratio, time):
    """Pitch that slides from target * start_ratio onto target, settling in tune."""
    return target * (1 + (start_ratio - 1) * np.exp(-t / time))


def bubble(seconds, pitch, rise, decay, delay=0.0):
    """A Minnaert bubble: a quick upward chirp that settles on `pitch`."""
    t = timeline(seconds)
    local = np.clip(t - delay, 0, None)
    frequency = glide(pitch, local, 1 / (1 + rise), 0.008)
    voice = tone(frequency, local) * envelope(local, 0.002, decay)
    return np.where(t >= delay, voice, 0.0)


def bell(seconds, frequency, delay=0.0, decay=0.5, brightness=0.35):
    """Soft glockenspiel-like note; harmonic partials keep it inside the key."""
    t = timeline(seconds)
    local = np.clip(t - delay, 0, None)
    voice = np.zeros_like(t)
    for ratio, level, speed in ((1.0, 1.0, 1.0), (2.0, 0.45, 1.7), (3.0, brightness, 2.6), (4.0, brightness * 0.5, 4.2)):
        voice += level * np.sin(2 * np.pi * frequency * ratio * local) * np.exp(-local * speed / decay)
    voice *= np.minimum(1.0, local / 0.003)
    return taper(np.where(t >= delay, voice, 0.0))


def taper(signal, seconds=0.08):
    """Fade a tail that has not fully decayed, so cutting it never clicks."""
    length = min(signal.size, int(RATE * seconds))
    signal = signal.copy()
    signal[-length:] *= np.cos(np.linspace(0, np.pi / 2, length)) ** 2
    return signal


def bandpass_noise(t, centers, width, seed):
    """Noise through a time-varying resonant band-pass (state-variable filter)."""
    noise = np.random.default_rng(seed).uniform(-1, 1, t.size)
    out = np.zeros_like(noise)
    low = band = 0.0
    damping = 1.0 / width
    for i, sample in enumerate(noise):
        f = 2 * np.sin(np.pi * min(centers[i], RATE / 6) / RATE)
        high = sample - low - damping * band
        band += f * high
        low += f * band
        out[i] = band
    return out


def lowpass(signal, cutoff):
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.zeros_like(signal)
    value = 0.0
    for i, sample in enumerate(signal):
        value += alpha * (sample - value)
        out[i] = value
    return out


def room(signal, delay=0.075, feedback=0.28, taps=5):
    """A light cozy echo so chimes bloom instead of stopping dead."""
    signal = taper(signal)
    offset = int(RATE * delay)
    out = np.concatenate([signal, np.zeros(offset * taps)])
    for tap in range(1, taps + 1):
        out[offset * tap:offset * tap + signal.size] += signal * feedback ** tap * (0.7 if tap % 2 else 1.0)
    return out


def finish(signal, peak):
    """Normalize, then fade both ends so no cue ever clicks."""
    signal = signal - np.mean(signal)
    signal = signal / max(np.max(np.abs(signal)), 1e-9) * peak
    fade_in = min(signal.size, int(RATE * 0.002))
    fade_out = min(signal.size, int(RATE * 0.025))
    signal[:fade_in] *= np.linspace(0, 1, fade_in)
    signal[-fade_out:] *= np.linspace(1, 0, fade_out) ** 2
    return signal


def write(name, signal, peak):
    data = (finish(np.asarray(signal, dtype=np.float64), peak) * 32767).astype('<i2')
    with wave.open(str(ROOT / 'assets' / 'audio' / f'{name}.wav'), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(data.tobytes())


def select():
    # A squishy "bloop" lifting from C5 up to G5, with a wet C6 bubble on top.
    t = timeline(0.2)
    body = tone(glide(note('G5'), t, 2 ** (-7 / 12), 0.03), t) * envelope(t, 0.004, 0.06)
    return body + 0.35 * bubble(0.2, note('C6'), 0.3, 0.03, 0.02)


def deselect():
    # The same squish settling back down from G5 to C5.
    t = timeline(0.18)
    body = tone(glide(note('C5'), t, 2 ** (7 / 12), 0.014), t) * envelope(t, 0.004, 0.055)
    return body + 0.2 * bubble(0.18, note('G4'), 0.2, 0.03)


def pour():
    # An airy swish that sweeps up and back down like a jelly flying by.
    t = timeline(0.38)
    shape = np.sin(np.pi * np.clip(t / 0.36, 0, 1)) ** 1.6
    centers = 500 + 1500 * np.sin(np.pi * np.clip(t / 0.36, 0, 1)) ** 2
    return bandpass_noise(t, centers, 3.0, seed=11) * shape


def plop():
    # A soft C3 thump plus a water-drop bubble landing on C5, sparkling at G5.
    t = timeline(0.3)
    thump = tone(glide(note('C3'), t, 1.5, 0.02), t) * envelope(t, 0.003, 0.045)
    return thump * 0.8 + bubble(0.3, note('C5'), 0.5, 0.05, 0.004) + 0.3 * bubble(0.3, note('G5'), 0.3, 0.025, 0.05)


def merge():
    # Two blobs squelch together: a wobbling G3 goo under a bubble arpeggio.
    # Only roots and fifths (C, G), so it stays in key when the game transposes it.
    t = timeline(0.5)
    wobble = 1 + 0.025 * np.sin(2 * np.pi * 24 * t) * np.exp(-t / 0.15)
    goo = tone(glide(note('G3'), t, 1.3, 0.03) * wobble, t) * envelope(t, 0.006, 0.11)
    pops = sum(level * bubble(0.5, note(name), 0.12, 0.06, at) for level, name, at in
               ((0.8, 'C5', 0.0), (0.6, 'G5', 0.07), (0.45, 'C6', 0.14)))
    return goo * 0.6 + pops + 0.12 * bell(0.5, note('G6'), 0.08, 0.2)


def complete():
    # The merge squelch resolving into a warm rising chime (C6, E6, G6, C7).
    notes = [bell(1.5, note(name), at, 0.45) * level for name, at, level in
             (('C6', 0.05, 0.8), ('E6', 0.12, 0.7), ('G6', 0.19, 0.65), ('C7', 0.28, 0.55))]
    chime = room(sum(notes), 0.09, 0.3, 4)
    squish = np.concatenate([merge() * 0.9, np.zeros(chime.size - int(RATE * 0.5))])
    return squish + chime * 0.9


def invalid():
    # A soft, muffled G3 "bonk" over a D3 undertone: clearly no, yet still in key.
    t = timeline(0.26)
    pitch = glide(note('G3'), t, 1.12, 0.012) * (1 + 0.02 * np.sin(2 * np.pi * 17 * t))
    body = (tone(pitch, t) + 0.3 * tone(pitch * 2, t)) * envelope(t, 0.005, 0.08)
    return lowpass(body, 900) + 0.3 * tone(note('D3') * pitch / note('G3'), t) * envelope(t, 0.01, 0.06)


def undo():
    # A little reversed swell that drops from E5 onto C5, as if time slurps backwards.
    t = timeline(0.24)
    swell = np.minimum(1.0, t / 0.12) ** 2 * np.exp(-np.clip(t - 0.12, 0, None) / 0.035)
    swoop = tone(glide(note('C5'), t, 2 ** (4 / 12), 0.04), t) * swell
    air = bandpass_noise(t, 1200 * np.exp(-t / 0.1) + 300, 4.0, seed=5) * swell
    return swoop + 0.12 * air


def hint():
    # Two sparkly twinkles pointing the way (E6 then A6).
    return room(bell(0.7, note('E6'), 0.0, 0.25, 0.5) + 0.8 * bell(0.7, note('A6'), 0.09, 0.25, 0.5), 0.07, 0.25, 3)


def tap():
    # A tiny soft wooden tick on C6 for interface buttons.
    t = timeline(0.07)
    return tone(glide(note('C6'), t, 1.1, 0.005), t) * envelope(t, 0.001, 0.012) + \
        0.35 * bandpass_noise(t, np.full(t.size, 3000.0), 2.0, seed=3) * envelope(t, 0.0005, 0.006)


def win():
    # A marimba run up C major that lands on a glowing bell chord.
    run = ['C5', 'E5', 'G5', 'C6', 'E6']
    marimba = sum(bell(2.2, note(name), 0.11 * i, 0.22, 0.15) * 0.7 for i, name in enumerate(run))
    chord = sum(bell(2.2, note(name), 0.6, 0.7, 0.3) * level for name, level in
                (('C6', 0.6), ('E6', 0.5), ('G6', 0.5), ('C7', 0.35)))
    t = timeline(2.2)
    shimmer = chord * (1 + 0.08 * np.sin(2 * np.pi * 5.5 * t))
    return room(marimba + shimmer + 0.5 * bubble(2.2, note('C5'), 0.4, 0.05, 0.58), 0.12, 0.25, 2)[:int(RATE * 2.45)]


CUES = {
    'select': (select, 0.55), 'deselect': (deselect, 0.45), 'pour': (pour, 0.4),
    'plop': (plop, 0.7), 'merge': (merge, 0.75), 'complete': (complete, 0.8),
    'invalid': (invalid, 0.5), 'undo': (undo, 0.5), 'hint': (hint, 0.55),
    'tap': (tap, 0.4), 'win': (win, 0.8),
}


if __name__ == '__main__':
    for name, (build, peak) in CUES.items():
        write(name, build(), peak)
    print(f'Generated {len(CUES)} original sounds. Level data was not modified.')
