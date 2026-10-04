#!/usr/bin/env python3
"""WG-6.0/6.1 independent terrain: bounded isolated tests and review gallery."""
import argparse
from datetime import datetime
import json
import re
import uuid
import run_wg0 as support

BASE_COMMIT = "e333c90c46d03e6a9bf4080d758bb8e264548d8e"
PRESETS = dict(fern="蕨叶庭 · 713284 · 中央浅沟", ribbon="长叶湾 · 2649 · 单侧缓坡",
               lily="浮叶荫 · 42 · 沉积低洼", root="垂根岸 · 731 · 石质高岸")
CAMERAS = [(0, 0), (320, 60), (640, 120), (0, 120), (640, 0)]


def gallery(output):
    cards = []
    for preset, title in PRESETS.items():
        views = ''.join(f'<option value="{x}-{y}">{name} ({x}, {y})</option>'
                        for (x, y), name in zip(CAMERAS, ['左上', '中心', '右下', '左下', '右上']))
        cards.append(f'''<section data-preset="{preset}"><h2>{title}</h2>
<p>整世界 · WG-6 地势与现有环境</p><a href="{preset}/full-world.png"><img class="world" src="{preset}/full-world.png" alt="{title} 整世界"></a>
<details open><summary>地势单独显示</summary><a href="{preset}/terrain-world.png"><img class="world" src="{preset}/terrain-world.png" alt="{title} 地势"></a></details>
<p>同镜头对照 <select class="camera" aria-label="选择镜头">{views}</select> <select class="comparison" aria-label="选择对照"><option value="before">现有生成水域</option><option value="legacy">Legacy 原版</option><option value="terrain">只看地势</option></select></p>
<div class="pair"><figure><figcaption>WG-6</figcaption><a class="after-link"><img class="after" alt="WG-6 同镜头"></a></figure><figure><figcaption class="compare-title">现有生成水域</figcaption><a class="before-link"><img class="before" alt="同镜头对照"></a></figure></div>
<a href="{preset}/terrain-plan.json">纯值地势描述</a></section>''')
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>WG-6.1 地势评审</title><style>
:root{color-scheme:dark}body{margin:32px auto;max-width:1440px;padding:0 20px;background:#10292d;color:#d7e8dd;font:16px/1.65 system-ui}h1{font-size:30px}h2{font-size:22px}p{color:#adc7c1}a{color:#a9dfc6}section{padding:20px;margin:28px 0;background:#153338;border:1px solid #315455;border-radius:12px}img{image-rendering:pixelated;width:100%;display:block}.world{margin:12px 0}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}figcaption{margin:6px 0}select{padding:8px;margin:4px;border:1px solid #547b71;border-radius:5px;background:#183e43}summary{cursor:pointer}nav{display:flex;gap:18px;flex-wrap:wrap}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style>
<h1>WG-6.1 · 水下地势样片</h1><p>坡、丘、沟、台地 · 独立预览 · 等待地势方向确认。正式试玩仍为 0.25.6。现有植物与 WG-5 材质仅作为参照，没有新增生态植物或动物。</p>
<p>先看起伏是否自然，再看石坡是否像可碰撞的障碍。四套构图均有整世界、五镜头、地势单独显示和 Legacy 对照。静态时间均为 0；这里的地势不会阻挡鱼或抄网。</p>'''
    script = '''<script>document.querySelectorAll('section').forEach(s=>{let c=s.querySelector('.camera'),m=s.querySelector('.comparison');c.value='320-60';function update(){let a=s.dataset.preset+'/full-'+c.value+'.png',b=s.dataset.preset+'/'+m.value+'-'+c.value+'.png';s.querySelector('.after').src=a;s.querySelector('.before').src=b;s.querySelector('.after-link').href=a;s.querySelector('.before-link').href=b;s.querySelector('.compare-title').textContent=m.options[m.selectedIndex].text}c.addEventListener('change',update);m.addEventListener('change',update);update()})</script></html>'''
    (output / 'gallery.html').write_text(page + ''.join(cards) + script, encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--mode', choices=['all', 'headless', 'native', 'preview'], default='all')
    parser.add_argument('--run-id', default='wg6-' + datetime.now(support.TZ).strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6])
    parser.add_argument('--timeout', type=int, default=180)
    parser.add_argument('--legacy', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,79}', args.run_id) or args.timeout <= 0:
        parser.error('Invalid run id or timeout')
    output = support.ROOT / 'artifacts/watergen' / args.run_id
    output.mkdir(parents=True, exist_ok=False)
    sources = support.source_manifest()
    # WG6's first round adds isolated modules only. Any changed existing runtime
    # or production configuration must fail the gate, even if tests still pass.
    existing = support.git('diff', '--name-only', '--diff-filter=DMRTUXB', BASE_COMMIT).splitlines()
    protected = [p for p in existing if p.startswith(('scripts/', 'scenes/', 'data/', 'tests/', 'tools/'))
                 or p in ('project.godot', 'export_presets.cfg')]
    manifest = dict(task_id='WG-6.1', base_commit=BASE_COMMIT, tested_commit=support.git('rev-parse', 'HEAD'),
                    dirty=bool(support.git('status', '--porcelain')), started_at=datetime.now(support.TZ).isoformat(),
                    source_files_sha256=sources, changed_existing_runtime_files=protected, tests=[],
                    production_integration=False, version_bumped=False, human_acceptance='NOT_RUN', next_gate='WAITING_FOR_REVIEW')
    modes = ['headless', 'native'] if args.mode == 'all' else [args.mode]
    for mode in modes:
        command = [args.godot, '--path', str(support.ROOT), '--audio-driver', 'Dummy',
                   '--log-file', str(output / (mode + '-engine.log'))]
        if mode == 'headless': command += ['--headless', '--script', 'res://tests/watergen/terrain_contract.gd']
        else:
            command += ['--scene', 'res://scenes/watergen/terrain_preview.tscn', '--', '--wg-output=' + output.as_posix()]
            if mode == 'native': command += ['--wg-capture']
            if args.legacy: command += ['--wg-legacy']
        result = support.run(command, output, mode, 43200 if mode == 'preview' else args.timeout, expect_summary=mode != 'preview')
        if mode == 'preview' and result['status'] == 'PASS': result['status'] = 'NOT_APPLICABLE'
        manifest['tests'].append(result)
        if result['status'] in ('FAIL', 'BLOCKED'): break
    manifest['source_unchanged_during_run'] = sources == support.source_manifest()
    manifest['finished_at'] = datetime.now(support.TZ).isoformat()
    evidence = output / 'wg6-native-evidence.json'
    if evidence.exists():
        manifest['native_evidence'] = json.loads(evidence.read_text(encoding='utf-8'))
        gallery(output)
    manifest['status'] = 'PASS' if not protected and manifest['source_unchanged_during_run'] and all(t['status'] in ('PASS', 'NOT_APPLICABLE') for t in manifest['tests']) else 'FAIL'
    (output / 'run-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(output, flush=True)
    return 0 if manifest['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
