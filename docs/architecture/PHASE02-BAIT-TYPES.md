# P2.2 Bait Archetypes — 0.24.2

Baseline: `feature/dev @ 3f916e4609f6758e5b928f6cf343b075210ecfd4`. User permitted progression after v0.24.1 automatic mouth Bite. This is permission to implement P2.2, not a permanent closure of prior feedback or permission to start P2.3.

## Scope and neutral profiles

`FoodProfile` centralizes `id`, `visual_kind`, `shape_hint`, `smell_hint`, `suction_efficiency`, `bite_efficiency`, `satiety_scale`, and `fragmentation`. Cluster is granular, Worm a curved slender strip, Chunk a compact block. All numeric multipliers remain 1.0 and are intentionally not wired into feeding yet. §49 reserves differentiation of feeding efficiency and combined balance for P2.3. Type conveys no hook probability and no suspicion increment.

Each form retains the same 44 edible grain identities, layer counts, per-layer points and total food budget. Its actual grain offsets match the displayed silhouette, within the existing small footprint; no rendering-only phantom target or new hook/contact radius. Physical placement can affect which grains fall inside mouth range; that geometric consequence is not a tuned efficiency multiplier. Automatic mouth Bite stays 18 px / 4 grains / 0.40 s; no F key, automatic Suck, movement, or new hook roll.

## Lifecycle and RNG

Survival starts with three active food targets, one of each type, shuffled using Simulation RNG. Undeployed duel retains two ambient targets, sampled without replacement from the three types; it does not gain a third food budget. Hidden reserves/rod food draw from the same pool. Existing population hook constraints run independently before the initial type shuffle. Refills roll a type without reading hook truth, then perform the existing hook roll and population constraint repair, which never reads type.

`bait_type` is immutable for existing food. Recasting uneaten food creates the existing new hook identity but preserves its food shape/type. Full rehang creates new food and rolls a fresh type. Already loose, uneaten grains keep their own `visual_kind` and stable identity when appended to replacement food, preventing detached food from morphing into the new type.

Simulation RNG owns type selection. Deterministic profile layout consumes no simulation randomness; rendering consumes none. Existing Watergen/Visual RNG and Map Contract are unchanged.

## Information and snapshot contract

Authority `bait_type` and full profiles are private. Fish projection includes only legal `visual_kind`, `shape_hint`, `smell_hint` and visible grain kinds. Distance-limited decision hints keep far observations coarse; shape/scent details appear medium/near. Invisible reserves publish empty cues, not future food type. Mixed loose food keeps per-grain public kinds. Safe/hooked pairs with matched observable physical state produce equal observations and pixels.

Authority snapshot remains schema 14 with explicit `bait_profile_version=1`. Fish presentation also requires that profile-version guard. Missing/unknown versions, unknown enum values or unexpected nested keys are rejected before mutation. Earlier schema14 snapshots lack type information and are rejected rather than fabricating a replay history. Live network sessions additionally require exact build 0.24.2. This is a documented sub-version compatibility boundary, not a claim of backward-compatible old replay loading.

## Gate

P2.2 stops at visual/lifecycle review: recognize each type, consistent pixel style, no type looking inherently hooked, sensible loose/partially eaten food, no overcrowding. Confirm geometry and visual reading before P2.3 changes feeding efficiency, satiety values, fragmentation, statistics and combined policy balance. No AI fish, multi-rod, new maps, Watergen, economy or fourth food type.

Source-only delivery was requested. No ZIP/export/upload is produced here; published v0.24.1 packages remain historical and unchanged.
