# P2.3 tighter/slower automatic bite — v0.24.6

2026-10-03. Base `9c447e7210987472d108ce284b9df5cd057f2dc7`, `feature/dev`, preserving the newly published 0.24.5 release documentation. Godot 4.7.2 official `ed1daf0bf`, Linux. Source-only: no new ZIP, export, release upload, Windows launch or hardware-audio verification. Latest public Windows package remains 0.24.5.

## Bounded change

- Default automatic mouth radius 12→10 px; accepted-intake cooldown .60→.80 s. Nominal uninterrupted rate 1.667→1.25 bites/second, 25% fewer repeat opportunities when food is continuously available
- Base/type capacities 4/6/8 and .18 s jaw feedback remain. No bite button, disable switch, automatic suction, extra hook probability, duplicated intake, gradient, profile multiplier, map or RNG changes
- Exact catalog comparison confirms only these two default values change among 150 entries; existing bounds already accept 10/.8. Simulation, food profiles, snapshot schema and fish projection files are unchanged
- Personal-profile feeding-defaults revision 3 independently migrates old 12/.6 to 10/.8. Older default migrations still chain. Revision-1 explicit 18 and revision-2 explicit 14/18/.4 remain, as do unrelated custom values. New revision-3 explicit old values and named/imported presets persist. An old hand-entered value equal to that profile revision's default cannot be distinguished and migrates once
- Authority schema 14/guard 3 and public guard 1 stay unchanged. Guard-3 snapshots with explicit 14/.4 and 12/.6 rules restore and replay without personal-profile migration. Live peers require exact build 0.24.6

## Verification

Current headless gate: **44/44 suites, 25,873 summary assertions**, plus successful bounded editor import. Python runner **28/28**, analysis **11/11**. [Headless summary](data/phase02-bite-tuning-0246/headless-summary.json), [Bite 57/57](data/phase02-bite-tuning-0246/bite.log), [real ENet/replay 136/136](data/phase02-bite-tuning-0246/bite-network.log), [rules/migration 256/256](data/phase02-bite-tuning-0246/rules.log), [Python runner](data/phase02-bite-tuning-0246/python-runner.log), [analysis tests](data/phase02-bite-tuning-0246/python-analysis.log).

Native gate: **19/19 suites, 480 summary-counted assertions plus 2 visual pass markers**, and a separate focused Bite run **23/23** with successful editor import. Actual Linux X11 desktop (`DISPLAY=:0`), OpenGL Compatibility / Mesa llvmpipe, Dummy audio. The driver warns that changing V-Sync is unsupported. Existing `bait_suction_native_v0211`, `effort_native_v013` and `pond_native_v021` report ObjectDB-at-exit warnings (2/2/3 instances), all exit 0; no script/engine errors or failed assertions. [Native summary](data/phase02-bite-tuning-0246/native-summary.json), [focused summary](data/phase02-bite-tuning-0246/native-focused-summary.json), [native Bite log](data/phase02-bite-tuning-0246/native-bite.log), [frozen-source manifest](data/phase02-bite-tuning-0246/native-source-manifest.json).

Actual 640×360 PNG inspection confirms the title is 0.24.6 and no F/bite-key instruction is shown. A grain 11 px from the mouth stays visible, with byte-identical ready/idle images. At 36 ticks (.60 s), food stays 04/18 with .2 s cooldown; at 48 ticks (.80 s), food becomes 08/18 with a fresh .8 s cooldown and jaw feedback. HUD remains readable and does not overlap neighboring bars. Hidden-hook pixel-equivalence checks pass. All 376 frozen runtime/asset/test/tool manifest entries match both the frozen copy and the final source checkout.

Targeted real-60-Hz checks include 9.9/exact-10 px acceptance, 10.01 px rejection, deterministic repeat intervals, no empty feedback, suction/bite arbitration without doubled food/satiety, recoil-boundary intake, and original physical hook-contact precedence. The migration matrix covers missing/0/1/2/3 stamps, independent default/custom combinations, earlier explicit settings and named/imported presets. Tests retain old assertions and adapt their geometry/wait duration to the requested new boundary/cadence.

Preliminary development runs used partly updated old test fixtures and failed expected old geometry/wait assertions; those runs are excluded from the final counts. Fixtures were updated without changing gameplay arbitration, then focused and full current gates passed. Native runs passed on their first imported frozen-source attempt.

No full 100-pair policy/balance experiment was repeated for this bounded adjustment. Earlier 0.24.4/0.24.5 reports and published artifacts remain historical, not proof of 0.24.6 balance. Automated tests and assistant image inspection do not establish subjective feel, fun, fairness, hardware audio or two-player Windows behavior.

## Final manual gate remains OPEN

1. Run current source in Godot 4.7.2 and check menu version 0.24.6. Existing 0.24.5 ZIP still uses 12 px/.60 s
2. Approach food without a button: intake should start only within 10 px. Remain nearby to assess .80 s repeat cadence for cluster/worm/chunk
3. Hold suction across intake/cooldown and compare near/mid/far response; gradient and 4/6/8 capacities should feel unchanged
4. Load older personal settings, then save explicit custom old values and reopen; unrelated preferences and new explicit values should persist
5. Use two 0.24.6 source peers to assess repeated intake, actual hook contact, pause/reconnect and privacy

Phase 2 stays at the final human gate. No Phase 3 work.
