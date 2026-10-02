#!/usr/bin/env python3
"""Bounded batch runner with isolated Godot user/cache directories."""
import argparse
import json
import os
from pathlib import Path
from run_tests import ROOT, run_bounded

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--project', type=Path, default=ROOT)
p.add_argument('--harness', type=Path, default=ROOT / 'tools' / 'simulate_rounds.gd')
p.add_argument('--rounds', type=int, default=1000)
p.add_argument('--seed', type=int, default=1)
p.add_argument('--strategy', default='baseline', choices=['baseline'])
p.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
p.add_argument('--timeout', type=float, default=3600)
p.add_argument('--output', type=Path, default=ROOT / 'artifacts' / 'batch-baseline')
a = p.parse_args()
out = a.output.resolve(); out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ)
for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
    folder = out / key.lower(); folder.mkdir(exist_ok=True); env[key] = str(folder)
r = run_bounded([a.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(a.project.resolve()), '--script', str(a.harness.resolve()), '--', f'--rounds={a.rounds}', f'--seed={a.seed}', f'--strategy={a.strategy}', f'--output={out}'], a.timeout, ROOT, env)
(out/'run.log').write_text(r['output'])
import hashlib
(out/'provenance.json').write_text(json.dumps({'project':str(a.project.resolve()), 'harness':str(a.harness.resolve()), 'harness_sha256':hashlib.sha256(a.harness.read_bytes()).hexdigest()},indent=2))
print(r['output'][-6000:])
print(json.dumps({k:v for k,v in r.items() if k!='output'}))
raise SystemExit(1 if r['returncode'] or r['timed_out'] or 'SCRIPT ERROR:' in r['output'] or 'ERROR:' in r['output'] or 'BATCH_SUMMARY | ' not in r['output'] else 0)
