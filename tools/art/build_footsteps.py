"""Original sample-free footsteps, synthesized with Python's standard library."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
DEST = Path(__file__).resolve().parents[2] / "assets/generated/audio"
DURATIONS = {"dirt": 0.18, "stone": 0.16, "wood": 0.20}


def render(surface, variant):
    duration = DURATIONS[surface]
    rng = random.Random(701 + list(DURATIONS).index(surface) * 17 + variant)
    low = 0.0
    values = []
    for index in range(round(duration * RATE)):
        time = index / RATE
        noise = rng.uniform(-1, 1)
        low += 0.045 * (noise - low)
        attack = min(1.0, time / 0.003)
        # A short sole impact followed by material-specific friction/resonance.
        sole = math.sin(math.tau * (78 + 7 * variant) * time) * math.exp(-time / 0.020)
        if surface == "dirt":
            value = 0.50 * sole + 1.8 * low * math.exp(-time / 0.055)
            value += 0.11 * noise * math.exp(-time / 0.045)
        elif surface == "stone":
            value = 0.45 * sole + 0.75 * noise * math.exp(-time / 0.014)
            value += 0.12 * math.sin(math.tau * (1280 + 43 * variant) * time) * math.exp(-time / 0.009)
        else:
            value = 0.45 * sole + 0.32 * noise * math.exp(-time / 0.018)
            for frequency, gain in [(174, 0.34), (387, 0.13), (623, 0.06)]:
                value += gain * math.sin(math.tau * (frequency + variant * 9) * time) * math.exp(-time / 0.035)
        tail = min(1.0, (duration - time) / 0.025)
        values.append(value * attack * max(0, tail))
    gain = 0.32 / max(abs(value) for value in values)
    samples = [round(value * gain * 32767) for value in values]
    samples[0] = samples[-1] = 0
    name = f"step_{surface}_{variant + 1}"
    with wave.open(str(DEST / f"{name}.wav"), "wb") as output:
        output.setparams((1, 2, RATE, len(samples), "NONE", "not compressed"))
        output.writeframes(struct.pack("<" + "h" * len(samples), *samples))
    print(f"{name}: {duration:.2f}s, peak=0.320")


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    for material in DURATIONS:
        for take in range(2):
            render(material, take)
