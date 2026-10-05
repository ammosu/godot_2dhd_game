"""Synthesize the original hand-bell cue for Sia's field bell (standard library only).

Usage: python3 tools/art/build_bell.py
Writes assets/generated/audio/hand_bell.wav: mono 48 kHz / 16-bit, 1.3 s, peak 0.34.
A struck small bell: inharmonic partials with individual decays, a short
mallet click and a gentle beat between two near-unison hum partials.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
LENGTH = 1.3
PEAK = 0.34
FUNDAMENTAL = 880.0
# (ratio, amplitude, decay seconds): classic small-bell inharmonic series.
PARTIALS = [(0.5, 0.35, 0.9), (0.503, 0.30, 0.9), (1.0, 1.0, 0.75), (1.19, 0.45, 0.5),
            (1.5, 0.30, 0.42), (2.0, 0.55, 0.35), (2.74, 0.28, 0.22), (3.76, 0.16, 0.14)]


def main() -> None:
    random.seed(7)
    count = int(RATE * LENGTH)
    samples = []
    for index in range(count):
        t = index / RATE
        value = sum(amp * math.exp(-t / decay) * math.sin(2 * math.pi * FUNDAMENTAL * ratio * t)
                    for ratio, amp, decay in PARTIALS)
        if t < 0.012:
            value += (random.random() * 2 - 1) * 0.6 * (1 - t / 0.012)
        attack = min(1.0, t / 0.002)
        release = min(1.0, (LENGTH - t) / 0.05)
        samples.append(value * attack * release)
    scale = PEAK / max(abs(s) for s in samples)
    out = Path(__file__).resolve().parents[2] / "assets/generated/audio/hand_bell.wav"
    with wave.open(str(out), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))
    print(out)


if __name__ == "__main__":
    main()
