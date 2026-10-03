#!/usr/bin/env python3
"""Source-fingerprinted, paired NoNPC/PassiveNPC/ForagingNPC experiment."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import random
import statistics
from run_tests import ROOT, run_bounded, ERROR

MODES = ('NoNPC', 'PassiveNPC', 'ForagingNPC')
METRICS = ('player_food', 'npc_food', 'hook_events', 'hook_contacts', 'duration',
           'lifecycle_events', 'lifecycle_per_sim_minute', 'no_food_seconds',
           'longest_no_food_seconds', 'longest_player_no_intake_seconds',
           'npc_feeding_events', 'player_npc_food_contests', 'npc_target_switches')
SOURCES = tuple(sorted((ROOT / 'scripts').glob('*.gd'))) + (
    ROOT / 'tools/phase02_feeding_policy.gd',
    ROOT / 'tools/phase03_simulate_competition.gd',
    ROOT / 'tools/phase03_run_competition.py',
)

def fingerprints():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCES}

def summarize(rows, seeds, bootstrap=2000):
    grouped = {mode: {} for mode in MODES}
    for row in rows:
        mode, seed = row['mode'], row['seed']
        if mode not in grouped or seed in grouped[mode]:
            raise ValueError('Unknown mode or duplicate seed')
        grouped[mode][seed] = row
        if abs(row['ticks'] / 60 - row['duration']) > 1e-6:
            raise ValueError('Measured duration is not actual 60 Hz ticks')
        for total, typed in [('player_food', 'player_food_by_type'), ('npc_food', 'npc_food_by_type')]:
            if abs(row[total] - sum(row[typed].values())) > 1e-6:
                raise ValueError(f'{total} does not reconcile with per-type totals')
        if row['npc_hook_count'] is not None or row['wrong_catches'] is not None:
            raise ValueError('Unimplemented P3.4 outcomes must not masquerade as measured zero')
    if any(set(grouped[mode]) != set(seeds) for mode in MODES):
        raise ValueError('Incomplete paired sample')
    for seed in seeds:
        if len({grouped[mode][seed]['food_goal'] for mode in MODES}) != 1:
            raise ValueError('Goal differs across paired modes')
    metrics = {key: lambda r, key=key: r[key] for key in METRICS}
    metrics.update(fish_win_fraction=lambda r: float(r['winner'] == 'fish'),
                   home_win_fraction=lambda r: float(r['home_win']),
                   completion_fraction=lambda r: float(r['completed']),
                   hook_event_fraction=lambda r: float(r['hook_events'] > 0))
    report = {'paired_seeds': len(seeds), 'seeds': seeds, 'modes': {}, 'paired_differences': {},
              'note': 'All outcomes retained. Win fractions divide by all rounds, with incomplete counts reported separately. Marginal paired bootstrap intervals are descriptive seed uncertainty, not a human-playability guarantee.',
              'unimplemented_metrics': ['npc_hook_count', 'wrong_catches']}
    for mode in MODES:
        samples = [grouped[mode][seed] for seed in seeds]
        reasons = {}
        for row in samples:
            reason = row['reason'] or 'incomplete'
            reasons[reason] = reasons.get(reason, 0) + 1
        report['modes'][mode] = {
            'completed': sum(r['completed'] for r in samples),
            'incomplete_seeds': [r['seed'] for r in samples if not r['completed']],
            'outcome_reasons': reasons,
            'metrics': {key: statistics.mean(fn(r) for r in samples) for key, fn in metrics.items()},
            'npc_food_by_type_mean': {kind: statistics.mean(r['npc_food_by_type'].get(kind, 0.0) for r in samples) for kind in ('cluster', 'worm', 'chunk')}}
    control_keys = ('player_food', 'player_food_by_type', 'winner', 'reason', 'completed',
                    'hook_events', 'hook_contacts', 'duration', 'lifecycle_events', 'stats')
    report['passive_control_mismatched_seeds'] = [seed for seed in seeds
        if any(grouped['NoNPC'][seed][key] != grouped['PassiveNPC'][seed][key] for key in control_keys)]
    report['passive_control_check'] = 'Exact non-NPC outcome, player intake, hook, lifecycle and authority-stat equality; NPC motion/population fields excluded.'
    rng = random.Random(325061)
    for left, right in [('NoNPC', 'PassiveNPC'), ('NoNPC', 'ForagingNPC'), ('PassiveNPC', 'ForagingNPC')]:
        effects = {}
        for key, fn in metrics.items():
            diffs = [fn(grouped[right][seed]) - fn(grouped[left][seed]) for seed in seeds]
            resamples = sorted(statistics.mean(rng.choices(diffs, k=len(diffs))) for _ in range(bootstrap))
            effects[key] = {'mean': statistics.mean(diffs), 'paired_bootstrap_95_percent': [resamples[int(bootstrap*.025)], resamples[int(bootstrap*.975)-1]]}
        report['paired_differences'][f'{right} minus {left}'] = effects
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=('pilot', 'heldout', 'test'), required=True)
    parser.add_argument('--rounds', type=int, default=4)
    parser.add_argument('--seed', type=int, default=43001)
    parser.add_argument('--max-ticks', type=int, default=22200)
    parser.add_argument('--pilot', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--timeout', type=float, default=1200)
    args = parser.parse_args()
    if not 1 <= args.rounds <= 1000 or not 1 <= args.max_ticks <= 108600 or not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error('Invalid bounds')
    output = args.output.resolve()
    if (output / 'provenance.json').exists():
        parser.error('Preserve existing results; choose a new output directory')
    seeds = list(range(args.seed, args.seed + args.rounds))
    hashes = fingerprints()
    if args.phase == 'heldout':
        if args.pilot is None: parser.error('--pilot is required')
        pilot = json.loads((args.pilot / 'provenance.json').read_text())
        if pilot.get('phase') != 'pilot' or not pilot.get('success'): parser.error('Successful pilot required')
        if set(pilot['seeds']) & set(seeds): parser.error('Held-out seeds overlap pilot')
        if pilot['source_sha256'] != hashes: parser.error('Source changed since pilot')
        if args.max_ticks != pilot['max_ticks']: parser.error('Pilot horizon mismatch')
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
        path = output / key.lower(); path.mkdir(exist_ok=True); env[key] = str(path)
    manifest = {'phase': args.phase, 'seeds': seeds, 'max_ticks': args.max_ticks,
                'source_sha256': hashes, 'success': False,
                'pilot': str(args.pilot.resolve()) if args.pilot else None,
                'note': 'All modes use paired seeds and unmodified default survival challenge rules; source checked before/after; no outcome filtering.'}
    manifest_path = output / 'provenance.json'
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    for source in SOURCES[-3:]: (output / source.name).write_bytes(source.read_bytes())
    command = [args.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT),
               '--script', 'res://tools/phase03_simulate_competition.gd', '--', '--test-profile',
               f'--rounds={args.rounds}', f'--seed={args.seed}', f'--max-ticks={args.max_ticks}', f'--output={output}']
    result = run_bounded(command, args.timeout, ROOT, env)
    (output / 'run.log').write_text(result['output'])
    manifest['execution'] = {k: v for k, v in result.items() if k != 'output'}
    manifest['source_stable'] = fingerprints() == hashes
    success = (not result['returncode'] and not result['timed_out'] and not result['launch_error']
               and not ERROR.search(result['output']) and 'NPC_COMPARISON_SUMMARY | ' in result['output']
               and manifest['source_stable'])
    if success:
        rows = json.loads((output / 'rounds.json').read_text())
        comparison = summarize(rows, seeds)
        (output / 'comparison.json').write_text(json.dumps(comparison, indent=2) + '\n')
        for mode, row in comparison['modes'].items(): print(mode, json.dumps(row['metrics']))
    manifest['success'] = success
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print(result['output'][-6000:])
    print(json.dumps({'success': success, 'output': str(output), **manifest['execution']}))
    raise SystemExit(0 if success else 1)

if __name__ == '__main__': main()
