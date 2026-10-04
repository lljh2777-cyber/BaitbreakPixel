"""Fail-closed defenses for the P4.2 frozen old-authority/context comparison."""
from __future__ import annotations
import copy
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import phase04_compare_authority as probe


def approved(files):
    return {'format': 'phase04-authority-reviewed-runtime-v1', 'baseline_commit': probe.COMMIT,
            'review_status': 'reviewed',
            'files': {name: {'sha256': probe.sha(data), 'reason': 'Reviewed authority-only migration'}
                      for name, data in files.items()}}


class ArchiveTests(unittest.TestCase):
    def archive(self, name, kind=tarfile.REGTYPE):
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w') as archive:
            entry = tarfile.TarInfo(name); entry.type = kind
            if kind == tarfile.REGTYPE:
                entry.size = 4; archive.addfile(entry, io.BytesIO(b'test'))
            else:
                entry.linkname = 'outside'; archive.addfile(entry)
        stream.seek(0)
        return tarfile.open(fileobj=stream)

    def test_regular_files_preserve_bytes(self):
        with tempfile.TemporaryDirectory() as tmp, self.archive('scripts/file.gd') as archive:
            probe.extract_baseline_archive(archive, Path(tmp))
            self.assertEqual((Path(tmp) / 'scripts/file.gd').read_bytes(), b'test')

    def test_path_traversal_absolute_windows_and_links_rejected_before_extraction(self):
        for name, kind in [('../escape', tarfile.REGTYPE), ('/escape', tarfile.REGTYPE),
                           ('C:/escape', tarfile.REGTYPE), ('scripts\\escape', tarfile.REGTYPE),
                           ('link', tarfile.SYMTYPE), ('link', tarfile.LNKTYPE), ('device', tarfile.CHRTYPE)]:
            with self.subTest(name=name, kind=kind), tempfile.TemporaryDirectory() as tmp, self.archive(name, kind) as archive:
                with self.assertRaises(ValueError): probe.extract_baseline_archive(archive, Path(tmp))
                self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_frozen_source_edit_extra_and_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / 'scripts').mkdir(); path = root / 'scripts/a.gd'; path.write_bytes(b'old')
            hashes = {'scripts/a.gd': probe.sha(b'old')}
            probe.verify_frozen(root, hashes)
            path.write_bytes(b'new')
            with self.assertRaises(ValueError): probe.verify_frozen(root, hashes)
            path.write_bytes(b'old'); (root / 'scripts/extra.gd').write_text('extra')
            with self.assertRaises(ValueError): probe.verify_frozen(root, hashes)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / 'scripts').mkdir(); (root / 'target').write_bytes(b'old')
            (root / 'scripts/a.gd').symlink_to(root / 'target')
            with self.assertRaises(ValueError): probe.verify_frozen(root, {'scripts/a.gd': probe.sha(b'old')})

    def test_committed_lock_and_historical_harness_match_actual_archive(self):
        archive = probe.tracked_archive(ROOT); files = probe.archive_files(archive)
        lock = json.loads((ROOT / probe.LOCK).read_text())
        runtime = {name: digest for name, digest in files.items()
                   if name.startswith(('scripts/', 'assets/', 'scenes/')) or name == 'project.godot'}
        self.assertEqual(lock['runtime_sha256'], runtime)
        self.assertEqual(lock['harness_sha256'], files[probe.HARNESS])
        self.assertEqual(lock['net_probe_sha256'], files[probe.NET_PROBE])
        probe.historical_contract(ROOT, lock)

    def test_fingerprints_detect_changed_added_and_removed_test_sources(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / 'project.godot').write_text('project')
            (root / 'tests').mkdir(); first = probe.fingerprints(root)
            test = root / 'tests/example.gd'; test.write_text('test')
            second = probe.fingerprints(root); self.assertNotEqual(first, second)
            test.write_text('changed'); self.assertNotEqual(second, probe.fingerprints(root))

    def test_frozen_manifest_never_silently_replaced(self):
        lock = json.loads((ROOT / probe.LOCK).read_text())
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'frozen'; path.mkdir()
            (path / 'baseline-manifest.json').write_text('{}')
            with self.assertRaisesRegex(ValueError, 'never silently replace'):
                probe.freeze(ROOT, path, lock)
            self.assertEqual((path / 'baseline-manifest.json').read_text(), '{}')



class RuntimeTests(unittest.TestCase):
    def contract(self, relative=None, old=b'old', new=b'old', review_change=False, extra=None, tweak=None):
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp) / 'a', Path(tmp) / 'b'
            baseline = {'scripts/world_simulation.gd': b'old legacy authority'}
            current = {'scripts/world_simulation.gd': b'new context authority',
                       'scripts/maps/map_context.gd': b'context', 'scripts/maps/map_geometry.gd': b'geometry'}
            reviewed = dict(current)
            if relative:
                baseline[relative] = old; current[relative] = new
                if review_change: reviewed[relative] = new
            if extra: current[extra] = b'extra'
            for base, files in ((a, baseline), (b, current)):
                for name, data in files.items():
                    path = base / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)
            review = approved(reviewed)
            if tweak: tweak(review)
            return probe.runtime_contract(a, b, {'runtime_sha256': {name: probe.sha(data) for name, data in baseline.items()}}, review)

    def test_exact_reviewed_authority_context_change_allowed(self):
        self.assertTrue(self.contract()['success'])
        self.assertTrue(self.contract('scripts/angler_brain.gd', b'old', b'new', True)['success'])

    def test_unreviewed_authority_change_and_stale_hash_fail(self):
        self.assertFalse(self.contract('scripts/angler_brain.gd', b'old', b'new')['success'])
        self.assertFalse(self.contract(tweak=lambda review: review['files']['scripts/world_simulation.gd'].update(sha256='0' * 64))['success'])

    def test_review_must_be_completed_and_include_world_context_geometry(self):
        self.assertFalse(self.contract(tweak=lambda review: review.update(review_status='pending'))['success'])
        self.assertFalse(self.contract(tweak=lambda review: review['files'].pop('scripts/maps/map_geometry.gd'))['success'])
        self.assertFalse(self.contract(tweak=lambda review: review.update(baseline_commit='wrong'))['success'])

    def test_malformed_review_is_a_failed_gate(self):
        self.assertFalse(self.contract(tweak=lambda review: review.update(files=[]))['success'])
        self.assertFalse(self.contract(tweak=lambda review: review['files'].update({'scripts/world_simulation.gd': None}))['success'])

    def test_snapshot_wire_presentation_assets_never_become_review_exemptions(self):
        for name in ('scripts/world_snapshot.gd', 'scripts/fish_network_observation.gd',
                     'scripts/angler_network_observation.gd', 'scripts/network_session.gd',
                     'scripts/pond_view.gd', 'scripts/pond_layout.gd', 'assets/example.png', 'scenes/main.tscn'):
            with self.subTest(path=name):
                self.assertFalse(self.contract(name, b'old', b'changed', True)['success'])

    def test_release_markers_are_exact_substitutions_not_file_exemptions(self):
        for name, (old, new) in probe.METADATA_REPLACEMENTS.items():
            with self.subTest(path=name):
                self.assertTrue(self.contract(name, old + b'\n', new + b'\n')['success'])
                self.assertFalse(self.contract(name, old + b'\n', new + b'\nextra')['success'])
                self.assertFalse(self.contract(name, old + old, new + new)['success'])

    def test_added_runtime_files_need_exact_path_and_review(self):
        for name in ('scripts/new.gd', 'scripts/maps/other_context.gd', 'scripts/maps/map_context.gd.uid',
                     'assets/new.png', 'scenes/new.tscn'):
            with self.subTest(path=name): self.assertFalse(self.contract(extra=name)['success'])


class ComparisonTests(unittest.TestCase):
    def report(self):
        rows = []
        for spec in probe.SCENARIOS:
            checkpoints = []
            for tick in [-1, *range(0, spec['ticks'], 30), spec['ticks'] - 1]:
                checkpoints.append({'input_tick': tick, 'simulation_tick': max(0, tick + 1),
                    'fish_wire_valid': True, 'angler_wire_valid': True, 'snapshot_bytes': 10,
                    'rng_seed': '17401', 'rng_state': '-12345678901234567',
                    **{key: 'a' * 64 for key in probe.CHECKPOINT_HASHES}})
            rows.append({'scenario': dict(spec), 'checkpoints': checkpoints,
                'input_trace_sha256': 'b' * 64, 'every_tick_authority_sha256': 'c' * 64,
                'witnesses': {key: False for key in ('attached', 'entry', 'net_sweep', 'net_warning',
                    'npc_hooked', 'npc_landing', 'npc_replaced', 'qte', 'refill', 'wrap')},
                'outcome': {key: 0 for key in ('hook_events', 'match_over', 'net_catches', 'next_bait_id',
                    'next_fish_id', 'npc_food', 'reason', 'score', 'wrap_good', 'wrong_catches')}})
        return {'format': 'phase04-map-baseline-v1', 'engine': '4.7.2-stable (official)',
                'schema': 15, 'passed': 1690, 'failed': 0, 'scenarios': rows}

    def test_exact_valid_report_has_8_scenarios_2100_ticks_86_checkpoints(self):
        result = probe.compare_reports(self.report(), self.report())
        self.assertTrue(result['success'], result)
        self.assertEqual((result['scenario_count'], result['input_ticks_per_build'], result['checkpoint_count_per_build']), (8, 2100, 86))

    def test_identical_truncated_or_fabricated_reports_cannot_pass(self):
        mutations = [lambda r: r.update(passed=0), lambda r: r.update(passed=True),
            lambda r: r.update(failed=1), lambda r: r.update(schema=16),
            lambda r: r.update(scenarios=[]),
            lambda r: r['scenarios'][0]['scenario'].update(ticks=1),
            lambda r: r['scenarios'][0].update(checkpoints=[]),
            lambda r: r['scenarios'][0].update(every_tick_authority_sha256=''),
            lambda r: r['scenarios'][0].update(witnesses={}),
            lambda r: r['scenarios'][0]['checkpoints'][0].pop('npc_observations_sha256'),
            lambda r: r['scenarios'][0]['checkpoints'][0].update(rng_state=123),
            lambda r: r['scenarios'][0]['checkpoints'][0].update(fish_wire_valid=False)]
        for mutate in mutations:
            report = self.report(); mutate(report)
            with self.subTest(report=repr(report)[:100]): self.assertFalse(probe.compare_reports(report, copy.deepcopy(report))['success'])

    def test_detects_input_every_tick_rng_snapshot_observation_wire_witness_drift(self):
        for field in ('input_trace_sha256', 'every_tick_authority_sha256', 'witnesses', 'outcome'):
            report = self.report(); report['scenarios'][0][field] = 'changed'
            self.assertFalse(probe.compare_reports(self.report(), report)['success'])
        for field in (*probe.CHECKPOINT_HASHES, 'rng_seed', 'rng_state', 'snapshot_bytes', 'simulation_tick'):
            report = self.report(); report['scenarios'][0]['checkpoints'][0][field] = 'changed'
            result = probe.compare_reports(self.report(), report)
            self.assertFalse(result['success'])
            self.assertTrue(any('first differing checkpoint' in error for error in result['differences']))

    def test_malformed_top_level_and_scenario_rows_fail_closed(self):
        self.assertFalse(probe.compare_reports([], [])['success'])
        for rows in (None, [None] * 8, ['invalid'] * 8):
            report = self.report(); report['scenarios'] = rows
            self.assertFalse(probe.compare_reports(report, copy.deepcopy(report))['success'])

    def test_cross_engine_reports_rejected(self):
        report = self.report(); report['engine'] = '4.6.3'
        self.assertFalse(probe.compare_reports(self.report(), report)['success'])


class InheritedNetTests(unittest.TestCase):
    def report(self):
        cases = []
        for index, name in enumerate(('same-tick batch', 'separate authority ticks')):
            points = []
            for tick in (-1, 0, 1, 2, 30, 60, 119):
                inherited = index == 0 and tick >= 0
                points.append({'tick': tick, 'authority_restore': True, 'angler_wire_valid': True,
                    'fish_wire_valid': not inherited, 'fish_wire_apply': not inherited,
                    'net_age_variant_type': 'int' if inherited else 'float',
                    'net_age': 0 if inherited else 0.0})
            cases.append({'input': name, 'checkpoints': points})
        return {'engine': '4.7.2', 'cases': cases}

    def test_inherited_rejection_and_staged_acceptance_retained(self):
        self.assertTrue(probe.compare_net_reports(self.report(), self.report())['success'])

    def test_fix_guard_relaxation_and_missing_evidence_rejected_even_if_both_match(self):
        for field, value in [('fish_wire_valid', True), ('fish_wire_apply', True),
                             ('net_age_variant_type', 'float'), ('net_age', 0.0), ('authority_restore', False)]:
            report = self.report(); report['cases'][0]['checkpoints'][1][field] = value
            self.assertFalse(probe.compare_net_reports(report, copy.deepcopy(report))['success'])
        report = self.report(); report['cases'][1]['checkpoints'].pop()
        self.assertFalse(probe.compare_net_reports(report, copy.deepcopy(report))['success'])


if __name__ == '__main__':
    unittest.main()
