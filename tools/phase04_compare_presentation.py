#!/usr/bin/env python3
"""P4.4-6 frozen/current full-state equivalence, using direct bytes rather than hashes.

The fixed P4.0 input tape runs against each project's real runtime. Compressed raw
streams retain every authority tick. Summary rows name each checkpoint/subsystem;
there is no value normalization, metadata exclusion, image masking or tolerance.
"""
from __future__ import annotations
import argparse
import base64
import gzip
import io
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import tarfile
from run_tests import ROOT, classify, run_bounded
from phase04_compare_snapshot import SCENARIOS, TAPE_FUNCTIONS, REQUIRED_WITNESSES, WITNESSES, OUTCOME_FIELDS

COMMIT = '7efe59b5974a0da0042600c5817e66b3c2d23616'
TREE = '3f4d8ddda4f72d4bdf1d6c1fce435ccbfdcef66a'
HARNESS = 'tests/phase04_map_equivalence.gd'
HISTORICAL = 'tests/phase04_map_baseline.gd'
PAYLOADS = frozenset(('snapshot', 'fish_observation', 'fish_decision_observation',
    'npc_observations', 'npcs', 'bait', 'hook_qte_wrap', 'net', 'stats', 'fish_wire',
    'angler_wire', 'packed_authority'))
RUNTIME_PATHS = frozenset(('scripts/'+name+'.gd' for name in (
    'pond_view','pond_camera','pond_scenery','pond_water_art','pond_depth_art',
    'pond_wood_art','pixel_art','shore_view','line_motion','grass_binding',
    'fish_winding','net_observation','net_motion','network_protocol','network_session',
    'npc_fish_state','npc_fish_public_state','world_simulation','net_simulation',
    'fish_observation','fish_network_observation','maps/map_presentation','rope','pond_layout')))
METADATA_PATHS = frozenset(('project.godot','scripts/menu.gd','scripts/pond.gd'))

def write_json(path, value):
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT)

def runtime(name):
    return name == 'project.godot' or name.startswith(('scripts/','assets/','scenes/'))

def frozen_bytes():
    if git('rev-parse',f'{COMMIT}^{{tree}}').decode().strip()!=TREE:
        raise ValueError('Pinned baseline Git identity mismatch')
    with tarfile.open(fileobj=io.BytesIO(git('archive','--format=tar',COMMIT))) as archive:
        return {e.name:archive.extractfile(e).read() for e in archive.getmembers()
                if e.isfile() and (runtime(e.name) or e.name==HISTORICAL)}

def source_bytes(project):
    paths=[project/'project.godot',project/HISTORICAL]
    for folder in ('scripts','assets','scenes'):
        paths.extend(p for p in (project/folder).rglob('*') if p.is_file())
    if any(p.is_symlink() for p in paths): raise ValueError('Runtime symlink is not admitted')
    return {p.relative_to(project).as_posix():p.read_bytes() for p in paths}

def tape_function(source, name):
    match=re.search(rb'^func '+name.encode()+rb'\([^\n]*\n.*?(?=^func |\Z)',source,re.M|re.S)
    if not match: raise ValueError('Missing frozen tape function '+name)
    return match.group().rstrip()

def verify_sources(baseline, current):
    committed=frozen_bytes()
    if source_bytes(baseline)!=committed:
        raise ValueError('Frozen baseline runtime or historical tape differs from Git source')
    present=source_bytes(current)
    changed=sorted(p for p in committed.keys()|present.keys() if committed.get(p)!=present.get(p))
    for path in changed:
        if path==HISTORICAL: raise ValueError('Historical input tape was modified')
        script=path.removesuffix('.uid') if path.endswith('.gd.uid') else path
        if script not in RUNTIME_PATHS and path not in METADATA_PATHS:
            raise ValueError('Unreviewed runtime path: '+path)
    harness=(current/HARNESS).read_bytes()
    for name in TAPE_FUNCTIONS:
        if tape_function(committed[HISTORICAL],name)!=tape_function(harness,name):
            raise ValueError('Historical scenario/setup/input/intervention changed: '+name)
    return changed

def decode(value):
    if not isinstance(value,str): raise ValueError('Raw evidence must be base64 text')
    data=base64.b64decode(value,validate=True)
    if not data: raise ValueError('Raw evidence must not be empty')
    return data

def records(value):
    raw=gzip.decompress(decode(value)); result=[]; offset=0
    while offset<len(raw):
        if offset+4>len(raw): raise ValueError('Truncated frame length')
        length=struct.unpack_from('<I',raw,offset)[0]; offset+=4
        if length==0 or offset+length>len(raw): raise ValueError('Invalid frame payload length')
        result.append(raw[offset:offset+length]); offset+=length
    if not result: raise ValueError('Empty evidence stream')
    return result

def validate(report):
    errors=[]
    if not isinstance(report,dict): return ['Report is not an object']
    keys={'format','engine','schema','probe','registry_ref','metadata_exclusions','scenarios','passed','failed'}
    if set(report)!=keys: errors.append('Report fields differ')
    if report.get('format')!='phase04-map-direct-equivalence-v1' or report.get('schema')!=16: errors.append('Wrong format/schema')
    if type(report.get('schema')) is not int: errors.append('Schema type differs')
    if report.get('passed')!=3791 or type(report.get('passed')) is not int or report.get('failed')!=0 or type(report.get('failed')) is not int: errors.append('Assertions incomplete or failed')
    if report.get('metadata_exclusions')!=[]: errors.append('No metadata exclusions permitted')
    ref=report.get('registry_ref',{})
    if (not isinstance(ref,dict) or set(ref)!={'id','revision','contract_version','content_hash'}
        or ref.get('id')!='pond_v2' or ref.get('revision')!=1 or ref.get('contract_version')!=1
        or type(ref.get('revision')) is not int or type(ref.get('contract_version')) is not int
        or not isinstance(ref.get('content_hash'),str) or not re.fullmatch('[0-9a-f]{64}',ref['content_hash'])):
        errors.append('Invalid built-in map identity')
    rows=report.get('scenarios')
    if not isinstance(rows,list) or len(rows)!=len(SCENARIOS): return errors+['Exactly eight scenarios required']
    for row,spec in zip(rows,SCENARIOS):
        name=spec['name']
        if not isinstance(row,dict) or set(row)!={'scenario','checkpoints','input_trace_gzip','every_tick_authority_gzip','witnesses','outcome'}: errors.append(name+': row fields differ'); continue
        if row['scenario']!=spec or any(type(row['scenario'].get(k)) is not type(v) for k,v in spec.items()): errors.append(name+': scenario/tape contract differs')
        for field in ('input_trace_gzip','every_tick_authority_gzip'):
            try:
                if len(records(row[field]))!=spec['ticks']: errors.append(name+': stream frame count differs: '+field)
            except (ValueError,TypeError,OSError,EOFError) as exc: errors.append(name+': invalid stream '+field+': '+str(exc))
        saw=row['witnesses']
        if not isinstance(saw,dict) or set(saw)!=WITNESSES or not all(type(v) is bool for v in saw.values()): errors.append(name+': invalid witnesses')
        elif any(not saw[k] for k in REQUIRED_WITNESSES.get(name,())): errors.append(name+': required behavior unexercised')
        if not isinstance(row['outcome'],dict) or set(row['outcome'])!=OUTCOME_FIELDS: errors.append(name+': incomplete outcome')
        ticks=[-1,*range(0,spec['ticks'],30),spec['ticks']-1]
        cps=row['checkpoints']
        if not isinstance(cps,list) or len(cps)!=len(ticks): errors.append(name+': incomplete checkpoints'); continue
        for cp,tick in zip(cps,ticks):
            if not isinstance(cp,dict) or set(cp)!={'input_tick','simulation_tick','fish_wire_valid','angler_wire_valid','rng_seed','rng_state','payloads'}: errors.append(name+': checkpoint fields differ'); continue
            if cp['input_tick']!=tick or type(cp['input_tick']) is not int or type(cp['simulation_tick']) is not int: errors.append(name+': checkpoint tick differs')
            if cp['fish_wire_valid'] is not True or cp['angler_wire_valid'] is not True: errors.append(name+': public projection invalid')
            for field in ('rng_seed','rng_state'):
                if not isinstance(cp[field],str) or not re.fullmatch(r'-?[0-9]+',cp[field]): errors.append(name+': RNG not lossless integer text')
            if not isinstance(cp['payloads'],dict) or set(cp['payloads'])!=PAYLOADS: errors.append(name+': payload subsystem fields differ'); continue
            for payload in cp['payloads'].values():
                try: decode(payload)
                except (ValueError,TypeError): errors.append(name+': invalid raw payload')
    return errors

def compare(old,new):
    errors=[*['baseline: '+e for e in validate(old)],*['current: '+e for e in validate(new)]]
    result={'success':False,'errors':errors,'metadata_exclusions':[],'method':'Exact decoded full Variant bytes; gzip is storage only, no payload hashing','scenarios':[]}
    if errors: return result
    for key in ('engine','schema','registry_ref','probe'):
        if old[key]!=new[key]: errors.append(key+' differs')
    for a,b in zip(old['scenarios'],new['scenarios']):
        name=a['scenario']['name']; row={'name':name,'ticks':a['scenario']['ticks'],'checkpoint_count':len(a['checkpoints']),'different_inputs':[],'different_authority_ticks':[],'different_checkpoint_payloads':[]}
        for field,label in [('input_trace_gzip','different_inputs'),('every_tick_authority_gzip','different_authority_ticks')]:
            row[label]=[i for i,(x,y) in enumerate(zip(records(a[field]),records(b[field]))) if x!=y]
        for ca,cb in zip(a['checkpoints'],b['checkpoints']):
            for field in ca.keys()-{'payloads'}:
                if ca[field]!=cb[field]: row['different_checkpoint_payloads'].append([ca['input_tick'],field])
            for field in PAYLOADS:
                if decode(ca['payloads'][field])!=decode(cb['payloads'][field]): row['different_checkpoint_payloads'].append([ca['input_tick'],field])
        row['witnesses']=a['witnesses'];row['outcome']=a['outcome']
        row['success']=not any(row[k] for k in ('different_inputs','different_authority_ticks','different_checkpoint_payloads')) and a['witnesses']==b['witnesses'] and a['outcome']==b['outcome']
        if not row['success']: errors.append(name+': exact behavior differs')
        result['scenarios'].append(row)
    result['success']=not errors
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',default=os.environ.get('GODOT','godot'))
    parser.add_argument('--baseline',type=Path,default=ROOT/'artifacts/p44-frozen-baseline-7efe59b')
    parser.add_argument('--output-directory',type=Path,required=True)
    args=parser.parse_args(); out=args.output_directory.resolve();out.mkdir(parents=True,exist_ok=False)
    changed=verify_sources(args.baseline,ROOT)
    before={label:source_bytes(p) for label,p in [('baseline',args.baseline),('current',ROOT)]}
    harness=(ROOT/HARNESS).read_bytes();external=out/'frozen-input-harness.gd';external.write_bytes(harness)
    (out/'scoped-runtime.diff').write_bytes(git('diff',COMMIT,'--','scripts','assets','scenes','project.godot'))
    reports={}; runs=[]
    for label,project in [('baseline',args.baseline),('current',ROOT)]:
        dest=out/label;dest.mkdir();env=dict(os.environ)
        for key in ('XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'):
            p=dest/key.lower();p.mkdir();env[key]=str(p)
        command=[args.godot,'--headless','--audio-driver','Dummy','--path',str(project),'--script',str(external),'--','--test-profile','--single-pass','--output='+str(dest/'raw-evidence.json')]
        run=classify(run_bounded(command,120,project,env));(dest/'console.log').write_text(run.pop('output'));run['label']=label;runs.append(run)
        if run['status']!='passed':
            write_json(out/'summary.json',{'success':False,'runs':runs,'error':'harness failed'});return 1
        reports[label]=json.loads((dest/'raw-evidence.json').read_text())
    result=compare(reports['baseline'],reports['current'])
    stable=before=={label:source_bytes(p) for label,p in [('baseline',args.baseline),('current',ROOT)]} and harness==(ROOT/HARNESS).read_bytes() and harness==external.read_bytes()
    result.update(baseline_commit=COMMIT,baseline_tree=TREE,runs=runs,source_stable=stable,reviewed_runtime_paths=changed,source_verification='Pinned Git archive and direct source bytes before/after; path list is scope admission, scoped diff still requires review')
    if not stable: result['success']=False;result['errors'].append('Source changed during comparison')
    write_json(out/'summary.json',result);print(json.dumps({k:v for k,v in result.items() if k not in ('scenarios','runs')},indent=2));return 0 if result['success'] else 1

if __name__=='__main__': raise SystemExit(main())
