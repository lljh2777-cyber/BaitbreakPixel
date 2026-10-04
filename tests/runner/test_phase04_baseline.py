"""Fail-closed checks for the independent P4.0 baseline comparison driver."""
from __future__ import annotations
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import phase04_compare_baseline as probe


class RuntimeContractTests(unittest.TestCase):
    def contract(self, relative, old, new, extra=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            a, b = root / 'baseline', root / 'current'
            for base, value in ((a, old), (b, new)):
                path = base / relative
                path.parent.mkdir(parents=True)
                path.write_bytes(value)
            if extra:
                path = b / extra
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('extends RefCounted\n')
            return probe.runtime_contract(a, b, {'runtime_sha256': {relative: probe.sha(old)}})

    def test_existing_world_must_be_byte_identical(self):
        self.assertTrue(self.contract('scripts/world_simulation.gd', b'original', b'original')['success'])
        self.assertFalse(self.contract('scripts/world_simulation.gd', b'original', b'changed')['success'])

    def test_network_allows_only_exact_build_replacement(self):
        before = b'const BUILD := "0.25.5"\nconst VERSION := 1\n'
        after = b'const BUILD := "0.26.0"\nconst VERSION := 1\n'
        report = self.contract('scripts/network_protocol.gd', before, after)
        self.assertTrue(report['success'])
        self.assertEqual(report['existing_runtime_files'][0]['status'], 'exact_release_metadata_only')
        self.assertFalse(self.contract('scripts/network_protocol.gd', before, after + b'# extra\n')['success'])
        self.assertFalse(self.contract('scripts/network_protocol.gd', before, after.replace(b':= 1', b':= 2'))['success'])

    def test_metadata_allowlist_is_exact_not_whole_file_exemption(self):
        before = 'text("0.25.5 · 生态平衡 · 等待最终试玩")\n'.encode()
        after = 'text("0.26.0 · 地图数据基础 · P4.1")\n'.encode()
        self.assertTrue(self.contract('scripts/menu.gd', before, after)['success'])
        self.assertFalse(self.contract('scripts/menu.gd', before, after.replace(b'text(', b'other('))['success'])

    def test_only_new_map_data_sources_are_admitted(self):
        self.assertTrue(self.contract('scripts/world_simulation.gd', b'a', b'a', 'scripts/maps/map_definition.gd')['success'])
        for path in ('scripts/new_gameplay.gd', 'assets/new.png', 'scenes/new.tscn'):
            with self.subTest(path=path):
                self.assertFalse(self.contract('scripts/world_simulation.gd', b'a', b'a', path)['success'])


class ComparisonTests(unittest.TestCase):
    def report(self):
        return {'format': 'phase04-map-baseline-v1', 'engine': '4.7.2.stable.official.test',
                'schema': 15, 'passed': 1, 'failed': 0, 'scenarios': [
                    {'scenario': {'name': f'case-{i}', 'ticks': 10}, 'input_trace_sha256': 'input',
                     'every_tick_authority_sha256': 'trace', 'checkpoints': [
                         {'input_tick': 0, 'fish_wire_valid': True, 'snapshot_sha256': 'snapshot'}]}
                    for i in range(8)]}

    def test_exact_reports_match(self):
        result = probe.compare_reports(self.report(), self.report())
        self.assertTrue(result['success'])
        self.assertEqual(result['checkpoint_count_per_build'], 8)

    def test_rejects_engine_schema_assertion_and_missing_scenario(self):
        for key, value in [('engine', '4.6.3'), ('schema', 16), ('failed', 1), ('passed', 0), ('scenarios', [])]:
            with self.subTest(key=key):
                changed = self.report(); changed[key] = value
                self.assertFalse(probe.compare_reports(self.report(), changed)['success'])

    def test_detects_input_rng_physics_wire_and_witness_difference(self):
        for key in ('input_trace_sha256', 'every_tick_authority_sha256', 'witnesses'):
            with self.subTest(key=key):
                changed = self.report(); changed['scenarios'][0][key] = 'different'
                self.assertFalse(probe.compare_reports(self.report(), changed)['success'])
        for key in ('snapshot_sha256', 'rng_state', 'fish_wire_sha256', 'fish_wire_valid'):
            with self.subTest(key=key):
                changed = self.report(); changed['scenarios'][0]['checkpoints'][0][key] = 'different'
                result = probe.compare_reports(self.report(), changed)
                self.assertFalse(result['success'])
                self.assertTrue(any('first differing checkpoint' in error for error in result['differences']))


if __name__ == '__main__':
    unittest.main()
