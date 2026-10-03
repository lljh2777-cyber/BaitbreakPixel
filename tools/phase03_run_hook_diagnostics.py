#!/usr/bin/env python3
"""P3.4 source-fingerprinted four-arm, same-seed diagnostic; no balance tuning."""
from __future__ import annotations
import argparse
import hashlib
import itertools
import json
import math
import os
from pathlib import Path
import random
import statistics
from run_tests import ROOT, run_bounded, ERROR

MODES = ('NoNPC', 'PassiveNPC', 'ForagingNPC', 'HookableNPC')
METRICS = ('player_food', 'npc_food', 'hook_events', 'hook_contacts', 'duration',
           'player_hooked_seconds', 'npc_hook_count', 'npc_escapes', 'npc_breaks',
           'wrong_catches', 'npc_hooked_seconds', 'lifecycle_events',
           'lifecycle_per_sim_minute', 'no_food_seconds', 'longest_no_food_seconds',
           'longest_player_no_intake_seconds', 'replacement_ids_allocated')
COUNTERS = ('hook_events', 'hook_contacts', 'npc_hook_count', 'npc_escapes',
            'npc_breaks', 'wrong_catches', 'lifecycle_events', 'replacement_ids_allocated')


def sources():
    return tuple(sorted((ROOT / 'scripts').glob('*.gd'))) + (
        ROOT / 'tools/phase03_hook_protocol.md',
        ROOT / 'tools/phase02_feeding_policy.gd',
        ROOT / 'tools/phase03_hook_diagnostics.gd', Path(__file__).resolve())


def fingerprints():
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources()}


def summarize(rows, seeds, bootstrap=2000):
    if not seeds or len(seeds) != len(set(seeds)):
        raise ValueError('Require nonempty distinct paired seeds')
    if bootstrap < 40:
        raise ValueError('At least 40 bootstrap resamples required')
    grouped = {mode: {} for mode in MODES}
    for row in rows:
        mode, seed = row['mode'], row['seed']
        if mode not in grouped or seed in grouped[mode]:
            raise ValueError('Unknown mode or duplicate seed')
        grouped[mode][seed] = row
        for key in METRICS:
            value = row[key]
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                raise ValueError(f'Invalid measured metric: {key}')
        for key in COUNTERS:
            if int(row[key]) != row[key]:
                raise ValueError(f'Counter is not an integer: {key}')
        if type(row['ticks']) is not int or row['ticks'] <= 0 or abs(row['ticks'] / 60 - row['duration']) > 1e-6:
            raise ValueError('Measured duration is not actual 60 Hz ticks')
        if type(row['completed']) is not bool or row['winner'] not in ('', 'fish', 'angler'):
            raise ValueError('Invalid match outcome')
        if row['completed'] != bool(row['winner']) or row['completed'] != bool(row['reason']):
            raise ValueError('Incomplete round must not masquerade as a completed win/loss')
        if row['home_win'] != (row['winner'] == 'fish' and row['reason'] == 'home'):
            raise ValueError('Inconsistent home outcome')
        for total, typed in [('player_food', 'player_food_by_type'), ('npc_food', 'npc_food_by_type')]:
            if set(row[typed]) != {'cluster', 'worm', 'chunk'} or any(not isinstance(v, (int, float)) or isinstance(v, bool) or not math.isfinite(v) or v < 0 for v in row[typed].values()):
                raise ValueError('Invalid per-type food totals')
            if abs(row[total] - sum(row[typed].values())) > 1e-6:
                raise ValueError(f'{total} does not reconcile with per-type totals')
        if row['observed_npc_attachments'] != row['npc_hook_count']:
            raise ValueError('NPC hook counter disagrees with observed target transitions')
        if sum(row[k] for k in ('npc_escapes', 'npc_breaks', 'wrong_catches')) > row['npc_hook_count']:
            raise ValueError('NPC resolutions exceed actual attachments')
        unresolved = row['npc_hook_count'] - sum(row[k] for k in ('npc_escapes', 'npc_breaks', 'wrong_catches'))
        if unresolved != int(row['final_hook_target_fish_id'] > 1):
            raise ValueError('NPC lifecycle outcomes do not reconcile with final target')
        for key in ('npc_hooked_seconds', 'player_hooked_seconds', 'no_food_seconds', 'longest_no_food_seconds', 'longest_player_no_intake_seconds'):
            if row[key] > row['duration'] + 1e-6:
                raise ValueError(f'Time metric exceeds round duration: {key}')
        if row['longest_no_food_seconds'] > row['no_food_seconds'] + 1e-6:
            raise ValueError('Longest no-food interval exceeds total')
        if mode != 'HookableNPC' and any(row[key] != 0 for key in ('npc_hook_count', 'npc_escapes', 'npc_breaks', 'wrong_catches', 'npc_hooked_seconds', 'replacement_ids_allocated')):
            raise ValueError('Nonhookable control reports an NPC hook outcome')
        if mode in ('NoNPC', 'PassiveNPC') and row['npc_food'] != 0:
            raise ValueError('Passive control consumed food')
    if any(set(grouped[mode]) != set(seeds) for mode in MODES):
        raise ValueError('Incomplete paired sample')
    reference_rules = grouped['NoNPC'][seeds[0]]['rules']
    for seed in seeds:
        if len({grouped[mode][seed]['food_goal'] for mode in MODES}) != 1:
            raise ValueError('Goal differs across paired modes')
        if any(grouped[mode][seed]['rules'] != reference_rules for mode in MODES):
            raise ValueError('Rules differ across arms or seeds')
    metrics = {key: lambda row, key=key: row[key] for key in METRICS}
    metrics.update(fish_win_fraction=lambda row: float(row['winner'] == 'fish'),
                   completion_fraction=lambda row: float(row['completed']),
                   player_hook_fraction=lambda row: float(row['hook_events'] > 0),
                   npc_hook_fraction=lambda row: float(row['npc_hook_count'] > 0),
                   wrong_catch_fraction=lambda row: float(row['wrong_catches'] > 0))
    result = {'format': 'phase03-hook-comparison-v1', 'paired_seeds': len(seeds), 'seeds': seeds,
              'modes': {}, 'paired_differences': {},
              'note': 'All outcomes retained; win fractions use all rounds, unfinished separately listed. Paired seed-bootstrap intervals describe this bounded autonomous sample, not human win rates or balance acceptance.'}
    for mode in MODES:
        samples = [grouped[mode][seed] for seed in seeds]
        result['modes'][mode] = {
            'completed': sum(row['completed'] for row in samples),
            'incomplete_seeds': [row['seed'] for row in samples if not row['completed']],
            'outcome_reasons': {reason: sum((row['reason'] or 'incomplete') == reason for row in samples)
                                for reason in sorted({row['reason'] or 'incomplete' for row in samples})},
            'metrics': {key: statistics.mean(fn(row) for row in samples) for key, fn in metrics.items()},
            'totals': {key: sum(row[key] for row in samples) for key in COUNTERS}}
    control_keys = ('player_food', 'player_food_by_type', 'winner', 'reason', 'completed',
                    'hook_events', 'hook_contacts', 'duration', 'lifecycle_events', 'stats')
    result['passive_control_mismatched_seeds'] = [seed for seed in seeds if any(
        grouped['NoNPC'][seed][key] != grouped['PassiveNPC'][seed][key] for key in control_keys)]
    rng = random.Random(634050)
    for left, right in itertools.combinations(MODES, 2):
        effects = {}
        for key, fn in metrics.items():
            diffs = [fn(grouped[right][seed]) - fn(grouped[left][seed]) for seed in seeds]
            estimates = sorted(statistics.mean(rng.choices(diffs, k=len(diffs))) for _ in range(bootstrap))
            effects[key] = {'mean': statistics.mean(diffs), 'paired_bootstrap_95_percent':
                            [estimates[int(bootstrap * .025)], estimates[int(bootstrap * .975) - 1]]}
        result['paired_differences'][f'{right} minus {left}'] = effects
    result['observed_hookable_events'] = sum(grouped['HookableNPC'][seed]['npc_hook_count'] for seed in seeds)
    result['event_coverage_note'] = ('Actual NPC hook events occurred; review outcomes and occupied time.'
                                   if result['observed_hookable_events'] else 'No natural NPC hook event in this sample; do not infer that wrong-catch behavior was exercised or frequency is zero.')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=('pilot', 'heldout', 'test'), required=True)
    parser.add_argument('--rounds', type=int, default=8)
    parser.add_argument('--seed', type=int, default=64301)
    parser.add_argument('--max-ticks', type=int, default=22200)
    parser.add_argument('--pilot', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--timeout', type=float, default=1800)
    args = parser.parse_args()
    if not 1 <= args.rounds <= 1000 or not 1 <= args.max_ticks <= 108600 or not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error('Invalid bounds')
    output = args.output.resolve()
    if any((output / name).exists() for name in ('provenance.json', 'rounds.json', 'summary.json')):
        parser.error('Preserve existing results; choose a new output directory')
    seeds = list(range(args.seed, args.seed + args.rounds))
    hashes = fingerprints()
    if args.phase == 'heldout':
        if args.pilot is None: parser.error('--pilot is required')
        pilot = json.loads((args.pilot / 'provenance.json').read_text())
        if pilot.get('phase') != 'pilot' or not pilot.get('success') or not pilot.get('source_stable'):
            parser.error('Successful source-stable pilot required')
        if set(pilot['seeds']) & set(seeds): parser.error('Held-out seeds overlap pilot')
        if pilot['source_sha256'] != hashes: parser.error('Source changed since pilot')
        if args.max_ticks != pilot['max_ticks']: parser.error('Pilot horizon mismatch')
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
        directory = output / key.lower(); directory.mkdir(exist_ok=True); env[key] = str(directory)
    manifest = {'format': 'phase03-hook-provenance-v1', 'phase': args.phase, 'seeds': seeds,
                'max_ticks': args.max_ticks, 'source_sha256': hashes, 'success': False,
                'pilot': str(args.pilot.resolve()) if args.pilot else None,
                'note': 'Unmodified default rules and P2 policies; all four arms and all outcomes retained.'}
    manifest_path = output / 'provenance.json'
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    for source in sources()[-4:]: (output / source.name).write_bytes(source.read_bytes())
    command = [args.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT),
               '--script', 'res://tools/phase03_hook_diagnostics.gd', '--', '--test-profile',
               f'--rounds={args.rounds}', f'--seed={args.seed}', f'--max-ticks={args.max_ticks}', f'--output={output}']
    run = run_bounded(command, args.timeout, ROOT, env)
    (output / 'run.log').write_text(run['output'])
    manifest['execution'] = {key: value for key, value in run.items() if key != 'output'}
    manifest['source_stable'] = fingerprints() == hashes
    success = not (run['returncode'] or run['timed_out'] or run['launch_error'] or ERROR.search(run['output']))
    success = success and 'NPC_HOOK_DIAGNOSTIC_SUMMARY | ' in run['output'] and manifest['source_stable']
    if success:
        try:
            report = summarize(json.loads((output / 'rounds.json').read_text()), seeds)
        except (KeyError, TypeError, ValueError) as error:
            success = False; manifest['analysis_error'] = str(error)
        else:
            (output / 'comparison.json').write_text(json.dumps(report, indent=2) + '\n')
            for mode, data in report['modes'].items(): print(mode, json.dumps(data['metrics']))
    manifest['success'] = bool(success)
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print(run['output'][-6000:]); print(json.dumps({'success': success, 'output': str(output)}))
    raise SystemExit(0 if success else 1)


if __name__ == '__main__': main()
