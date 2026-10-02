#!/usr/bin/env python3
"""Merge disjoint held-out feeding batches with identical source fingerprints."""
from __future__ import annotations
import argparse
import csv
import json
from pathlib import Path
from phase02_compare_feeding import summarize


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('batches', nargs='+', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if (args.output / 'provenance.json').exists():
        parser.error('Use a new output directory to preserve previous evidence')
    rows, provenance, seen = [], [], set()
    for folder in args.batches:
        manifest = json.loads((folder / 'provenance.json').read_text())
        if not manifest.get('success') or manifest.get('phase') != 'heldout':
            parser.error(f'{folder}: requires completed held-out run')
        if seen & set(manifest['seeds']):
            parser.error('Seed batches overlap')
        if provenance and any(manifest[key] != provenance[0][key] for key in ('source_sha256', 'max_ticks', 'pilot')):
            parser.error('Source, horizon or pilot differs')
        seen.update(manifest['seeds'])
        batch = json.loads((folder / 'rounds.json').read_text())
        if len(batch) != len(manifest['seeds']) * 3 or {r['seed'] for r in batch} != set(manifest['seeds']):
            parser.error(f'{folder}: row set differs from provenance')
        rows.extend(batch)
        provenance.append(manifest)
    rows.sort(key=lambda row: (row['seed'], row['policy']))
    comparison = summarize(rows)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'rounds.json').write_text(json.dumps(rows, indent=2) + '\n')
    (args.output / 'comparison.json').write_text(json.dumps(comparison, indent=2) + '\n')
    manifest = {'phase': 'heldout', 'success': True, 'seeds': sorted(seen),
                'source_sha256': provenance[0]['source_sha256'], 'max_ticks': provenance[0]['max_ticks'],
                'pilot': provenance[0]['pilot'], 'batches': [str(p.resolve()) for p in args.batches],
                'note': 'Disjoint unchanged-source paired batches; all rows preserved, no selection on outcomes.'}
    (args.output / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')
    summaries = [json.loads((folder / 'summary.json').read_text()) for folder in args.batches]
    summary = dict(summaries[0])
    summary.update(paired_seeds=len(seen), first_seed=min(seen), last_seed=max(seen),
                   wall_seconds=sum(item['wall_seconds'] for item in summaries),
                   note='Merged disjoint unchanged-source held-out batches; all results preserved. Wall seconds sum batch durations, which may overlap.')
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    fields = ['seed', 'policy', 'ticks', 'duration', 'completed', 'winner', 'reason', 'home_win', 'food_consumed',
              'satiety_final', 'satiety_mean', 'satiety_min', 'hook_contacts', 'hook_events', 'feeding_attempts',
              'feeding_seconds', 'suction_command_attempts', 'suction_command_seconds', 'automatic_bite_events',
              'automatic_bite_while_suction_command']
    with (args.output / 'rounds.csv').open('w', newline='') as file:
        writer = csv.DictWriter(file, fields, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps({'paired_seeds': len(seen), 'rounds': len(rows), 'output': str(args.output)}))
    for name, data in comparison['policies'].items():
        print(name, json.dumps(data['metrics']))


if __name__ == '__main__':
    main()
