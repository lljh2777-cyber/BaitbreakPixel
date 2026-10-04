"""Fail-closed defenses for the schema15/schema16 exact-payload proof."""
from __future__ import annotations
import copy
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import phase04_compare_snapshot as probe


def report(schema):
    reference = {'id': 'pond_v2', 'revision': 1, 'contract_version': 1, 'content_hash': 'f' * 64}
    rows = []
    for spec in probe.SCENARIOS:
        points = []
        for tick in [-1, *range(0, spec['ticks'], 30), spec['ticks'] - 1]:
            cp = {'input_tick': tick, 'simulation_tick': max(0, tick + 1),
                'fish_wire_valid': True, 'angler_wire_valid': True,
                'rng_seed': str(spec['seed']), 'rng_state': '-9184344280088230356',
                'snapshot_bytes': 100, 'raw_snapshot_bytes': 156 if schema == 15 else 324,
                **{key: 'a' * 64 for key in probe.HASH_FIELDS},
                **{key: ('b' if schema == 15 else 'c') * 64 for key in probe.RAW_HASH_FIELDS}}
            for kind in ('authority', 'angler', 'fish'):
                cp[kind + '_metadata'] = {'schema': (1 if schema == 15 else 2) if kind == 'fish' else schema,
                    'map': 'pond_v2' if schema == 15 else copy.deepcopy(reference)}
            points.append(cp)
        rows.append({'scenario': dict(spec), 'checkpoints': points,
            'input_trace_sha256': 'd' * 64, 'every_tick_authority_sha256': 'e' * 64,
            'witnesses': {key: key in probe.REQUIRED_WITNESSES.get(spec['name'], ()) for key in probe.WITNESSES},
            'outcome': {**{key: 0 for key in probe.OUTCOME_FIELDS},
                'reason': '', 'match_over': False, 'next_bait_id': 5, 'next_fish_id': spec['count'] + 2,
                'score': 4.0 if spec['name'] == 'feeding_refill' else 0.0,
                'npc_food': 4.0 if spec['name'] == 'feeding_refill' else 0.0,
                'hook_events': 1 if spec['name'] == 'player_entry' else 0,
                'wrap_good': 1 if spec['name'] == 'player_wrap' else 0,
                'wrong_catches': 1 if spec['name'] == 'npc_capture_respawn' else 0,
                'net_catches': 1 if spec['name'] == 'net_player' else 0}})
    return {'format': 'phase04-snapshot-equivalence-v1', 'engine': '4.7.2-stable (official)',
        'schema': schema, 'registry_ref': reference, 'probe': 'bounded',
        'metadata_exclusions': ['schema', 'map_id' if schema == 15 else 'map_ref'],
        'passed': 4221, 'failed': 0, 'scenarios': rows}


class ReportTests(unittest.TestCase):
    def test_exact_schema_and_registry_checked_only_metadata_exclusions_pass(self):
        result = probe.compare_reports(report(15), report(16))
        self.assertTrue(result['success'], result)
        self.assertEqual((result['scenario_count'], result['input_ticks_per_build'], result['checkpoint_count_per_build']), (8, 2100, 86))

    def test_old_to_old_and_new_to_new_are_not_migration_proof(self):
        for schema in (15, 16):
            self.assertFalse(probe.compare_reports(report(schema), report(schema))['success'])

    def test_report_structure_tampering_fails_closed(self):
        mutations = [lambda r: r.update(passed=0), lambda r: r.update(passed=True),
            lambda r: r.update(failed=1), lambda r: r.update(schema=15),
            lambda r: r.update(scenarios=[]), lambda r: r.update(scenarios=[None] * 8),
            lambda r: r.update(extra=True), lambda r: r.pop('probe'),
            lambda r: r['scenarios'][0].update(checkpoints=[]),
            lambda r: r['scenarios'][0]['checkpoints'].__setitem__(0, None),
            lambda r: r['scenarios'][0].update(witnesses={}),
            lambda r: r['scenarios'][0].update(every_tick_authority_sha256=''),
            lambda r: r['scenarios'][0]['scenario'].update(ticks=1),
            lambda r: r['scenarios'][0]['checkpoints'][0].update(fish_wire_valid=False),
            lambda r: r['scenarios'][0]['checkpoints'][0].update(rng_state=9184344280088230356),
            lambda r: r['scenarios'][0]['checkpoints'][0].pop('npc_observations_sha256')]
        for index, mutation in enumerate(mutations):
            current = report(16); mutation(current)
            with self.subTest(index=index): self.assertFalse(probe.compare_reports(report(15), current)['success'])
        for malformed in (None, [], 'report', 16):
            self.assertFalse(probe.compare_reports(malformed, malformed)['success'])

    def test_exact_field_allowlist_rejects_any_broad_normalization(self):
        for excluded in ('state', 'rig', 'rng_seed', 'rng_state', 'bait_profile_version', 'npc_profile_version'):
            current = report(16); current['metadata_exclusions'].append(excluded)
            self.assertFalse(probe.compare_reports(report(15), current)['success'])
        for field in probe.HASH_FIELDS:
            current = report(16); current['scenarios'][0]['checkpoints'][0][field] = '0' * 64
            result = probe.compare_reports(report(15), current)
            self.assertFalse(result['success'], field)
            self.assertTrue(any('differing checkpoint' in error for error in result['differences']))

    def test_registry_hash_revision_contract_and_metadata_must_match(self):
        for field, value in (('id', 'unknown'), ('revision', 2), ('revision', True),
                             ('contract_version', 2), ('content_hash', 'bad')):
            current = report(16); current['registry_ref'][field] = value
            self.assertFalse(probe.compare_reports(report(15), current)['success'])
        current = report(16); current['registry_ref']['content_hash'] = '0' * 64
        for row in current['scenarios']:
            for cp in row['checkpoints']:
                for kind in ('authority', 'angler', 'fish'): cp[kind + '_metadata']['map'] = current['registry_ref']
        self.assertFalse(probe.compare_reports(report(15), current)['success'])
        for kind in ('authority', 'angler', 'fish'):
            for field, value in (('schema', 1), ('map', 'pond_v2'), ('map', {})):
                current = report(16); current['scenarios'][0]['checkpoints'][0][kind + '_metadata'][field] = value
                self.assertFalse(probe.compare_reports(report(15), current)['success'])

    def test_metadata_change_must_be_real_and_envelope_size_delta_constant(self):
        for raw_hash in probe.RAW_HASH_FIELDS:
            current = report(16); current['scenarios'][0]['checkpoints'][0][raw_hash] = 'b' * 64
            self.assertFalse(probe.compare_reports(report(15), current)['success'])
        current = report(16); current['scenarios'][0]['checkpoints'][0]['raw_snapshot_bytes'] += 4
        self.assertFalse(probe.compare_reports(report(15), current)['success'])

    def test_equal_missing_behavior_witnesses_and_fake_outcomes_are_rejected(self):
        for schema in (15, 16):
            candidate = report(schema)
            candidate['scenarios'][2]['witnesses']['refill'] = False
            self.assertTrue(probe.report_contract(candidate, schema, 'report'))
            candidate = report(schema); candidate['scenarios'][2]['outcome']['score'] = 0
            self.assertTrue(probe.report_contract(candidate, schema, 'report'))
            candidate = report(schema); candidate['scenarios'][0]['outcome']['match_over'] = 0
            self.assertTrue(probe.report_contract(candidate, schema, 'report'))
            candidate = report(schema); candidate['scenarios'][0]['scenario']['challenge'] = 1
            self.assertTrue(probe.report_contract(candidate, schema, 'report'))
        candidate = report(16)
        candidate['scenarios'][0]['checkpoints'][0]['fish_metadata']['map']['revision'] = True
        self.assertTrue(probe.report_contract(candidate, 16, 'report'))

    def test_same_bad_truncated_reports_never_pass_even_with_equal_payloads(self):
        old, current = report(15), report(16)
        for item in (old, current):
            item['scenarios'][0]['checkpoints'][0]['snapshot_sha256'] = ''
        self.assertFalse(probe.compare_reports(old, current)['success'])

    def test_lossless_rng_and_exact_inputs_outcomes_witnesses_checked(self):
        for field in ('input_trace_sha256', 'every_tick_authority_sha256'):
            current = report(16); current['scenarios'][0][field] = '0' * 64
            self.assertFalse(probe.compare_reports(report(15), current)['success'])
        for field in ('rng_seed', 'rng_state', 'simulation_tick', 'snapshot_bytes'):
            current = report(16); cp = current['scenarios'][0]['checkpoints'][0]
            cp[field] = '123' if field.startswith('rng_') else 120
            self.assertFalse(probe.compare_reports(report(15), current)['success'])
        for field in ('witnesses', 'outcome'):
            current = report(16); key = next(iter(current['scenarios'][0][field]))
            current['scenarios'][0][field][key] = True if field == 'witnesses' else 42
            self.assertFalse(probe.compare_reports(report(15), current)['success'])

    def test_cross_engine_rejected(self):
        current = report(16); current['engine'] = '4.6.3'
        self.assertFalse(probe.compare_reports(report(15), current)['success'])


class SourceTests(unittest.TestCase):
    def source(self):
        historical = (ROOT / probe.HISTORICAL[0]).read_bytes()
        baseline = {name: b'historical' for name in probe.HISTORICAL}
        baseline[probe.HISTORICAL[0]] = historical
        baseline['scripts/world_snapshot.gd'] = b'old schema'
        current = dict(baseline)
        current[probe.HARNESS] = (ROOT / probe.HARNESS).read_bytes()
        current['scripts/world_snapshot.gd'] = b'new schema'
        return baseline, current

    def test_owned_paths_accepted_without_claiming_review(self):
        baseline, current = self.source()
        self.assertTrue(probe.source_contract(baseline, current)['success'])
        for path in probe.RUNTIME_PATHS:
            baseline[path] = b'old'; current[path] = b'changed'
        self.assertTrue(probe.source_contract(baseline, current)['success'])

    def test_historical_tools_harness_and_locks_are_not_updateable(self):
        for path in probe.HISTORICAL:
            baseline, current = self.source(); current[path] += b'change'
            self.assertFalse(probe.source_contract(baseline, current)['success'], path)

    def test_new_removed_or_out_of_scope_runtime_fails(self):
        for name in ('scripts/rope.gd', 'scripts/maps/pond_v2_map.gd', 'scripts/pond_view.gd',
                     'assets/texture.png', 'scenes/main.tscn'):
            baseline, current = self.source(); baseline[name] = b'old'; current[name] = b'changed'
            self.assertFalse(probe.source_contract(baseline, current)['success'], name)
        baseline, current = self.source(); current['scripts/new.gd'] = b'new'
        self.assertFalse(probe.source_contract(baseline, current)['success'])
        baseline, current = self.source(); current.pop('scripts/world_snapshot.gd')
        self.assertFalse(probe.source_contract(baseline, current)['success'])

    def test_release_metadata_allowance_is_one_exact_string_only(self):
        for name, (old, new) in probe.METADATA_REPLACEMENTS.items():
            baseline, current = self.source(); baseline[name] = b'prefix\n' + old; current[name] = b'prefix\n' + new
            self.assertTrue(probe.source_contract(baseline, current)['success'])
            current[name] += b'gameplay edit'
            self.assertFalse(probe.source_contract(baseline, current)['success'])
            baseline[name] = old + old; current[name] = new + new
            self.assertFalse(probe.source_contract(baseline, current)['success'])

    def test_scenario_and_input_tape_function_byte_lock(self):
        baseline, current = self.source()
        for name in probe.TAPE_FUNCTIONS:
            self.assertEqual(probe.function_source(baseline[probe.HISTORICAL[0]], name), probe.function_source(current[probe.HARNESS], name))
            altered = dict(current)
            target = probe.function_source(altered[probe.HARNESS], name)
            altered[probe.HARNESS] = altered[probe.HARNESS].replace(target, target + b'\n\tpass', 1)
            self.assertFalse(probe.source_contract(baseline, altered)['success'], name)

    def test_current_historical_evidence_equals_committed_git_bytes(self):
        committed = probe.committed_sources(ROOT)
        for name in probe.HISTORICAL:
            self.assertEqual(committed[name], (ROOT / name).read_bytes(), name)

    def test_missing_symlink_and_unexpected_frozen_runtime_fail(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for folder in ('scripts', 'assets', 'scenes'): (root / folder).mkdir()
            for name in ('project.godot', *probe.HISTORICAL):
                path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(b'old')
            committed = probe.read_sources(root)
            probe.verify_frozen(root, committed)
            (root / 'scripts/extra.gd').write_bytes(b'extra')
            with self.assertRaisesRegex(ValueError, 'differs'): probe.verify_frozen(root, committed)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); (root / 'scripts').symlink_to(ROOT / 'scripts')
            with self.assertRaisesRegex(ValueError, 'symlink'): probe.read_sources(root)


class NetTests(unittest.TestCase):
    def report(self):
        return {'engine': '4.7.2', 'cases': [
            {'input': ('same-tick batch', 'separate authority ticks')[index],
             'checkpoints': [{'tick': tick, 'authority_restore': True, 'angler_wire_valid': True,
                'fish_wire_valid': not (index == 0 and tick >= 0), 'fish_wire_apply': not (index == 0 and tick >= 0),
                'net_age_variant_type': 'int' if index == 0 and tick >= 0 else 'float',
                'net_age': 0 if index == 0 and tick >= 0 else 0.0}
                for tick in (-1, 0, 1, 2, 30, 60, 119)]} for index in (0, 1)]}

    def test_preserves_inherited_failure_and_separate_tick_success(self):
        self.assertTrue(probe.compare_net_reports(self.report(), self.report())['success'])

    def test_equal_incomplete_or_weakened_reports_rejected(self):
        mutations = [lambda r: r.update(cases=[]), lambda r: r.update(cases=[None, None]),
            lambda r: r['cases'][0].update(checkpoints=[]),
            lambda r: r['cases'][0]['checkpoints'][1].update(fish_wire_valid=True),
            lambda r: r['cases'][1]['checkpoints'][1].update(fish_wire_apply=False),
            lambda r: r['cases'][0]['checkpoints'][1].update(net_age_variant_type='float')]
        for mutation in mutations:
            report = self.report(); mutation(report)
            self.assertFalse(probe.compare_net_reports(report, copy.deepcopy(report))['success'])
        self.assertFalse(probe.compare_net_reports([], [])['success'])


if __name__ == '__main__':
    unittest.main()
