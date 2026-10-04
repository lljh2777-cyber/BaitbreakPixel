#!/usr/bin/env python3
"""Source-frozen P3.5 ecology matrix. Diagnostics, never automatic balance approval."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
from run_tests import ROOT, run_bounded, ERROR
from phase03_ecology_analysis import summarize

HARNESS_FILES = ('tools/phase03_ecology_diagnostics.gd', 'tools/phase02_feeding_policy.gd',
                 'tools/phase03_ecology_protocol.md', 'tools/phase03_run_ecology.py',
                 'tools/phase03_ecology_analysis.py', 'tools/run_tests.py')

def fingerprints(project=ROOT):
    paths = sorted((project / 'scripts').glob('*.gd')) + [project / p for p in HARNESS_FILES] + [project / 'project.godot']
    return {p.relative_to(project).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}

def admit_pilot(pilot, seeds, hashes, max_ticks):
    if pilot.get('phase') != 'pilot' or pilot.get('success') is not True or pilot.get('source_stable') is not True:
        raise ValueError('Successful source-stable pilot required')
    pilot_seeds=pilot.get('seeds')
    if not isinstance(pilot_seeds,list) or not pilot_seeds or any(type(seed) is not int for seed in pilot_seeds) or len(set(pilot_seeds))!=len(pilot_seeds):
        raise ValueError('Pilot seeds must be nonempty distinct integers')
    if set(pilot_seeds) & set(seeds): raise ValueError('Heldout overlaps pilot')
    if pilot['source_sha256'] != hashes: raise ValueError('Source changed after pilot')
    if pilot['max_ticks'] != max_ticks: raise ValueError('Pilot horizon mismatch')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=('pilot','heldout','test'), required=True)
    parser.add_argument('--rounds', type=int, default=4)
    parser.add_argument('--seed', type=int, default=73501)
    parser.add_argument('--max-ticks', type=int, default=22200)
    parser.add_argument('--pilot', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--project', type=Path, default=ROOT)
    parser.add_argument('--godot', default=os.environ.get('GODOT','godot'))
    parser.add_argument('--timeout', type=float, default=14400)
    args=parser.parse_args()
    if not 1<=args.rounds<=1000 or not 1<=args.max_ticks<=108600 or not math.isfinite(args.timeout) or args.timeout<=0:
        parser.error('Invalid bounds')
    project=args.project.resolve(); output=args.output.resolve()
    if any((output/n).exists() for n in ('provenance.json','rounds.json','summary.json')):
        parser.error('Preserve evidence; choose a new output directory')
    seeds=list(range(args.seed,args.seed+args.rounds)); hashes=fingerprints(project)
    if args.phase=='heldout':
        if args.pilot is None: parser.error('--pilot required')
        try: admit_pilot(json.loads((args.pilot/'provenance.json').read_text()),seeds,hashes,args.max_ticks)
        except (ValueError,KeyError) as error: parser.error(str(error))
    output.mkdir(parents=True,exist_ok=True)
    env=dict(os.environ)
    for name in ('XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'):
        directory=output/name.lower(); directory.mkdir(exist_ok=True); env[name]=str(directory)
    manifest={'format':'phase03-ecology-provenance-v1','phase':args.phase,'seeds':seeds,
              'max_ticks':args.max_ticks,'source_sha256':hashes,'success':False,
              'pilot':str(args.pilot.resolve()) if args.pilot else None,
              'project':str(project),'note':'48 rows/seed; same default authority rules. No balancing target or human approval.'}
    manifest_path=output/'provenance.json'
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    for name in HARNESS_FILES: (output/Path(name).name).write_bytes((project/name).read_bytes())
    command=[args.godot,'--headless','--audio-driver','Dummy','--path',str(project),'--script',
             'res://tools/phase03_ecology_diagnostics.gd','--','--test-profile',
             f'--rounds={args.rounds}',f'--seed={args.seed}',f'--max-ticks={args.max_ticks}',f'--output={output}']
    run=run_bounded(command,args.timeout,project,env)
    (output/'run.log').write_text(run['output'])
    manifest['execution']={k:v for k,v in run.items() if k!='output'}
    manifest['source_stable']=fingerprints(project)==hashes
    success=not (run['returncode'] or run['timed_out'] or run['launch_error'] or ERROR.search(run['output']))
    success=success and 'ECOLOGY_SUMMARY | ' in run['output'] and manifest['source_stable']
    if success:
        try: report=summarize(json.loads((output/'rounds.json').read_text()),seeds,max_ticks=args.max_ticks)
        except (KeyError,TypeError,ValueError) as error:
            success=False; manifest['analysis_error']=str(error)
        else: (output/'comparison.json').write_text(json.dumps(report,indent=2)+'\n')
    manifest['success']=bool(success); manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    print(run['output'][-5000:]); print(json.dumps({'success':success,'source_stable':manifest['source_stable'],'output':str(output)}))
    raise SystemExit(0 if success else 1)

if __name__=='__main__': main()
