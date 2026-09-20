import unittest

from run_asset_checks import ROOT, manifest


class AssetRunnerTest(unittest.TestCase):
    def test_groups_are_disjoint_and_complete(self):
        cpu = manifest("godot", "cpu")
        gpu = manifest("godot", "gpu")
        self.assertEqual(len(cpu), 48)
        self.assertEqual(len(gpu), 8)
        self.assertEqual(manifest("godot", "all"), cpu + gpu)
        self.assertEqual(len({name for name, _, _ in cpu + gpu}), 56)

    def test_recent_interior_regressions_are_included(self):
        cpu_names = {name for name, _, _ in manifest("godot", "cpu")}
        self.assertTrue({"furniture_cutaway", "house_circulation", "pillar_art", "crystal_material"} <= cpu_names)
        gpu_names = {name for name, _, _ in manifest("godot", "gpu")}
        for renderer in ("forward_plus", "gl_compatibility"):
            self.assertIn(f"interior_textiles-{renderer}", gpu_names)

    def test_rendering_requirements(self):
        for _, command, _ in manifest("godot", "gpu"):
            self.assertNotIn("--headless", command)
            self.assertIn("--rendering-method", command)
        for name, command, _ in manifest("godot", "cpu"):
            if name != "audio_pcm":
                self.assertIn("--headless", command)
            self.assertNotEqual(name, "roof_art")

    def test_nonstandard_success_marker(self):
        marker = next(marker for name, _, marker in manifest("godot", "cpu")
                      if name == "party_battle_balance")
        self.assertEqual(marker, "PARTY_BALANCE_TEST_PASS")

    def test_manifest_paths_exist(self):
        for _, command, _ in manifest("godot", "all"):
            script = command[command.index("--script") + 1] if "--script" in command else command[-1]
            self.assertTrue((ROOT / script).is_file(), script)


if __name__ == "__main__":
    unittest.main()
