#!/usr/bin/env python3
"""P4.2: independent archive-locked Authority MapContext equivalence gate.

The unchanged P4.0 harness runs against committed 0.26.0 legacy authority and
reviewed 0.26.1 context authority. Snapshot, wire shape, presentation and assets
are byte-locked. Outputs are new-only; source identity is checked before/after.
"""
from __future__ import annotations

import argparse
import hashlib
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

COMMIT = '0a3e5af3dc3ca26f0909644505ff24a1de1fe06d'
TREE = '3bc012c3e84f2ad79872757c7d574c3a0234dab1'
ARCHIVE_SHA256 = '6635f95a7cb5282c5560e9cef3c1b9c5400675c6d45e0f322f0cbe7d6d8b5737'
HARNESS = 'tests/phase04_map_baseline.gd'
LOCK = 'tests/fixtures/phase04/authority_baseline_0a3e5af.json'
REVIEW = 'tests/fixtures/phase04/authority_reviewed_runtime.json'
NET_PROBE = 'tests/fixtures/phase04/net_batch_probe.gd'
TOOL = 'tools/phase04_compare_authority.py'
# Exact, reviewed string substitutions, never an arbitrary line/file exclusion.
METADATA_REPLACEMENTS = {
    'project.godot': (b'config/version="0.26.0"', b'config/version="0.26.1"'),
    'scripts/network_protocol.gd': (b'const BUILD := "0.26.0"', b'const BUILD := "0.26.1"'),
    'scripts/menu.gd': ('0.26.0 · 地图数据基础 · P4.1'.encode(), '0.26.1 · 权威地图上下文 · P4.2'.encode()),
    'scripts/pond.gd': (b'v0.26.0 | phase04-map-data-foundation', b'v0.26.1 | phase04-authority-map-context'),
}
# No wildcard directory exemptions. A listed path also needs its reviewed hash.
AUTHORITY_PATHS = frozenset({
    'scripts/world_simulation.gd', 'scripts/angler_brain.gd',
    'scripts/angler_rig.gd', 'scripts/fish_brain.gd',
    'scripts/fish_observation.gd', 'scripts/net_simulation.gd',
    'scripts/npc_hook.gd', 'scripts/npc_fish_state.gd',
    'scripts/maps/map_context.gd', 'scripts/maps/map_context.gd.uid',
    'scripts/maps/map_geometry.gd', 'scripts/maps/map_geometry.gd.uid',
})
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
CHECKPOINT_HASHES = ('snapshot_sha256', 'fish_observation_sha256',
    'fish_decision_observation_sha256', 'npc_observations_sha256', 'npcs_sha256',
    'bait_sha256', 'hook_qte_wrap_sha256', 'net_sha256', 'stats_sha256',
    'fish_wire_sha256', 'angler_wire_sha256', 'packed_authority_sha256')



def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def tracked_archive(repo: Path) -> bytes:
    actual = subprocess.check_output(['git', 'rev-parse', f'{COMMIT}^{{tree}}'], cwd=repo, text=True).strip()
    if actual != TREE:
        raise ValueError('Baseline commit/tree mismatch')
    archive = subprocess.check_output(['git', 'archive', '--format=tar', COMMIT], cwd=repo)
    if sha(archive) != ARCHIVE_SHA256:
        raise ValueError('Baseline git archive hash mismatch')
    return archive


def archive_files(archive: bytes) -> dict[str, str]:
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
        return {entry.name: sha(tar.extractfile(entry).read()) for entry in tar.getmembers() if entry.isfile()}


def extract_baseline_archive(tar: tarfile.TarFile, destination: Path) -> None:
    """Extract only contained regular files/directories on Python 3.11 too."""
    root = destination.resolve()
    entries = tar.getmembers()
    for entry in entries:
        target = (root / entry.name).resolve()
        if (not target.is_relative_to(root) or "\\" in entry.name or ":" in entry.name
                or not (entry.isfile() or entry.isdir())):
            raise ValueError(f'Unsafe baseline archive entry: {entry.name}')
    for entry in entries:
        target = root / entry.name
        if entry.isdir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(tar.extractfile(entry).read())


def freeze(repo: Path, destination: Path, lock: dict) -> dict:
    archive = tracked_archive(repo)
    hashes = archive_files(archive)
    expected_runtime = {path: value for path, value in hashes.items() if path.startswith(('scripts/', 'assets/', 'scenes/')) or path == 'project.godot'}
    if expected_runtime != lock['runtime_sha256']:
        raise ValueError('Tracked baseline lock differs from the immutable git archive')
    for relative, field in ((HARNESS, 'harness_sha256'), (NET_PROBE, 'net_probe_sha256'),
                            ('tools/phase04_compare_baseline.py', 'historical_tool_sha256'),
                            ('tests/fixtures/phase04/baseline_9d11fe8.json', 'historical_lock_sha256'),
                            ('tools/run_tests.py', 'runner_sha256')):
        if hashes[relative] != lock[field]:
            raise ValueError(f'Historical lock differs from immutable archive: {relative}')
    expected = {'format': 'phase04-authority-frozen-baseline-v1', 'commit': COMMIT, 'tree': TREE,
                'archive_sha256': ARCHIVE_SHA256,
                'source': 'git archive (tracked committed tree only; no working-tree/untracked files)',
                'files_sha256': hashes}
    if destination.exists():
        manifest = json.loads((destination / 'baseline-manifest.json').read_text(encoding='utf-8'))
        if manifest != expected:
            raise ValueError('Existing baseline manifest differs; never silently replace frozen evidence')
    else:
        destination.mkdir(parents=True)
        with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
            extract_baseline_archive(tar, destination)
        write_json(destination / 'baseline-manifest.json', expected)
    verify_frozen(destination, hashes)
    return expected


def verify_frozen(project: Path, hashes: dict[str, str]) -> None:
    for relative, expected in hashes.items():
        path = project / relative
        if path.is_symlink() or not path.is_file() or sha(path.read_bytes()) != expected:
            raise ValueError(f'Frozen baseline source changed: {relative}')
    # Import caches are allowed, extra runtime sources are not.
    for folder in ('scripts', 'scenes', 'assets'):
        for path in (project / folder).rglob('*'):
            if path.is_symlink() or (path.is_file() and path.relative_to(project).as_posix() not in hashes):
                raise ValueError(f'Unexpected file in frozen runtime: {path.relative_to(project)}')


def fingerprints(project: Path) -> dict[str, str]:
    paths = [project / 'project.godot']
    for folder in ('scripts', 'assets', 'scenes', 'tests', 'tools'):
        paths.extend(path for path in (project / folder).rglob('*')
                     if path.is_file() and '__pycache__' not in path.parts and path.suffix != '.pyc')
    return {path.relative_to(project).as_posix(): sha(path.read_bytes()) for path in sorted(paths)}


def historical_contract(project: Path, lock: dict) -> None:
    for relative, field in ((HARNESS, 'harness_sha256'), (NET_PROBE, 'net_probe_sha256'),
                            ('tools/phase04_compare_baseline.py', 'historical_tool_sha256'),
                            ('tests/fixtures/phase04/baseline_9d11fe8.json', 'historical_lock_sha256'),
                            ('tools/run_tests.py', 'runner_sha256')):
        if sha((project / relative).read_bytes()) != lock[field]:
            raise ValueError(f'Historical P4.0 evidence changed: {relative}')


def runtime_contract(baseline: Path, current: Path, lock: dict, review: dict) -> dict:
    rows = []
    approved = review.get('files', {})
    review_errors = []
    if not isinstance(approved, dict):
        return {'success': False, 'review_errors': ['review files must be an object']}
    invalid_entries = [name for name, entry in approved.items() if not isinstance(entry, dict)]
    if invalid_entries:
        return {'success': False, 'review_errors': [f'malformed review entry: {name}' for name in invalid_entries]}
    required = {'scripts/world_simulation.gd', 'scripts/maps/map_context.gd', 'scripts/maps/map_geometry.gd'}
    if not required.issubset(approved) or review.get('review_status') != 'reviewed':
        review_errors.append('authority migration lacks completed exact-hash review')
    if review.get('baseline_commit') != COMMIT or review.get('format') != 'phase04-authority-reviewed-runtime-v1':
        review_errors.append('review identity mismatch')
    for relative, entry in approved.items():
        if relative not in AUTHORITY_PATHS:
            review_errors.append(f'non-authority review exemption: {relative}')
        if not isinstance(entry, dict) or not re.fullmatch(r'[0-9a-f]{64}', str(entry.get('sha256', ''))) or not entry.get('reason'):
            review_errors.append(f'missing reviewed hash/reason: {relative}')
    for relative, before_hash in lock['runtime_sha256'].items():
        old = (baseline / relative).read_bytes()
        path = current / relative
        new = path.read_bytes() if path.is_file() else b''
        status = 'identical' if old == new and path.is_file() else 'forbidden_change'
        if sha(old) != before_hash:
            status = 'forbidden_change'
        elif relative in METADATA_REPLACEMENTS and old != new:
            before, after = METADATA_REPLACEMENTS[relative]
            if old.count(before) == 1 and new == old.replace(before, after, 1):
                status = 'exact_release_metadata_only'
        elif (old != new and path.is_file() and relative in AUTHORITY_PATHS
              and relative in approved and sha(new) == approved[relative].get('sha256')):
            status = 'exact_reviewed_authority_change'
        rows.append({'path': relative, 'baseline_sha256': before_hash,
                     'current_sha256': sha(new) if path.is_file() else None, 'status': status,
                     'review_reason': approved.get(relative, {}).get('reason')})
    extra = sorted(path.relative_to(current).as_posix() for folder in ('scripts', 'assets', 'scenes')
                   for path in (current / folder).rglob('*')
                   if path.is_file() and path.relative_to(current).as_posix() not in lock['runtime_sha256'])
    forbidden_extra = [path for path in extra if not (path in AUTHORITY_PATHS and path in approved
                       and sha((current / path).read_bytes()) == approved[path].get('sha256'))]
    for relative, entry in approved.items():
        path = current / relative
        if not path.is_file() or sha(path.read_bytes()) != entry.get('sha256'):
            review_errors.append(f'reviewed current source drift: {relative}')
    return {'success': all(row['status'] != 'forbidden_change' for row in rows) and not forbidden_extra and not review_errors,
            'review_errors': review_errors, 'forbidden_new_runtime_files': forbidden_extra,
            'existing_runtime_files': rows, 'new_reviewed_runtime_files': extra,
            'reviewed_runtime': review,
            'note': 'Exact hashes admit reviewed authority context/consumer changes only. Snapshot, wire shapes, presentation, assets and all other runtime bytes stay locked; four exact 0.26.1 markers are separate.'}


def report_contract(report: dict, label: str) -> list[str]:
    errors = []
    if not isinstance(report, dict):
        return [f'{label}: report must be an object']
    if not isinstance(report.get('engine'), str) or not report['engine']:
        errors.append(f'{label}: engine missing')
    if report.get('format') != 'phase04-map-baseline-v1' or report.get('schema') != 15:
        errors.append(f'{label}: report format/schema mismatch')
    if type(report.get('passed')) is not int or report['passed'] != 1690 or type(report.get('failed')) is not int or report['failed'] != 0:
        errors.append(f'{label}: exact single-pass assertion count must be 1690/0 (1691 after output-write assertion)')
    rows = report.get('scenarios')
    if not isinstance(rows, list) or len(rows) != len(SCENARIOS):
        return errors + [f'{label}: expected exactly eight named scenarios']
    for row, spec in zip(rows, SCENARIOS):
        name = spec['name']
        if not isinstance(row, dict) or row.get('scenario') != spec:
            errors.append(f'{label}: scenario/input contract mismatch: {name}')
            continue
        for field in ('input_trace_sha256', 'every_tick_authority_sha256'):
            if not re.fullmatch(r'[0-9a-f]{64}', str(row.get(field, ''))):
                errors.append(f'{label}: missing complete digest {name}/{field}')
        checkpoints = row.get('checkpoints')
        ticks = [-1, *range(0, spec['ticks'], 30), spec['ticks'] - 1]
        if not isinstance(checkpoints, list) or [cp.get('input_tick') for cp in checkpoints if isinstance(cp, dict)] != ticks:
            errors.append(f'{label}: exact checkpoint tape mismatch: {name}')
            continue
        for cp in checkpoints:
            for field in CHECKPOINT_HASHES:
                if not re.fullmatch(r'[0-9a-f]{64}', str(cp.get(field, ''))):
                    errors.append(f'{label}: missing checkpoint digest {name}/{field}')
            if cp.get('fish_wire_valid') is not True or cp.get('angler_wire_valid') is not True:
                errors.append(f'{label}: staged wire validity failed: {name}')
            for field in ('rng_seed', 'rng_state'):
                if not isinstance(cp.get(field), str) or not re.fullmatch(r'-?[0-9]+', cp[field]):
                    errors.append(f'{label}: exact RNG integer string missing: {name}/{field}')
            if type(cp.get('snapshot_bytes')) is not int or cp['snapshot_bytes'] <= 0 or type(cp.get('simulation_tick')) is not int:
                errors.append(f'{label}: authority size/tick missing: {name}')
        if (not isinstance(row.get('witnesses'), dict) or set(row['witnesses']) != {'attached', 'entry', 'net_sweep', 'net_warning', 'npc_hooked', 'npc_landing', 'npc_replaced', 'qte', 'refill', 'wrap'}
            or not all(type(value) is bool for value in row['witnesses'].values())
            or not isinstance(row.get('outcome'), dict) or set(row['outcome']) != {'hook_events', 'match_over', 'net_catches', 'next_bait_id', 'next_fish_id', 'npc_food', 'reason', 'score', 'wrap_good', 'wrong_catches'}):
            errors.append(f'{label}: witnesses/outcome missing: {name}')
    return errors


def compare_reports(baseline: dict, current: dict) -> dict:
    differences = report_contract(baseline, 'baseline') + report_contract(current, 'current')
    if not isinstance(baseline, dict) or not isinstance(current, dict):
        return {'success': False, 'differences': differences}
    if baseline.get('engine') != current.get('engine'):
        differences.append('engine mismatch; cross-engine byte equivalence is not admissible')
    old_rows = baseline.get('scenarios') if isinstance(baseline.get('scenarios'), list) else []
    new_rows = current.get('scenarios') if isinstance(current.get('scenarios'), list) else []
    for index, (old, new) in enumerate(zip(old_rows, new_rows)):
        if old == new:
            continue
        if not isinstance(old, dict) or not isinstance(new, dict):
            differences.append(f'scenario {index}: malformed row')
            continue
        name = SCENARIOS[index]['name'] if index < len(SCENARIOS) else str(index)
        for key in sorted(set(old) | set(new)):
            if old.get(key) != new.get(key):
                differences.append(f'{name}: {key} differs')
        old_points, new_points = old.get('checkpoints'), new.get('checkpoints')
        if isinstance(old_points, list) and isinstance(new_points, list):
            for old_cp, new_cp in zip(old_points, new_points):
                if old_cp != new_cp and isinstance(old_cp, dict) and isinstance(new_cp, dict):
                    fields = sorted(key for key in set(old_cp) | set(new_cp) if old_cp.get(key) != new_cp.get(key))
                    differences.append(f'{name}: first differing checkpoint input_tick={old_cp.get("input_tick")}: {fields}')
                    break
    valid_rows = [row for row in old_rows if isinstance(row, dict) and isinstance(row.get('scenario'), dict)]
    return {'success': not differences, 'differences': differences,
            'scenario_count': len(old_rows),
            'input_ticks_per_build': sum(row['scenario']['ticks'] for row in valid_rows if type(row['scenario'].get('ticks')) is int),
            'checkpoint_count_per_build': sum(len(row['checkpoints']) for row in valid_rows if isinstance(row.get('checkpoints'), list)),
            'variant_byte_fields': ['every_tick_authority', 'snapshot', 'FishObservation visual and decision',
                                    'NPC social observations', 'NPC private state', 'bait', 'Hook/QTE/wrap',
                                    'net', 'round stats', 'fish/angler wire', 'compressed authority'],
            'known_baseline_fish_wire_rejections': []}


def compare_net_reports(baseline: dict, current: dict) -> dict:
    errors = []
    if baseline != current:
        errors.append('inherited net diagnostic differs; do not repair or weaken this P4.2 gate')
    for label, report in (('baseline', baseline), ('current', current)):
        cases = report.get('cases', [])
        if len(cases) != 2 or [case.get('input') for case in cases] != ['same-tick batch', 'separate authority ticks']:
            errors.append(f'{label}: missing inherited and staged net cases')
            continue
        for index, case in enumerate(cases):
            points = case.get('checkpoints', [])
            if [cp.get('tick') for cp in points] != [-1, 0, 1, 2, 30, 60, 119]:
                errors.append(f'{label}: missing net diagnostic checkpoints')
            for cp in points:
                inherited = index == 0 and cp.get('tick', -1) >= 0
                if (cp.get('authority_restore') is not True or cp.get('angler_wire_valid') is not True
                    or cp.get('fish_wire_valid') is not (not inherited)
                    or cp.get('fish_wire_apply') is not (not inherited)
                    or cp.get('net_age_variant_type') != ('int' if inherited else 'float')
                    or (inherited and (type(cp.get('net_age')) is not int or cp['net_age'] != 0))):
                    errors.append(f'{label}: inherited net guard changed at {index}/{cp.get("tick")}')
    return {'success': not errors, 'differences': errors,
            'scope': 'Separate inherited same-tick int-zero fish-wire rejection stays reproduced, not counted as a passing gameplay suite or repaired'}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT)
    parser.add_argument('--baseline', type=Path, default=ROOT / 'artifacts/p42-frozen-baseline-0a3e5af')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--require-engine', help='Require this version prefix (e.g. 4.7.2); never relabel another executable')
    parser.add_argument('--freeze-only', action='store_true')
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error('--timeout must be positive and finite')
    project, baseline, output = args.project.resolve(), args.baseline.resolve(), args.output.resolve()
    if output.exists():
        parser.error('Output must be a new directory; preserve earlier evidence')
    output.mkdir(parents=True)
    try:
        lock = json.loads((project / LOCK).read_text(encoding='utf-8'))
        if (lock.get('commit'), lock.get('tree'), lock.get('archive_sha256')) != (COMMIT, TREE, ARCHIVE_SHA256):
            raise ValueError('Baseline lock identity changed')
        historical_contract(project, lock)
        manifest = freeze(project, baseline, lock)
        write_json(output / 'baseline-manifest.json', manifest)
        if args.freeze_only:
            print(json.dumps({'frozen': str(baseline), 'commit': COMMIT, 'tree': TREE})); return
        source_before = fingerprints(project)
        review = json.loads((project / REVIEW).read_text(encoding='utf-8'))
        contract = runtime_contract(baseline, project, lock, review)
        write_json(output / 'source-before.json', source_before)
        write_json(output / 'runtime-contract.json', contract)
        harness = output / 'phase04_map_baseline.gd'
        harness.write_bytes((project / HARNESS).read_bytes())
        shutil.copyfile(project / TOOL, output / 'phase04_compare_authority.py')
        shutil.copyfile(project / LOCK, output / Path(LOCK).name)
        shutil.copyfile(project / REVIEW, output / Path(REVIEW).name)
        env = dict(os.environ)
        for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
            directory = output / key.lower(); directory.mkdir(); env[key] = str(directory)
        resolved_engine = shutil.which(args.godot)
        if not resolved_engine: raise ValueError(f'Engine executable not found: {args.godot}')
        engine_sha256_before = sha(Path(resolved_engine).read_bytes())
        version_run = run_bounded([resolved_engine, '--version'], 15, project, env)
        version_lines = [line.strip() for line in version_run['output'].splitlines() if re.match(r'^\d+\.\d+\.\d+', line.strip())]
        if version_run['returncode'] or version_run['timed_out'] or version_run['launch_error'] or len(version_lines) != 1:
            raise ValueError('Unable to verify engine version')
        version = version_lines[0]
        if args.require_engine and not (version == args.require_engine or version.startswith(args.require_engine + '.')):
            raise ValueError(f'Required engine {args.require_engine}, actual executable reports {version}')
        runs = {}
        reports = {}
        net_reports = {}
        net_probe = output / 'net_batch_probe.gd'
        net_probe.write_bytes((project / NET_PROBE).read_bytes())
        for label, selected in (('baseline', baseline), ('current', project)):
            command = [resolved_engine, '--headless', '--audio-driver', 'Dummy', '--path', str(selected),
                       '--script', str(harness), '--', '--test-profile', '--single-pass',
                       f'--baseline-output={output / (label + ".json")}']
            run = run_bounded(command, args.timeout, selected, env)
            (output / f'{label}.log').write_text(run['output'], encoding='utf-8')
            runs[label] = {'command': command, **{key: value for key, value in run.items() if key != 'output'}}
            runs[label]['success'] = not (run['returncode'] or run['timed_out'] or run['launch_error'] or ERROR.search(run['output'])) and 'PHASE04_MAP_BASELINE_TESTS' in run['output']
            report_path = output / f'{label}.json'
            if report_path.exists(): reports[label] = json.loads(report_path.read_text(encoding='utf-8'))
            net_command = [resolved_engine, '--headless', '--audio-driver', 'Dummy', '--path', str(selected),
                           '--script', str(net_probe), '--', '--test-profile',
                           f'--output={output / (label + "-net.json")}']
            net_run = run_bounded(net_command, args.timeout, selected, env)
            (output / f'{label}-net.log').write_text(net_run['output'], encoding='utf-8')
            runs[label + '-net'] = {'command': net_command, **{key: value for key, value in net_run.items() if key != 'output'}}
            runs[label + '-net']['success'] = not (net_run['returncode'] or net_run['timed_out'] or net_run['launch_error'] or ERROR.search(net_run['output'])) and 'P40_NET_BATCH_PROBE_COMPLETE' in net_run['output']
            net_path = output / f'{label}-net.json'
            if net_path.exists(): net_reports[label] = json.loads(net_path.read_text(encoding='utf-8'))
        verify_frozen(baseline, manifest['files_sha256'])
        source_after = fingerprints(project)
        write_json(output / 'source-after.json', source_after)
        source_stable = (source_before == source_after and sha(harness.read_bytes()) == lock['harness_sha256']
                         and sha(net_probe.read_bytes()) == lock['net_probe_sha256']
                         and sha(Path(resolved_engine).read_bytes()) == engine_sha256_before)
        comparison = compare_reports(reports['baseline'], reports['current']) if len(reports) == 2 else {'success': False, 'differences': ['missing harness output']}
        write_json(output / 'comparison.json', comparison)
        net_comparison = compare_net_reports(net_reports['baseline'], net_reports['current']) if len(net_reports) == 2 else {'success': False, 'differences': ['missing net diagnostic output']}
        write_json(output / 'inherited-net-comparison.json', net_comparison)
        result = {'format': 'phase04-authority-comparison-v1', 'success': bool(contract['success'] and source_stable and comparison['success'] and net_comparison['success'] and all(run['success'] for run in runs.values())),
                  'commit': COMMIT, 'tree': TREE, 'engine': version,
                  'engine_executable': str(Path(resolved_engine).resolve()), 'engine_sha256': engine_sha256_before, 'engine_binary_stable': sha(Path(resolved_engine).read_bytes()) == engine_sha256_before,
                  'required_engine': args.require_engine, 'required_4_7_2_verified': version.startswith('4.7.2.stable.official.'),
                  'engine_scope': 'Official 4.7.2 gate' if version.startswith('4.7.2.stable.official.') else 'Development engine only; does not satisfy a 4.7.2 requirement',
                  'frozen_source_stable': True, 'working_source_stable': source_stable, 'source_sha256': source_before,
                  'frozen_harness_sha256': sha(harness.read_bytes()), 'runtime_contract_success': contract['success'],
                  'reviewed_runtime': review, 'changed_during_run': sorted(path for path in set(source_before) | set(source_after) if source_before.get(path) != source_after.get(path)),
                  'comparison': comparison, 'inherited_net_comparison': net_comparison, 'runs': runs,
                  'scope': 'Actual committed old authority adapter versus current MapContext. Eight focused deterministic simulation scenarios with identical seed/input/intervention tapes; no statistical balance, renderer pixels, real ENet transport, export, or human-playtest claim. Net toggle/endpoints use separate ticks, like ordinary UI input.'}
        write_json(output / 'summary.json', result)
        print(json.dumps({key: result[key] for key in ('success', 'engine', 'engine_scope', 'working_source_stable', 'runtime_contract_success')}))
        print(json.dumps(comparison))
        raise SystemExit(0 if result['success'] else 1)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, tarfile.TarError) as error:
        write_json(output / 'summary.json', {'success': False, 'error': str(error)})
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
