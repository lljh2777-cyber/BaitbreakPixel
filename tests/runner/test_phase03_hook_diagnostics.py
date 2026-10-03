"""P3.4 diagnostic integrity guards. Synthetic rows are not gameplay evidence."""
from __future__ import annotations
import copy
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from phase03_run_hook_diagnostics import MODES, METRICS, fingerprints, summarize


def rows_for(seed=1):
    rows = []
    for mode in MODES:
        row = dict.fromkeys(METRICS, 0.0)
        row.update(seed=seed, mode=mode, ticks=120, duration=2.0, completed=True,
                   winner='angler', reason='synthetic_fixture', home_win=False,
                   food_goal=60.0, rules={'synthetic_fixture': True}, player_food=6.0,
                   player_food_by_type={'cluster': 1.0, 'worm': 2.0, 'chunk': 3.0},
                   npc_food=3.0 if mode in ('ForagingNPC', 'HookableNPC') else 0.0,
                   npc_food_by_type={'cluster': 3.0 if mode in ('ForagingNPC', 'HookableNPC') else 0.0,
                                     'worm': 0.0, 'chunk': 0.0},
                   observed_npc_attachments=0, final_hook_target_fish_id=-1, stats={'synthetic_fixture': 1})
        rows.append(row)
    return rows


class HookComparisonGuards(unittest.TestCase):
    def invalid(self, transform):
        rows = rows_for(); transform(rows)
        with self.assertRaises(ValueError): summarize(rows, [1], bootstrap=40)

    def test_four_arms_and_all_six_paired_differences(self):
        result = summarize(rows_for(), [1], bootstrap=40)
        self.assertEqual(set(result['modes']), set(MODES))
        self.assertEqual(len(result['paired_differences']), 6)
        self.assertEqual(result['passive_control_mismatched_seeds'], [])
        self.assertIn('No natural NPC hook event', result['event_coverage_note'])

    def test_measured_hook_capture_and_incomplete_are_preserved(self):
        rows = rows_for()
        rows[3].update(npc_hook_count=2, observed_npc_attachments=2, wrong_catches=1,
                       final_hook_target_fish_id=3, npc_hooked_seconds=1.2,
                       completed=False, winner='', reason='')
        result = summarize(rows, [1], bootstrap=40)
        self.assertEqual(result['modes']['HookableNPC']['incomplete_seeds'], [1])
        self.assertEqual(result['modes']['HookableNPC']['metrics']['wrong_catches'], 1)
        self.assertEqual(result['observed_hookable_events'], 2)

    def test_unknown_mode(self): self.invalid(lambda rows: rows[0].update(mode='Other'))
    def test_duplicate_row(self): self.invalid(lambda rows: rows.append(dict(rows[0])))
    def test_missing_arm(self): self.invalid(lambda rows: rows.pop())
    def test_missing_seed(self):
        with self.assertRaises(ValueError): summarize(rows_for(), [1, 2], bootstrap=40)
    def test_duplicate_requested_seed(self):
        with self.assertRaises(ValueError): summarize(rows_for(), [1, 1], bootstrap=40)
    def test_empty_requested_seeds(self):
        with self.assertRaises(ValueError): summarize([], [], bootstrap=40)
    def test_goal_change(self): self.invalid(lambda rows: rows[3].update(food_goal=59.0))
    def test_rule_change(self): self.invalid(lambda rows: rows[3].update(rules={'synthetic_fixture': False}))
    def test_player_type_total(self): self.invalid(lambda rows: rows[0].update(player_food=7.0))
    def test_npc_type_total(self): self.invalid(lambda rows: rows[3].update(npc_food=4.0))
    def test_type_nan(self): self.invalid(lambda rows: rows[0]['player_food_by_type'].update(cluster=math.nan))
    def test_omitted_food_type(self): self.invalid(lambda rows: rows[0]['player_food_by_type'].pop('worm'))
    def test_fake_elapsed(self): self.invalid(lambda rows: rows[0].update(duration=1.0))
    def test_zero_ticks(self): self.invalid(lambda rows: rows[0].update(ticks=0, duration=0.0))
    def test_metric_null_not_zero(self): self.invalid(lambda rows: rows[3].update(npc_hook_count=None))
    def test_metric_nan(self): self.invalid(lambda rows: rows[3].update(npc_hooked_seconds=math.nan))
    def test_metric_infinite(self): self.invalid(lambda rows: rows[3].update(npc_hooked_seconds=math.inf))
    def test_metric_negative(self): self.invalid(lambda rows: rows[3].update(npc_hooked_seconds=-1))
    def test_counter_fractional(self): self.invalid(lambda rows: rows[3].update(wrong_catches=.5))
    def test_counter_boolean(self): self.invalid(lambda rows: rows[3].update(wrong_catches=True))
    def test_transition_counter_mismatch(self): self.invalid(lambda rows: rows[3].update(npc_hook_count=1))
    def test_resolution_without_contact(self): self.invalid(lambda rows: rows[3].update(wrong_catches=1))
    def test_unaccounted_hook(self): self.invalid(lambda rows: rows[3].update(npc_hook_count=1, observed_npc_attachments=1))
    def test_nonhookable_resolution(self):
        self.invalid(lambda rows: rows[2].update(npc_hook_count=1, observed_npc_attachments=1, npc_escapes=1))
    def test_passive_intake(self):
        self.invalid(lambda rows: rows[1].update(npc_food=1, npc_food_by_type={'cluster': 1, 'worm': 0, 'chunk': 0}))
    def test_npc_faction_invalid(self): self.invalid(lambda rows: rows[3].update(winner='npc'))
    def test_incomplete_not_disguised_as_loss(self): self.invalid(lambda rows: rows[3].update(completed=False))
    def test_wrong_home_win(self): self.invalid(lambda rows: rows[3].update(home_win=True))
    def test_time_cannot_exceed_observation(self): self.invalid(lambda rows: rows[3].update(npc_hooked_seconds=3))
    def test_longest_interval_exceeds_total(self): self.invalid(lambda rows: rows[3].update(longest_no_food_seconds=1))
    def test_passive_mismatch_is_reported_not_filtered(self):
        rows = rows_for(); rows[1]['stats']['synthetic_fixture'] = 2
        result = summarize(rows, [1], bootstrap=40)
        self.assertEqual(result['passive_control_mismatched_seeds'], [1])
    def test_multiple_seeds_retained(self):
        rows = rows_for(1) + rows_for(2)
        rows[-1].update(completed=False, winner='', reason='')
        result = summarize(rows, [1, 2], bootstrap=40)
        self.assertEqual(result['modes']['HookableNPC']['metrics']['completion_fraction'], .5)
        self.assertEqual(result['modes']['HookableNPC']['incomplete_seeds'], [2])


class HookProvenanceGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Preserve fixtures; repository disallows recursive/bulk deletion.
        cls.root = Path(tempfile.mkdtemp(prefix='p34-hook-analysis-tests-')); cls.serial = 0

    def rejection(self, manifest, **flags):
        type(self).serial += 1
        pilot = self.root / f'pilot-{self.serial}'; pilot.mkdir()
        (pilot / 'provenance.json').write_text(json.dumps(manifest))
        output = self.root / f'out-{self.serial}'
        command = [sys.executable, str(ROOT / 'tools/phase03_run_hook_diagnostics.py'),
                   '--phase', 'heldout', '--rounds', '1', '--seed', '2', '--pilot', str(pilot),
                   '--output', str(output), '--godot', '/not-invoked-invalid-godot']
        for key, value in flags.items(): command.extend(['--' + key.replace('_', '-'), str(value)])
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists(), 'Reject before writing output or launching Godot')
        return result.stderr

    def manifest(self):
        return {'phase': 'pilot', 'success': True, 'source_stable': True,
                'seeds': [1], 'max_ticks': 22200, 'source_sha256': fingerprints()}

    def test_pilot_overlap(self):
        manifest = self.manifest(); manifest['seeds'] = [2]
        self.assertIn('overlap', self.rejection(manifest))
    def test_pilot_source_mismatch(self):
        manifest = self.manifest(); manifest['source_sha256'] = {'changed': 'hash'}
        self.assertIn('Source changed', self.rejection(manifest))
    def test_pilot_unstable(self):
        manifest = self.manifest(); manifest['source_stable'] = False
        self.assertIn('source-stable', self.rejection(manifest))
    def test_pilot_failure(self):
        manifest = self.manifest(); manifest['success'] = False
        self.assertIn('Successful', self.rejection(manifest))
    def test_pilot_horizon(self):
        self.assertIn('horizon', self.rejection(self.manifest(), max_ticks=300))
    def test_bad_bounds(self):
        self.assertIn('Invalid bounds', self.rejection(self.manifest(), rounds=0))
    def test_existing_evidence_rejected(self):
        type(self).serial += 1; output = self.root / f'existing-{self.serial}'; output.mkdir()
        existing = output / 'rounds.json'; existing.write_text('do not replace')
        result = subprocess.run([sys.executable, str(ROOT / 'tools/phase03_run_hook_diagnostics.py'),
                                 '--phase', 'test', '--output', str(output), '--godot', '/not-invoked'],
                                cwd=ROOT, text=True, capture_output=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Preserve existing', result.stderr)
        self.assertEqual(existing.read_text(), 'do not replace')


if __name__ == '__main__': unittest.main()
