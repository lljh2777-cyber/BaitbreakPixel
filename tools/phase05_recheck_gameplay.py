"""Retain original evidence and replay rounds stopped by the net-lift test bug."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import json
from run_tests import ROOT, ERROR, run_bounded
from phase05_run_gameplay import summarize


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    report_path = output / 'report.json'
    initial = json.loads(report_path.read_text(encoding='utf-8'))
    rows = [json.loads(line) for p in sorted(output.glob('rounds-[0-9][0-9][0-9][0-9].jsonl'))
            for line in p.read_text(encoding='utf-8').splitlines() if line]
    assert len(rows) == 1000 and {r['run'] for r in rows} == set(range(1000))
    before = output / 'initial-report.json'
    if before.exists():
        raise SystemExit('Rechecks already attempted; preserve evidence and investigate separately')
    before.write_bytes(report_path.read_bytes())
    rechecks = output / 'rechecks'
    rechecks.mkdir(exist_ok=True)
    selected = [r for r in rows if not r['valid'] or not r['completed']]

    def replay(row):
        path = rechecks / f"round-{row['run']:04d}.jsonl"
        command = [args.godot, '--headless', '--path', str(ROOT), '--script',
                   'res://tools/phase05_gameplay_sweep.gd', '--', f"--first={row['run']}",
                   '--count=1', f'--output={path.as_posix()}']
        result = run_bounded(command, 180, ROOT)
        path.with_suffix('.log').write_text(result['output'], encoding='utf-8')
        assert result['returncode'] == 0 and not result['timed_out'] and not ERROR.search(result['output']), path
        updated = json.loads(path.read_text(encoding='utf-8').strip())
        assert updated['run'] == row['run'] and updated['valid'] and updated['completed']
        print('RECHECK PASS', row['run'], flush=True)
        return updated

    with ThreadPoolExecutor(max_workers=4) as pool:
        replacements = {r['run']: r for r in pool.map(replay, selected)}
    rows = sorted((replacements.get(r['run'], r) for r in rows), key=lambda r: r['run'])
    passed = all(r['valid'] and r['completed'] and not r['supply_deadlock'] for r in rows)
    initial['passed'] = passed
    initial['summary'] = summarize(rows)
    initial['maps'] = {str(seed): summarize([r for r in rows if r['map_seed'] == seed]) for seed in sorted({r['map_seed'] for r in rows})}
    initial['strata'] = {key: summarize([r for r in rows if r['policy']+'/'+r['mode'] == key]) for key in sorted({r['policy']+'/'+r['mode'] for r in rows})}
    initial['rechecked_runs'] = sorted(replacements)
    initial['test_correction'] = 'Harness v1 incorrectly required net-caught fish to remain inside water during legal lift/retraction. v2 permits net-caught/landing positions and still validates full final Snapshot. All stopped/invalid rounds replayed from tick zero; original files retained.'
    (output / 'validated-rounds.jsonl').write_text(''.join(json.dumps(r, ensure_ascii=False)+'\n' for r in rows), encoding='utf-8')
    report_path.write_text(json.dumps(initial, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'passed': passed, 'replayed': len(replacements), 'runs': len(rows)}), flush=True)
    raise SystemExit(0 if passed else 1)


if __name__ == '__main__':
    main()
