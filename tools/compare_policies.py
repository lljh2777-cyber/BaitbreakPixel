#!/usr/bin/env python3
"""Paired policy evidence, with deterministic bootstrap intervals (not a fun verdict)."""
import argparse
import json
import random
import statistics
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('distance',type=Path); p.add_argument('cautious',type=Path)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args()
left={row['seed']:row for row in json.loads((a.distance/'rounds.json').read_text())}
right={row['seed']:row for row in json.loads((a.cautious/'rounds.json').read_text())}
if set(left)!=set(right): raise SystemExit('Seed sets do not match')
seeds=sorted(left)
metrics={'fish_win_rate':lambda row:float(row['winner']=='fish'),
         'hook_event_rate':lambda row:float(row['stats']['hook_events']>0),
         'hook_events_mean':lambda row:float(row['stats']['hook_events']),
         'food_consumed_mean':lambda row:float(row['food_consumed']),
         'survival_seconds_mean':lambda row:float(row['duration'])}
summary={'paired_seeds':len(seeds),'first_seed':min(seeds),'last_seed':max(seeds),
         'completed_distance':sum(row['completed'] for row in left.values()),
         'completed_cautious':sum(row['completed'] for row in right.values()),
         'difference_direction':'cautious minus distance','bootstrap_replicates':2000,'metrics':{},
         'note':'Paired bot policies share seeds; uncertainty intervals describe this seed distribution, not human play quality.'}
rng=random.Random(73623)
for name,fn in metrics.items():
    differences=[fn(right[seed])-fn(left[seed]) for seed in seeds]
    bootstrap=sorted(statistics.mean(rng.choices(differences,k=len(seeds))) for _ in range(2000))
    summary['metrics'][name]={'distance':statistics.mean(fn(left[seed]) for seed in seeds),
                              'cautious':statistics.mean(fn(right[seed]) for seed in seeds),
                              'paired_difference':statistics.mean(differences),
                              'paired_bootstrap_95_percent':[bootstrap[50],bootstrap[1949]]}
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
