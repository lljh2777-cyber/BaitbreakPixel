#!/usr/bin/env python3
"""Run registered WG-3 gates with provenance and isolated Windows/Linux profiles."""
import argparse
from datetime import datetime, timezone, timedelta
import hashlib
import json
import os
from pathlib import Path
import re
import sys

import run_wg0 as support
sys.path.insert(0, str(support.ROOT / 'tools'))
import run_tests as runner

def source_manifest():
    result = support.source_manifest()
    result['export_presets.cfg'] = hashlib.sha256((support.ROOT/'export_presets.cfg').read_bytes()).hexdigest()
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--mode', choices=['current', 'native', 'generated', 'focused'], default='focused')
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--import', dest='do_import', action='store_true')
    parser.add_argument('--pack', type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,79}', args.run_id): parser.error('Invalid run id')
    out = support.ROOT / 'artifacts/watergen' / args.run_id
    out.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ)
    for key in ['APPDATA', 'LOCALAPPDATA', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
        folder = out / 'isolated-user' / key.lower()
        folder.mkdir(parents=True)
        env[key] = str(folder)
    registry = runner.load_registry()
    names = ['watergen_integration', 'watergen_native'] if args.mode == 'focused' else runner.select_suites(registry, 'native' if args.mode == 'generated' else args.mode, [])
    if args.mode == 'generated': names.remove('watergen_native')  # This suite verifies default opt-out itself.
    sources = source_manifest()
    stamp = lambda: datetime.now(timezone(timedelta(hours=8))).isoformat()
    manifest = dict(task_id='WG-3', base_commit='c1e3946f0b8cf1afa7becf2b238c8297efda5dc8',
        tested_commit=support.git('rev-parse', 'HEAD'), dirty=bool(support.git('status', '--porcelain')),
        dirty_diff_sha256=hashlib.sha256(support.git('diff', '--binary', 'HEAD').encode()).hexdigest(),
        source_files_sha256=sources, started_at=stamp(), mode=args.mode,
        pack=str(args.pack.resolve()) if args.pack else None,
        pack_sha256=hashlib.sha256(args.pack.read_bytes()).hexdigest() if args.pack else None,
        results=[], human_acceptance='NOT_RUN', next_stop_gate='WAITING_FOR_PLAYTEST: optional local fish environment only')
    def execute(name, command, timeout, summary=True):
        cwd = args.pack.resolve().parent if args.pack else support.ROOT
        result = runner.classify(runner.run_bounded(command, timeout, cwd, env), expect_summary=summary)
        (out / (name + '.log')).write_text(result.pop('output'), encoding='utf-8', newline='\n')
        result.update(suite=name, command=command, log=name+'.log')
        manifest['results'].append(result)
        print(f"{name}: {result['status']} ({result['passed']} / {result['failed']})", flush=True)
        return result['status'] == 'passed'
    ok = True
    if args.do_import:
        if args.pack: parser.error('Do not import with --pack')
        ok = execute('import', [args.godot, '--headless', '--path', str(support.ROOT), '--editor', '--import', '--quit'], 180, False)
    if ok:
        for name in names:
            entry = registry['suites'][name]
            if args.pack and entry.get('pack_compatible') is False:
                manifest['results'].append(dict(suite=name, status='blocked', reason=entry['pack_reason'], passed=0, failed=0))
                continue
            captures = out / 'captures' / name
            captures.mkdir(parents=True)
            command = [args.godot, '--audio-driver', 'Dummy', '--log-file', str(out/(name+'-engine.log'))]
            command += ['--headless'] if entry['mode'] == 'headless' else ['--rendering-method', 'gl_compatibility']
            command += ['--main-pack', str(args.pack.resolve()), '--script', str(support.ROOT/'tests'/f'{name}.gd')] if args.pack else ['--path', str(support.ROOT), '--script', f'res://tests/{name}.gd']
            command += ['--', '--test-profile', '--capture-output-directory='+str(captures)]
            if args.mode == 'generated': command += ['--water-appearance=fern']
            execute(name, command, entry.get('timeout_seconds', 90))
    manifest['source_unchanged_during_run'] = sources == source_manifest()
    manifest['finished_at'] = stamp()
    manifest['status'] = 'PASS' if manifest['source_unchanged_during_run'] and manifest['results'] and all(t['status'] == 'passed' for t in manifest['results']) else 'FAIL'
    (out/'run-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')
    print(str(out), flush=True)
    return 0 if manifest['status'] == 'PASS' else 1

if __name__ == '__main__':
    raise SystemExit(main())
