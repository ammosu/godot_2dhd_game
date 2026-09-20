"""Prologue asset regression manifest. GPU cases must never run headless."""
import argparse
import json
from pathlib import Path
import sys
import tempfile

from run_environment_checks import CASES, ROOT, run_check

ADDITIONAL_CASES = (
    "gate_art", "garden_art", "grounding", "player_art", "player_combat_art",
    "guardian_art", "enemy_roster_art", "crate_art", "jar_art", "pig_art",
    "hearth_art", "interior_textiles", "moon_lamp_art", "ally_combat_art",
    "guardian_attack_art", "party_defeated_art", "traveler_attack_motion",
    "caster_motion", "physical_hit_art", "party_ward", "magic_burst",
    "party_weapon_audio", "party_battle", "party_battle_balance",
    "party_battle_ui", "music", "ambience", "audio_preferences",
    "battle_font", "map_resource_cache", "furniture_cutaway", "house_circulation",
)
GPU_CASES = ("roof_art", "water_render", "interior_backdrop", "interior_textiles")
MARKERS = {"party_battle_balance": "PARTY_BALANCE_TEST_PASS"}


def manifest(godot: str, group: str) -> list[tuple[str, list[str], str]]:
    checks = []
    base = [godot, "--path", str(ROOT)]
    if group in ("cpu", "all"):
        for case in (*CASES, *ADDITIONAL_CASES):
            checks.append((case, base + ["--headless", "--script", f"tests/{case}_test.gd"],
                           MARKERS.get(case, f"{case.upper()}_TEST_PASS")))
        checks.append(("audio_pcm", [sys.executable, "tests/audio_asset_test.py"], "\nOK\n"))
    if group in ("gpu", "all"):
        for renderer in ("forward_plus", "gl_compatibility"):
            for case in GPU_CASES:
                checks.append((f"{case}-{renderer}", base + ["--rendering-method", renderer,
                               "--script", f"tests/{case}_test.gd"], f"{case.upper()}_TEST_PASS"))
    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--group", choices=("cpu", "gpu", "all"), default="cpu")
    parser.add_argument("--timeout", type=float, default=90)
    args = parser.parse_args()
    if not 0 < args.timeout < float("inf"):
        parser.error("--timeout must be finite and positive")
    logs = Path(tempfile.mkdtemp(prefix="wanderlight-assets-"))
    print(f"Logs: {logs}", flush=True)
    results = []
    for name, command, marker in manifest(args.godot, args.group):
        passed, output = run_check(command, marker, args.timeout)
        if "instances were leaked at exit" in output:
            passed = False
        (logs / f"{name}.log").write_text(output, encoding="utf-8")
        results.append({"name": name, "passed": passed, "command": command, "marker": marker})
        print(f"{'PASS' if passed else 'FAIL'} {name}", flush=True)
    (logs / "results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    passed_count = sum(item["passed"] for item in results)
    print(f"Asset checks: {passed_count}/{len(results)} passed; logs: {logs}", flush=True)
    return 0 if passed_count == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
