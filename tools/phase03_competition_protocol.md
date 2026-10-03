# P3.2 resource and competition verification

These are two different kinds of evidence. Do not describe the resource witness as an autonomous win guarantee.

## Structural supply witness

`tests/phase03_food_reachability.gd` runs seeds 51001–52000 in each of survival/duel × challenge/practice, six NPCs, default food goals and refill timing. Each case:

1. Assigns every currently visible edible grain to NPCs via production `_consume_grain`, recording genuine grain disappearance and NPC-only intake
2. Advances the existing `_step_supply` lifecycle at 60 Hz until active real food with a new bait identity appears
3. Repeats total NPC depletion for three additional supply cycles
4. Uses production automatic Bite, with controlled player mouth placement and an explicitly reset cooldown between claims, to collect subsequent actual food until the unchanged target is met

No grain or food batch is added by the test. No goal, bait points, hook truth or timing constant is changed. The test records all 4,000 case rows, including failures, and reports 24 aggregate checks rather than multiplying assertion counts by every tick.

The witness deliberately isolates supply: travel, active rival decisions, hook contact, hunger and escape are not advanced; mouth-claim cooldown is reset to isolate the resource witness. It proves that the finite initial pool cannot create permanent resource exhaustion under the supported refill conditions, with an explicit subsequent resource-allocation witness. It does not prove every real-time policy can beat competitors or win. Paused/finished/hooked-world lifecycle gates retain their own semantics.

## Autonomous paired comparison

`phase03_simulate_competition.gd` runs actual `advance_tick` at 60 Hz for:

- NoNPC: zero NPCs
- PassiveNPC: three NPCs with foraging disabled
- ForagingNPC: three NPCs with foraging enabled

The player is the existing P2 `Mixed` policy, receiving only detached `FishObservation`; the opponent is the unchanged survival `AnglerBrain`. Default survival challenge rules, a 60-point goal and a 370-second maximum observation horizon are shared across modes. The player has no private-state QTE adapter. Keep all outcomes and unfinished rounds. Report observed win fraction and censoring separately, without imposing a desired win rate.

Collected values include player food, NPC food/by-type/events, contest events, target switches, hook events, actual wins/reasons/durations, and new bait identities per simulation minute. NPC hook count and wrong catches are explicitly null because those features are deferred to P3.4. A zero would incorrectly look like a measurement.

### Reproduction

Set `GODOT` to the available Godot executable, then run:

```sh
python3 tools/phase03_run_competition.py --phase pilot --rounds 4 --seed 43001 --output artifacts/p32-pilot-final
python3 tools/phase03_run_competition.py --phase heldout --rounds 25 --seed 44001 --pilot artifacts/p32-pilot-final --output artifacts/p32-heldout-0
python3 tools/phase03_run_competition.py --phase heldout --rounds 25 --seed 44026 --pilot artifacts/p32-pilot-final --output artifacts/p32-heldout-1
python3 tools/phase03_run_competition.py --phase heldout --rounds 25 --seed 44051 --pilot artifacts/p32-pilot-final --output artifacts/p32-heldout-2
python3 tools/phase03_run_competition.py --phase heldout --rounds 25 --seed 44076 --pilot artifacts/p32-pilot-final --output artifacts/p32-heldout-3
python3 tools/phase03_merge_competition.py artifacts/p32-heldout-0 artifacts/p32-heldout-1 artifacts/p32-heldout-2 artifacts/p32-heldout-3 --output artifacts/p32-heldout-100
```

The four held-out commands may run concurrently. The wrapper rejects source changes between pilot and held-out, source changes during each run, mismatched horizons, overlapping seeds and accidental result replacement. Merge additionally requires complete, disjoint shards with identical source hashes, phase, pilot and horizon. All production GDScript and the controller/harness are fingerprinted. Exploratory or source-unstable runs remain preserved as diagnostics; they are not formal paired evidence.

Comparisons use paired mean differences and deterministic seed bootstrap marginal 95% intervals (2,000 replicates). They characterize the tested seed distribution and this specific unskilled bot, not human skill or a universal balance guarantee. Small pilot results are not pooled with held-out results.

## Shared-field regression boundary

Integration checks cover actual player/NPC 4/6/8 whole-grain automatic Bite, mixed old loose-grain budgets, 10 px mouth range, 0.8 s cooldown, sole ownership/nutrition, exact typed peeling/transport, hidden-hook equivalence during real feeding, passive main-RNG isolation, and deterministic snapshot continuation.

During review, the shared release-budget path was corrected to credit a consumer only when eligible food actually intersects that consumer's suction field. Previously a distant feeding actor could increase another actor's release budget. This is a small shared-field behavior correction for both NPC and player suction; geometric forces, rates and Bite capacities were not retuned. Three remote-feeder controls require identical local results with or without a distant NPC/player.

`phase03_diagnose_supply.gd` provides optional read-only instrumentation for foodless intervals under the same frozen real-tick policy. The longest held-out interval is seed 44072's 22.15 seconds: all 1,329 ticks are HOOKED with zero supply-eligible ticks; the fish already collected 67.95 points and then lost by landing. Seed 44009's 22-second interval independently has the same eligibility explanation after collecting 60 points. Do not apply the structural 7.05-second renewal bound while the existing hook/net lifecycle gate is closed.

## Analysis and provenance tests

`python3 -m unittest discover -s tests/runner -p test_phase03_competition.py -v` runs 20 synthetic-fixture tests. They reject duplicate/missing mode-seed pairs, per-type total and goal mismatches, non-60-Hz duration, unsupported metrics disguised as zero, overlapping held-out/pilot seeds, source changes, unstable or unsuccessful shards, incompatible horizons and incomplete merges. A changed passive control is retained and surfaced rather than discarded. Synthetic fixtures are explicitly not gameplay evidence; temporary fixture files are preserved rather than bulk-deleted.
