#!/usr/bin/env python3
"""WG-1 private validation/capture/preview using WG-0's bounded isolated runner."""
from datetime import datetime
import argparse
import hashlib
import json
import re
import uuid
import run_wg0 as support


def gallery(output):
    cards = []
    for seed in (42, 731, 2649, 713284):
        path = f"seed-{seed}"
        cameras = [(0, 0), (320, 60), (640, 120), (0, 120), (640, 0)]
        views = ''.join(f'<a href="{path}/viewport-{x}-{y}.png"><img src="{path}/viewport-{x}-{y}.png" alt="镜头 {x},{y}"></a>' for x, y in cameras)
        layers = ''.join(f'<a href="{path}/layer-{name}.png">{name}</a> ' for name in ('water', 'distance', 'surface', 'terrain', 'floor', 'foreground'))
        cards.append(f'<section><h2>Seed {seed}</h2><a href="{path}/world-with-geometry.png"><img class="world" src="{path}/world-with-geometry.png" alt="整世界参考"></a><div class="views">{views}</div><details><summary>环境与六层</summary><a href="{path}/world-environment.png">纯环境</a> · <a href="{path}/world-guides.png">保护区诊断</a><p>{layers}</p></details></section>')
    text = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>WG-1 静态水域样片</title><style>body{margin:32px auto;max-width:1320px;background:#102b30;color:#d6e3d3;font:16px/1.6 system-ui;padding:0 16px}h1{font-size:28px}p{color:#acc4bd}a{color:#a9d8c6}.world{width:100%;image-rendering:pixelated}.views{display:flex;gap:12px;overflow:auto}.views img{width:640px;max-width:none;image-rendering:pixelated}section{margin:32px 0;padding:18px;background:#16353a;border:1px solid #335354;border-radius:8px}summary{cursor:pointer;margin:12px 0}</style><h1>WG-1 · 一个池塘，四种构图</h1><p>forest_pond_v1 · 固定 pond_v2 几何 · 静态时间 0 · 点击图像查看原始尺寸。下排依次为左上、中心、右下、左下、右上视口。尚未接入对局，等待人工选定方向。</p>'''
    (output / 'gallery.html').write_text(text + ''.join(cards) + '</html>', encoding='utf-8')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--mode', choices=['all', 'headless', 'native', 'preview'], default='all')
    parser.add_argument('--run-id', default='wg1-' + datetime.now(support.TZ).strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6])
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,79}', args.run_id) or args.timeout <= 0: parser.error('Invalid run id or timeout')
    output = support.ROOT / 'artifacts/watergen' / args.run_id
    output.mkdir(parents=True, exist_ok=False)
    sources = support.source_manifest()
    changed = support.git('diff', '--name-only', '--diff-filter=DMRTUXB', support.BASELINE['source_commit'])
    manifest = dict(format='baitbreak-watergen-run-manifest', task_id='WG-1', authorized_stage='WG-1', base_commit=support.BASELINE['source_commit'], tested_commit=support.git('rev-parse', 'HEAD'), dirty=bool(support.git('status', '--porcelain')), dirty_diff_sha256=hashlib.sha256(support.git('diff', '--binary', 'HEAD').encode()).hexdigest(), source_files_sha256=sources, started_at=datetime.now(support.TZ).isoformat(), changed_original_files=changed.splitlines(), generator_version='wg-1.0', profile_id='forest_pond_v1', seeds=[42, 731, 2649, 713284], tests=[], human_acceptance='NOT_RUN', next_stop_gate='WAITING_FOR_PLAYTEST: choose visual direction before WG-2')
    (output / 'run-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    modes = ['headless', 'native'] if args.mode == 'all' else [args.mode]
    for mode in modes:
        command = [args.godot, '--path', str(support.ROOT), '--audio-driver', 'Dummy', '--log-file', str(output / (mode + '-engine.log'))]
        if mode == 'headless': command += ['--headless', '--script', 'res://tests/watergen/generation_contract.gd']
        else:
            command += ['--scene', 'res://scenes/watergen/generated_preview.tscn', '--', '--wg-output=' + output.as_posix()]
            if mode == 'native': command += ['--wg-capture']
        result = support.run(command, output, mode, max(args.timeout, 43200) if mode == 'preview' else args.timeout, expect_summary=mode != 'preview')
        if mode == 'preview' and result['status'] == 'PASS': result['status'] = 'NOT_APPLICABLE'
        manifest['tests'].append(result)
        if result['status'] in ('FAIL', 'BLOCKED'): break
    manifest['source_unchanged_during_run'] = sources == support.source_manifest()
    manifest['finished_at'] = datetime.now(support.TZ).isoformat()
    evidence_path = output / 'wg1-native-evidence.json'
    if evidence_path.exists():
        manifest['native_evidence'] = json.loads(evidence_path.read_text(encoding='utf-8'))
        gallery(output)
    manifest['status'] = 'PASS' if not changed and manifest['source_unchanged_during_run'] and all(r['status'] in ('PASS', 'NOT_APPLICABLE') for r in manifest['tests']) else 'FAIL'
    (output / 'run-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(output, flush=True)
    return 0 if manifest['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
