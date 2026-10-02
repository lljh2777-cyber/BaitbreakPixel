# Phase 0–1 implementation checkpoints

Baseline: `85299be`, source 0.22.6. Scope is the one-fish bait-suspicion prototype.
Automatic feeding pulses remain deferred until movement-only instinct is playtested.

## M0.1 — entity identity

- Fish and rod have explicit IDs. Bait and hook IDs are monotonic within each round; refilling creates a new bait identity, slots are only compatibility indices
- `_make_bait` remains pure; identity allocation happens only at creation/refill events
- Snapshot schema migrates once from 12 to 13; IDs and allocator cursors roundtrip, duplicate IDs are rejected before mutation
- Network interpolation uses lifecycle `bait_id`, not reusable slot `id`
- Checks: `phase01_entities` 11/11 and `architecture_v020` 46/46 on Linux Godot

Remaining checkpoints: observation boundary, measurement/baseline gate, then sequential survival pressure, suspicion, random hooks, role-filtered networking, statistical/native validation. This is not Phase 1 acceptance evidence.

## M0.2 — perception foundation

- Pure FishObservation whitelists fish-visible bait/grain records; unknown future authority fields stay private
- Fish bait rendering and bot food selection consume observation records identified by bait_id
- Far/medium/near hints progressively expose position/shape/scent/motion/disturbance. Exact visible grain geometry remains for Phase0 rendering compatibility; no hook truth is copied
- Visual decoration uses its own deterministic grain RNG; observation and drawing never consume simulation RNG
- Checks: hidden-truth equivalence, detachment, tier edges, serialized finite values and stable identity: 22/22
- The authority network transport remains unchanged at this checkpoint; role filtering is required before Phase1 network acceptance

## M0.3 — measurement foundation

- RoundStats records duration, feeding attempts/aborts, approaches/retreats, hook/escape outcomes and physiology/caution occupancy placeholders
- Both production simulate and legacy step sample statistics; pause/end remain frozen
- `python3 tools/run_rounds.py --rounds 1000 --seed 1` runs bounded, isolated 60 Hz headless rounds and exports summary.json, rounds.json and rounds.csv
- Immutable `--project` archives isolate measurements from ongoing edits; `summarize_rounds.py` merges disjoint seed shards, rejects duplicate seeds and marks censored rounds
- Initial two-round real-simulation probe completed; 1000-seed baseline is in progress and is a required Phase0 gate, not yet acceptance
- Deterministic replay/counter/freeze checks: 8/8. Current aggregate/native regression and full baseline measurement remain pending

## Phase0 review corrections and baseline evidence

- Feeding abort now means the entire stopped session consumed no food; successful sessions do not become aborts on their final tick
- Mouth contacts and successful hook attachments are distinct counters
- Snapshot validation rejects fractional identity fields without changing authority/RNG state
- 1000 immutable-baseline seeds 1–1000 completed, zero censored. Median duration **40.90 seconds**, mean 39.24; food mean 58.27, fish bot win rate 93.8%
- `docs/test-reports/PHASE0-BASELINE-1000.json` records source and exact harness hash. The older baseline's hook_events column actually meant mouth contacts; corrected summary labels it contacts and leaves unavailable actual attachment totals null
- Duration/outcomes were unaffected by the accounting corrections. Final Phase0 gate still includes current headless/native regression results

## M1.1 — satiety

Phase0 gate: immutable f083b63 current29 headless + import passed; native15 + import passed, all134 PNGs identical to clean baseline; Python runner28 passed. Historical/manual suites were not included.

Satiety starts at100, decays2.445/s from measured baseline median40.90s. With no food, hungry60 arrives at16.36s (0.40T), critical25 at30.67s (0.75T). Consumed pellets restore satiety, clamp0–100; low satiety reduces only stamina recovery at this checkpoint. The ordinary settings expose a hunger toggle, developer numeric parameters remain hidden from its search/categories. HUD/observation expose qualitative bands, not decimals.

Checks: satiety14, stats11, architecture46, rules186 all pass. This is source development, not a new packaged release.

## M1.2 — movement-only instinct

Low satiety increases a continuous urge toward the nearest observed edible target. The bias defaults to0.35 and has a hard0.45 cap; unit opposing input retains at least55% directional control. Settings expose low/standard/high intensity, while developer thresholds remain hidden. No suction button is changed; no automatic feeding pulse is implemented. HUD shows a qualitative urge cue.

Focused checks: instinct81 (including72 opposing directions), satiety14 and authority architecture46 pass. Movement feel and any later pulse still require human playtest approval.

## M1.3 — subjective caution

Suspicion is tracked per bait_id and accepts only FishObservation. Measured bait velocity, water-relative motion, recent disturbance and visible suction displacement supply evidence. Hunger changes risk tolerance separately from suspicion. Fast rise/slow recovery plus hysteresis produce CALM/UNEASY/ALARMED; fish-view posture marks and text make the qualitative state readable. Interpretation happens before movement/contact resolution, using information already available at the decision point.

Checks: hidden-hook equivalence, per-target evidence, separate hunger tolerance, smooth rise/slow recovery and hysteresis8; observation22 and architecture46 pass. Cue usefulness/false positives remain the later statistical gate, not established by these unit checks.

## M1.4 — event-random hooks

Creation/refill/rehanging allocates a new bait_id and samples hook truth only once using simulation RNG. Active initial food gets configurable danger bounds (default1–2 of3). Hook presence is no longer slot parity. Existing single-rod tackle membership is distinct from internal hook presence, so a safe rolled cast remains deployable; ambient targets also roll danger. Redeploying an already used bait rehangs a fresh lifecycle. No additional rod or dual-tether mechanic is introduced.

Physical flutter distributions have identical0–4 support for both truths: max-of-two draws for hooked and min-of-two for safe. Their overlap supplies noisy evidence without any amplitude interval proving hook truth. Interpretation still reads only measured physical motion. Authority-only BAIT_CREATED events record ID/truth/seed; these must be excluded from fish networking in the next gate.

Checks: random hook206, IDs13, suction41, architecture46 and tackle26 pass; final RNG-distribution/counter adjustments rerun random206+architecture46. Native acceptance fixture added for the upcoming final visual gate, not yet executed.

## Phase1 interpretation/accounting review

- Critical-satiety occupancy uses the configured threshold and does not accrue when hunger is disabled
- Briefly unseen same-ID evidence decays instead of resetting; replaced/destroyed IDs are pruned from authority state
- Focus switching has a12px margin so nearby competing targets do not make the displayed caution flicker every frame
- Focused suspicion11, statistics13 and architecture46 pass after these corrections

## M1.5 — role-filtered transport

A separate strict fish-presentation schema now allowlists public fields before every fish welcome/start/state/reliable/chunk send. Application validates the entire payload before mutation; authoritative schema13 capture/restore remains separate. Bait hook/tackle/private assignment fields, RNG/seed, truth logs, future supply state and internal beliefs never enter the fish payload. Opponent QTE targets are neutralized while realized line-force effects remain visible. Sanitized bait dictionaries do not regain fake hook fields on the client.

Focused real-ENet projection42, network rules25, rules synchronization9, untangle6, net02013 and net02113 pass. A fixed-six-frame capture assertion proved timing-sensitive under the larger simulation workload; it now waits within a bounded caught-state window for both peers, while retaining capture-once and final-victory assertions.

## M1.6 — validation in progress

Distance-only and cautious bot policies use the same public bait observation; cautious policy adds its own observation-derived beliefs, never authority hook fields. Self-induced suction displacement is compensated in the motion cue rather than mistaken for new danger evidence. Policy choice/hidden-truth invariance3, suspicion11 and suction41 checks pass.

Paired1000-seed policies (seeds1001–2000) are running from an immutable authority/policy tree with a source hash manifest. Final aggregate/native checks and report follow. Version0.23.0 denotes unreleased source only; no Windows package or GitHub Release has been produced.
