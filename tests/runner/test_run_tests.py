"""Runner infrastructure tests; run with python3 -m unittest discover -s tests/runner."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[2] / "tools" / "run_tests.py"
spec = importlib.util.spec_from_file_location("run_tests", MODULE)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class ClassificationTests(unittest.TestCase):
    def result(self, output, code=0):
        return runner.classify(dict(output=output, returncode=code, timed_out=False, launch_error=False))

    def test_valid_summary(self):
        result = self.result("RULE_PASS | ok\nRULES_V020 | passed=177 | failed=0\n")
        self.assertEqual((result["status"], result["passed"], result["failed"]), ("passed", 177, 0))

    def test_script_error_with_zero_exit_is_not_green(self):
        self.assertEqual(self.result("SCRIPT ERROR: Invalid call.\n", 0)["status"], "failed")

    def test_parse_error_with_zero_exit_is_not_green(self):
        self.assertEqual(self.result("SCRIPT ERROR: Parse Error: unexpected token\nTEST | passed=4 | failed=0")["status"], "failed")

    def test_engine_error_after_summary_is_not_green(self):
        self.assertEqual(self.result("SUITE | passed=4 | failed=0\nERROR: Can't save PNG")["status"], "failed")

    def test_failed_count_even_with_zero_exit(self):
        result = self.result("SUITE | passed=4 | failed=2")
        self.assertEqual((result["status"], result["failed"]), ("failed", 2))

    def test_nonzero_exit_even_with_good_summary(self):
        self.assertEqual(self.result("SUITE | passed=4 | failed=0", 1)["status"], "failed")

    def test_empty_success_is_not_test_success(self):
        self.assertEqual(self.result("Godot engine ready")["status"], "failed")

    def test_legacy_pass_marker(self):
        self.assertEqual(self.result("NATIVE_V05_PASS | completed")["status"], "passed")

    def test_continuous_alpha_summary(self):
        result = self.result("ARM_ALPHA_V0159 | continuous_alpha_poses=384 | failed=0")
        self.assertEqual((result["status"], result["passed"]), ("passed", 384))

    def test_passed_only_legacy_summary(self):
        result = self.result("ANGLER_NATIVE_V010_TESTS | passed=31")
        self.assertEqual((result["status"], result["passed"]), ("passed", 31))

    def test_timeout_even_after_good_summary(self):
        result = runner.classify(dict(output="TEST | passed=4 | failed=0", returncode=-9, timed_out=True, launch_error=False))
        self.assertEqual(result["status"], "timeout")


class ProcessTests(unittest.TestCase):
    def test_normal_process(self):
        result = runner.run_bounded([sys.executable, "-c", "print('TEST | passed=1 | failed=0')"], 5, MODULE.parent)
        self.assertEqual(runner.classify(result)["status"], "passed")

    def test_timeout_is_bounded(self):
        began = time.monotonic()
        result = runner.run_bounded([sys.executable, "-c", "import time; print('started', flush=True); time.sleep(30)"], .15, MODULE.parent)
        self.assertEqual(runner.classify(result)["status"], "timeout")
        self.assertIn("started", result["output"])
        self.assertLess(time.monotonic()-began, 8)

    @unittest.skipIf(sys.platform == "win32", "POSIX process-group check")
    def test_timeout_cleans_child_holding_pipe(self):
        script = "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)']); print('child started',flush=True); time.sleep(30)"
        began = time.monotonic()
        result = runner.run_bounded([sys.executable, "-c", script], .2, MODULE.parent)
        self.assertTrue(result["timed_out"])
        self.assertIn("child started", result["output"])
        self.assertLess(time.monotonic()-began, 8)

    def test_keyboard_interrupt_cleans_process_tree(self):
        with patch.object(runner.subprocess, "Popen") as popen, patch.object(runner, "stop_process_tree") as stop:
            process = popen.return_value
            process.wait.side_effect = [KeyboardInterrupt, None]
            with self.assertRaises(KeyboardInterrupt):
                runner.run_bounded(["fake-godot"], 5, MODULE.parent)
            stop.assert_called_once_with(process)

    def test_missing_executable_is_blocked(self):
        result = runner.run_bounded(["/certainly-missing/godot"], 1, MODULE.parent)
        self.assertEqual(runner.classify(result)["status"], "blocked")


class RegistryTests(unittest.TestCase):
    def test_registry_covers_every_source_suite(self):
        registry = runner.load_registry()
        self.assertIn("rules_v020", runner.select_suites(registry, "current", []))
        self.assertNotIn("rules_v019", runner.select_suites(registry, "current", []))

    def test_retirement_is_explicit_and_replacement_recorded(self):
        entry = runner.load_registry()["suites"]["rules_v019"]
        self.assertEqual(entry["status"], "retired")
        self.assertEqual(entry["replacement"], "rules_v020")
        self.assertIn("net_capture_seconds", entry["reason"])

    def test_historical_failures_still_selectable(self):
        registry = runner.load_registry()
        self.assertIn("angler_v010", runner.select_suites(registry, "historical", []))
        self.assertEqual(runner.select_suites(registry, "current", ["angler_v010"]), ["angler_v010"])

    def test_unknown_suite_fails(self):
        with self.assertRaises(ValueError):
            runner.select_suites(runner.load_registry(), "current", ["typo"])

    def test_invalid_timeout_rejected(self):
        for value in ["0", "-1", "nan", "inf"]:
            with self.subTest(value=value), self.assertRaises(SystemExit):
                runner.main(["--timeout", value, "--list"])


if __name__ == "__main__":
    unittest.main()
