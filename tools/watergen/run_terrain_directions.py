"""Open or capture the three standalone terrain art directions. No gameplay run."""
import argparse
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from run_tests import classify, run_bounded


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--capture', action='store_true')
    parser.add_argument('--run-id', default='terrain-r1-' + datetime.now(timezone(timedelta(hours=8))).strftime('%Y%m%d-%H%M%S'))
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,79}', args.run_id):
        parser.error('Invalid run id')
    output = ROOT / 'artifacts/watergen' / args.run_id
    output.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    for key in ('APPDATA', 'LOCALAPPDATA', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
        directory = output / 'isolated-user' / key.lower()
        directory.mkdir(parents=True, exist_ok=True)
        env[key] = str(directory)
    command = [args.godot, '--path', str(ROOT), '--audio-driver', 'Dummy',
               '--log-file', str(output / 'engine.log'), '--scene',
               'res://scenes/watergen/terrain_direction_preview.tscn', '--',
               '--output=' + output.as_posix()]
    if args.capture:
        command.append('--capture')
    result = classify(run_bounded(command, 120 if args.capture else 43200, ROOT, env), expect_summary=args.capture)
    (output / 'run.log').write_text(result.pop('output'), encoding='utf-8')
    result.update(command=command, production_integration=False)
    (output / 'run-results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"{result['status']}: {result['passed']} passed, {result['failed']} failed; {output}", flush=True)
    if result['status'] != 'passed':
        print((output / 'run.log').read_text(encoding='utf-8')[-7500:])
    return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
