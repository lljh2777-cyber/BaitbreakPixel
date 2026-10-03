#!/usr/bin/env python3
"""Merge complete, disjoint, identical-source NPC experiment shards."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from phase03_run_competition import summarize

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('shards', nargs='+', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if (output / 'provenance.json').exists(): parser.error('Preserve previous evidence; use a new output directory')
    rows, seeds, manifests = [], [], []
    for shard in args.shards:
        manifest = json.loads((shard / 'provenance.json').read_text())
        if not manifest.get('success') or not manifest.get('source_stable'):
            parser.error(f'Unsuccessful or source-unstable shard: {shard}')
        if set(seeds) & set(manifest['seeds']): parser.error('Overlapping seeds')
        if manifests:
            for key in ('source_sha256', 'max_ticks', 'phase', 'pilot'):
                if manifest[key] != manifests[0][key]: parser.error(f'Mismatched {key}')
        seeds.extend(manifest['seeds']); rows.extend(json.loads((shard / 'rounds.json').read_text())); manifests.append(manifest)
    seeds.sort(); rows.sort(key=lambda row: (row['seed'], row['mode']))
    comparison = summarize(rows, seeds)
    output.mkdir(parents=True, exist_ok=True)
    (output / 'rounds.json').write_text(json.dumps(rows, indent=2) + '\n')
    (output / 'comparison.json').write_text(json.dumps(comparison, indent=2) + '\n')
    manifest = dict(manifests[0])
    manifest.pop('execution', None)
    manifest.update(seeds=seeds, source_stable=True, success=True,
                    shard_directories=[str(path.resolve()) for path in args.shards],
                    shard_manifest_sha256={str(path.resolve()): hashlib.sha256((path / 'provenance.json').read_bytes()).hexdigest() for path in args.shards},
                    merge_script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                    note='Complete disjoint shards with identical source, policy, horizon and pilot. All rows retained; no favorable seed filtering.')
    (output / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')
    for mode, row in comparison['modes'].items(): print(mode, json.dumps(row['metrics']))
    print(json.dumps({'success': True, 'paired_seeds': len(seeds), 'output': str(output)}))

if __name__ == '__main__': main()
