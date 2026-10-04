#!/usr/bin/env python3
"""P4.0: archive-locked, same-engine exact deterministic behavior comparison.

Run this before and after adding unused map data. Only explicitly listed release
metadata may change in existing runtime files; no World/Snapshot/Network/renderer
migration is accepted. Development engines are allowed but labelled honestly.
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

COMMIT = '9d11fe8ae4bb7a49abe5fcd0e6f518ed0ebd3a92'
TREE = '377f935c054e6204d0b84075ef7b69cb72b5d6e1'
ARCHIVE_SHA256 = 'eee55fe8c1df8b85cf941433591be4a02ad4eb65ef0c0009382cd2339399a2ee'
HARNESS = 'tests/phase04_map_baseline.gd'
LOCK = 'tests/fixtures/phase04/baseline_9d11fe8.json'
# Exact, reviewed string substitutions, never an arbitrary line/file exclusion.
METADATA_REPLACEMENTS = {
    'project.godot': (b'config/version="0.25.5"', b'config/version="0.26.0"'),
    'scripts/network_protocol.gd': (b'const BUILD := "0.25.5"', b'const BUILD := "0.26.0"'),
    'scripts/menu.gd': ('0.25.5 · 生态平衡 · 等待最终试玩'.encode(), '0.26.0 · 地图数据基础 · P4.1'.encode()),
    'scripts/pond.gd': (b'v0.25.5 | playtest-gate-phase03-ecology', b'v0.26.0 | phase04-map-data-foundation'),
}


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
    expected = {'format': 'phase04-frozen-baseline-v1', 'commit': COMMIT, 'tree': TREE,
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
        if not path.is_file() or sha(path.read_bytes()) != expected:
            raise ValueError(f'Frozen baseline source changed: {relative}')
    # Import caches are allowed, extra runtime sources are not.
    for folder in ('scripts', 'scenes', 'assets'):
        for path in (project / folder).rglob('*'):
            if path.is_file() and path.relative_to(project).as_posix() not in hashes:
                raise ValueError(f'Unexpected file in frozen runtime: {path.relative_to(project)}')


def fingerprints(project: Path) -> dict[str, str]:
    paths = [project / 'project.godot', project / HARNESS, project / LOCK,
             project / 'tools/phase04_compare_baseline.py', project / 'tools/run_tests.py']
    for folder in ('scripts', 'assets', 'scenes'):
        paths.extend(path for path in (project / folder).rglob('*') if path.is_file())
    return {path.relative_to(project).as_posix(): sha(path.read_bytes()) for path in sorted(paths)}


def runtime_contract(baseline: Path, current: Path, lock: dict) -> dict:
    rows = []
    for relative, before_hash in lock['runtime_sha256'].items():
        old = (baseline / relative).read_bytes()
        path = current / relative
        new = path.read_bytes() if path.is_file() else b''
        status = 'identical' if old == new else 'forbidden_change'
        if relative in METADATA_REPLACEMENTS and old != new:
            before, after = METADATA_REPLACEMENTS[relative]
            if old.count(before) == 1 and new == old.replace(before, after, 1):
                status = 'exact_release_metadata_only'
        rows.append({'path': relative, 'baseline_sha256': before_hash,
                     'current_sha256': sha(new) if path.is_file() else None, 'status': status})
    extra = sorted(path.relative_to(current).as_posix() for folder in ('scripts', 'assets', 'scenes')
                   for path in (current / folder).rglob('*')
                   if path.is_file() and path.relative_to(current).as_posix() not in lock['runtime_sha256'])
    forbidden_extra = [path for path in extra if not (path.startswith('scripts/maps/') and path.endswith(('.gd', '.gd.uid')))]
    return {'success': all(row['status'] != 'forbidden_change' for row in rows) and not forbidden_extra,
            'forbidden_new_runtime_files': forbidden_extra,
            'existing_runtime_files': rows, 'new_unreferenced_runtime_files': extra,
            'note': 'All existing scripts, shaders, assets, scenes and project config are byte-locked except four exact metadata replacements. New data source files do not prove World migration.'}


def compare_reports(baseline: dict, current: dict) -> dict:
    differences = []
    if baseline.get('format') != 'phase04-map-baseline-v1' or current.get('format') != baseline.get('format'):
        differences.append('report format mismatch')
    if baseline.get('engine') != current.get('engine'):
        differences.append('engine mismatch; cross-engine byte equivalence is not admissible')
    if baseline.get('schema') != 15 or current.get('schema') != 15:
        differences.append('authority schema must remain 15')
    for label, report in (('baseline', baseline), ('current', current)):
        if report.get('failed') != 0 or not isinstance(report.get('passed'), int) or report['passed'] <= 0:
            differences.append(f'{label} harness failed or lacked assertions')
    old_rows, new_rows = baseline.get('scenarios', []), current.get('scenarios', [])
    if len(old_rows) != 8 or len(new_rows) != len(old_rows):
        differences.append('expected exactly eight named scenarios')
    for index, (old, new) in enumerate(zip(old_rows, new_rows)):
        if old != new:
            name = old.get('scenario', {}).get('name', str(index))
            for key in sorted(set(old) | set(new)):
                if old.get(key) != new.get(key):
                    differences.append(f'{name}: {key} differs')
            for old_cp, new_cp in zip(old.get('checkpoints', []), new.get('checkpoints', [])):
                if old_cp != new_cp:
                    fields = sorted(key for key in set(old_cp) | set(new_cp) if old_cp.get(key) != new_cp.get(key))
                    differences.append(f'{name}: first differing checkpoint input_tick={old_cp.get("input_tick")}: {fields}')
                    break
    return {'success': not differences, 'differences': differences,
            'scenario_count': len(old_rows),
            'input_ticks_per_build': sum(row['scenario']['ticks'] for row in old_rows),
            'checkpoint_count_per_build': sum(len(row['checkpoints']) for row in old_rows),
            'variant_byte_fields': ['every_tick_authority', 'snapshot', 'FishObservation visual and decision',
                                    'NPC social observations', 'NPC private state', 'bait', 'Hook/QTE/wrap',
                                    'net', 'round stats', 'fish/angler wire', 'compressed authority'],
            'known_baseline_fish_wire_rejections': [
                {'scenario': row['scenario']['name'], 'input_tick': cp['input_tick']}
                for row in old_rows for cp in row['checkpoints'] if not cp['fish_wire_valid']]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT)
    parser.add_argument('--baseline', type=Path, default=ROOT / 'artifacts/p40-frozen-baseline-9d11fe8')
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
        manifest = freeze(project, baseline, lock)
        write_json(output / 'baseline-manifest.json', manifest)
        if args.freeze_only:
            print(json.dumps({'frozen': str(baseline), 'commit': COMMIT, 'tree': TREE})); return
        source_before = fingerprints(project)
        contract = runtime_contract(baseline, project, lock)
        write_json(output / 'runtime-contract.json', contract)
        harness = output / 'phase04_map_baseline.gd'
        harness.write_bytes((project / HARNESS).read_bytes())
        shutil.copyfile(project / 'tools/phase04_compare_baseline.py', output / 'phase04_compare_baseline.py')
        env = dict(os.environ)
        for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
            directory = output / key.lower(); directory.mkdir(); env[key] = str(directory)
        resolved_engine = shutil.which(args.godot)
        if not resolved_engine: raise ValueError(f'Engine executable not found: {args.godot}')
        version_run = run_bounded([resolved_engine, '--version'], 15, project, env)
        version_lines = [line.strip() for line in version_run['output'].splitlines() if re.match(r'^\d+\.\d+\.\d+', line.strip())]
        if version_run['returncode'] or version_run['timed_out'] or version_run['launch_error'] or len(version_lines) != 1:
            raise ValueError('Unable to verify engine version')
        version = version_lines[0]
        if args.require_engine and not (version == args.require_engine or version.startswith(args.require_engine + '.')):
            raise ValueError(f'Required engine {args.require_engine}, actual executable reports {version}')
        runs = {}
        reports = {}
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
        verify_frozen(baseline, manifest['files_sha256'])
        source_stable = source_before == fingerprints(project) and sha(harness.read_bytes()) == source_before[HARNESS]
        comparison = compare_reports(reports['baseline'], reports['current']) if len(reports) == 2 else {'success': False, 'differences': ['missing harness output']}
        write_json(output / 'comparison.json', comparison)
        result = {'format': 'phase04-baseline-comparison-v1', 'success': bool(contract['success'] and source_stable and comparison['success'] and all(run['success'] for run in runs.values())),
                  'commit': COMMIT, 'tree': TREE, 'engine': version,
                  'engine_executable': str(Path(resolved_engine).resolve()), 'engine_sha256': sha(Path(resolved_engine).read_bytes()),
                  'required_engine': args.require_engine, 'required_4_7_2_verified': version.startswith('4.7.2.stable.official.'),
                  'engine_scope': 'Official 4.7.2 gate' if version.startswith('4.7.2.stable.official.') else 'Development engine only; does not satisfy a 4.7.2 requirement',
                  'frozen_source_stable': True, 'working_source_stable': source_stable, 'source_sha256': source_before,
                  'frozen_harness_sha256': sha(harness.read_bytes()), 'runtime_contract_success': contract['success'],
                  'comparison': comparison, 'runs': runs,
                  'scope': 'Eight focused deterministic simulation scenarios with identical seed/input/intervention tapes; no statistical balance, renderer pixels, real ENet transport, export, or human-playtest claim. Net toggle/endpoints use separate ticks, like ordinary UI input.'}
        write_json(output / 'summary.json', result)
        print(json.dumps({key: result[key] for key in ('success', 'engine', 'engine_scope', 'working_source_stable', 'runtime_contract_success')}))
        print(json.dumps(comparison))
        raise SystemExit(0 if result['success'] else 1)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, tarfile.TarError) as error:
        write_json(output / 'summary.json', {'success': False, 'error': str(error)})
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
