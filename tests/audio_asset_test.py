"""PCM integrity checks; not a substitute for subjective listening/mix review."""
import array
import hashlib
import math
from pathlib import Path
import sys
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1] / "assets/generated/audio"
ROLE_CUES = {
    "moon_slash": 0.36, "moon_bolt": 0.38, "frost_nova": 0.30,
    "frost_impact": 0.52, "protect": 0.62, "moon_heal": 0.72,
    "spear_thrust": 0.29, "claw_swipe": 0.30, "staff_strike": 0.32,
}


class AudioAssetTest(unittest.TestCase):
    def test_footstep_pcm(self):
        hashes = set()
        for surface, duration in {"dirt": 0.18, "stone": 0.16, "wood": 0.20}.items():
            for variant in (1, 2):
                name = f"step_{surface}_{variant}"
                with self.subTest(cue=name), wave.open(str(ROOT / (name + ".wav"))) as clip:
                    self.assertEqual((clip.getnchannels(), clip.getsampwidth(), clip.getframerate()), (1, 2, 48000))
                    self.assertEqual(clip.getnframes(), round(duration * 48000))
                    raw = clip.readframes(clip.getnframes())
                    samples = array.array("h", raw)
                    if sys.byteorder != "little":
                        samples.byteswap()
                    self.assertEqual((samples[0], samples[-1]), (0, 0))
                    self.assertAlmostEqual(max(abs(v) for v in samples) / 32767, 0.32, places=3)
                    rms = math.sqrt(sum((v / 32767) ** 2 for v in samples) / len(samples))
                    self.assertGreater(rms, 0.01)
                    self.assertLess(rms, 0.15)
                    hashes.add(hashlib.sha256(raw).hexdigest())
        self.assertEqual(len(hashes), 6, "Footsteps must have distinct material/variant waveforms")

    def test_role_cue_pcm(self):
        hashes = set()
        for name, duration in ROLE_CUES.items():
            with self.subTest(cue=name), wave.open(str(ROOT / (name + ".wav"))) as clip:
                self.assertEqual((clip.getnchannels(), clip.getsampwidth(), clip.getframerate()), (1, 2, 48000))
                self.assertEqual(clip.getnframes(), round(duration * 48000))
                raw = clip.readframes(clip.getnframes())
                samples = array.array("h", raw)
                if sys.byteorder != "little":
                    samples.byteswap()
                self.assertEqual((samples[0], samples[-1]), (0, 0))
                peak = max(abs(value) for value in samples) / 32767
                rms = math.sqrt(sum((value / 32767) ** 2 for value in samples) / len(samples))
                self.assertAlmostEqual(peak, 0.5, places=3)
                self.assertGreater(rms, 0.01)
                self.assertLess(rms, 0.3)
                hashes.add(hashlib.sha256(raw).hexdigest())
        self.assertEqual(len(hashes), len(ROLE_CUES), "Role effects must not be duplicated PCM")


if __name__ == "__main__":
    unittest.main()
