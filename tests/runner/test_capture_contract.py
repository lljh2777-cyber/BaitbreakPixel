"""Keep native capture entrypoints portable without adding PCK dependencies."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CaptureContractTests(unittest.TestCase):
    def test_every_renderer_capture_producer_supports_override(self):
        producers = []
        for script in sorted((ROOT / "tests").glob("*.gd")):
            source = script.read_text(encoding="utf-8")
            if "DisplayServer.get_name()" not in source or ".save_png(" not in source:
                continue
            producers.append(script.name)
            with self.subTest(script=script.name):
                self.assertIn('"--capture-output-directory="', source)
                self.assertIn("func prepare_capture_output() -> bool:", source)
                self.assertIn("not prepare_capture_output():", source)
                self.assertIn("CAPTURE_OUTPUT_FAIL", source)
                self.assertIn("error != OK", source)
                self.assertNotRegex(source, r'save_png\("res://')
                self.assertNotIn('preload("res://tests/', source)
        self.assertIn("phase01_native.gd", producers)
        self.assertIn("phase02_bite_native.gd", producers)
        self.assertIn("phase02_bait_native.gd", producers)
        self.assertIn("phase03_npc_hook_native.gd", producers)
        self.assertIn("player_hook_entry_native.gd", producers)
        self.assertEqual(len(producers), 37)

    def test_capture_success_cannot_overwrite_failure(self):
        for script in sorted((ROOT / "tests").glob("*.gd")):
            source = script.read_text(encoding="utf-8")
            if "DisplayServer.get_name()" not in source or ".save_png(" not in source:
                continue
            with self.subTest(script=script.name):
                self.assertNotRegex(source, r"\bquit\((?:0)?\)")

    def test_render_only_reel_hand_needs_no_capture_option(self):
        source = (ROOT / "tests" / "reel_hand_native_v016.gd").read_text()
        self.assertNotIn("save_png", source)
        self.assertIn("DisplayServer.get_name()", source)


if __name__ == "__main__":
    unittest.main()
