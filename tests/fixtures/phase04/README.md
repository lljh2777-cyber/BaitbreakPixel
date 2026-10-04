# P4.0 immutable behavior baseline

`baseline_9d11fe8.json` identifies the exact tracked 0.25.5 source tree and hashes
its runtime files. It is an independent pre-change source lock, not a fixture
regenerated from the new map definitions.

- Commit: `9d11fe8ae4bb7a49abe5fcd0e6f518ed0ebd3a92`
- Tree: `377f935c054e6204d0b84075ef7b69cb72b5d6e1`
- Earlier tested ancestor: `7fc99f6`; the comparison uses the newer commit above
- Archive source: `git archive`, so working changes/untracked files never enter
- Authority schema remains 15, map identity `pond_v2`, FoodProfile guard 3

## Reproduce

```sh
python3 tools/phase04_compare_baseline.py \
  --godot /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --require-engine 4.7.2 \
  --output artifacts/p40-comparison-new
python3 tools/run_tests.py --godot /absolute/path/to/godot --suite phase04_map_baseline
python3 -m unittest discover -s tests/runner -p test_phase04_baseline.py -v
```

The comparison driver creates or verifies
`artifacts/p40-frozen-baseline-9d11fe8/`, verifies commit/tree/archive/content
hashes, and launches one frozen external harness against each project with the
same executable. Engine path, executable SHA-256, reported version, all command
lines, source stability, and bounded process results are retained. Existing
output directories are refused. `--freeze-only` creates/verifies the archive
without running it. A development engine is explicitly labelled; it does not
satisfy the official 4.7.2 gate.

Runtime checks compare all previously committed scripts, shaders, assets,
scenes and project configuration byte-for-byte. Only the four exact release
metadata substitutions in the driver are accepted. In `network_protocol.gd`,
only the exact BUILD string can change. New runtime files may only be GDScript
sources/UIDs under `scripts/maps/`; existing sources cannot begin referencing
them without failing this P4.1 foundation-only gate.

## What the simulation comparison establishes

Eight bounded deterministic scenarios run 2,100 input ticks per build, with 86
checkpoints. Every input/intervention and every tick's complete Variant-encoded
authority snapshot contributes to a SHA-256 stream. Each detailed checkpoint
also captures main RNG seed/state as exact integer strings, authority size/hash,
visual and decision FishObservation, NPC social observations/private state,
bait, Hook/QTE/wrap, net, stats, both role projections and compressed authority.
No floating-point state is compared through rounded JSON. Checks require
schema15, statistics validity, exact snapshot restoration, wire validation,
compression round-trip, midpoint pause freezing and full second-half replay.
Standalone suite mode repeats each independently reset scenario as well.

Scenarios are deliberately focused:

1. Survival movement with two ambient NPCs, seed 17401
2. Duel movement/deploy/reel/release with four NPCs, seed 17402
3. Actual player/NPC loose-grain intake and controlled bait refill, seed 17403
4. Real player mouth-hook entry, ignored warning presses and timeout attachment
5. Attached-player QTE/physical wrap using the existing white-box coil fixture
6. Real NPC mouth contact, ordinary reeling, landing, capture and delayed fresh ID
7. Ordinary staged net controls and a player capture
8. The same net lane crossing an NPC, without granting an NPC catch

Seeds, counts, challenge/ruleset settings and fixed horizons appear in each
report. Scenarios 3–8 use explicit controlled initial geometry; the wrap fixture
also sets the QTE age to its seeded green zone, and feeding refills one slot at a
fixed tick. Those interventions are identical and hashed, not represented as
unassisted or statistically sampled gameplay. Net toggle and endpoint clicks
occur on separate authority ticks, as in ordinary UI input.

This is compatibility evidence for unused map data only. It is not World
migration, a balance/win-rate experiment, screenshot equivalence, actual ENet
transport, export verification, or human-playtest approval. Existing dedicated
suites and native baseline/current pixel comparisons cover those separate gates.

## Separately retained inherited batched-net edge

`net_batch_probe.gd` is a diagnostic, not an acceptance suite. Run it externally
against each project using the same engine and `--output=/absolute/path.json`.
It records unmodified authority restore, fish wire validation/application and
angler validation for both same-tick and staged net events.

On the frozen 9d11fe8 and current builds with official 4.7.2, a single command
batch containing toggle + both endpoints opens and closes observation before
`net_action.age` integrates from integer zero to float. The fish projection's
existing strict float guard then rejects it through the 120-tick observation
window. Authority/angler restoration succeeds. The staged three-tick input is
accepted throughout. `network_session._receive_state` stops the round if a fish
client receives an invalid projected state; this direct probe does not measure
real ENet delivery or occurrence frequency. No runtime fix, guard relaxation or
existing-test change is included in the unused-data P4 gate.
