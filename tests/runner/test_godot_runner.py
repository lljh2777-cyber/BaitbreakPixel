"""Optional engine integration checks for the runner's failure handling."""
import os
from pathlib import Path
import shutil
import sys
import unittest

from test_run_tests import runner


@unittest.skipUnless(shutil.which(os.environ.get("GODOT", "godot")), "Godot is not installed")
class GodotFailureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder = runner.ROOT / "artifacts" / "runner-fixtures"
        cls.folder.mkdir(parents=True, exist_ok=True)
        cls.env = dict(os.environ)
        if sys.platform.startswith("linux"):
            for key, name in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
                target = cls.folder / name
                target.mkdir(parents=True, exist_ok=True)
                cls.env[key] = str(target)

    def invoke(self, filename, source, timeout=5):
        script = self.folder / filename
        script.write_text(source, encoding="utf-8")
        command = [os.environ.get("GODOT", "godot"), "--headless", "--audio-driver", "Dummy", "--path", str(runner.ROOT), "--script", str(script), "--", "--test-profile"]
        return runner.classify(runner.run_bounded(command, timeout, runner.ROOT, self.env))

    def test_real_parse_error_fails(self):
        result = self.invoke("parse_error.gd", "extends SceneTree\nfunc broken(:\n")
        self.assertEqual(result["status"], "failed")
        self.assertIn("Parse Error", result["output"])

    def test_runtime_abort_cannot_hang_runner(self):
        result = self.invoke("runtime_abort.gd", 'extends SceneTree\nfunc _initialize(): call_deferred("run")\nfunc run():\n\tvar value: Dictionary={}\n\tprint(value.missing_key)\n\tquit(0)\n', 1)
        self.assertEqual(result["status"], "timeout")
        self.assertIn("SCRIPT ERROR", result["output"])
        self.assertLess(result["duration_seconds"], 8)

    def test_preset_file_collision_still_reports_engine_error(self):
        result = self.invoke("preset_file_collision.gd", 'extends SceneTree\nconst Store=preload("res://scripts/rules_store.gd")\nfunc _initialize():\n\tvar path="user://preset-file-collision-"+str(OS.get_process_id())\n\tvar file=FileAccess.open(path,FileAccess.WRITE)\n\tfile.store_string("not a directory")\n\tfile.close()\n\tStore.preset_names(path)\n\tprint("PROBE | passed=1 | failed=0")\n\tquit(0)\n')
        self.assertEqual(result["status"], "failed")
        self.assertIn("ERROR:", result["output"])

    def test_direct_retired_suite_exits_fast_nonzero(self):
        for suite in ["rules_v019", "net_route_v0102"]:
            with self.subTest(suite=suite):
                command = [os.environ.get("GODOT", "godot"), "--headless", "--audio-driver", "Dummy", "--path", str(runner.ROOT), "--script", "res://tests/"+suite+".gd", "--", "--test-profile"]
                result = runner.run_bounded(command, 10, runner.ROOT, self.env)
                self.assertEqual(result["returncode"], 2)
                self.assertFalse(result["timed_out"])
                self.assertIn("RETIRED_SUITE", result["output"])
                self.assertNotIn("SCRIPT ERROR", result["output"])
