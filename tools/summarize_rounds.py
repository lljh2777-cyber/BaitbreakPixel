#!/usr/bin/env python3
"""Merge disjoint seed shards without treating censored rounds as finished."""
import argparse
import csv
import json
import statistics
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('inputs', nargs='+', type=Path)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--source-commit', required=True)
a=p.parse_args()
rows=[]
for folder in a.inputs:
    rows.extend(json.loads((folder/'rounds.json').read_text()))
seeds=[row['seed'] for row in rows]
if len(seeds)!=len(set(seeds)):
    raise SystemExit('Duplicate seed across input shards')
rows.sort(key=lambda row: row['seed'])
completed=[row for row in rows if row['completed']]
summary={'source_commit':a.source_commit,'rounds':len(rows),'completed_rounds':len(completed),
         'censored_rounds':len(rows)-len(completed),'first_seed':min(seeds),'last_seed':max(seeds),
         'median_round_duration':statistics.median(row['duration'] for row in completed) if completed else None,
         'mean_round_duration':statistics.mean(row['duration'] for row in completed) if completed else None,
         'fish_win_rate':sum(row['winner']=='fish' for row in rows)/len(rows),
         'food_consumed_mean':statistics.mean(row['food_consumed'] for row in rows),
         'hook_event_rate':sum(row['hook_events']>0 for row in rows)/len(rows),
         'hook_events_mean':statistics.mean(row['hook_events'] for row in rows),
         'note':'Completed-round duration excludes explicitly censored rows; bot evidence is not human playability acceptance.'}
for key in ['instinct_trigger_count','instinct_total_duration','critical_satiety_seconds','satiety_min','satiety_mean','caution_low_seconds','caution_medium_seconds','caution_high_seconds','feeding_attempts','feeding_aborts']:
    values=[row['stats'][key] for row in rows if key in row['stats']]
    summary[key+'_mean']=statistics.mean(values) if len(values)==len(rows) else None
for source,name in [('instinct_trigger_count','instinct_trigger_rate'),('critical_satiety_seconds','critical_satiety_rate')]:
    summary[name]=sum(row['stats'].get(source,0)>0 for row in rows)/len(rows) if all(source in row['stats'] for row in rows) else None
a.output.mkdir(parents=True,exist_ok=True)
(a.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
(a.output/'rounds.json').write_text(json.dumps(rows,indent=2)+'\n')
with (a.output/'rounds.csv').open('w',newline='') as handle:
    writer=csv.DictWriter(handle,fieldnames=[key for key in rows[0] if key!='stats']); writer.writeheader()
    writer.writerows({key:value for key,value in row.items() if key!='stats'} for row in rows)
print(json.dumps(summary,indent=2))
