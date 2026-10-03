# P2.3 distance tuning — v0.24.4

2026-10-02. Parent: `63f5e6e1cea725ed74642969fc7e5863a960df90`, feature/dev. Godot official4.7.2 `ed1daf0bf`, Linux. Source-only change; no ZIP/export/Windows launch claimed. Public Windows package remains0.24.3.

## Requested change

- Automatic Bite default18→14px; base4 and typed4/6/8 capacity, .40s cooldown unchanged
- Existing cone44px length/default width/spread preserved. Replace centerline factor `1−0.4d` with `t²(3−2t)`, `t=1−clamp(d,0,1)` where d=forward-depth/range. Mouth100%, midpoint50%, far boundary0%; smooth interior, zero outside
- Existing lateral factor unchanged. Attached-grain detachment progress and whole-bait displacement target already used strength; loose-grain transport now uses the same field exactly once. Body target remains capped at mouth distance and existing response-speed limit
- No auto-suction, Bite button, F change, hook-contact-radius change, hidden-risk roll, map/RNG or type-table change
- Authority schema14 retained, physics guard3 rejects old guard1/2 snapshots. Public guard1 unchanged; exact network build0.24.4
- Old unmarked personal saved18 migrates narrowly to14. Older saves cannot distinguish manual18 from the old built-in18, so both migrate once. Other rules/ranges preserved; new saves stamp feeding-defaults revision1 and later explicit18 persists. Named imported presets retain explicit values

## Regression evidence

Final current gate: 44/44 headless suites (25,816 summary assertions) plus editor import; 19/19 native suites plus import (479 assertions), Python runner28/28 and benchmark-analysis11/11. [Headless summary](data/phase02-distance/headless-summary.json), [native summary](data/phase02-distance/native-summary.json). Supplemental native gradient11/11: the same0.05s pulse moves a loose grain2.697998px at20px versus0.240906px at38px, with actual mouth-directed displacement, no premature intake, and exact hook-blind pixel equality. [Gradient log](data/phase02-distance/native-gradient.log). Linux OpenGL/llvmpipe, Dummy audio; no Windows hardware or sound verification. Automatic verification cannot establish subjective feel or final balance.

Initial failures were retained, not hidden:

- Original `feeding_feel_v022` produced24pass/3fail. Strong pull at26px no longer contacts the hook in1s, and old uniform loose-particle-speed bands no longer describe intended physics
- Revised fixture explicitly asserts no contact at26px, then confirms strong suction at20px still causes ordinary swept physical contact while gentle peeling remains outside contact. Centerline strong target shift is about9.5px at26 versus14.8px at20, explaining the change without modifying hook rules
- The next full headless run also found `bait_suction_v0212`37/4: three multiplier-independence checks still assumed uniform loose speed and one26px contact fixture assumed old body reach. The independence assertions now use exact field×speed without the body multiplier; the contact-only setup moves to20px. No gameplay or physical contact radius was altered to satisfy them
- Loose travel is checked against six exact field×power integration steps, rather than widening arbitrary bands. Revised suite28/0
- New distance tests initially hit floating-point coordinate tolerance and near-mouth target clipping. Test comparisons now allow0.00004px precision error and use non-saturated near/mid/far positions; gameplay was not weakened for those failures. Expanded feeding balance suite204/0
- First preliminary benchmark was interrupted after profile migration invalidated its starting fingerprint. It is incomplete diagnostic output only, not evidence of a completed comparison. The final run starts after runtime-code freeze and verifies fingerprints again on completion

## Reused-seed tuning comparison (not new held-out proof)

Final100 paired seeds31001–31100, three unchanged observation-only policies, real60Hz simulation, unchanged370s horizon. All300 rounds terminated; no outcomes or seeds discarded. Runtime fingerprints matched before/after. These seeds were already examined in0.24.3 and are explicitly labeled `phase=test`; they are a tuning comparison, not untouched confirmatory evidence. [Full rounds](data/phase02-distance/tuning-100/rounds.json), [scalar-column CSV](data/phase02-distance/tuning-100/rounds.csv), [paired policy intervals](data/phase02-distance/tuning-100/comparison.json), [provenance](data/phase02-distance/tuning-100/provenance.json). Original baseline remains in [0.24.3 report](PHASE02-FEEDING-VALIDATION.md).

| Policy | Wins old→new | Food old→new | Mean satiety | Contacts/round | Attachments/round | Duration seconds | Auto-Bite events |
|---|---:|---:|---:|---:|---:|---:|---:|
| SuckOnly |60→36/100|57.585→49.731|69.454|0.01|0.01|78.096|46.37|
| BiteOnly |17→17/100|43.554→43.3305|87.110|0.80|0.76|28.721|13.17|
| Mixed |59→37/100|56.075→51.0795|76.795|0.09|0.09|64.856|37.84|

No policy weakly dominates across all five sample mean metrics in this run, and none meets the stringent all-interval dominance criterion. Neither result proves balance, equivalence, fun or readable handfeel. The cost is visible: standoff and Mixed win rates fell24/22 percentage points and rounds became much longer; far suction is deliberately weaker and may now be too weak for satisfactory play. SuckOnly still receives41.1825/49.731=82.81% of food through automatic Bite (previously81.3%). This change has not removed dependence on automatic mouth intake, and direct-approach BiteOnly remains at17% with high physical-contact exposure. A plausible explanation is slower far-field peeling/transport while arriving fragments still hand off to automatic Bite; this is a mechanism hypothesis, not an isolated causal experiment.

The controller has no QTE/escape skill and is unchanged, so these outcomes cannot predict skilled-player fairness. Higher Bite event count despite less food may reflect smaller arrivals and longer rounds rather than stronger reward. Short BiteOnly rounds often end in defeat; do not label them efficiency. Final human balance gate remains OPEN; no further tuning was performed after this comparison.

## Manual gate remains OPEN

1. Run source0.24.4 in Godot4.7.2; check menu version. Old0.24.3 executable cannot verify this change
2. At near/mid/far positions, try all three powers and bait types. Far interior should progress slowly, approaching the mouth should accelerate, and exact outer boundary should exert no pull
3. Approach into14px without pressing anything: automatic Bite should work continuously with .40s cooldown. Hold suction through handoff/cooldown: no stall, duplicate food or sudden extra near-mouth acceleration
4. Compare gentle/strong suction near actual hooks: the reduced long-distance pull must not erase physical contact risk when closer. Do not infer hook identity from bait shape
5. Load old settings and verify normal18px default becomes14 without losing unrelated preferences; custom ranges remain explicit
6. Use two0.24.4 peers for intake, contact, pause, reconnect and privacy behavior. Automated ENet and Linux renderer checks do not replace two-player Windows testing

Phase2 final balance and subjective playtest remain open. No Phase3 work is included.
