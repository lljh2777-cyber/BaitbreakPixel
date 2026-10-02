#!/usr/bin/env python3
"""Bounded, source-fingerprinted paired 60 Hz feeding policy experiment.

Run pilot and held-out separately. Held-out requires a completed pilot manifest,
checks seed disjointness, and refuses mechanics/policy edits after pilot. Retain
all unsuccessful, incomplete and negative outcomes; inspect comparison.json.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
from run_tests import ROOT, run_bounded, ERROR
from phase02_compare_feeding import summarize


SOURCE_FILES = tuple(sorted((ROOT / 'scripts').glob('*.gd'))) + (
    ROOT / 'tools' / 'phase02_feeding_policy.gd',
    ROOT / 'tools' / 'phase02_simulate_feeding.gd',
)


def fingerprints() -> dict[str, str]:
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in SOURCE_FILES}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=('pilot', 'heldout', 'test'), required=True)
    parser.add_argument('--rounds', type=int, default=4, help='Paired seeds; three rounds per seed')
    parser.add_argument('--seed', type=int, default=21001)
    parser.add_argument('--max-ticks', type=int, default=22200)
    parser.add_argument('--pilot', type=Path, help='Completed pilot output directory; required for heldout')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--timeout', type=float, default=600.0)
    args = parser.parse_args()
    if not 1 <= args.rounds <= 1000 or not 1 <= args.max_ticks <= 108600 or not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error('Invalid bounds')
    output = args.output.resolve()
    if (output / 'provenance.json').exists():
        parser.error('Output already contains an experiment; use a new directory to preserve evidence')
    hashes = fingerprints()
    seeds = list(range(args.seed, args.seed + args.rounds))
    if args.phase == 'heldout':
        if not args.pilot:
            parser.error('--pilot is required for heldout')
        pilot = json.loads((args.pilot / 'provenance.json').read_text())
        if pilot.get('phase') != 'pilot' or not pilot.get('success'):
            parser.error('Pilot must be a successful completed experiment')
        if set(pilot['seeds']) & set(seeds):
            parser.error('Held-out seeds must not overlap pilot seeds')
        if hashes != pilot['source_sha256']:
            parser.error('Source changed since pilot; run a new bounded pilot before held-out evaluation')
        if args.max_ticks != pilot['max_ticks']:
            parser.error('Pilot and held-out horizons must match')
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
        folder = output / key.lower()
        folder.mkdir(exist_ok=True)
        env[key] = str(folder)
    manifest = {'phase': args.phase, 'seeds': seeds, 'max_ticks': args.max_ticks,
                'source_sha256': hashes, 'pilot': str(args.pilot.resolve()) if args.pilot else None,
                'success': False, 'note': 'Source hashes checked before and after; no outcome/seed filtering.'}
    (output / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')
    # Freeze controller/harness alongside results for audit; game scripts remain
    # identified by their full source hashes and selected project checkout.
    for source in SOURCE_FILES[-2:]:
        (output / source.name).write_bytes(source.read_bytes())
    command = [args.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT),
               '--script', 'res://tools/phase02_simulate_feeding.gd', '--', '--test-profile',
               f'--rounds={args.rounds}', f'--seed={args.seed}', f'--max-ticks={args.max_ticks}',
               f'--phase={args.phase}', f'--output={output}']
    result = run_bounded(command, args.timeout, ROOT, env)
    (output / 'run.log').write_text(result['output'])
    manifest['execution'] = {key: value for key, value in result.items() if key != 'output'}
    manifest['source_stable'] = fingerprints() == hashes
    success = (not result['returncode'] and not result['timed_out'] and not result['launch_error']
               and not ERROR.search(result['output']) and 'FEEDING_SUMMARY | ' in result['output']
               and manifest['source_stable'])
    if success:
        rows = json.loads((output / 'rounds.json').read_text())
        if len(rows) != args.rounds * 3 or {r['seed'] for r in rows} != set(seeds):
            success = False
        else:
            comparison = summarize(rows)
            (output / 'comparison.json').write_text(json.dumps(comparison, indent=2) + '\n')
            for name, data in comparison['policies'].items():
                print(name, json.dumps(data['metrics']))
    manifest['success'] = success
    (output / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(result['output'][-5000:])
    print(json.dumps({'success': success, 'output': str(output), **manifest['execution']}))
    raise SystemExit(0 if success else 1)


if __name__ == '__main__':
    main()
