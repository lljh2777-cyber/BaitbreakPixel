"""Synthetic classifier/provenance tests; these are not gameplay measurements."""
import copy
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[2] / "tools" / "phase03_analyze_social.py"
spec = importlib.util.spec_from_file_location("social", path)
social = importlib.util.module_from_spec(spec)
spec.loader.exec_module(social)


def row(seed, truth, index, state="FEED", split=None, dataset="natural"):
    return {"dataset": dataset, "split": split or ("train" if seed < 3 else "heldout"),
            "episode": str(seed), "seed": seed, "fish_id": 2, "tick": index,
            "state": state, "feeding": state == "FEED", "speed": 12.0,
            "hook_truth": truth, "satiety": 5.0, "scene": "motion"}


class SocialDiagnosticTests(unittest.TestCase):
    def test_balanced_identical_cues_are_chance(self):
        rows = [row(seed, truth, tick) for seed in range(1, 5) for tick in range(30) for truth in [False, True]]
        result = social.classifier(rows)
        self.assertEqual(result["accuracy"], .5)
        self.assertEqual(result["balanced_accuracy"], .5)
        self.assertTrue(result["sufficient_support"])
        self.assertEqual(result["flags"], [])

    def test_state_oracle_triggers_critical_review(self):
        rows = [row(seed, truth, tick, "FLEE" if truth else "FEED") for seed in range(1, 5) for tick in range(30) for truth in [False, True]]
        result = social.classifier(rows)
        self.assertEqual(result["accuracy"], 1)
        self.assertIn("BALANCED_ACCURACY_ABOVE_95_CRITICAL_REVIEW", result["flags"])

    def test_imbalanced_majority_is_not_balanced_evidence(self):
        rows = [row(seed, tick != 0, tick) for seed in range(1, 5) for tick in range(100)]
        result = social.classifier(rows)
        self.assertEqual(result["accuracy"], .99)
        self.assertEqual(result["balanced_accuracy"], .5)
        self.assertIn("HIGH_MAJORITY_BASELINE", result["flags"])
        self.assertIn("INSUFFICIENT_CLASS_OR_SEED_SUPPORT", result["flags"])

    def test_single_class_never_reports_safe(self):
        result = social.classifier([row(seed, True, tick) for seed in range(1, 5) for tick in range(30)])
        self.assertIsNone(result["balanced_accuracy"])
        self.assertFalse(result["sufficient_support"])

    def test_identity_hunger_and_truth_are_not_classifier_features(self):
        first = row(1, False, 0)
        altered = dict(first, seed=77, bait_id=999, hook_truth=True, satiety=99.0, danger_cues=1)
        self.assertEqual(social.feature(first), social.feature(altered))

    def fixture(self):
        rows = [row(seed, truth, tick, dataset="counterfactual") for seed in range(1, 5) for tick in range(30) for truth in [False, True]]
        return {"format": social.FORMAT, "source_stable": True, "source_hashes": {"fake": "fixture-only"}, "mismatched_counterfactual_pairs": 0, "matched_counterfactual_pairs": 120, "rows": rows}

    def test_complete_counterfactuals_accepted(self):
        social.validate(self.fixture())

    def test_missing_partner_rejected(self):
        report = self.fixture(); report["rows"].pop()
        with self.assertRaisesRegex(ValueError, "partner"):
            social.validate(report)

    def test_observable_difference_rejected(self):
        report = self.fixture(); report["rows"][0]["speed"] = 8.0
        with self.assertRaisesRegex(ValueError, "mismatch"):
            social.validate(report)

    def test_seed_split_leak_rejected(self):
        report = self.fixture(); report["rows"][0]["split"] = "heldout"
        with self.assertRaisesRegex(ValueError, "Seed leaked"):
            social.validate(report)

    def test_witnessed_results_are_partitioned_from_prediction(self):
        report = self.fixture()
        for item in report["rows"]:
            item["witnessed_danger_recent"] = item["tick"] < 10
        result = social.summarize(report)["datasets"]["counterfactual"]
        self.assertEqual(result["predictive_without_witnessed_result"]["heldout_rows"], 80)
        self.assertEqual(result["witnessed_result"]["heldout_rows"], 40)
        self.assertEqual(result["predictive_without_witnessed_result"]["balanced_accuracy"], .5)

    def test_source_change_rejected(self):
        report = self.fixture(); report["source_stable"] = False
        with self.assertRaises(ValueError):
            social.validate(report)

    def test_duplicate_row_rejected(self):
        report = self.fixture(); report["rows"].append(copy.deepcopy(report["rows"][0]))
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            social.validate(report)


if __name__ == "__main__":
    unittest.main()
