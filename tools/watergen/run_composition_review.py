"""Bounded first-round visual checks; reports engine errors even after exit code 0."""
from pathlib import Path
import argparse
import json
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from run_tests import run_bounded, classify

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot',required=True)
    parser.add_argument('--output',type=Path,default=ROOT/'artifacts/watergen/composition-review-final')
    args=parser.parse_args()
    output=args.output.resolve(); output.mkdir(parents=True,exist_ok=True)
    jobs=[('import',['--headless','--editor','--quit'],90),
          ('boundary',['--headless','--script','res://tests/watergen/composition_boundary.gd'],180),
          ('native',['--rendering-method','gl_compatibility','--script','res://tests/watergen/composition_native.gd','--','--test-profile','--output='+output.as_posix()],240),
          ('review-ui',['--rendering-method','gl_compatibility','--script','res://tests/watergen/composition_review_ui.gd','--','--test-profile','--output='+output.as_posix()],120)]
    results=[]
    for name,flags,timeout in jobs:
        print('RUN '+name,flush=True)
        result=classify(run_bounded([args.godot,'--path',str(ROOT),'--audio-driver','Dummy',*flags],timeout,ROOT),expect_summary=name!='import')
        (output/(name+'.log')).write_text(result.pop('output'),encoding='utf-8')
        result['suite']=name; results.append(result)
        print(name+': '+result['status'],flush=True)
        if result['status']!='passed': break
    (output/'results.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
    return 0 if len(results)==len(jobs) and all(r['status']=='passed' for r in results) else 1

if __name__=='__main__': raise SystemExit(main())
