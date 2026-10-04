#!/usr/bin/env python3
"""Lossless, readable ecology evidence: one shared rules file and JSONL per stratum."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from phase03_ecology_analysis import STRATA, validate_rows, summarize


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode('utf-8')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_bundle(rows, seeds, destination, max_ticks=22200):
    validate_rows(rows,seeds,max_ticks)
    destination=Path(destination)
    if destination.exists():
        raise ValueError('Preserve prior evidence; choose a new destination')
    destination.mkdir(parents=True)
    rules=rows[0]['rules']
    rules_bytes=(json.dumps(rules,ensure_ascii=False,indent=2,allow_nan=False)+'\n').encode()
    (destination/'rules.json').write_bytes(rules_bytes)
    manifest={'format':'phase03-ecology-readable-v1','seeds':seeds,'max_ticks':max_ticks,
              'rows':len(rows),'canonical_rows_sha256':digest(canonical(rows)),
              'rules_sha256':digest(rules_bytes),'files':{},
              'note':'Uncompressed JSONL preserves every original value except identical rules, stored once. index restores original order. Read with phase03_ecology_evidence.py to reconstruct and verify all raw rows.'}
    for stratum in STRATA:
        filename=stratum.replace('/','-')+'.jsonl'
        selected=[{'index':i,'row':{k:v for k,v in row.items() if k!='rules'}} for i,row in enumerate(rows) if row['stratum_key']==stratum]
        data=b''.join(canonical(record)+b'\n' for record in selected)
        (destination/filename).write_bytes(data)
        manifest['files'][filename]={'stratum':stratum,'rows':len(selected),'sha256':digest(data)}
    (destination/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    reconstructed=read_bundle(destination)
    if reconstructed!=rows:
        raise ValueError('Lossless raw evidence round-trip failed')
    return manifest


def read_bundle(source):
    source=Path(source); manifest=json.loads((source/'manifest.json').read_text())
    if manifest.get('format')!='phase03-ecology-readable-v1': raise ValueError('Unknown bundle format')
    expected={stratum.replace('/','-')+'.jsonl':stratum for stratum in STRATA}
    if set(manifest['files'])!=set(expected): raise ValueError('Missing/extra evidence file')
    rules_bytes=(source/'rules.json').read_bytes()
    if digest(rules_bytes)!=manifest['rules_sha256']: raise ValueError('Rules checksum mismatch')
    rules=json.loads(rules_bytes); indexed={}
    for filename,stratum in expected.items():
        entry=manifest['files'][filename]
        if entry['stratum']!=stratum: raise ValueError('Incorrect stratum label')
        data=(source/filename).read_bytes()
        if digest(data)!=entry['sha256']: raise ValueError('Evidence checksum mismatch')
        records=[json.loads(line) for line in data.splitlines()]
        if len(records)!=entry['rows']: raise ValueError('Evidence count mismatch')
        for record in records:
            index=record['index']; row=record['row']
            if type(index) is not int or index<0 or index in indexed: raise ValueError('Invalid/duplicate row index')
            if row.get('stratum_key')!=stratum or 'rules' in row: raise ValueError('Mixed or duplicated shared-rule evidence')
            row['rules']=rules.copy(); indexed[index]=row
    if set(indexed)!=set(range(manifest['rows'])): raise ValueError('Incomplete source row ordering')
    rows=[indexed[i] for i in range(manifest['rows'])]
    if digest(canonical(rows))!=manifest['canonical_rows_sha256']: raise ValueError('Canonical raw row checksum mismatch')
    validate_rows(rows,manifest['seeds'],manifest['max_ticks'])
    return rows


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='action',required=True)
    out=sub.add_parser('export');out.add_argument('rounds',type=Path);out.add_argument('--seeds',nargs='+',type=int,required=True);out.add_argument('--max-ticks',type=int,default=22200);out.add_argument('--output',type=Path,required=True)
    check=sub.add_parser('verify');check.add_argument('bundle',type=Path);check.add_argument('--analysis-output',type=Path)
    args=parser.parse_args()
    if args.action=='export':
        result=write_bundle(json.loads(args.rounds.read_text()),args.seeds,args.output,args.max_ticks)
        print(json.dumps({'rows':result['rows'],'canonical_rows_sha256':result['canonical_rows_sha256']}))
    else:
        rows=read_bundle(args.bundle);manifest=json.loads((args.bundle/'manifest.json').read_text())
        if args.analysis_output:
            if args.analysis_output.exists(): parser.error('Preserve previous analysis')
            result=summarize(rows,manifest['seeds'],max_ticks=manifest['max_ticks'])
            args.analysis_output.write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
        print(json.dumps({'verified_rows':len(rows),'canonical_rows_sha256':digest(canonical(rows))}))

if __name__=='__main__': main()
