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
    def test_loop_pcm_boundaries(self):
        # Guard gross seam/DC regressions, not musical phrasing or backend gaps.
        loops = {
            "music_village": (2, 768000), "music_ruins": (2, 960000),
            "music_battle": (2, 548571), "ambience_village": (1, 368000),
            "ambience_ruins": (1, 368000), "ambience_house": (1, 368000),
        }
        for name, (channels, frames) in loops.items():
            with self.subTest(loop=name), wave.open(str(ROOT / (name + ".wav"))) as clip:
                self.assertEqual((clip.getnchannels(), clip.getsampwidth(), clip.getframerate()), (channels, 2, 32000))
                self.assertEqual(clip.getnframes(), frames)
                samples = array.array("h", clip.readframes(frames))
                if sys.byteorder != "little":
                    samples.byteswap()
                for channel in range(channels):
                    pcm = samples[channel::channels]
                    self.assertLess(max(abs(value) for value in pcm), 32767, "Loop PCM clips")
                    self.assertLess(abs(sum(pcm) / len(pcm)) / 32768, 0.001, "Loop has DC offset")
                    self.assertLess(abs(pcm[0] - pcm[-1]) / 32768, 0.02, "Loop seam has a large sample jump")
                    # 100 ms edge windows must contain signal, without a gross
                    # loudness discontinuity. Neither window is required silent:
                    # the source deliberately wraps reverb tails into its start.
                    edge_rms = [math.sqrt(sum((v / 32768) ** 2 for v in window) / len(window))
                                for window in (pcm[:3200], pcm[-3200:])]
                    self.assertGreater(min(edge_rms), 0.005, "Loop has a silent edge")
                    self.assertLess(max(edge_rms) / min(edge_rms), 2.0, "Loop edge levels differ by over 6 dB")

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
