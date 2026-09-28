#!/usr/bin/env python3
"""Run the Godot regression suite in parallel and report a strict pass/fail.

A test passes only when Godot exits with 0, prints a `*_PASS` marker and the
output contains neither `ERROR:` nor `SCRIPT ERROR:`. A failed `assert` does not
quit a SceneTree script, so a test is stopped shortly after its first error
instead of waiting for the full timeout.

Tests may declare needs in their leading `##` comment lines:
    ## test-args: -- --layered-equipment   extra Godot arguments
    ## test-requires: gpu                  needs a real renderer; skipped unless --gpu

Examples:
    python3 tools/run_tests.py                      # every tests/*_test.gd + playthrough
    python3 tools/run_tests.py hit_feedback field_  # only names containing a pattern
    python3 tools/run_tests.py --renderer forward_plus --jobs 4
    python3 tools/run_tests.py --gpu roof water     # windowed GPU tests
    python3 tools/run_tests.py --list
"""

from __future__ import annotations

import argparse
import os
import re
import shlex
import shutil
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS_DIR = ROOT / "tests"
PLAYTHROUGH = "playthrough"
PLAYTHROUGH_MARKER = "PLAYTHROUGH_TEST_PASS dialogue quest maps save battle"
PASS_PATTERN = re.compile(r"\b[A-Z][A-Z0-9_]*_PASS\b")
ERROR_PATTERN = re.compile(r"^\s*(SCRIPT )?ERROR:")
DIRECTIVE_PATTERN = re.compile(r"^##\s*test-(args|requires):\s*(.*)$")
# Tests usually print every failed check before quitting; allow them to finish.
ERROR_GRACE_SECONDS = 10.0


@dataclass
class TestSpec:
    name: str
    args: list[str] = field(default_factory=list)
    gpu: bool = False


@dataclass
class Result:
    name: str
    status: str  # PASS, FAIL or SKIP
    reason: str
    seconds: float
    log_path: Path | None


def read_spec(name: str) -> TestSpec:
    spec = TestSpec(name)
    if name == PLAYTHROUGH:
        spec.args = ["--", "--playthrough-test"]
        return spec
    spec.args = ["--script", f"tests/{name}.gd"]
    for line in (TESTS_DIR / f"{name}.gd").read_text().splitlines():
        if not line.startswith("#") and line.strip():
            if not line.startswith(("extends", "class_name", "@")):
                break
            continue
        match = DIRECTIVE_PATTERN.match(line)
        if match is None:
            continue
        if match.group(1) == "args":
            spec.args += shlex.split(match.group(2))
        elif "gpu" in match.group(2).split():
            spec.gpu = True
    return spec


def discover(patterns: list[str]) -> list[TestSpec]:
    names = sorted(p.stem for p in TESTS_DIR.glob("*_test.gd"))
    names.append(PLAYTHROUGH)
    if patterns:
        names = [n for n in names if any(p in n for p in patterns)]
    return [read_spec(n) for n in names]


def command_for(godot: str, spec: TestSpec, renderer: str, fixed_fps: int, windowed: bool) -> list[str]:
    command = [godot, "--path", str(ROOT), "--rendering-method", renderer]
    if not windowed:
        command.insert(1, "--headless")
    if fixed_fps > 0:
        command += ["--fixed-fps", str(fixed_fps)]
    # spec.args ends with any `--` user arguments, after all Godot options.
    return command + spec.args


def run_one(godot: str, spec: TestSpec, renderer: str, fixed_fps: int, timeout: float, log_dir: Path) -> Result:
    log_path = log_dir / f"{spec.name}.log"
    started = time.monotonic()
    lines: list[str] = []
    first_error: list[float] = []

    proc = subprocess.Popen(
        command_for(godot, spec, renderer, fixed_fps, spec.gpu),
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        errors="replace",
    )

    def pump() -> None:
        assert proc.stdout is not None
        for line in proc.stdout:
            lines.append(line)
            if not first_error and ERROR_PATTERN.match(line):
                first_error.append(time.monotonic())

    reader = threading.Thread(target=pump, daemon=True)
    reader.start()
    stopped = ""
    while proc.poll() is None:
        now = time.monotonic()
        if now - started > timeout:
            stopped = f"timeout after {timeout:.0f}s"
        elif first_error and now - first_error[0] > ERROR_GRACE_SECONDS:
            stopped = "stopped: still running after its first error"
        if stopped:
            proc.kill()
            break
        time.sleep(0.2)
    proc.wait()
    reader.join(timeout=5)

    elapsed = time.monotonic() - started
    output = "".join(lines)
    log_path.write_text(output)
    error_lines = [line.strip() for line in lines if ERROR_PATTERN.match(line)]
    if spec.name == PLAYTHROUGH:
        has_marker = PLAYTHROUGH_MARKER in output
    else:
        has_marker = PASS_PATTERN.search(output) is not None

    if error_lines:
        reason = f"{len(error_lines)} error line(s), first: {error_lines[0][:160]}"
    elif stopped:
        reason = stopped
    elif proc.returncode != 0:
        reason = f"exit code {proc.returncode}"
    elif not has_marker:
        reason = "no PASS marker"
    else:
        return Result(spec.name, "PASS", "", elapsed, log_path)
    return Result(spec.name, "FAIL", reason, elapsed, log_path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("patterns", nargs="*", help="only run tests whose name contains one of these")
    parser.add_argument("--renderer", default="gl_compatibility", choices=["gl_compatibility", "forward_plus"])
    parser.add_argument("--jobs", type=int, default=max(1, min(6, (os.cpu_count() or 2) // 2)))
    parser.add_argument("--fixed-fps", type=int, default=0, help="pass --fixed-fps to Godot (0 = off)")
    parser.add_argument("--timeout", type=float, default=300.0, help="seconds per test")
    parser.add_argument("--gpu", action="store_true", help="also run `test-requires: gpu` tests in a window")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--log-dir", type=Path, default=ROOT / "build" / "test-logs")
    parser.add_argument("--list", action="store_true", help="print selected tests and exit")
    args = parser.parse_args()

    specs = discover(args.patterns)
    if args.list:
        for spec in specs:
            tags = " [gpu]" if spec.gpu else ""
            print(f"{spec.name}{tags}")
        return 0
    if not specs:
        print("No tests matched.", file=sys.stderr)
        return 2
    if shutil.which(args.godot) is None and not Path(args.godot).exists():
        print(f"Godot executable not found: {args.godot}", file=sys.stderr)
        return 2

    log_dir = args.log_dir / args.renderer
    log_dir.mkdir(parents=True, exist_ok=True)
    runnable = [s for s in specs if args.gpu or not s.gpu]
    results = [Result(s.name, "SKIP", "needs GPU; pass --gpu", 0.0, None) for s in specs if s not in runnable]
    print(f"Running {len(runnable)} test(s) with {args.renderer}, {args.jobs} job(s); logs in {log_dir}")

    started = time.monotonic()
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [
            pool.submit(run_one, args.godot, s, args.renderer, args.fixed_fps, args.timeout, log_dir)
            for s in runnable
        ]
        for index, future in enumerate(as_completed(futures), start=1):
            result = future.result()
            results.append(result)
            detail = f"  {result.reason}" if result.status == "FAIL" else ""
            print(f"[{index:3}/{len(runnable)}] {result.status} {result.name} ({result.seconds:.1f}s){detail}", flush=True)

    failed = sorted((r for r in results if r.status == "FAIL"), key=lambda r: r.name)
    skipped = [r for r in results if r.status == "SKIP"]
    passed = len(results) - len(failed) - len(skipped)
    total = time.monotonic() - started
    print(f"\n{passed} passed, {len(failed)} failed, {len(skipped)} skipped in {total:.0f}s")
    for result in skipped:
        print(f"  SKIP {result.name}: {result.reason}")
    for result in failed:
        print(f"  FAIL {result.name}: {result.reason}\n       log: {result.log_path}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
