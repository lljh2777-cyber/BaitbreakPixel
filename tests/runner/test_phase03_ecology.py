"""P3.5 synthetic integrity/inference fixtures; not gameplay evidence."""
from __future__ import annotations
import copy
import math
import json
import tempfile
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from phase03_ecology_analysis import (MODES, POLICIES, GAME_MODES, STATES, STRATA,
    METRICS, COUNTERS, _Bootstrap, summarize, validate_rows)


def rows_for(seed=1):
    rows = []
    for game in GAME_MODES:
        for challenge in (True, False):
            for policy in POLICIES:
                for mode in MODES:
                    row = dict.fromkeys(METRICS, 0.0)
                    row.update({key: 0 for key in COUNTERS})
                    row.update(seed=seed, mode=mode, game_mode=game, challenge=challenge, policy=policy,
                        stratum_key=f'{game}/{"challenge" if challenge else "practice"}/{policy}',
                        npc_count=0 if mode == 'NoNPC' else 3, max_ticks=120, ticks=120,
                        duration=2.0, completed=True, winner='angler', reason='synthetic_fixture', home_win=False,
                        food_goal=60.0 if challenge else 18.0,
                        rules={'food_goal': 60., 'practice_goal': 18.}, player_food=6.0,
                        player_food_by_type={'cluster': 1., 'worm': 2., 'chunk': 3.},
                        npc_food=3.0 if mode in ('ForagingNPC', 'HookableNPC') else 0.,
                        npc_food_by_type={'cluster': 3.0 if mode in ('ForagingNPC', 'HookableNPC') else 0., 'worm': 0., 'chunk': 0.},
                        observed_npc_attachments=0, final_hook_target_fish_id=-1,
                        player_food_goal_tick=-1, minimum_available_food=10.,
                        player_satiety_min=70., player_satiety_final=70., player_satiety_mean=70.,
                        npc_active_seconds=0. if mode == 'NoNPC' else 6.,
                        npc_satiety_integral=0. if mode == 'NoNPC' else 420.,
                        npc_satiety_min=None if mode == 'NoNPC' else 70.,
                        npc_state_seconds={state: 6. if state == 'WANDER' and mode != 'NoNPC' else 0. for state in STATES})
                    sync_stats(row)
                    rows.append(row)
    return rows


def sync_stats(row):
    row['stats'] = {key: row[key] for key in ('hook_events', 'npc_hook_count', 'npc_escapes', 'npc_breaks', 'wrong_catches',
        'npc_hooked_seconds', 'npc_feeding_events', 'player_npc_food_contests', 'npc_target_switches')}
    row['stats'].update(food_consumed=row['player_food'], npc_food_consumed=row['npc_food'],
                        hooked_seconds=row['player_hooked_seconds'])


def make_hooked(row):
    row.update(npc_hook_count=2, observed_npc_attachments=2, wrong_catches=1,
               final_hook_target_fish_id=6, npc_occupied_ticks=60, npc_hooked_seconds=1.,
               successful_respawns=1, replacement_ids_allocated=1,
               player_food_while_npc_hooked=2., player_intake_ticks_while_npc_hooked=2)
    sync_stats(row)


class EcologyValidation(unittest.TestCase):
    def invalid(self, transform, text=None):
        rows = rows_for()
        transform(rows)
        with self.assertRaisesRegex((ValueError, KeyError), text or '.'):
            validate_rows(rows, [1], max_ticks=120)

    def test_complete_grid_and_13_cluster_summaries(self):
        result = summarize(rows_for(), [1], bootstrap=40, max_ticks=120)
        self.assertEqual(result['rounds'], 48)
        self.assertEqual(set(result['strata']), set(STRATA))
        self.assertEqual(result['overall_equal_weight_strata']['independent_seed_clusters'], 1)
        for stratum in result['strata'].values():
            self.assertEqual(len(stratum['paired_differences']), 6)
            self.assertEqual(stratum['passive_control_mismatched_seeds'], [])

    def test_duplicate_row(self): self.invalid(lambda rows: rows.append(copy.deepcopy(rows[0])), 'Duplicate')
    def test_missing_row(self): self.invalid(lambda rows: rows.pop(), 'Incomplete factorial')
    def test_unselected_seed(self): self.invalid(lambda rows: rows[0].update(seed=2), 'unselected')
    def test_seed_bool(self): self.invalid(lambda rows: rows[0].update(seed=True), 'seed')
    def test_duplicate_seeds(self):
        with self.assertRaises(ValueError): validate_rows(rows_for(), [1, 1], 120)
    def test_empty_seeds(self):
        with self.assertRaises(ValueError): validate_rows([], [], 120)
    def test_unknown_game(self): self.invalid(lambda rows: rows[0].update(game_mode='sandbox'))
    def test_unknown_policy(self): self.invalid(lambda rows: rows[0].update(policy='Oracle'))
    def test_unknown_arm(self): self.invalid(lambda rows: rows[0].update(mode='Other'))
    def test_nonboolean_challenge(self): self.invalid(lambda rows: rows[0].update(challenge=1))
    def test_bad_stratum_label(self): self.invalid(lambda rows: rows[0].update(stratum_key='wrong'))
    def test_bad_population(self): self.invalid(lambda rows: rows[0].update(npc_count=3))
    def test_changed_rule(self): self.invalid(lambda rows: rows[1]['rules'].update(food_goal=61), 'rules differ')
    def test_practice_goal_uses_effective_target(self): self.invalid(lambda rows: rows[12].update(food_goal=60), 'effective food goal')
    def test_goal_tick_matches_monotonic_score(self): self.invalid(lambda rows: rows[0].update(player_food_goal_tick=10))
    def test_goal_tick_beyond_elapsed(self): self.invalid(lambda rows: rows[0].update(player_food_goal_tick=121))
    def test_nonfinite(self): self.invalid(lambda rows: rows[0].update(player_food=math.nan))
    def test_bool_metric(self): self.invalid(lambda rows: rows[0].update(npc_food=False))
    def test_missing_measured_metric(self): self.invalid(lambda rows: rows[0].pop('npc_critical_seconds'))
    def test_fractional_counter(self): self.invalid(lambda rows: rows[0].update(hook_events=.5))
    def test_food_total(self): self.invalid(lambda rows: rows[0].update(player_food=7))
    def test_missing_food_type(self): self.invalid(lambda rows: rows[0]['player_food_by_type'].pop('chunk'))
    def test_negative_typed_intake(self): self.invalid(lambda rows: rows[0]['player_food_by_type'].update(chunk=-3))
    def test_no_npc_minimum_null(self): self.invalid(lambda rows: rows[0].update(npc_satiety_min=0))
    def test_npc_minimum_not_null(self): self.invalid(lambda rows: rows[1].update(npc_satiety_min=None))
    def test_exposure_is_not_round_time(self):
        validate_rows(rows_for(), [1], 120)  # 6 NPC-seconds legitimately exceeds a 2s round.
    def test_state_exposure_partition(self): self.invalid(lambda rows: rows[1]['npc_state_seconds'].update(FEED=.1))
    def test_unknown_state(self): self.invalid(lambda rows: rows[1]['npc_state_seconds'].update(CAPTURED=0))
    def test_satiety_exposure_upper_bound(self): self.invalid(lambda rows: rows[1].update(npc_satiety_integral=601))
    def test_starving_is_subset_of_critical(self): self.invalid(lambda rows: rows[1].update(npc_starving_seconds=.1))
    def test_player_minimum_bounded(self): self.invalid(lambda rows: rows[0].update(player_satiety_min=71))
    def test_nonhookable_event(self):
        self.invalid(lambda rows: make_hooked(rows[2]), 'Nonhookable')
    def test_passive_intake(self):
        self.invalid(lambda rows: rows[1].update(npc_food=1., npc_food_by_type={'cluster': 1., 'worm': 0., 'chunk': 0.}), 'Nonforaging')
    def test_observed_attachment_closure(self): self.invalid(lambda rows: rows[3].update(observed_npc_attachments=1))
    def test_hook_lifecycle_closure(self):
        self.invalid(lambda rows: rows[3].update(npc_hook_count=1, observed_npc_attachments=1))
    def test_respawn_closure(self):
        def corrupt(rows):
            make_hooked(rows[3]); rows[3]['pending_respawns'] = 1
        self.invalid(corrupt, 'capture/respawn')
    def test_actual_respawn_not_allocator(self):
        def corrupt(rows):
            make_hooked(rows[3]); rows[3]['replacement_ids_allocated'] = 0
        self.invalid(corrupt, 'respawn')
    def test_occupied_time_matches_authority(self):
        def corrupt(rows):
            make_hooked(rows[3]); rows[3]['npc_occupied_ticks'] = 59
        self.invalid(corrupt, 'occupied authority time')
    def test_occupied_intake_ticks_and_amount(self):
        def corrupt(rows):
            make_hooked(rows[3]); rows[3]['player_intake_ticks_while_npc_hooked'] = 0
        self.invalid(corrupt, 'intake amount/ticks')
    def test_occupied_intake_bounded(self):
        def corrupt(rows):
            make_hooked(rows[3]); rows[3]['player_food_while_npc_hooked'] = 7
        self.invalid(corrupt)
    def test_supply_subset(self): self.invalid(lambda rows: rows[0].update(no_food_supply_eligible_seconds=.1))
    def test_no_food_longest_subset(self): self.invalid(lambda rows: rows[0].update(longest_no_food_seconds=.1))
    def test_lifecycle_rate_reconciles(self): self.invalid(lambda rows: rows[0].update(lifecycle_per_sim_minute=1))
    def test_authority_stats_reconcile(self): self.invalid(lambda rows: rows[0]['stats'].update(food_consumed=9))
    def test_actual_ticks(self): self.invalid(lambda rows: rows[0].update(duration=1.9))
    def test_horizon_consistency(self): self.invalid(lambda rows: rows[0].update(max_ticks=121))
    def test_incomplete_not_labeled_loss(self): self.invalid(lambda rows: rows[0].update(completed=False))
    def test_incomplete_requires_full_horizon(self):
        self.invalid(lambda rows: rows[0].update(completed=False, winner='', reason='', ticks=119, duration=119/60), 'before selected horizon')
    def test_timeout_objective_stratification(self):
        rows = rows_for()
        rows[0].update(reason='timeout')
        rows[24].update(reason='timeout', winner='fish')
        validate_rows(rows, [1], 120)
        self.invalid(lambda rows: rows[24].update(reason='timeout', winner='angler'), 'Timeout')
    def test_incomplete_and_occupied_round_retained(self):
        rows = rows_for(); make_hooked(rows[3]); rows[3].update(completed=False, winner='', reason='')
        result = summarize(rows, [1], 40, 120)
        data = result['strata'][STRATA[0]]['modes']['HookableNPC']
        self.assertEqual(data['incomplete_seeds'], [1])
        self.assertEqual(data['metrics']['fish_win_fraction']['mean'], 0)
        self.assertEqual(data['metrics']['fish_win_upper_bound']['mean'], 1)
        self.assertEqual(data['event_coverage']['occupied_intake_rounds'], 1)
    def test_passive_mismatch_preserved(self):
        rows = rows_for(); rows[1]['stats']['additional_counter'] = 1
        result = summarize(rows, [1], 40, 120)
        self.assertEqual(result['strata'][STRATA[0]]['passive_control_mismatched_seeds'], [1])
        self.assertEqual(result['rounds'], 48)
    def test_undefined_no_npc_exposure_not_zero(self):
        result = summarize(rows_for(), [1], 40, 120)
        data = result['strata'][STRATA[0]]
        self.assertIsNone(data['modes']['NoNPC']['metrics']['npc_satiety_mean']['mean'])
        paired = data['paired_differences']['PassiveNPC minus NoNPC']['npc_satiety_mean']
        self.assertIsNone(paired['mean']); self.assertIsNone(paired['paired_bootstrap_95_percent'])
    def test_cluster_count_not_rounds_or_strata(self):
        rows = rows_for(1) + rows_for(2)
        # Every Hookable stratum changes identically within seed; 12 repeats
        # must not manufacture 24 independent experimental units.
        for row in rows:
            if row['seed'] == 2 and row['mode'] == 'HookableNPC':
                row['player_food'] = 12.; row['player_food_by_type']['chunk'] = 9.; sync_stats(row)
        result = summarize(rows, [1, 2], 100, 120)
        effects = result['overall_equal_weight_strata']['paired_differences']['HookableNPC minus ForagingNPC']['player_food']
        self.assertEqual(effects['paired_seeds'], 2)
        self.assertEqual(effects['mean'], 3.)
        self.assertEqual(effects['paired_bootstrap_95_percent'], [0., 6.])
    def test_deterministic_bootstrap(self):
        a = _Bootstrap(4, 100).estimate([1., 2., 4., -3.])
        b = _Bootstrap(4, 100).estimate([1., 2., 4., -3.])
        self.assertEqual(a, b)
    def test_single_seed_ci_undefined(self):
        self.assertIsNone(_Bootstrap(1, 40).estimate([2.])['paired_bootstrap_95_percent'])
    def test_constant_ci_caveat(self):
        result = _Bootstrap(2, 40).estimate([0., 0.])
        self.assertEqual(result['paired_bootstrap_95_percent'], [0., 0.])
        self.assertEqual(result['status'], 'constant_observed_differences')
    def test_partial_undefined_support_no_selected_pair_ci(self):
        result = _Bootstrap(2, 40).estimate([1., None])
        self.assertEqual(result['paired_seeds'], 1)
        self.assertIsNone(result['mean'])
        self.assertIsNone(result['paired_bootstrap_95_percent'])
    def test_too_few_bootstraps(self):
        with self.assertRaises(ValueError): summarize(rows_for(), [1], 39, 120)


class EcologyProvenance(unittest.TestCase):
    def pilot(self):
        return {'phase': 'pilot', 'success': True, 'source_stable': True,
                'seeds': [10, 11], 'source_sha256': {'synthetic': 'digest'}, 'max_ticks': 120}

    def admission(self, pilot=None, seeds=None, hashes=None, max_ticks=120):
        from phase03_run_ecology import admit_pilot
        return admit_pilot(pilot or self.pilot(), seeds or [20, 21],
                           hashes or {'synthetic': 'digest'}, max_ticks)

    def test_admit_disjoint_source_stable_pilot(self):
        self.assertIsNone(self.admission())

    def test_reject_unsuccessful_pilot(self):
        pilot = self.pilot(); pilot['success'] = False
        with self.assertRaisesRegex(ValueError, 'Successful'): self.admission(pilot)

    def test_reject_unstable_pilot(self):
        pilot = self.pilot(); pilot['source_stable'] = False
        with self.assertRaisesRegex(ValueError, 'source-stable'): self.admission(pilot)

    def test_reject_wrong_phase(self):
        pilot = self.pilot(); pilot['phase'] = 'test'
        with self.assertRaisesRegex(ValueError, 'pilot'): self.admission(pilot)

    def test_reject_overlap(self):
        with self.assertRaisesRegex(ValueError, 'overlaps'): self.admission(seeds=[11, 20])

    def test_reject_source_change(self):
        with self.assertRaisesRegex(ValueError, 'Source changed'): self.admission(hashes={'synthetic': 'new'})

    def test_reject_horizon_change(self):
        with self.assertRaisesRegex(ValueError, 'horizon'): self.admission(max_ticks=121)

    def test_fingerprints_capture_runtime_controller_harness_protocol_analyzer(self):
        from phase03_run_ecology import fingerprints, HARNESS_FILES
        # Synthetic source tree is preserved; no bulk/recursive fixture deletion.
        project = Path(tempfile.mkdtemp(prefix='p35-ecology-provenance-'))
        (project / 'scripts').mkdir()
        (project / 'tools').mkdir()
        (project / 'scripts/world_simulation.gd').write_text('synthetic runtime')
        (project / 'project.godot').write_text('synthetic project')
        for name in HARNESS_FILES: (project / name).write_text('synthetic ' + name)
        first = fingerprints(project)
        self.assertIn('scripts/world_simulation.gd', first)
        for name in HARNESS_FILES:
            self.assertIn(name, first)
            old = (project / name).read_text()
            (project / name).write_text(old + ' change')
            self.assertNotEqual(fingerprints(project)[name], first[name])
            (project / name).write_text(old)
        (project / 'scripts/world_simulation.gd').write_text('mutated runtime')
        self.assertNotEqual(fingerprints(project)['scripts/world_simulation.gd'], first['scripts/world_simulation.gd'])


class EcologyMerge(unittest.TestCase):
    def setUp(self):
        # Explicitly synthetic, preserved evidence fixtures; no recursive cleanup.
        self.root = Path(tempfile.mkdtemp(prefix='p35-ecology-merge-tests-'))
        self.project = self.root / 'project'; self.project.mkdir()
        self.hashes = {'tools/phase03_ecology_analysis.py': 'synthetic-analyzer-digest',
                       'scripts/world_simulation.gd': 'synthetic-runtime-digest'}
        self.pilot = self.write_run('pilot', [10], 'pilot')
        self.first = self.write_run('first', [20], 'heldout')
        self.second = self.write_run('second', [21], 'heldout')
        self.output = self.root / 'merged'

    def write_run(self, name, seeds, phase):
        path = self.root / name; path.mkdir()
        rows = [row for seed in seeds for row in rows_for(seed)]
        summary = {'format': 'phase03-ecology-diagnostics-v1', 'rows': len(rows),
                   'paired_seeds': len(seeds), 'first_seed': min(seeds), 'last_seed': max(seeds),
                   'max_ticks': 120, 'strata_per_seed': 12, 'modes': list(MODES)}
        provenance = {'format': 'phase03-ecology-provenance-v1', 'phase': phase,
                      'success': True, 'source_stable': True, 'seeds': seeds,
                      'max_ticks': 120, 'source_sha256': self.hashes, 'project': str(self.project),
                      'pilot': str(self.root / 'pilot') if phase == 'heldout' else None,
                      'execution': {'returncode': 0, 'timed_out': False, 'launch_error': False}}
        for filename, contents in [('rounds.json', rows), ('summary.json', summary), ('provenance.json', provenance)]:
            (path / filename).write_text(json.dumps(contents))
        (path / 'run.log').write_text('Synthetic fixture, not gameplay evidence.\n')
        return path

    def change(self, path, filename, transform):
        data = json.loads((path / filename).read_text()); transform(data)
        (path / filename).write_text(json.dumps(data))

    def merge(self, paths=None, seeds=None, hashes=None):
        from phase03_merge_ecology import merge_runs
        with patch('phase03_merge_ecology.fingerprints', return_value=hashes or self.hashes):
            return merge_runs(paths or [self.first, self.second], seeds or [20, 21], self.output,
                              project=self.project, bootstrap=40)

    def rejection(self, message='.', **kwargs):
        with self.assertRaisesRegex((ValueError, KeyError, OSError), message): self.merge(**kwargs)
        self.assertFalse(self.output.exists())

    def test_complete_merge_preserves_every_row_and_input_digest(self):
        report = self.merge()
        self.assertTrue(report['success']); self.assertEqual(report['rows'], 96)
        self.assertEqual(report['seeds'], [20, 21]); self.assertEqual(len(report['inputs']), 2)
        self.assertEqual(set(report['inputs'][0]['file_sha256']), {'rounds.json', 'provenance.json', 'summary.json', 'run.log'})
        actual = json.loads((self.output / 'rounds.json').read_text())
        expected = rows_for(20) + rows_for(21)
        self.assertEqual(actual, expected)
        comparison = json.loads((self.output / 'comparison.json').read_text())
        self.assertEqual(comparison['paired_seeds'], 2)
        self.assertEqual(comparison['overall_equal_weight_strata']['independent_seed_clusters'], 2)

    def test_reject_missing_expected_seed(self): self.rejection('exactly', seeds=[20, 21, 22])
    def test_reject_extra_seed(self): self.rejection('exactly', seeds=[20])
    def test_reject_duplicate_path(self): self.rejection('distinct', paths=[self.first, self.first])
    def test_reject_overlap(self):
        overlap = self.write_run('overlap', [20], 'heldout')
        self.rejection('overlap', paths=[self.first, overlap])
    def test_reject_failed_shard(self):
        self.change(self.first, 'provenance.json', lambda d: d.update(success=False))
        self.rejection('Unsuccessful')
    def test_reject_string_success(self):
        self.change(self.first, 'provenance.json', lambda d: d.update(success='true'))
        self.rejection('Unsuccessful')
    def test_reject_unstable_shard(self):
        self.change(self.first, 'provenance.json', lambda d: d.update(source_stable=False))
        self.rejection('unstable')
    def test_reject_wrong_phase_shard(self):
        self.change(self.first, 'provenance.json', lambda d: d.update(phase='pilot'))
        self.rejection('phase')
    def test_reject_contradictory_execution(self):
        self.change(self.first, 'provenance.json', lambda d: d['execution'].update(timed_out=True))
        self.rejection('Execution')
    def test_reject_replaced_runtime(self):
        self.rejection('Current source', hashes={**self.hashes, 'new-file': 'changed'})
    def test_reject_incompatible_shard_hashes(self):
        self.change(self.second, 'provenance.json', lambda d: d['source_sha256'].update(extra='changed'))
        self.rejection('Incompatible shard source_sha256')
    def test_reject_incompatible_project(self):
        self.change(self.second, 'provenance.json', lambda d: d.update(project=str(self.root / 'elsewhere')))
        self.rejection('Incompatible shard project')
    def test_reject_incompatible_pilot(self):
        self.change(self.second, 'provenance.json', lambda d: d.update(pilot=str(self.root / 'other-pilot')))
        self.rejection('Incompatible shard pilot')
    def test_reject_horizon_disagreement(self):
        self.change(self.second, 'provenance.json', lambda d: d.update(max_ticks=121))
        self.rejection('Summary contradicts')
    def test_reject_truncated_rows(self):
        self.change(self.second, 'rounds.json', lambda d: d.pop())
        self.rejection('Summary contradicts')
    def test_reject_incomplete_grid_despite_forged_row_count(self):
        self.change(self.second, 'rounds.json', lambda d: d.pop())
        self.change(self.second, 'summary.json', lambda d: d.update(rows=47))
        self.rejection('Incomplete factorial')
    def test_reject_failed_pilot(self):
        self.change(self.pilot, 'provenance.json', lambda d: d.update(success=False))
        self.rejection('Unsuccessful')
    def test_reject_changed_pilot_source(self):
        self.change(self.pilot, 'provenance.json', lambda d: d['source_sha256'].update(changed='yes'))
        self.rejection('Source changed')
    def test_existing_evidence_never_overwritten(self):
        self.output.mkdir(); sentinel = self.output / 'rounds.json'; sentinel.write_text('preserve')
        with self.assertRaisesRegex(ValueError, 'Preserve'): self.merge()
        self.assertEqual(sentinel.read_text(), 'preserve')
    def test_source_change_during_analysis_rejected(self):
        from phase03_merge_ecology import merge_runs
        with patch('phase03_merge_ecology.fingerprints', side_effect=[self.hashes, {}]):
            with self.assertRaisesRegex(ValueError, 'changed during merge'):
                merge_runs([self.first, self.second], [20, 21], self.output, project=self.project, bootstrap=40)
        self.assertFalse(self.output.exists())
    def test_input_change_during_analysis_rejected(self):
        from phase03_merge_ecology import merge_runs
        def mutate(*args, **kwargs):
            result = summarize(*args, **kwargs)
            (self.first / 'run.log').write_text('changed during analysis')
            return result
        with patch('phase03_merge_ecology.fingerprints', return_value=self.hashes), patch('phase03_merge_ecology.summarize', side_effect=mutate):
            with self.assertRaisesRegex(ValueError, 'changed during merge'):
                merge_runs([self.first, self.second], [20, 21], self.output, project=self.project, bootstrap=40)
        self.assertFalse(self.output.exists())


if __name__ == '__main__': unittest.main()
