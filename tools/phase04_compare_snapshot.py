#!/usr/bin/env python3
"""P4.3: same-input schema15/schema16 comparison with exact map-envelope exclusions.

Git commit/tree provenance and direct source-byte checks replace mass file hashes.
SHA256 is used only by the Godot harness for meaningful deterministic payloads.
A scoped runtime diff is retained for human review; path admission is not review.
"""
from __future__ import annotations

import argparse
import io
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile

from run_tests import ERROR, ROOT, run_bounded

COMMIT = '8831f52ee7daae5d592282d5da432cbd67fccfb0'
TREE = 'c90e98d2e07d20b5cf0c8742fba5818758813939'
HARNESS = 'tests/phase04_snapshot_equivalence.gd'
TOOL = 'tools/phase04_compare_snapshot.py'
NET_PROBE = 'tests/fixtures/phase04/net_batch_probe.gd'
HISTORICAL = (
    'tests/phase04_map_baseline.gd', 'tools/phase04_compare_baseline.py',
    'tools/phase04_compare_authority.py', NET_PROBE,
    'tests/fixtures/phase04/baseline_9d11fe8.json',
    'tests/fixtures/phase04/authority_baseline_0a3e5af.json',
    'tests/fixtures/phase04/authority_reviewed_runtime.json',
)
TAPE_FUNCTIONS = ('scenarios', 'fresh', 'place_hook', 'commands', 'intervention')
RUNTIME_PATHS = frozenset({
    'scripts/world_snapshot.gd', 'scripts/world_simulation.gd',
    'scripts/maps/map_registry.gd', 'scripts/maps/map_context.gd',
    'scripts/network_protocol.gd', 'scripts/network_session.gd',
    'scripts/network_presentation.gd', 'scripts/fish_network_observation.gd',
    'scripts/angler_network_observation.gd', 'scripts/npc_fish_state.gd',
    'scripts/npc_fish_public_state.gd',
})
METADATA_REPLACEMENTS = {
    'project.godot': (b'config/version="0.26.1"', b'config/version="0.26.2"'),
    'scripts/menu.gd': ('0.26.1 · 权威地图上下文 · P4.2'.encode(), '0.26.2 · 地图存档与联机 · P4.3'.encode()),
    'scripts/pond.gd': (b'v0.26.1 | phase04-authority-map-context', b'v0.26.2 | phase04-snapshot-network-map-ref'),
}
SCENARIOS = [
    {'name': 'ambient_survival', 'seed': 17401, 'mode': 'survival', 'count': 2, 'challenge': True, 'ticks': 240},
    {'name': 'ambient_duel', 'seed': 17402, 'mode': 'duel', 'count': 4, 'challenge': False, 'ticks': 240},
    {'name': 'feeding_refill', 'seed': 17403, 'mode': 'duel', 'count': 3, 'challenge': False, 'ticks': 180},
    {'name': 'player_entry', 'seed': 64317, 'mode': 'survival', 'count': 0, 'challenge': True, 'ticks': 180},
    {'name': 'player_wrap', 'seed': 64317, 'mode': 'survival', 'count': 0, 'challenge': True, 'ticks': 120},
    {'name': 'npc_capture_respawn', 'seed': 64317, 'mode': 'duel', 'count': 3, 'challenge': False, 'ticks': 900},
    {'name': 'net_player', 'seed': 75401, 'mode': 'duel', 'count': 3, 'challenge': True, 'ticks': 120},
    {'name': 'net_npc_only', 'seed': 75401, 'mode': 'duel', 'count': 3, 'challenge': True, 'ticks': 120},
]
HASH_FIELDS = (
    'snapshot_sha256', 'fish_observation_sha256', 'fish_decision_observation_sha256',
    'npc_observations_sha256', 'npcs_sha256', 'bait_sha256', 'hook_qte_wrap_sha256',
    'net_sha256', 'stats_sha256', 'fish_wire_sha256', 'angler_wire_sha256',
    'packed_authority_sha256',
)
RAW_HASH_FIELDS = ('raw_snapshot_sha256', 'raw_fish_wire_sha256', 'raw_angler_wire_sha256')
ENVELOPE_FIELDS = frozenset((*RAW_HASH_FIELDS, 'raw_snapshot_bytes',
    'authority_metadata', 'fish_metadata', 'angler_metadata'))
CHECKPOINT_FIELDS = frozenset((*HASH_FIELDS, *ENVELOPE_FIELDS, 'input_tick',
    'simulation_tick', 'fish_wire_valid', 'angler_wire_valid', 'rng_seed', 'rng_state', 'snapshot_bytes'))
WITNESSES = frozenset(('attached', 'entry', 'net_sweep', 'net_warning', 'npc_hooked',
    'npc_landing', 'npc_replaced', 'qte', 'refill', 'wrap'))
REQUIRED_WITNESSES = {
    'feeding_refill': ('refill',), 'player_entry': ('entry', 'attached', 'qte'),
    'player_wrap': ('attached', 'qte', 'wrap'),
    'npc_capture_respawn': ('npc_hooked', 'npc_landing', 'npc_replaced'),
    'net_player': ('net_warning', 'net_sweep'), 'net_npc_only': ('net_warning', 'net_sweep'),
}
OUTCOME_FIELDS = frozenset(('hook_events', 'match_over', 'net_catches', 'next_bait_id',
    'next_fish_id', 'npc_food', 'reason', 'score', 'wrap_good', 'wrong_catches'))


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def is_runtime(name: str) -> bool:
    return name == 'project.godot' or name.startswith(('scripts/', 'assets/', 'scenes/'))


def git(repo: Path, *args: str) -> bytes:
    return subprocess.check_output(['git', *args], cwd=repo)


def committed_sources(repo: Path) -> dict[str, bytes]:
    if git(repo, 'rev-parse', f'{COMMIT}^{{tree}}').decode().strip() != TREE:
        raise ValueError('Baseline Git commit/tree identity mismatch')
    archive = git(repo, 'archive', '--format=tar', COMMIT)
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as source:
        return {entry.name: source.extractfile(entry).read() for entry in source.getmembers()
                if entry.isfile() and (is_runtime(entry.name) or entry.name in HISTORICAL)}


def read_sources(project: Path, include_harness: bool = False) -> dict[str, bytes]:
    result = {}
    for folder in ('scripts', 'assets', 'scenes'):
        directory = project / folder
        if directory.is_symlink(): raise ValueError(f'Runtime directory symlink: {folder}')
        for path in directory.rglob('*'):
            if path.is_symlink(): raise ValueError(f'Runtime symlink: {path}')
            if path.is_file(): result[path.relative_to(project).as_posix()] = path.read_bytes()
    names = ['project.godot', *HISTORICAL]
    if include_harness:
        names += [HARNESS, TOOL, 'tests/runner/test_phase04_snapshot.py', 'tools/run_tests.py']
    for name in names:
        path = project / name
        if path.is_symlink() or not path.is_file(): raise ValueError(f'Missing or symlinked source: {name}')
        result[name] = path.read_bytes()
    return result


def verify_frozen(project: Path, committed: dict[str, bytes]) -> None:
    actual = read_sources(project)
    if actual != committed:
        changed = sorted(name for name in set(actual) | set(committed) if actual.get(name) != committed.get(name))
        raise ValueError(f'Frozen baseline differs from committed Git source: {changed}')


def function_source(script: bytes, name: str) -> bytes:
    match = re.search(rb'^func ' + name.encode() + rb'\([^\n]*\n.*?(?=^func |\Z)', script, re.M | re.S)
    if not match: raise ValueError(f'Missing input-tape function: {name}')
    return match.group().rstrip()


def source_contract(committed: dict[str, bytes], current: dict[str, bytes]) -> dict:
    errors = []
    changed = []
    for name in sorted(set(committed) | set(current)):
        old, new = committed.get(name), current.get(name)
        if name in HISTORICAL and old != new:
            errors.append(f'Historical evidence changed: {name}')
        if not is_runtime(name) or old == new: continue
        changed.append(name)
        if old is None or new is None:
            errors.append(f'Runtime source added or removed: {name}')
        elif name in METADATA_REPLACEMENTS:
            before, after = METADATA_REPLACEMENTS[name]
            if old.count(before) != 1 or new != old.replace(before, after, 1):
                errors.append(f'Non-metadata change in release marker: {name}')
        elif name not in RUNTIME_PATHS:
            errors.append(f'Runtime change outside reviewed P4.3 scope: {name}')
    try:
        for name in TAPE_FUNCTIONS:
            if function_source(committed[HISTORICAL[0]], name) != function_source(current[HARNESS], name):
                errors.append(f'Historical scenario/setup/input/intervention changed: {name}')
    except (KeyError, ValueError) as error:
        errors.append(str(error))
    return {'success': not errors, 'errors': errors, 'changed_runtime_paths': changed,
            'note': 'Path admission is not human code review. Exact scoped Git diff is retained; unchanged runtime and historical evidence are direct byte comparisons, without redundant SHA256 inventory.'}


def hash_string(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r'[0-9a-f]{64}', value) is not None


def map_ref_valid(value: object) -> bool:
    return (isinstance(value, dict) and set(value) == {'id', 'revision', 'contract_version', 'content_hash'}
            and value['id'] == 'pond_v2' and type(value['revision']) is int and value['revision'] == 1
            and type(value['contract_version']) is int and value['contract_version'] == 1
            and hash_string(value['content_hash']))


def report_contract(report: object, schema: int, label: str) -> list[str]:
    errors = []
    if not isinstance(report, dict): return [f'{label}: report must be an object']
    expected_keys = {'format', 'engine', 'schema', 'probe', 'registry_ref', 'metadata_exclusions', 'scenarios', 'passed', 'failed'}
    if set(report) != expected_keys: errors.append(f'{label}: exact report fields mismatch')
    if report.get('format') != 'phase04-snapshot-equivalence-v1' or type(report.get('schema')) is not int or report['schema'] != schema:
        errors.append(f'{label}: exact schema/format mismatch')
    if not isinstance(report.get('engine'), str) or not report['engine']: errors.append(f'{label}: engine missing')
    if type(report.get('passed')) is not int or report['passed'] != 4221 or type(report.get('failed')) is not int or report['failed'] != 0:
        errors.append(f'{label}: exact single-pass assertions must be 4221/0 (4222 with output write)')
    if report.get('metadata_exclusions') != ['schema', 'map_id' if schema == 15 else 'map_ref']:
        errors.append(f'{label}: exclusion allowlist changed')
    reference = report.get('registry_ref')
    if not map_ref_valid(reference): errors.append(f'{label}: invalid registry reference')
    rows = report.get('scenarios')
    if not isinstance(rows, list) or len(rows) != len(SCENARIOS): return errors + [f'{label}: exactly eight scenarios required']
    for row, spec in zip(rows, SCENARIOS):
        name = spec['name']
        if not isinstance(row, dict) or set(row) != {'scenario', 'checkpoints', 'input_trace_sha256', 'every_tick_authority_sha256', 'witnesses', 'outcome'} or row.get('scenario') != spec or any(type(row['scenario'][key]) is not type(value) for key, value in spec.items()):
            errors.append(f'{label}: exact scenario/input contract mismatch: {name}'); continue
        for field in ('input_trace_sha256', 'every_tick_authority_sha256'):
            if not hash_string(row.get(field)): errors.append(f'{label}: incomplete digest {name}/{field}')
        witnesses = row.get('witnesses')
        if not isinstance(witnesses, dict) or set(witnesses) != WITNESSES or not all(type(v) is bool for v in witnesses.values()):
            errors.append(f'{label}: exact typed witnesses missing: {name}')
        elif any(witnesses[key] is not True for key in REQUIRED_WITNESSES.get(name, ())):
            errors.append(f'{label}: scenario lacks its exercised behavior witnesses: {name}')
        outcome = row.get('outcome')
        if not isinstance(outcome, dict) or set(outcome) != OUTCOME_FIELDS:
            errors.append(f'{label}: exact outcome fields missing: {name}')
        elif (type(outcome['match_over']) is not bool or not isinstance(outcome['reason'], str)
              or any(type(outcome[key]) not in (int, float) or not math.isfinite(outcome[key]) or outcome[key] < 0
                     for key in OUTCOME_FIELDS - {'match_over', 'reason'})
              or any(type(outcome[key]) is not int for key in ('hook_events', 'net_catches', 'next_bait_id', 'next_fish_id', 'wrap_good', 'wrong_catches'))):
            errors.append(f'{label}: outcome values have invalid types/ranges: {name}')
        elif ((name == 'feeding_refill' and not (outcome['score'] > 0 and outcome['npc_food'] > 0))
              or (name == 'player_entry' and outcome['hook_events'] < 1)
              or (name == 'player_wrap' and outcome['wrap_good'] < 1)
              or (name == 'npc_capture_respawn' and outcome['wrong_catches'] < 1)
              or (name == 'net_player' and outcome['net_catches'] != 1)
              or (name == 'net_npc_only' and outcome['net_catches'] != 0)):
            errors.append(f'{label}: scenario outcome did not exercise intended behavior: {name}')
        points = row.get('checkpoints')
        ticks = [-1, *range(0, spec['ticks'], 30), spec['ticks'] - 1]
        if not isinstance(points, list) or len(points) != len(ticks) or any(not isinstance(cp, dict) for cp in points):
            errors.append(f'{label}: complete checkpoint tape missing: {name}'); continue
        for cp, tick in zip(points, ticks):
            if set(cp) != CHECKPOINT_FIELDS or type(cp.get('input_tick')) is not int or cp['input_tick'] != tick:
                errors.append(f'{label}: exact checkpoint fields/tick mismatch: {name}/{tick}')
            for field in (*HASH_FIELDS, *RAW_HASH_FIELDS):
                if not hash_string(cp.get(field)): errors.append(f'{label}: invalid digest {name}/{tick}/{field}')
            for field in ('rng_seed', 'rng_state'):
                if not isinstance(cp.get(field), str) or re.fullmatch(r'-?[0-9]+', cp[field]) is None:
                    errors.append(f'{label}: RNG must be lossless integer text: {name}/{tick}/{field}')
            for field in ('snapshot_bytes', 'raw_snapshot_bytes'):
                if type(cp.get(field)) is not int or cp[field] <= 0: errors.append(f'{label}: invalid byte count: {name}/{tick}/{field}')
            if (type(cp.get('raw_snapshot_bytes')) is int and type(cp.get('snapshot_bytes')) is int
                and cp['raw_snapshot_bytes'] - cp['snapshot_bytes'] != (56 if schema == 15 else 224)):
                errors.append(f'{label}: envelope overhead differs from exact serialized schema/map metadata: {name}/{tick}')
            if type(cp.get('simulation_tick')) is not int or cp['simulation_tick'] < 0:
                errors.append(f'{label}: invalid simulation tick: {name}/{tick}')
            if cp.get('fish_wire_valid') is not True or cp.get('angler_wire_valid') is not True:
                errors.append(f'{label}: public projection failed validation: {name}/{tick}')
            map_value = 'pond_v2' if schema == 15 else reference
            for kind in ('authority', 'angler', 'fish'):
                wire_schema = (1 if schema == 15 else 2) if kind == 'fish' else schema
                metadata = cp.get(f'{kind}_metadata')
                if (not isinstance(metadata, dict) or set(metadata) != {'schema', 'map'}
                    or type(metadata.get('schema')) is not int or metadata['schema'] != wire_schema
                    or metadata.get('map') != map_value
                    or (schema == 16 and not map_ref_valid(metadata.get('map')))):
                    errors.append(f'{label}: unchecked metadata exclusion: {name}/{tick}/{kind}')
    return errors


def compare_reports(baseline: object, current: object) -> dict:
    errors = report_contract(baseline, 15, 'baseline') + report_contract(current, 16, 'current')
    if errors: return {'success': False, 'differences': errors}
    if baseline['engine'] != current['engine']: errors.append('Cross-engine equivalence is inadmissible')
    if baseline['registry_ref'] != current['registry_ref']: errors.append('Registry reference changed; metadata exclusion cannot hide map changes')
    raw_deltas = set()
    for old, new in zip(baseline['scenarios'], current['scenarios']):
        name = old['scenario']['name']
        for field in ('scenario', 'input_trace_sha256', 'every_tick_authority_sha256', 'witnesses', 'outcome'):
            if old[field] != new[field]: errors.append(f'{name}: {field} differs')
        for before, after in zip(old['checkpoints'], new['checkpoints']):
            changed = sorted(key for key in CHECKPOINT_FIELDS - ENVELOPE_FIELDS if before[key] != after[key])
            if changed: errors.append(f'{name}: differing checkpoint input_tick={before["input_tick"]}: {changed}')
            if any(before[field] == after[field] for field in RAW_HASH_FIELDS):
                errors.append(f'{name}: raw wire/snapshot must reflect expected schema/map metadata change')
            raw_deltas.add(after['raw_snapshot_bytes'] - before['raw_snapshot_bytes'])
    if raw_deltas != {168}:
        errors.append('Expected exact +168-byte schema/map-ref envelope delta')
    return {'success': not errors, 'differences': errors, 'scenario_count': 8,
            'input_ticks_per_build': 2100, 'checkpoint_count_per_build': 86,
            'raw_snapshot_envelope_byte_delta': sorted(raw_deltas),
            'exact_fields': ['every-tick state/rig/RNG', *HASH_FIELDS, 'RNG seed/state', 'witnesses/outcomes'],
            'exclusions': 'Only exact schema15→16 (fish1→2) and map_id→registry-verified map_ref envelopes; no gameplay field, private boundary, ordering or number normalization'}


def compare_net_reports(baseline: object, current: object) -> dict:
    errors = []
    if not isinstance(baseline, dict) or not isinstance(current, dict): return {'success': False, 'differences': ['Missing net diagnostic object']}
    if baseline != current: errors.append('Inherited same-tick/staged net behavior changed')
    for label, report in (('baseline', baseline), ('current', current)):
        cases = report.get('cases')
        if not isinstance(cases, list) or len(cases) != 2:
            errors.append(f'{label}: exactly two net cases required'); continue
        for index, case in enumerate(cases):
            if not isinstance(case, dict) or case.get('input') != ('same-tick batch', 'separate authority ticks')[index]:
                errors.append(f'{label}: exact net input mismatch'); continue
            points = case.get('checkpoints')
            if not isinstance(points, list) or len(points) != 7 or any(not isinstance(cp, dict) for cp in points):
                errors.append(f'{label}: seven net checkpoints required'); continue
            for cp, tick in zip(points, (-1, 0, 1, 2, 30, 60, 119)):
                inherited = index == 0 and tick >= 0
                if (cp.get('tick') != tick or cp.get('authority_restore') is not True or cp.get('angler_wire_valid') is not True
                    or cp.get('fish_wire_valid') is not (not inherited) or cp.get('fish_wire_apply') is not (not inherited)
                    or cp.get('net_age_variant_type') != ('int' if inherited else 'float')
                    or not isinstance(cp.get('net_age'), (float, int)) or not math.isfinite(cp['net_age'])
                    or (inherited and cp['net_age'] != 0)):
                    errors.append(f'{label}: inherited/staged net contract mismatch at {index}/{tick}')
    return {'success': not errors, 'differences': errors,
            'scope': 'Synthetic toggle+two-points same tick retains inherited int-zero fish-wire rejection. Ordinary separate-tick input remains accepted; not repaired or normalized by P4.3.'}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default=str(ROOT))
    parser.add_argument('--baseline', default=str(ROOT / 'artifacts/p43-frozen-baseline-8831f52'))
    parser.add_argument('--output', required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--require-engine', default='4.7.2')
    parser.add_argument('--timeout', type=float, default=240)
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0: parser.error('Timeout must be positive and finite')
    project, baseline, output = (Path(value).resolve() for value in (args.project, args.baseline, args.output))
    if output.exists(): parser.error('Output must be a new directory; never replace earlier evidence')
    output.mkdir(parents=True)
    try:
        committed = committed_sources(project)
        verify_frozen(baseline, committed)
        before = read_sources(project, True)
        contract = source_contract(committed, before)
        write_json(output / 'source-contract.json', contract)
        if not contract['success']: raise ValueError('; '.join(contract['errors']))
        provenance = {'baseline_commit': COMMIT, 'baseline_tree': TREE,
                      'working_head': git(project, 'rev-parse', 'HEAD').decode().strip(),
                      'working_head_tree': git(project, 'rev-parse', 'HEAD^{tree}').decode().strip(),
                      'changed_runtime_paths': contract['changed_runtime_paths']}
        write_json(output / 'git-provenance.json', provenance)
        (output / 'runtime.diff').write_bytes(git(project, 'diff', '--binary', COMMIT, '--', 'scripts', 'assets', 'scenes', 'project.godot'))
        harness, net = output / Path(HARNESS).name, output / Path(NET_PROBE).name
        harness.write_bytes(before[HARNESS]); net.write_bytes(before[NET_PROBE])
        (output / Path(TOOL).name).write_bytes(before[TOOL])
        env = dict(os.environ)
        for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
            directory = output / key.lower(); directory.mkdir(); env[key] = str(directory)
        engine = shutil.which(args.godot)
        if not engine: raise ValueError('Godot executable not found')
        engine_before = Path(engine).stat()
        version = run_bounded([engine, '--version'], 15, project, env)
        lines = [line.strip() for line in version['output'].splitlines() if re.match(r'^\d+\.\d+\.\d+', line.strip())]
        if version['returncode'] or version['timed_out'] or version['launch_error'] or len(lines) != 1:
            raise ValueError('Unable to verify engine version')
        if not lines[0].startswith(args.require_engine + '.stable.official.'):
            raise ValueError(f'Required official stable {args.require_engine}, got {lines[0]}')
        runs, reports, net_reports = {}, {}, {}
        for label, selected in (('baseline', baseline), ('current', project)):
            for suffix, script, marker, target in (('', harness, 'PHASE04_SNAPSHOT_EQUIVALENCE_TESTS', reports),
                    ('-net', net, 'P40_NET_BATCH_PROBE_COMPLETE', net_reports)):
                name = label + suffix
                command = [engine, '--headless', '--audio-driver', 'Dummy', '--path', str(selected), '--script', str(script),
                           '--', '--test-profile', '--single-pass', f'--output={output / (name + ".json")}']
                run = run_bounded(command, args.timeout, selected, env)
                (output / (name + '.log')).write_text(run['output'], encoding='utf-8')
                success = not (run['returncode'] or run['timed_out'] or run['launch_error'] or ERROR.search(run['output'])) and marker in run['output']
                runs[name] = {'command': command, 'success': success, **{key: value for key, value in run.items() if key != 'output'}}
                path = output / (name + '.json')
                if path.is_file(): target[label] = json.loads(path.read_text(encoding='utf-8'))
        verify_frozen(baseline, committed)
        after = read_sources(project, True)
        changed = sorted(name for name in set(before) | set(after) if before.get(name) != after.get(name))
        engine_after = Path(engine).stat()
        engine_stable = (engine_before.st_ino, engine_before.st_size, engine_before.st_mtime_ns) == (engine_after.st_ino, engine_after.st_size, engine_after.st_mtime_ns)
        source_stable = not changed and harness.read_bytes() == before[HARNESS] and net.read_bytes() == before[NET_PROBE]
        comparison = compare_reports(reports.get('baseline'), reports.get('current'))
        net_comparison = compare_net_reports(net_reports.get('baseline'), net_reports.get('current'))
        result = {'format': 'phase04-snapshot-comparison-v1',
            'success': bool(source_stable and engine_stable and comparison['success'] and net_comparison['success'] and all(run['success'] for run in runs.values())),
            'engine': lines[0], 'engine_executable': str(Path(engine).resolve()), 'engine_binary_stat_stable': engine_stable,
            'git_provenance': provenance, 'source_contract': contract, 'working_source_stable': source_stable,
            'frozen_source_stable': True, 'changed_during_run': changed, 'comparison': comparison,
            'inherited_net_comparison': net_comparison, 'runs': runs,
            'scope': 'Identical external harness and immutable baseline, exact input tapes, gameplay and public payload bytes; full unmodified restore/replay. No renderer, live ENet, export, statistical ecology, or human-playtest claim.'}
        write_json(output / 'comparison.json', comparison)
        write_json(output / 'inherited-net-comparison.json', net_comparison)
        write_json(output / 'summary.json', result)
        print(json.dumps({'success': result['success'], 'engine': lines[0], 'working_source_stable': source_stable, 'comparison': comparison}))
        raise SystemExit(0 if result['success'] else 1)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, tarfile.TarError) as error:
        write_json(output / 'summary.json', {'success': False, 'error': str(error)})
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
