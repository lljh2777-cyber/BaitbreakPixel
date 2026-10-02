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
