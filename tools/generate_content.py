"""Generate original sound effects; runtime levels live in level_generator.gd."""
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]


def sound(name, frequency, duration, volume=0.2, melody=False):
    rate = 22050
    samples = []
    for i in range(int(rate * duration)):
        t = i / rate
        local = t % 0.16 if melody else t
        f = frequency * ([1, 1.25, 1.5, 2][min(3, int(t / 0.16))] if melody else 1 + 0.5 * math.exp(-t * 35))
        env = min(1, local * 180) * math.exp(-local * 19) * min(1, (duration - t) * 80)
        value = (math.sin(math.tau * f * t) + 0.22 * math.sin(math.tau * f * 2 * t)) * env * volume
        samples.append(struct.pack('<h', int(max(-1, min(1, value)) * 32767)))
    with wave.open(str(ROOT / 'assets' / 'audio' / f'{name}.wav'), 'wb') as wav:
        wav.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        wav.writeframes(b''.join(samples))


if __name__ == '__main__':
    sound('pick', 620, 0.13, 0.12)
    sound('plop', 390, 0.2)
    sound('merge', 740, 0.3, 0.13)
    sound('win', 523.25, 0.72, 0.15, True)
    print('Generated four original sounds. Legacy level data was not modified.')
