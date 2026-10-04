import argparse, datetime, hashlib, json, os, pathlib, subprocess, sys
p=argparse.ArgumentParser(); p.add_argument('--label',required=True); p.add_argument('--manual',action='store_true'); args=p.parse_args()
root=pathlib.Path('/workspace/scratch/5dc5a43a1104/BaitbreakPixel'); out=root/'artifacts'/args.label; out.mkdir(parents=True,exist_ok=True)
godot='/workspace/shared/baitbreak-toolchain-472/Godot_v4.7.2-stable_linux.x86_64'
def manifest():
    paths=[]
    for folder in ('scripts','scenes','assets'):
        paths.extend(f for f in (root/folder).rglob('*') if f.is_file())
    paths += [root/'project.godot',root/'tools/run_tests.py',root/'tests/suite_registry.json']
    registry=json.loads((root/'tests/suite_registry.json').read_text())
    for name,entry in registry['suites'].items():
        if entry['status']=='current' and entry['mode']=='renderer':
            paths.append(root/'tests'/f'{name}.gd'); uid=root/'tests'/f'{name}.gd.uid'
            if uid.exists(): paths.append(uid)
    paths.append(root/'artifacts/p35-native-review/manual-ui-recorder.gd')
    return {str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(set(paths))}
start=datetime.datetime.now(datetime.timezone.utc).isoformat(); before=manifest(); start_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
(out/'native-source-before.json').write_text(json.dumps(before,indent=2)+'\n')
env=dict(os.environ)
for key,part in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
    directory=out/'profile'/part; directory.mkdir(parents=True,exist_ok=True); env[key]=str(directory)
if args.manual:
    command=[godot,'--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',str(root),'--script','res://artifacts/p35-native-review/manual-ui-recorder.gd','--','--test-profile','--ui-record-output='+str(out/'captures')]
else:
    command=[sys.executable,str(root/'tools/run_tests.py'),'--godot',godot,'--import','--profile','native','--output-directory',str(out)]
with (out/'native-runner.txt').open('w') as log:
    result=subprocess.run(command,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1200)
after=manifest(); (out/'native-source-after.json').write_text(json.dumps(after,indent=2)+'\n')
report={'started_at_utc':start,'finished_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':command,'returncode':result.returncode,'head_at_start':start_head,'wrapper_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'source_unchanged':before==after,'changed_files':[k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)],'file_count':len(before),'scope':'Runtime scripts/scenes/assets/import descriptors; project.godot; current renderer test bodies/UIDs; runner/registry; evidence-only UI recorder. Generated Godot cache, documentation and headless-only tests excluded.','godot_sha256':hashlib.sha256(pathlib.Path(godot).read_bytes()).hexdigest(),'display':os.environ.get('DISPLAY'),'mode':'ordinary native UI with F12 observation only' if args.manual else 'current native gate'}
(out/'native-provenance.json').write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps(report)); sys.exit(result.returncode)
