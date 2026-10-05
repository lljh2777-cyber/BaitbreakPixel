#!/usr/bin/env python3
"""WG-6.2 independent native preview and functional checks. No file-hash sweeps."""
import argparse
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from run_tests import run_bounded, classify


def gallery(output):
    sections = []
    for seed, name in [(42, '默认池塘'), (2166, '开阔地图'), (1346, '密集地图'), (296, '抄网路线复杂地图')]:
        sections.append(f'''<section data-seed="{seed}"><h2>{name} · 地图 {seed}</h2>
<p>相同真实地图，视觉种子 713284；群落随木石多边形、交互草边缘和池底空隙分布。</p>
<img class="world" src="map-{seed}/full-world.png" alt="完整环境与新增群落">
<details><summary>真实地形与群落（隐藏远景装饰）</summary><img src="map-{seed}/plants-world.png" alt="真实地形与群落"></details>
<p><select class="camera" aria-label="镜头"><option value="320-120">中下</option><option value="0-120">左下</option><option value="640-120">右下</option><option value="0-0">左上</option><option value="640-0">右上</option></select>
<select class="mode" aria-label="对照内容"><option value="before">开发基线 · 无新增群落</option><option value="plants">真实地形 + 群落</option><option value="geometry">真实地形</option></select></p>
<div class="pair"><figure><figcaption>完整环境 + 群落</figcaption><a class="a"><img class="after" alt="新增群落"></a></figure><figure><figcaption class="comparison"></figcaption><a class="b"><img class="before" alt="对照"></a></figure></div>
<a href="map-{seed}/communities.json">群落及真实表面挂点</a></section>''')
    html = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>WG-6.2 植物群落</title>
<style>body{max-width:1400px;margin:32px auto;padding:0 20px;background:#102b30;color:#d7e6d9;font:16px/1.65 system-ui}h1{font-size:30px}p{color:#aacbc1}section{margin:28px 0;padding:20px;background:#17373d;border:1px solid #315456;border-radius:10px}img{width:100%;image-rendering:pixelated;display:block}a{color:#a8dcc3}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}select{padding:8px;background:#23454a;color:#d6e7d9;border:1px solid #587a74;margin:4px}summary{cursor:pointer;padding:10px 0}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style>
<h1>WG-6.2 · 跟随真实地形的植物群落</h1><p>新分支 feature/watergen-v2，基线 feature/dev@c3c24b3。第一代 feature/watergen@63112b1 已冻结。本轮为独立视觉预览，正式 0.27.5 游戏入口与规则保持基线。</p>
<p>丝状藻、地毯藻、矮草、宽叶草、苔藻和木枝附生植物。浅色小圆点仅在预览的 G 挂点模式出现；这些植物不会成为食物、碰撞或缠线目标。</p>'''
    script = '''<script>document.querySelectorAll('section').forEach(s=>{let c=s.querySelector('.camera'),m=s.querySelector('.mode');function update(){let p='map-'+s.dataset.seed+'/';let a=p+'full-'+c.value+'.png',b=p+m.value+'-'+c.value+'.png';s.querySelector('.after').src=a;s.querySelector('.before').src=b;s.querySelector('.a').href=a;s.querySelector('.b').href=b;s.querySelector('.comparison').textContent=m.options[m.selectedIndex].text}c.onchange=update;m.onchange=update;update()})</script></html>'''
    (output / 'gallery.html').write_text(html + ''.join(sections) + script, encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--mode', choices=['all', 'headless', 'native', 'preview'], default='all')
    parser.add_argument('--skip-import', action='store_true')
    parser.add_argument('--run-id', default='wg62-' + datetime.now(timezone(timedelta(hours=8))).strftime('%Y%m%d-%H%M%S'))
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,79}', args.run_id): parser.error('Invalid run id')
    output = ROOT / 'artifacts/watergen' / args.run_id
    output.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    for key in ['APPDATA', 'LOCALAPPDATA', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
        path = output / 'isolated-user' / key.lower()
        path.mkdir(parents=True, exist_ok=True); env[key] = str(path)
    manifest = {'base': 'c3c24b3090ac148cae020414560a7eb6bbf54606',
                'tested_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'worktree_status': subprocess.check_output(['git', 'status', '--short'], cwd=ROOT, text=True, encoding='utf-8'),
                'tests': [], 'human_review': 'PENDING', 'production_integration': False}
    tasks = []
    if not args.skip_import: tasks.append(('import', ['--headless', '--editor', '--quit'], 90, False))
    if args.mode in ['all', 'headless']: tasks.append(('contract', ['--headless', '--script', 'res://tests/watergen/ecology_contract.gd'], 120, True))
    if args.mode in ['all', 'native', 'preview']:
        command = ['--scene', 'res://scenes/watergen/ecology_preview.tscn', '--', '--output=' + output.as_posix()]
        if args.mode != 'preview': command += ['--capture']
        tasks.append(('preview' if args.mode == 'preview' else 'native', command, 43200 if args.mode == 'preview' else 150, args.mode != 'preview'))
        if args.mode != 'preview':
            tasks.append(('gameplay-native', ['--script', 'res://tests/watergen/ecology_gameplay_native.gd', '--', '--test-profile', '--output=' + (output / 'gameplay').as_posix()], 120, True))
    for name, flags, timeout, summary in tasks:
        command = [args.godot, '--path', str(ROOT), '--audio-driver', 'Dummy', '--log-file', str(output / (name + '-engine.log')), *flags]
        result = classify(run_bounded(command, timeout, ROOT, env), expect_summary=summary)
        (output / (name + '.log')).write_text(result.pop('output'), encoding='utf-8')
        result.update(name=name, command=command)
        manifest['tests'].append(result)
        print(f"{name}: {result['status']} {result['passed']}/{result['passed']+result['failed']} ({result['duration_seconds']}s)", flush=True)
        if result['status'] != 'passed':
            print((output / (name + '.log')).read_text(encoding='utf-8')[-7500:], flush=True); break
    manifest['status'] = 'PASS' if all(t['status'] == 'passed' for t in manifest['tests']) else 'FAIL'
    if (output / 'native-results.json').exists(): gallery(output)
    (output / 'run-results.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(output, flush=True)
    return 0 if manifest['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
