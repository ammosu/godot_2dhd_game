"""Original deterministic synthesized cues; standard-library-only, no samples.

Run from any directory. Writes only the named project-generated WAV files.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
DEST = Path(__file__).resolve().parents[2] / "assets/generated/audio"


def render(name, duration, tones=(), noise=0.0, sweep=None, seed=17):
    rng = random.Random(seed)
    values = []
    filtered = 0.0
    phase = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        filtered += 0.12 * (rng.uniform(-1.0, 1.0) - filtered)
        value = noise * filtered * math.sin(math.pi * t / duration) ** 2
        for start, frequency, decay, gain in tones:
            age = t - start
            if age >= 0:
                attack = min(1.0, age / 0.008)
                value += gain * attack * math.exp(-age / decay) * (
                    math.sin(math.tau * frequency * age)
                    + 0.18 * math.sin(math.tau * frequency * 2.01 * age)
                )
        if sweep:
            frequency = sweep[0] + (sweep[1] - sweep[0]) * t / duration
            phase += math.tau * frequency / RATE
            value += 0.16 * math.sin(phase) * math.sin(math.pi * t / duration) ** 2
        # Smooth both endpoints, even if the modal tail extends past the clip.
        fade = min(1.0, t / 0.006, (duration - t) / 0.04)
        values.append(value * max(0.0, fade))
    peak = max(abs(value) for value in values)
    gain = (0.25 if name == "dialogue" else 0.5) / max(peak, 1e-9)
    samples = [round(value * gain * 32767) for value in values]
    samples[0] = samples[-1] = 0
    with wave.open(str(DEST / (name + ".wav")), "wb") as output:
        output.setparams((1, 2, RATE, len(samples), "NONE", "not compressed"))
        output.writeframes(struct.pack("<" + "h" * len(samples), *samples))
    print(f"{name}: {duration:.2f}s, peak={max(abs(v) for v in samples)/32767:.3f}")


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    render("dialogue", 0.14, [(0, 660, 0.035, 0.3), (0.035, 880, 0.03, 0.2)])
    render("slash", 0.26, noise=1.8, sweep=(520, 130))
    render("impact", 0.34, [(0, 110, 0.07, 0.6), (0, 247, 0.045, 0.25)], noise=0.45)
    render("guard", 0.48, [(0, 740, 0.13, 0.4), (0, 1187, 0.08, 0.22), (0, 1691, 0.04, 0.12)])
    render("heal", 0.9, [(0, 523.25, 0.22, 0.3), (0.12, 659.25, 0.24, 0.3), (0.24, 783.99, 0.27, 0.3)])
    render("skill", 0.6, [(0.03, 987.77, 0.18, 0.25), (0.08, 1479.98, 0.16, 0.2)], noise=0.8, sweep=(240, 960))
    render("victory", 1.5, [(0, 392, 0.24, 0.28), (0.18, 523.25, 0.3, 0.3), (0.36, 659.25, 0.45, 0.3), (0.36, 783.99, 0.45, 0.2)])
    render("defeat", 1.3, [(0, 329.63, 0.3, 0.3), (0.23, 293.66, 0.3, 0.3), (0.46, 220, 0.35, 0.35)])


if __name__ == "__main__":
    main()
