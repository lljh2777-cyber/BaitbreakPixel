#!/usr/bin/env python3
"""Merge complete source-frozen P3.5 heldout shards without subset admission.

This postprocessing tool is separately fingerprinted in merge provenance; it
never changes the frozen diagnostic source set or overwrites existing evidence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from phase03_ecology_analysis import MODES, STRATA, summarize, validate_rows
from phase03_run_ecology import ROOT, admit_pilot, fingerprints

REQUIRED_FILES = ('rounds.json', 'summary.json', 'provenance.json', 'run.log')


def _sha(data):
    return hashlib.sha256(data).hexdigest()


def _seed_list(values, description):
    if not isinstance(values, list) or not values or any(type(seed) is not int for seed in values) or len(set(values)) != len(values):
        raise ValueError(f'{description}: require nonempty distinct integer seeds')
    return values


def _read_run(path, phase):
    path = Path(path).resolve()
    raw = {name: (path / name).read_bytes() for name in REQUIRED_FILES}
    provenance = json.loads(raw['provenance.json'])
    summary = json.loads(raw['summary.json'])
    rows = json.loads(raw['rounds.json'])
    if provenance.get('format') != 'phase03-ecology-provenance-v1' or provenance.get('phase') != phase:
        raise ValueError(f'Wrong provenance format/phase: {path}')
    if provenance.get('success') is not True or provenance.get('source_stable') is not True:
        raise ValueError(f'Unsuccessful or source-unstable {phase}: {path}')
    execution = provenance.get('execution', {})
    if execution.get('returncode') != 0 or execution.get('timed_out') is not False or execution.get('launch_error') is not False:
        raise ValueError(f'Execution status contradicts success: {path}')
    seeds = _seed_list(provenance.get('seeds'), str(path))
    horizon = provenance.get('max_ticks')
    if type(horizon) is not int or not 1 <= horizon <= 108600:
        raise ValueError(f'Invalid horizon: {path}')
    if not isinstance(provenance.get('source_sha256'), dict) or not provenance['source_sha256']:
        raise ValueError(f'Missing source fingerprints: {path}')
    if not isinstance(provenance.get('project'), str) or not provenance['project']:
        raise ValueError(f'Missing source project: {path}')
    if (summary.get('format') != 'phase03-ecology-diagnostics-v1'
            or summary.get('rows') != len(rows)
            or summary.get('paired_seeds') != len(seeds)
            or summary.get('first_seed') != min(seeds)
            or summary.get('last_seed') != max(seeds)
            or summary.get('max_ticks') != horizon
            or summary.get('strata_per_seed') != 12
            or summary.get('modes') != list(MODES)):
        raise ValueError(f'Summary contradicts raw rows/provenance: {path}')
    validate_rows(rows, seeds, max_ticks=horizon)
    return {'path': path, 'provenance': provenance, 'summary': summary, 'rows': rows,
            'file_sha256': {name: _sha(data) for name, data in raw.items()}}


def _unchanged(run):
    return all(_sha((run['path'] / name).read_bytes()) == digest for name, digest in run['file_sha256'].items())


def merge_runs(paths, expected_seeds, output, *, project=ROOT, bootstrap=2000):
    expected_seeds = _seed_list(list(expected_seeds), 'Expected selection')
    paths = [Path(path).resolve() for path in paths]
    output, project = Path(output).resolve(), Path(project).resolve()
    if not paths or len(set(paths)) != len(paths):
        raise ValueError('Require distinct nonempty heldout shard paths')
    if output.exists():
        raise ValueError('Preserve existing evidence; output path already exists')
    current_hashes = fingerprints(project)
    runs = [_read_run(path, 'heldout') for path in paths]
    reference = runs[0]['provenance']
    if not isinstance(reference.get('pilot'), str) or not reference['pilot']:
        raise ValueError('Heldout shard lacks pilot path')
    if Path(reference['project']).resolve() != project:
        raise ValueError('Shard project differs from selected current project')
    if reference['source_sha256'] != current_hashes:
        raise ValueError('Current source differs from heldout fingerprints')
    pilot_path = Path(reference['pilot']).resolve()
    pilot = _read_run(pilot_path, 'pilot')
    if Path(pilot['provenance']['project']).resolve() != project:
        raise ValueError('Pilot project differs from heldout project')
    recorded = []
    all_rows = []
    for run in runs:
        meta = run['provenance']
        # Literal paths are intentionally part of identity; aliases are not silently
        # normalized into an apparently shared pilot/project provenance record.
        for key in ('source_sha256', 'project', 'max_ticks', 'pilot'):
            if meta.get(key) != reference.get(key):
                raise ValueError(f'Incompatible shard {key}: {run["path"]}')
        if set(recorded) & set(meta['seeds']):
            raise ValueError('Heldout shards overlap or duplicate seeds')
        admit_pilot(pilot['provenance'], meta['seeds'], current_hashes, meta['max_ticks'])
        recorded.extend(meta['seeds'])
        all_rows.extend(run['rows'])
    if set(recorded) != set(expected_seeds):
        raise ValueError('Shard union is not exactly the predeclared expected seed selection')
    all_rows.sort(key=lambda row: (row['seed'], STRATA.index(row['stratum_key']), MODES.index(row['mode'])))
    report = summarize(all_rows, expected_seeds, bootstrap=bootstrap, max_ticks=reference['max_ticks'])
    # Analysis may take time. Prove it consumed the same immutable input bytes and
    # current source before publishing a success record.
    if fingerprints(project) != current_hashes or not all(_unchanged(run) for run in runs + [pilot]):
        raise ValueError('Source or input evidence changed during merge')
    rounds_bytes = (json.dumps(all_rows, indent=2, allow_nan=False) + '\n').encode()
    comparison_bytes = (json.dumps(report, indent=2, allow_nan=False) + '\n').encode()
    manifest = {
        'format': 'phase03-ecology-merge-provenance-v1', 'phase': 'heldout',
        'success': True, 'source_stable': True, 'seeds': expected_seeds,
        'max_ticks': reference['max_ticks'], 'rows': len(all_rows),
        'project': str(project), 'pilot': str(pilot_path), 'source_sha256': current_hashes,
        'merger_sha256': _sha(Path(__file__).read_bytes()),
        'analyzer_sha256': current_hashes['tools/phase03_ecology_analysis.py'],
        'bootstrap_resamples': bootstrap,
        'inputs': [{'path': str(run['path']), 'seeds': run['provenance']['seeds'],
                    'file_sha256': run['file_sha256']} for run in runs],
        'pilot_file_sha256': pilot['file_sha256'],
        'output_sha256': {'rounds.json': _sha(rounds_bytes), 'comparison.json': _sha(comparison_bytes)},
        'note': 'Every predeclared seed and all 48 round rows retained. Shard CIs are not averaged; inference is recomputed over complete seed clusters.'}
    output.mkdir(parents=True, exist_ok=False)
    (output / 'rounds.json').write_bytes(rounds_bytes)
    (output / 'comparison.json').write_bytes(comparison_bytes)
    (output / 'merge-provenance.json').write_text(json.dumps(manifest, indent=2, allow_nan=False) + '\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('shards', type=Path, nargs='+')
    parser.add_argument('--seed', type=int, default=73601)
    parser.add_argument('--rounds', type=int, default=25)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--project', type=Path, default=ROOT)
    parser.add_argument('--bootstrap', type=int, default=2000)
    args = parser.parse_args()
    if not 1 <= args.rounds <= 1000:
        parser.error('Invalid expected round/seed count')
    try:
        manifest = merge_runs(args.shards, list(range(args.seed, args.seed + args.rounds)),
                              args.output, project=args.project, bootstrap=args.bootstrap)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.error(str(error))
    print(json.dumps({'success': manifest['success'], 'seeds': len(manifest['seeds']),
                      'rows': manifest['rows'], 'output': str(args.output.resolve())}))


if __name__ == '__main__':
    main()
