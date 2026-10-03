# P2.3 mouth range and cadence tuning — v0.24.5

2026-10-03. Base `a4a1f538860cb37741a49ccd9fdb078d7b39b8b0`, feature/dev (includes published0.24.4 release documentation). Official Godot4.7.2 `ed1daf0bf`, Linux. Source-only; no ZIP, export, upload, Windows launch or hardware-audio verification. Public Windows package remains0.24.4.

## Bounded change

- Default automatic mouth intake radius14→12px; accepted-intake cooldown.40→.60s. Nominal uninterrupted rate2.5→1.667 bites/second, one-third fewer successful opportunities at continuous availability
- Base and typed capacity4/6/8 unchanged. No button/F binding, auto-suction, extra hook probability, doubled awards, profile multiplier, gradient, map or RNG changes. Existing feedback animation duration.18s remains
- Developer cooldown range expands from.30–.55 to.30–.80s so the new default is valid
- Personal-profile feeding-defaults stamp2 migrates prior14/.4 independently to12/.6; unstamped18 follows original18→14 then12. Existing revision1 explicit18, unrelated settings and other custom values stay. Historical hand-entered values equal to the former defaults cannot be distinguished and migrate once. New stamp2 explicit14/18/.4 survives; named presets and imported explicit rules never migrate
- Authority schema14/physics guard3 and public guard1 retained. Physics code is unchanged and snapshots retain explicit rules/countdowns, not current defaults: a prior guard3 snapshot with14/.4 restores and replays deterministically. Live peers require exact build0.24.5

## Verification

Current headless gate44/44 suites, 25,828 summary assertions; focused editor import passed. Python runner28/28 and analysis11/11. [Headless summary](data/phase02-bite-tuning/headless-summary.json), [Bite log](data/phase02-bite-tuning/bite.log), [real ENet and replay log](data/phase02-bite-tuning/bite-network.log), [profile migration/rules log](data/phase02-bite-tuning/rules.log), [Python runner](data/phase02-bite-tuning/python-runner.log), [analysis tests](data/phase02-bite-tuning/python-analysis.log).

Native renderer gate19/19 suites, 482 assertions, plus separate editor import; focused Bite rerun23/23. Actual Linux X11/OpenGL compatibility/Mesa llvmpipe with Dummy audio. [Native summary](data/phase02-bite-tuning/native-summary.json), [native Bite log](data/phase02-bite-tuning/native-bite.log), [frozen source manifest](data/phase02-bite-tuning/native-source-manifest.json). Automated renderer assertions and assistant image inspection found clear640×360 HUD, no adjacent-bar overlap, and no F instruction. No human approval or Windows validation is implied.

At24 ticks (.40s), native food remains04 and cooldown.2; at36 ticks (.60s), food08 and cooldown.6 with restarted jaw feedback. Hidden-hook image equality passes. Runtime/native fixtures matched frozen source; only docs and the supplementary headless old-snapshot test changed afterward.

An initial native attempt before frozen-source asset import failed on missing cached textures/parse resources; retained in the validation workspace, excluded from gate counts. Clean editor import and full/focused reruns passed. A preliminary Python analysis invocation used a nonexistent tests/benchmark directory and did not execute tests; corrected official tools/phase02_test_analysis.py passed11/11.

Targeted real60Hz checks accept11.9px and exact12px, reject12.01px; repeated neutral intake remains deterministic, no empty feedback/cooldown, and held Suck still works during cooldown without double food/satiety. Migration covers independent defaults/custom combinations, revision0/1/2, old18 chain and explicit presets. Real ENet checks remote rewards, countdowns, privacy and physical-contact precedence. Native fixture rejects13px (inside the former radius), remains cooling at.40s and repeats at.60s; pre-contact hook-blind pixels remain required.

No100-pair policy/balance simulation rerun: this is a bounded user-requested range/cadence adjustment. Previous0.24.4 outcomes are historical, not evidence for0.24.5 balance. Automated checks cannot establish subjective feel, fun, fairness or two-player Windows behavior.

## Manual gate remains OPEN

1. Run current source in Godot4.7.2; menu must show0.24.5. Existing0.24.4 ZIP cannot test these defaults
2. Approach food without a button; only within12px should intake begin. Remain beside it and assess whether.60s feels appropriately slower across cluster/worm/chunk
3. Hold Suck across intake and cooldown; verify readable handoff without duplicated food or stalls. Near/mid/far suction gradient should feel unchanged
4. Load prior personal settings: old defaults update, unrelated custom settings remain. Newly saved explicit old values should persist
5. With two0.24.5 source peers, check repeat intake, actual hook contact, pause, reconnect and privacy

Final human balance gate stays open. No Phase3 work.
