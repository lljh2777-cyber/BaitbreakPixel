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
