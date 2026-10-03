"""Statistical/merge guards; synthetic fixtures are not gameplay evidence."""
from __future__ import annotations
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from phase03_run_competition import MODES, METRICS, fingerprints, summarize


def rows_for(seed=1):
    rows = []
    for mode in MODES:
        row = {key: 0.0 for key in METRICS}
        row.update(seed=seed, mode=mode, ticks=120, duration=2.0, completed=True,
                   winner='angler', reason='synthetic_fixture', home_win=False,
                   food_goal=60.0, player_food=6.0,
                   player_food_by_type={'cluster': 1.0, 'worm': 2.0, 'chunk': 3.0},
                   npc_food=3.0 if mode == 'ForagingNPC' else 0.0,
                   npc_food_by_type={'cluster': 3.0 if mode == 'ForagingNPC' else 0.0, 'worm': 0.0, 'chunk': 0.0},
                   npc_hook_count=None, wrong_catches=None, stats={'synthetic': 1})
        rows.append(row)
    return rows


class ComparisonGuards(unittest.TestCase):
    def assert_invalid(self, transform):
        rows = rows_for()
        transform(rows)
        with self.assertRaises(ValueError): summarize(rows, [1], bootstrap=100)

    def test_valid_complete_pair(self):
        result = summarize(rows_for(), [1], bootstrap=100)
        self.assertEqual(result['paired_seeds'], 1)
        self.assertEqual(result['passive_control_mismatched_seeds'], [])
        self.assertEqual(len(result['paired_differences']), 3)

    def test_duplicate_mode_seed(self):
        self.assert_invalid(lambda rows: rows.append(dict(rows[0])))

    def test_missing_mode(self):
        self.assert_invalid(lambda rows: rows.pop())

    def test_missing_requested_seed(self):
        with self.assertRaises(ValueError): summarize(rows_for(), [1, 2], bootstrap=100)

    def test_unknown_mode(self):
        self.assert_invalid(lambda rows: rows[0].update(mode='HookableNPC'))

    def test_player_type_total(self):
        self.assert_invalid(lambda rows: rows[0].update(player_food=7.0))

    def test_npc_type_total(self):
        self.assert_invalid(lambda rows: rows[2].update(npc_food=4.0))

    def test_goal_mismatch(self):
        self.assert_invalid(lambda rows: rows[2].update(food_goal=59.0))

    def test_duration_must_be_real_ticks(self):
        self.assert_invalid(lambda rows: rows[0].update(duration=1.0))

    def test_unimplemented_metric_is_not_fake_zero(self):
        for key in ('npc_hook_count', 'wrong_catches'):
            with self.subTest(key=key):
                self.assert_invalid(lambda rows, key=key: rows[0].update({key: 0}))

    def test_passive_difference_retained(self):
        rows = rows_for()
        rows[1]['player_food'] += 1.0
        rows[1]['player_food_by_type']['cluster'] += 1.0
        result = summarize(rows, [1], bootstrap=100)
        self.assertEqual(result['passive_control_mismatched_seeds'], [1])
        self.assertEqual(result['modes']['PassiveNPC']['metrics']['player_food'], 7.0)


class ProvenanceAndMergeGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Intentionally preserved for inspection. Repository policy prohibits
        # bulk/recursive deletion, including automatic TemporaryDirectory cleanup.
        cls.fixture_root = Path(tempfile.mkdtemp(prefix='phase03-analysis-tests-'))
        cls.serial = 0

    def shard(self, seed=1, **changes):
        type(self).serial += 1
        path = self.fixture_root / f'shard-{self.serial}'
        path.mkdir()
        manifest = {'phase': 'heldout', 'success': True, 'source_stable': True,
                    'source_sha256': {'scripts/synthetic.gd': 'synthetic-hash'},
                    'seeds': [seed], 'max_ticks': 22200, 'pilot': '/synthetic/pilot'}
        manifest.update(changes)
        (path / 'provenance.json').write_text(json.dumps(manifest))
        (path / 'rounds.json').write_text(json.dumps(rows_for(seed)))
        return path

    def merge(self, shards):
        type(self).serial += 1
        output = self.fixture_root / f'merged-{self.serial}'
        result = subprocess.run([sys.executable, str(ROOT / 'tools/phase03_merge_competition.py'),
                                 *map(str, shards), '--output', str(output)],
                                cwd=ROOT, text=True, capture_output=True, timeout=20)
        return result, output

    def test_merge_complete_disjoint_shards(self):
        result, output = self.merge([self.shard(1), self.shard(2)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((output / 'provenance.json').read_text())['seeds'], [1, 2])
        self.assertEqual(len(json.loads((output / 'rounds.json').read_text())), 6)

    def test_merge_overlapping_seeds(self):
        result, _ = self.merge([self.shard(1), self.shard(1)])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Overlapping seeds', result.stderr)

    def test_merge_source_mismatch(self):
        result, _ = self.merge([self.shard(1), self.shard(2, source_sha256={'scripts/synthetic.gd': 'changed'})])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Mismatched source_sha256', result.stderr)

    def test_merge_horizon_mismatch(self):
        result, _ = self.merge([self.shard(1), self.shard(2, max_ticks=999)])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Mismatched max_ticks', result.stderr)

    def test_merge_rejects_source_unstable(self):
        result, _ = self.merge([self.shard(1, source_stable=False)])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('source-unstable', result.stderr)

    def test_merge_rejects_unsuccessful(self):
        result, _ = self.merge([self.shard(1, success=False)])
        self.assertNotEqual(result.returncode, 0)

    def test_merge_rejects_missing_pair(self):
        shard = self.shard(1)
        (shard / 'rounds.json').write_text(json.dumps(rows_for(1)[:-1]))
        result, _ = self.merge([shard])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Incomplete paired sample', result.stderr)

    def heldout_rejection(self, manifest):
        type(self).serial += 1
        pilot = self.fixture_root / f'pilot-{self.serial}'; pilot.mkdir()
        (pilot / 'provenance.json').write_text(json.dumps(manifest))
        output = self.fixture_root / f'heldout-{self.serial}'
        result = subprocess.run([sys.executable, str(ROOT / 'tools/phase03_run_competition.py'),
                                 '--phase', 'heldout', '--rounds', '1', '--seed', '2',
                                 '--pilot', str(pilot), '--output', str(output),
                                 '--godot', '/not-invoked-invalid-godot'],
                                cwd=ROOT, text=True, capture_output=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists(), 'Must reject before creating results or launching Godot')
        return result

    def test_heldout_rejects_pilot_seed_overlap(self):
        result = self.heldout_rejection({'phase': 'pilot', 'success': True, 'seeds': [2],
                                        'max_ticks': 22200, 'source_sha256': fingerprints()})
        self.assertIn('seeds overlap', result.stderr)

    def test_heldout_rejects_source_change(self):
        result = self.heldout_rejection({'phase': 'pilot', 'success': True, 'seeds': [1],
                                        'max_ticks': 22200, 'source_sha256': {'changed': 'hash'}})
        self.assertIn('Source changed', result.stderr)


if __name__ == '__main__': unittest.main()
