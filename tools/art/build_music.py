"""Original scored, sample-free music loops for Wanderlight (stdlib only).

Notes, voicings and synthesis are authored here, not adapted from a song.
Tails and stereo delay wrap around the loop instead of being truncated.
"""
import array
import math
import struct
import wave
from pathlib import Path

RATE = 32000
DEST = Path(__file__).resolve().parents[2] / "assets/generated/audio"
CHORDS = [(52, 59, 64, 67), (48, 55, 59, 64), (43, 55, 59, 62), (50, 57, 62, 64),
          (45, 57, 60, 64), (48, 55, 60, 64), (47, 54, 59, 62), (52, 59, 64, 67)]
MELODY = [(0, 76, 1.0), (1.5, 71, 0.5), (2.5, 74, 1.0),
          (4.5, 72, 1.5), (6.5, 67, 0.75), (8, 71, 1.0), (9.5, 74, 0.75),
          (11, 79, 0.75), (12.5, 78, 1.25), (14.5, 74, 0.75),
          (16, 76, 1.25), (17.5, 72, 0.75), (19, 71, 0.75),
          (20.5, 67, 1.0), (22, 72, 1.0), (24, 74, 1.25), (26, 71, 1.0),
          (28, 67, 1.0), (29.5, 71, 0.75), (31, 76, 0.75)]


def instrument(note, seconds, kind):
    frequency = 440.0 * 2 ** ((note - 69) / 12)
    count = round(seconds * RATE)
    result = array.array("f")
    for index in range(count):
        t = index / RATE
        release = min(1.0, (seconds - t) / 0.08)
        phase = math.tau * frequency * t
        if kind == "pad":
            envelope = min(1.0, t / 0.28) * min(1.0, (seconds - t) / 0.65)
            tone = math.sin(phase) + 0.18 * math.sin(phase * 2) + 0.06 * math.sin(phase * 3)
        elif kind == "bass":
            envelope = min(1.0, t / 0.012) * math.exp(-t / 0.55) * release
            tone = math.sin(phase) + 0.2 * math.sin(phase * 2)
        else:
            envelope = min(1.0, t / 0.006) * math.exp(-t / (0.48 if kind == "pluck" else 0.85)) * release
            tone = math.sin(phase) + 0.28 * math.exp(-t * 4) * math.sin(phase * 2.002) + 0.08 * math.exp(-t * 8) * math.sin(phase * 3.997)
        result.append(tone * envelope)
    return result


def render(name, bpm, mood):
    beat = 60.0 / bpm
    frames = round(32 * beat * RATE)
    left = array.array("f", [0.0]) * frames
    right = array.array("f", [0.0]) * frames

    def add(start, note, duration, gain, kind, pan=0.0):
        samples = instrument(note, duration, kind)
        begin = round(start * beat * RATE)
        lg = gain * math.sqrt((1.0 - pan) / 2)
        rg = gain * math.sqrt((1.0 + pan) / 2)
        for index, sample in enumerate(samples):
            target = (begin + index) % frames
            left[target] += sample * lg
            right[target] += sample * rg

    for bar, chord in enumerate(CHORDS):
        for index, note in enumerate(chord[1:]):
            add(bar * 4, note - (12 if mood == "ruins" else 0), beat * 4.8, 0.10, "pad", (index - 1) * 0.35)
        if mood == "battle":
            for step in range(8):
                add(bar * 4 + step * 0.5, chord[0] - 12 + (7 if step % 4 == 3 else 0), 0.5, 0.23 if step % 2 == 0 else 0.14, "bass")
                add(bar * 4 + step * 0.5, chord[1 + step % 3] + 12, 0.55, 0.065, "pluck", -0.35 if step % 2 else 0.35)
        else:
            add(bar * 4, chord[0] - 12, beat * 3.8, 0.12, "bass")
            for step in range(4 if mood == "village" else 2):
                add(bar * 4 + step * (1 if mood == "village" else 2), chord[1 + step % 3], 1.8, 0.07, "pluck", -0.25 + step * 0.15)
    for start, note, length in MELODY:
        if mood == "ruins" and int(start * 2) % 3 != 0:
            continue
        add(start, note - (12 if mood == "ruins" else 0), length * beat + 0.6, 0.12 if mood == "battle" else 0.16, "bell", 0.12)

    # Circular, cross-channel room echoes preserve the musical loop boundary.
    dry_left, dry_right = left[:], right[:]
    for delay, gain in [(0.19, 0.13), (0.37, 0.07)]:
        offset = round(delay * RATE)
        for index in range(frames):
            source = (index - offset) % frames
            left[index] += dry_right[source] * gain
            right[index] += dry_left[source] * gain
    dc_left, dc_right = sum(left) / frames, sum(right) / frames
    peak = max(max(abs(value - dc_left) for value in left), max(abs(value - dc_right) for value in right))
    gain = 0.55 / peak
    pcm = array.array("h")
    for lvalue, rvalue in zip(left, right):
        pcm.extend((round((lvalue - dc_left) * gain * 32767), round((rvalue - dc_right) * gain * 32767)))
    # Explicit little-endian encoding, independent of the build host.
    with wave.open(str(DEST / f"music_{name}.wav"), "wb") as output:
        output.setparams((2, 2, RATE, frames, "NONE", "not compressed"))
        output.writeframes(struct.pack("<" + "h" * len(pcm), *pcm))
    seam = max(abs(pcm[0] - pcm[-2]), abs(pcm[1] - pcm[-1])) / 32767
    print(f"{name}: {frames / RATE:.3f}s, peak=0.55, loop-step={seam:.5f}")


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    render("village", 80, "village")
    render("ruins", 64, "ruins")
    render("battle", 112, "battle")
