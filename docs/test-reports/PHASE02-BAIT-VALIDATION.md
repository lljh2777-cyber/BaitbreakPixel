# P2.2 Bait Archetypes validation — v0.24.2

Date: 2026-10-02. Source baseline: `3f916e4609f6758e5b928f6cf343b075210ecfd4`, `feature/dev`. User authorized progression after v0.24.1 automatic mouth Bite; subjective playtest feedback remains reopenable.

## Delivered scope

- Three immutable food types: Cluster grains, Worm curved strip, Chunk compact block
- Central FoodProfile with only shape/scent presentation differences active; all feeding/satiety/fragmentation multipliers remain 1.0 pending P2.3
- Same 44 grains, total points and layer rewards for each type; actual particle positions match visual silhouettes
- Survival three ambient types once each; duel retains two targets with two sampled types, no food-budget increase
- Type selection via Simulation RNG independent of hook constraints; recasting existing food preserves type, full rehang rolls a fresh type, old loose food retains its own kind
- Explicit schema 14 profile-version guard plus exact network build 0.24.2; old/malformed/unknown typed records rejected before state mutation
- Strict fish allowlist for visible kinds and shape/scent cues, with no hidden hook, internal profile multipliers, truth events or RNG in fish payload
- Existing automatic Bite unchanged: mouth 18 px, at most 4 grains, 0.40 s cooldown; no F key, automatic suction, lunge or new hook roll
- Source only: no export, ZIP, upload or release created. Public v0.24.1 remains unchanged

Implementation commit: `485972cb50470eb9120ca8e7acc4af104e371bff`. The validation documentation follows in its own commit.

## Verification

Official Godot 4.7.2 stable (`ed1daf0bf`), Linux x86_64. Binary SHA256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`.

- Frozen native gate: all 19 renderer suites plus editor import passed, 457 summary assertions and 2 legacy visual log markers, 0 failed/timeout/blocked entries
- New archetype native suite: 60/60; existing automatic Bite native: 18/18
- 36 new 640×360 captures inspected: three-type overview, partial/loose food, actual automatic intake for each type, deformation, mouth/cooldown feedback; 13 matched safe/hooked PNG pairs independently confirmed pixel-identical
- Visual run used official 4.7.2 OpenGL Compatibility on the cloud Linux desktop (Mesa llvmpipe), with frozen gameplay/native-test SHA256 verification
- Independent read-only code review found no remaining blocker in lifecycle, hook independence, information boundary, strict snapshots or ENet scope

Frozen headless gate: all 42 current suites plus editor import passed, 25,577 assertions/log markers, 0 failed/timeout/blocked entries. Results are recorded in `artifacts/test-runs/bait242-current-final/summary.json`; native evidence is in the separately frozen Linux renderer run. These are current release gates, not a claim that all historical diagnostic suites pass.

Focused results already completed:
- phase02_bait_types: 6,564 checks, 0 failures
- phase02_food_profiles: 158 checks, 0 failures
- phase02_observation: 59 checks, 0 failures
- phase02_bait_network: 92 checks, 0 failures; real ENet all types, hidden rehang with old loose fragments, authority restore, automatic consumption/rewards and disconnect/fresh-room rejoin
- Python runner/capture contract: 28 tests, 0 failures

Initial aggregate run exposed the old pond_v021 assertion requiring every bait silhouette to be identical. P2.2 intentionally adds three shapes; the assertion was updated to require all three active types and per-type hook/slot-independent offsets. The focused pond suite then passed 31/31. This changes the expected art contract, not the hook-information boundary; safe/hooked equality remains covered for every type.

Fresh-room rejoin is tested. Existing multiplayer disconnect ends the current round; this change does not add or claim mid-round reconnect/resume. Linux native verification uses Dummy audio and does not establish actual speaker output or Windows-native execution.

## Type/hook independence diagnostic

Fixed seeds 10000–10999 for each survival/duel × default/zero/max constraint scenario: 6,000 initial worlds, 15,000 active initial food targets and 18,000 full rehang events. Every seed performs three rehangs. `zero` uses hook probability/min/max 0; `max` uses probability 1, danger min 1/max 2 and safe min 1. Default uses unchanged existing rules. Initial hook constraints and type shuffle are structurally independent; rehang constraints never inspect type.

The deterministic regression flags a type-conditioned rate spread ≥10 percentage points within a cohort. This is a coarse diagnostic, not proof of statistical independence or a balance claim. The maximum observed spread was 5.40 percentage points (survival/max/initial); no systematic type label was introduced by the code. The fully forced duel/max rehang result is 100% for every type because one safe ambient target remains and probability 1 is allowed; this is a population constraint, not a type effect.

| Mode | Constraints | Event | Cluster hooks/n | Worm hooks/n | Chunk hooks/n |
|---|---|---|---|---|---|
| survival | default | initial | 499/1000 (49.90%) | 488/1000 (48.80%) | 495/1000 (49.50%) |
| survival | default | rehang | 541/1037 (52.17%) | 492/984 (50.00%) | 482/979 (49.23%) |
| survival | zero | initial | 0/1000 (0.00%) | 0/1000 (0.00%) | 0/1000 (0.00%) |
| survival | zero | rehang | 0/1037 (0.00%) | 0/984 (0.00%) | 0/979 (0.00%) |
| survival | max | initial | 636/1000 (63.60%) | 690/1000 (69.00%) | 674/1000 (67.40%) |
| survival | max | rehang | 717/1037 (69.14%) | 646/984 (65.65%) | 677/979 (69.15%) |
| duel | default | initial | 332/685 (48.47%) | 345/654 (52.75%) | 323/661 (48.87%) |
| duel | default | rehang | 499/1007 (49.55%) | 509/1025 (49.66%) | 512/968 (52.89%) |
| duel | zero | initial | 0/685 (0.00%) | 0/654 (0.00%) | 0/661 (0.00%) |
| duel | zero | rehang | 0/1007 (0.00%) | 0/1025 (0.00%) | 0/968 (0.00%) |
| duel | max | initial | 347/685 (50.66%) | 329/654 (50.31%) | 324/661 (49.02%) |
| duel | max | rehang | 1007/1007 (100.00%) | 1025/1025 (100.00%) | 968/968 (100.00%) |

## Human playtest gate — OPEN

Please review the actual 0.24.2 source build, not the existing 0.24.1 download:
1. Can you distinguish granules, a curved strip and a block at ordinary zoom?
2. Do all three still look edible and belong to the same pixel-art style?
3. Does any type falsely read as inherently hooked or dangerous?
4. Do partially eaten food and scattered old fragments remain understandable?
5. Does new geometry still align naturally with automatic mouth intake and manual suction?
6. Is the scene readable without constant labels or overcrowding?

Actual efficiency differences, hunger-return differences, fragmentation tuning and combined Bite×Suck×satiety×suspicion balance are intentionally not delivered here. Stop before P2.3 until the user confirms this visual/type foundation. No AI fish, multi-rod, fourth type, map or Watergen changes.
