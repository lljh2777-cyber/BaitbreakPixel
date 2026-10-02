# P2.3 Feeding Choice Balance validation — v0.24.3

Date: 2026-10-02. Parent source: `f82f535ae3931d7e013ad7827c782cef5a7366be`, `feature/dev`. Godot: official 4.7.2 `ed1daf0bf`, Linux x86_64. This is a source-only step; no 0.24.3 ZIP/export/upload is claimed. Public Windows package remains 0.24.2 and cannot validate these changes.

## Scope and gate

User authorized continuing after P2.2. Concentrated profiles now affect real suction, automatic mouth Bite, fragmentation and satiety, while preserving grain count/score, manual suction controls, map, information/RNG contracts, hook lifecycle and schema 14. Authority profile guard 2 rejects old neutral-physics replay; exact network build is 0.24.3. Fish-visible shape guard remains 1. The final human gate is OPEN. Phase 3 is not started.

Mechanics and exact metric definitions are in [PHASE02-FEEDING-BALANCE.md](../architecture/PHASE02-FEEDING-BALANCE.md).

## Verification record

Final release gates: 44/44 current headless suites (25,651 summary assertions), official 4.7.2 editor import, and 19/19 native renderer suites passed. Python: 28 runner tests plus 11 benchmark-analysis tests passed. Headless evidence: [final summary](data/phase02-feeding/headless-gate-summary.json). Initial failures are retained, not relabelled as passes:

- First current-gate run: import passed; 42 of 44 headless suites passed, two legacy suction fixtures failed because seed 42 now selected a non-neutral food profile
- `bait_suction_v0212` and `feeding_feel_v022` now explicitly instantiate original Cluster identity/geometry; every original assertion is retained. Targeted reruns: 41/0 and 27/0
- Initial native run: import and 18/19 renderer suites passed; only two obsolete all-types-four-grain assertions failed. Updated typed native fixture checks 4/6/8 plus actual satiety, cap and HUD (78/0), with safe/hooked equality retained. Final 19/19 renderer suites: 475 summary assertions plus 2 legacy PASS markers; editor import is separate. Evidence: [native summary](data/phase02-feeding/native-gate-summary.json). Renderer: dot Linux desktop display :0, OpenGL compatibility llvmpipe, Dummy audio; no Windows/native sound-card verification claimed
- Original P2.1 Bite fixtures similarly pin Cluster so baseline four-grain tests continue to mean baseline capacity
- New profile/budget/physics/stats/privacy suite passes 44 assertions; observed-only policy suite passes 29
- New tests separately check Worm/Chunk intake, actual peel/movement/release, old loose-grain accounting, replay, unknown/nonfinite stats, and no new private metrics in fish payloads
- Existing type/hook independence diagnostic remains unchanged: 6,564 assertions, passed in this run. Existing information, RNG, network and map suites remain registered gates
- Python runner tests: 28/28; separate benchmark-analysis tests: 11/11 (including negative outcomes, pairing integrity, and weak point-estimate dominance with equal risk)

## Paired real-time experiment

All runs use actual `advance_tick` at 60 Hz, existing survival challenge, identical seeds for the three policies and the existing angler controller. No helper grants food, teleports fish or manufactures hook probabilities. Commands are calculated only from detached FishObservation and public rules; authority data is measured afterward.

Policy names are shorthand:

- SuckOnly: stand off and command suction; automatic mouth Bite is always active and is honestly counted
- BiteOnly: approach without suction commands; food is consumed through automatic Bite
- Mixed: choose approach or standoff from visible food shape, satiety and caution

Pilot: four paired seeds 21001–21004, 12 real rounds. One proposed table, no tuning changes after seeing outcomes. All 12 finished. Per-round means:

| Policy | Wins | Food | Hook contacts | Automatic Bite events |
|---|---:|---:|---:|---:|
| SuckOnly | 2/4 | 63.60 | 0.25 | 31.25 |
| BiteOnly | 0/4 | 56.06 | 1.00 | 18.25 |
| Mixed | 1/4 | 63.60 | 0.50 | 26.75 |

This pilot already contradicted any assumption that Mixed must win. Results were retained. Held-out seeds 31001–31100 are disjoint and use the same source/controller fingerprints and horizon. All 300 held-out rounds finished; no censoring or outcome filtering. The initial 12 pairs and extension 88 pairs were merged after checking seed disjointness and identical source fingerprints. Full [rounds JSON](data/phase02-feeding/heldout-100/rounds.json), [CSV](data/phase02-feeding/heldout-100/rounds.csv), [comparison with paired intervals](data/phase02-feeding/heldout-100/comparison.json), and [provenance](data/phase02-feeding/heldout-100/provenance.json) are retained alongside the pilot and both held-out batches.

| Policy | Fish wins | Food | Mean satiety | Final satiety | Contacts / round | Attachments / round | Duration seconds | Automatic Bite events / round |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| SuckOnly | 60/100 | 57.585 | 90.118 | 73.548 | 0.11 | 0.10 | 45.746 | 29.67 |
| BiteOnly | 17/100 | 43.554 | 87.085 | 64.925 | 0.80 | 0.76 | 28.790 | 13.15 |
| Mixed | 59/100 | 56.075 | 89.872 | 71.935 | 0.15 | 0.15 | 41.665 | 25.76 |

### Negative balance result: gate remains OPEN

SuckOnly weakly dominates both alternatives on all five core sample means: more food, higher time-mean satiety, more wins, fewer contacts and fewer attachments. Mixed also dominates BiteOnly. SuckOnly versus Mixed has a food advantage of 1.5105 with paired bootstrap 95% interval [0.2385, 2.8935], 0.04 fewer contacts [0.01, 0.08], and only a one-percentage-point win advantage whose interval spans [-5, +7] points. Both SuckOnly and Mixed have favorable marginal intervals against BiteOnly across the five core metrics. These are exploratory marginal intervals, not simultaneous confidence guarantees. Failure to distinguish SuckOnly/Mixed wins is not evidence of balance.

Do not call the no-dominant-policy goal passed. Do not claim shorter BiteOnly rounds are an efficiency advantage: many end in defeat. No post-held-out tuning was made to hide or reverse this result.

A concrete mechanism to investigate after human feedback: SuckOnly receives 46.794 of 57.585 food units (81.3%) through automatic Bite as detached food arrives, without deliberately bringing the mouth to the bait center. Its food split is Cluster 20.1495, Worm 21.6345, Chunk 15.801; all Chunk intake in this sample is auto-Bite. Meanwhile direct approach can trigger the ordinary hook-contact path before Bite arbitration. The no-QTE policy restriction magnifies that risk and prevents treating this as a skilled-human verdict.

Suggested next diagnostic, not an implemented change: ask the player whether controlled standoff already obtains the intended Worm/Chunk reward too safely. If confirmed, inspect detachment/fragment travel and approach commitment separately, preserving automatic Bite, whole-grain score and the shared physical hook path. Do not add an artificial type risk label or hidden Bite roll to force a winner.

## Interpretation limits

- These simple policies have no QTE/escape controller: FishObservation does not contain that state. Near-approach losses cannot be extrapolated to skilled human play
- Suction ticks, suction command sessions and automatic Bite candidate events are different denominators, not equivalent button attempts. Near 100% candidate Bite success excludes earlier physical contact interruptions and is not risk-adjusted safety
- Food reaching the mouth automatically triggers Bite even for SuckOnly. This is intentional current gameplay, not a bug in the policy labels
- Contact context counters can overlap and do not establish causality; physical contacts and actual attachments are separately reported
- Final satiety is affected by the 100 cap and round duration. Per-type food and gross/effective satiety are descriptive outcome composition, not randomized within-type causal effects
- Bootstrap intervals describe this seed sample. Neither 100 seeds nor automated pixel equality proves human readability, audible feedback, fun, fairness or final balance

## Final human playtest — stop here

Run `feature/dev` source in Godot 4.7.2 and verify 0.24.3 in the menu. Do not use the old 0.24.2 ZIP to assess this balance.

1. On each type, compare light/steady/strong suction, then deliberately move the mouth close. Cluster should peel most readily; Worm/Chunk should resist suction but reward approach
2. Compare low and high satiety. Chunk should help hunger more per unchanged score unit; observe the cap rather than expecting extra score
3. Under high caution, test taking a little from farther away and backing off. No type should be treated as a hook label
4. Ask whether you naturally choose distance, approach and mixed behavior in different situations. If one method always seems best, report type, power, satiety and caution
5. Verify 18 px proximity and 0.40-second cooldown remain readable, automatic Bite has no button/toggle, and no extra motion or random punishment appears
6. With two 0.24.3 source clients, compare intake, satiety, score, cooldown, contact and rejoin behavior; automated ENet is not a substitute for your two-player experience

Only an explicit user confirmation that Phase 2 can end permits discussing Phase 3. Otherwise continue 0.24.x based on feedback.
