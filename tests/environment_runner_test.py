"""Check runner failure detection without starting Godot or touching saves."""
import subprocess
import unittest
from unittest.mock import patch

from run_environment_checks import run_check


class EnvironmentRunnerTest(unittest.TestCase):
    def check_output(self, output: str, code: int = 0) -> bool:
        result = subprocess.CompletedProcess(["godot"], code, output)
        with patch("run_environment_checks.subprocess.run", return_value=result):
            return run_check(["godot"], "EXAMPLE_TEST_PASS", 1)[0]

    def test_requires_marker_and_clean_exit(self):
        self.assertTrue(self.check_output("EXAMPLE_TEST_PASS\n"))
        self.assertFalse(self.check_output("no marker"))
        self.assertFalse(self.check_output("EXAMPLE_TEST_PASS", 1))

    def test_godot_error_overrides_zero_exit_and_pass_marker(self):
        for label in ("ERROR:", "SCRIPT ERROR:"):
            self.assertFalse(self.check_output(f"{label} broken\nEXAMPLE_TEST_PASS"))

    def test_timeout_keeps_partial_log(self):
        error = subprocess.TimeoutExpired(["godot"], 1, output=b"partial output")
        with patch("run_environment_checks.subprocess.run", side_effect=error):
            passed, output = run_check(["godot"], "EXAMPLE_TEST_PASS", 1)
        self.assertFalse(passed)
        self.assertIn("partial output", output)
        self.assertIn("CHECK_TIMEOUT", output)

    def test_missing_executable(self):
        with patch("run_environment_checks.subprocess.run", side_effect=FileNotFoundError("missing")):
            passed, output = run_check(["missing"], "EXAMPLE_TEST_PASS", 1)
        self.assertFalse(passed)
        self.assertIn("CHECK_START_ERROR", output)


if __name__ == "__main__":
    unittest.main()
