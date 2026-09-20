"""Original, deterministic sample-free ambience; Python standard library only."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 32000
SECONDS = 12
COUNT = RATE * SECONDS
OUT = Path(__file__).resolve().parents[2] / "assets/generated/audio"


def build(kind: str, seed: int) -> None:
    rng = random.Random(seed)
    samples = []
    low = 0.0
    for i in range(COUNT):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += 0.018 * (noise - low)
        swell = 0.7 + 0.3 * math.sin(math.tau * t / SECONDS)
        samples.append(low * swell * (2.2 if kind == "ruins" else 1.2))
    if kind == "village":
        for start in (0.7, 1.3, 3.6, 4.3, 7.1, 8.0, 10.1):
            for j in range(int(RATE * 0.32)):
                t = j / RATE
                envelope = math.sin(math.pi * t / 0.32) ** 2
                pulse = (0.5 + 0.5 * math.sin(math.tau * 32 * t)) ** 4
                samples[int(start * RATE) + j] += 0.035 * envelope * pulse * math.sin(math.tau * 3600 * t)
    elif kind == "house":
        for _ in range(42):
            start = rng.randrange(COUNT)
            duration = rng.uniform(0.012, 0.065)
            gain = rng.uniform(0.025, 0.09)
            for j in range(int(RATE * duration)):
                envelope = math.sin(math.pi * j / (RATE * duration)) ** 2
                samples[(start + j) % COUNT] += rng.uniform(-1, 1) * gain * envelope
    # Overlap the last half-second with the start, then discard that tail.
    overlap = RATE // 2
    for i in range(overlap):
        blend = i / overlap
        samples[i] = samples[COUNT - overlap + i] * (1 - blend) + samples[i] * blend
    samples = samples[:-overlap]
    mean = sum(samples) / len(samples)
    peak = max(abs(value - mean) for value in samples)
    pcm = [round((value - mean) * 0.45 / peak * 32767) for value in samples]
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"ambience_{kind}.wav"), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))
    print(f"{kind}: {len(pcm) / RATE:.1f}s peak=0.45 boundary_step={abs(pcm[0] - pcm[-1]) / 32768:.5f}")


if __name__ == "__main__":
    for index, context in enumerate(("village", "ruins", "house")):
        build(context, 913 + index)
