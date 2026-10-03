#!/usr/bin/env python3
"""WG-2 private validation/capture/preview using WG-0's bounded isolated runner."""
from datetime import datetime
import argparse
import hashlib
from html import escape
import json
import re
import uuid
import run_wg0 as support


def gallery(output):
    evidence = json.loads((output / "wg2-native-evidence.json").read_text(encoding="utf-8"))
    recipes = {r["visual_seed"]: r.get("atmosphere", {}).get("label", "原版") for r in evidence["results"]}
    cards = []
    for seed in (713284, 42, 731, 2649):
        path = f"seed-{seed}"
        views = ''.join(f'<figure><a href="{path}/viewport-{x}-{y}.png"><img src="{path}/viewport-{x}-{y}.png" alt="镜头 {x},{y}"></a><figcaption>镜头 {x},{y} · <a href="{path}/viewport-{x}-{y}-fixtures.png">公开可读性样本</a></figcaption></figure>' for x,y in [(0,0),(320,60),(640,120),(0,120),(640,0)])
        layers = ' · '.join(f'<a href="{path}/layer-{name}.png">{name}</a>' for name in ('water','distance','surface','terrain','floor','foreground'))
        cards.append(f'<section><h2>Seed {seed} · {escape(recipes[seed])}</h2><img class="world" src="{path}/world-time-0.png" alt="时间零的整世界"><p><a href="{path}/world-time-3.png">3 秒姿态</a> · <a href="{path}/scene-plan.json">ScenePlan</a> · {layers}</p><div class="views">{views}</div></section>')
    html = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>WG-2 动态水域预览</title><style>body{margin:32px auto;max-width:1320px;background:#102b30;color:#d6e3d3;font:16px/1.6 system-ui;padding:0 16px}a{color:#a9d8c6}img{image-rendering:pixelated}.world{width:100%}.views{display:flex;gap:12px;overflow:auto}.views img{width:640px;max-width:none}figure{margin:0}section{margin:32px 0;padding:18px;background:#16353a;border:1px solid #335354}p{color:#acc4bd}</style><h1>WG-2 · 动态与可读性</h1><p>已选择 713284 · 原生 640×360 视口 · 18 处装饰植被摆动，根部固定；V 可切换原版对照。此页为固定时间截图；运行 Open-Dynamic-Preview.ps1 查看动画，空格暂停，逗号/句号逐步采样，F 显示公开样本。样本不代表真实对局。尚未接入主游戏。</p><a href="selected-readability.png"><img src="selected-readability.png" alt="选定种子的可读性样本"></a>'
    comparison = ''
    if (output / 'comparison-after.png').exists():
        comparison = '<section><h2>713284 · 同镜头、同时间对照</h2><div class="views"><figure><img src="comparison-before.png" alt="原版"><figcaption>wg-2.0 原版</figcaption></figure><figure><img src="comparison-after.png" alt="氛围版"><figcaption>wg-2.1 氛围版</figcaption></figure></div></section>'
    clip = '<section><h2>10 秒引擎渲染预览</h2><video controls muted playsinline preload="none" style="width:100%" poster="seed-713284/world-time-0.png" src="atmosphere.mp4"></video><p>固定种子 713284 · 1280×480 全景 · 10 fps 固定时间采样；实际预览按显示帧率播放。</p></section>' if evidence.get('clip') else ''
    if evidence['generator_version'] == 'wg-2.0':
        html = html.replace('18 处装饰植被摆动，根部固定；V 可切换原版对照。', '原版两株装饰草摆动，根部固定。')
    (output / 'gallery.html').write_text(html + comparison + clip + ''.join(cards) + '</html>', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--mode', choices=['all', 'headless', 'native', 'preview'], default='all')
    parser.add_argument('--run-id', default='wg2-' + datetime.now(support.TZ).strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6])
    parser.add_argument('--clip', action='store_true', help='Capture 100 deterministic panorama frames for a 10-second clip')
    parser.add_argument('--baseline', action='store_true', help='Use the frozen wg-2.0 profile for comparison')
    parser.add_argument('--test-seconds', type=int, default=60)
    parser.add_argument('--timeout', type=int, default=240)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,79}', args.run_id) or args.timeout <= 0 or not 1 <= args.test_seconds <= 120: parser.error('Invalid run id, timeout or test duration (1..120 seconds)')
    output = support.ROOT / 'artifacts/watergen' / args.run_id
    output.mkdir(parents=True, exist_ok=False)
    sources = support.source_manifest()
    changed = support.git('diff', '--name-only', '--diff-filter=DMRTUXB', support.BASELINE['source_commit'])
    manifest = dict(format='baitbreak-watergen-run-manifest', task_id='WG-2', authorized_stage='WG-2', base_commit=support.BASELINE['source_commit'], tested_commit=support.git('rev-parse', 'HEAD'), dirty=bool(support.git('status', '--porcelain')), dirty_diff_sha256=hashlib.sha256(support.git('diff', '--binary', 'HEAD').encode()).hexdigest(), source_files_sha256=sources, started_at=datetime.now(support.TZ).isoformat(), changed_original_files=changed.splitlines(), generator_version='wg-2.0' if args.baseline else 'wg-2.1', profile_id='forest_pond_v1', seeds=[42, 731, 2649, 713284], tests=[], human_acceptance='NOT_RUN', next_stop_gate='WAITING_FOR_REVIEW: visual review only; user deferred WG-3')
    (output / 'run-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    modes = ['headless', 'native'] if args.mode == 'all' else [args.mode]
    for mode in modes:
        command = [args.godot, '--path', str(support.ROOT), '--audio-driver', 'Dummy', '--log-file', str(output / (mode + '-engine.log'))]
        if mode == 'headless': command += ['--headless', '--script', 'res://tests/watergen/dynamic_contract.gd' if args.baseline else 'res://tests/watergen/atmosphere_contract.gd']
        else:
            command += ['--scene', 'res://scenes/watergen/dynamic_preview.tscn', '--', '--wg-output=' + output.as_posix()]
            if args.baseline: command += ['--wg-baseline']
            if args.clip and mode == 'native': command += ['--wg-clip']
            if mode == 'native': command += ['--wg-capture', '--wg-test-seconds=' + str(args.test_seconds)]
        result = support.run(command, output, mode, max(args.timeout, 43200) if mode == 'preview' else args.timeout, expect_summary=mode != 'preview')
        if mode == 'preview' and result['status'] == 'PASS': result['status'] = 'NOT_APPLICABLE'
        manifest['tests'].append(result)
        if result['status'] in ('FAIL', 'BLOCKED'): break
    manifest['source_unchanged_during_run'] = sources == support.source_manifest()
    manifest['finished_at'] = datetime.now(support.TZ).isoformat()
    evidence_path = output / 'wg2-native-evidence.json'
    if evidence_path.exists():
        manifest['native_evidence'] = json.loads(evidence_path.read_text(encoding='utf-8'))
        gallery(output)
    manifest['acceptance_60_seconds'] = manifest.get('native_evidence', {}).get('timed_preview', {}).get('acceptance_60_seconds', False)
    manifest['status'] = 'PASS' if not changed and manifest['source_unchanged_during_run'] and all(r['status'] in ('PASS', 'NOT_APPLICABLE') for r in manifest['tests']) else 'FAIL'
    (output / 'run-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(output, flush=True)
    return 0 if manifest['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
