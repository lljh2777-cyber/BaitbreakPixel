"""Bounded full-round matrix. No file, frame, or state SHA scans."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import argparse
import json
import time
from run_tests import ROOT, ERROR, run_bounded



def summarize(values):
    n = len(values)
    result = {'runs': n, 'completed': sum(r['completed'] for r in values),
              'valid': sum(r['valid'] for r in values), 'supply_deadlocks': sum(r['supply_deadlock'] for r in values)}
    for key in ['duration', 'food', 'npc_food', 'hook_events', 'npc_wrong_hooks', 'wrap_usage',
                'longest_no_food_seconds', 'longest_eligible_supply_stall', 'longest_return_stall']:
        result[key] = {'mean': sum(r[key] for r in values)/n, 'min': min(r[key] for r in values), 'max': max(r[key] for r in values)}
    result['fish_win_rate'] = sum(r['winner'] == 'fish' for r in values)/n
    for key in ['net_catch', 'home_completion']:
        result[key+'_rate'] = sum(r[key] for r in values)/n
    result['hook_rate'] = sum(r['hook_events'] > 0 for r in values)/n
    result['npc_wrong_hook_rate'] = sum(r['npc_wrong_hooks'] > 0 for r in values)/n
    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=4, choices=range(1, 9))
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise SystemExit('Use a new output directory to preserve previous evidence')
    start = time.monotonic()

    def batch(first, count):
        rows_path = output / f'rounds-{first:04d}.jsonl'
        command = [args.godot, '--headless', '--path', str(ROOT), '--script',
                   'res://tools/phase05_gameplay_sweep.gd', '--', f'--first={first}',
                   f'--count={count}', f'--output={rows_path.as_posix()}']
        result = run_bounded(command, 7200, ROOT)
        (output / f'batch-{first:04d}.log').write_text(result['output'], encoding='utf-8')
        ok = result['returncode'] == 0 and not result['timed_out'] and not ERROR.search(result['output'])
        print(f'BATCH {first}: {count} rounds, {"PASS" if ok else "FAIL"}', flush=True)
        return ok

    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        jobs = [pool.submit(batch, first, min(100, 1000-first)) for first in range(0, 1000, 100)]
        for job in as_completed(jobs):
            results.append(job.result())
    rows = [json.loads(line) for p in sorted(output.glob('rounds-*.jsonl'))
            for line in p.read_text(encoding='utf-8').splitlines() if line]
    maps = {}
    for row in rows:
        maps.setdefault(str(row['map_seed']), []).append(row)


    passed = (all(results) and len(rows) == 1000 and {r['run'] for r in rows} == set(range(1000))
              and all(r['valid'] and r['completed'] and not r['supply_deadlock'] for r in rows))
    report = {'format': 'phase05-gameplay-v1', 'passed': passed, 'wall_seconds': time.monotonic()-start,
              'protocol': '25 map seeds x 20 simulation seeds x 2 controllers; alternating survival/duel; default rules, 3 NPCs, 60 Hz; full rounds (370 s guard)',
              'limits': 'AI diagnostics are not human balance approval. Sustained no-food/supply or return stalls are retained for inspection, not discarded.',
              'summary': summarize(rows) if rows else {}, 'maps': {key: summarize(value) for key, value in maps.items()},
              'strata': {key: summarize([r for r in rows if r['policy']+'/'+r['mode'] == key]) for key in sorted({r['policy']+'/'+r['mode'] for r in rows})}}
    (output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'passed': passed, 'runs': len(rows), 'wall_seconds': report['wall_seconds']}), flush=True)
    raise SystemExit(0 if passed else 1)


if __name__ == '__main__':
    main()
