"""Bounded integration checks for the authored woodland scene."""
from pathlib import Path
import argparse
import json
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from run_tests import run_bounded, classify
parser=argparse.ArgumentParser()
parser.add_argument('--godot',required=True)
parser.add_argument('--output',type=Path,default=ROOT/'artifacts/woodland-integration')
args=parser.parse_args(); out=args.output.resolve(); out.mkdir(parents=True,exist_ok=True)
results=[]
for name,flags,timeout in [
    ('import',['--headless','--editor','--quit'],90),
    ('contract',['--headless','--script','res://tests/watergen/woodland_contract.gd'],120),
    ('network',['--headless','--script','res://tests/watergen/woodland_network.gd'],120),
    ('ui',['--headless','--script','res://tests/phase05_ui.gd','--','--test-profile'],90),
    ('native',['--rendering-method','gl_compatibility','--script','res://tests/watergen/woodland_native.gd','--','--test-profile','--output='+out.as_posix()],180)]:
    print('RUN '+name,flush=True)
    result=classify(run_bounded([args.godot,'--path',str(ROOT),'--audio-driver','Dummy',*flags],timeout,ROOT),expect_summary=name!='import')
    (out/(name+'.txt')).write_bytes(result.pop('output').replace('\r\n','\n').encode('utf-8'))
    result['suite']=name; results.append(result)
    print(name+': '+result['status'],flush=True)
    if result['status']!='passed': break
(out/'results.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
sys.exit(0 if len(results)==5 and all(r['status']=='passed' for r in results) else 1)
