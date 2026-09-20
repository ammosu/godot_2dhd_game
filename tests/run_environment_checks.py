"""Bounded, sequential environment regressions; visual approval remains manual."""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CASES = (
    "house_interior", "house_dressing", "house_exterior", "house_window",
    "foreground_cutaway", "interior_backdrop", "street_lantern", "footsteps",
    "ruin_soil", "ruin_rubble", "moon_shard", "water_feature",
)


def run_check(command: list[str], marker: str, timeout: float) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        return False, output + f"\nCHECK_TIMEOUT after {timeout:g}s\n"
    except OSError as error:
        return False, f"CHECK_START_ERROR: {error}\n"
    output = result.stdout
    passed = (
        result.returncode == 0 and marker in output
        and "ERROR:" not in output and "SCRIPT ERROR:" not in output
    )
    if not passed:
        output += f"\nCHECK_FAILED exit={result.returncode}, expected={marker}\n"
    return passed, output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot executable path")
    parser.add_argument("--timeout", type=float, default=90, help="Seconds per test")
    parser.add_argument("--case", choices=CASES, action="append", help="Run selected cases only")
    args = parser.parse_args()
    if not 0 < args.timeout < float("inf"):
        parser.error("--timeout must be finite and positive")
    cases = args.case or CASES
    logs = Path(tempfile.mkdtemp(prefix="wanderlight-environment-"))
    print(f"Logs: {logs}", flush=True)
    failures = []
    for case in cases:
        command = [args.godot, "--headless", "--path", str(ROOT), "--script", f"tests/{case}_test.gd"]
        passed, output = run_check(command, f"{case.upper()}_TEST_PASS", args.timeout)
        (logs / f"{case}.log").write_text(output, encoding="utf-8")
        print(f"{'PASS' if passed else 'FAIL'} {case}", flush=True)
        if not passed:
            failures.append(case)
    print(f"Environment checks: {len(cases) - len(failures)}/{len(cases)} passed; logs: {logs}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
