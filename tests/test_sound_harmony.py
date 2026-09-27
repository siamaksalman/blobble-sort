"""Every pitched cue must sit in C major, so any sounds that overlap stay consonant.

Run: python3 tests/test_sound_harmony.py  (needs numpy)
"""
from pathlib import Path
import sys
import wave

import numpy as np

AUDIO = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
C_MAJOR = {0, 2, 4, 5, 7, 9, 11}  # Pitch classes, C = 0.
PENTATONIC = {0, 2, 4, 7, 9}
UNPITCHED = {'pour'}  # Filtered noise with no pitch to tune.
# Cues the game transposes up the pentatonic as a pocket fills (sound_bank.gd scale_pitch).
TRANSPOSED = {'plop', 'merge'}
STEPS = [0, 2, 4, 7]
TOLERANCE_CENTS = 30
failures = 0


def check(condition, description):
    global failures
    if not condition:
        failures += 1
        print('FAIL:', description)


def read(name):
    with wave.open(str(AUDIO / f'{name}.wav')) as wav:
        data = np.frombuffer(wav.readframes(wav.getnframes()), '<i2') / 32768
        return data, wav.getframerate()


def pitch_class(frequency):
    """Nearest pitch class and how far off it is, in cents."""
    semitones = 12 * np.log2(frequency / 261.6256)
    nearest = round(semitones)
    return nearest % 12, abs(semitones - nearest) * 100


def peaks(data, rate, floor_db=-18):
    """Strong spectral peaks: the notes a listener actually hears."""
    size = 1 << int(np.ceil(np.log2(data.size * 4)))
    spectrum = np.abs(np.fft.rfft(data * np.hanning(data.size), size))
    frequencies = np.fft.rfftfreq(size, 1 / rate)
    level = 20 * np.log10(spectrum / spectrum.max() + 1e-12)
    found = []
    for i in range(1, spectrum.size - 1):
        if 90 < frequencies[i] < 6000 and level[i] > floor_db and spectrum[i] >= spectrum[i - 1] and spectrum[i] >= spectrum[i + 1]:
            found.append((frequencies[i], level[i]))
    return found


cues = sorted(path.stem for path in AUDIO.glob('*.wav'))
check(len(cues) >= 11, 'All sound cues are present')
for cue in cues:
    if cue in UNPITCHED:
        continue
    data, rate = read(cue)
    notes = peaks(data, rate)
    check(notes, f'{cue} has an audible pitch')
    for step in STEPS if cue in TRANSPOSED else [0]:
        for frequency, level in notes:
            pitch, cents = pitch_class(frequency * 2 ** (step / 12))
            check(pitch in C_MAJOR and cents <= TOLERANCE_CENTS,
                  f'{cue} +{step} semitones: {frequency:.0f} Hz ({level:.0f} dB) lands {cents:.0f} cents from pitch class {pitch}, outside C major')
    strongest = max(notes, key=lambda note: note[1])[0] if notes else 0
    if strongest:
        pitch, cents = pitch_class(strongest)
        check(pitch in PENTATONIC and cents <= TOLERANCE_CENTS,
              f'{cue}: main note {strongest:.0f} Hz is not on the C major pentatonic (C D E G A)')

print(f'Harmony checks: {failures} failed')
sys.exit(1 if failures else 0)
