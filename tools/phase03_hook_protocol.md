# P3.4 wrong-hook-target diagnostic protocol

This is new P3.4 evidence. Historical P3.2 competition and P3.3 social-cue records remain historical, and their original results must not be overwritten or relabeled. The old three-arm and social diagnostic harnesses now explicitly disable NPC hooks so that rerunning those controls does not silently change their meaning.

## Four paired arms

Each selected seed runs all four arms in this fixed order:

- `NoNPC`: no NPCs, NPC hooks disabled
- `PassiveNPC`: three ambient NPCs, foraging disabled, NPC hooks disabled
- `ForagingNPC`: three NPCs, foraging and social reactions enabled, NPC hooks disabled
- `HookableNPC`: three NPCs, foraging, social reactions and actual NPC hooks enabled

All arms use unmodified default survival challenge rules, the same accepted P3.2 detached-observation `Mixed` player policy and the existing survival `AnglerBrain`. The player has no QTE escape adapter and cannot read hook truth. NPC authority may resolve actual physical contact; no offline metric or truth label enters any decision. Hook support is the only configuration difference between `ForagingNPC` and `HookableNPC`. This experiment does not retune food budgets, goals, appetite, speed, hunger, suspicion or controller settings.

## Sampling and reproducibility

Formal pilot: seeds 64301–64304, four arms per seed. Formal heldout: seeds 64401–64425, four arms per seed. Horizon: 22,200 real 60 Hz ticks (370 simulated seconds), stopping early only at an actual terminal player-versus-angler outcome. Retain every seed, every arm, defeats and unfinished outcomes. The heldout sample is disjoint from the pilot and must use exactly the same source fingerprints and horizon. This is a bounded diagnostic sample, not human balance validation.

```sh
python3 tools/phase03_run_hook_diagnostics.py --phase pilot --rounds 4 --seed 64301 --max-ticks 22200 --output artifacts/p34-hook-pilot-final
python3 tools/phase03_run_hook_diagnostics.py --phase heldout --rounds 25 --seed 64401 --max-ticks 22200 --pilot artifacts/p34-hook-pilot-final --output artifacts/p34-hook-heldout-final
```

Use a new output directory for every attempt. The launcher refuses to overwrite existing evidence, checks all production GDScript plus controller, harness, launcher and protocol hashes before/after execution, and rejects a changed-source run. Heldout admission rejects source changes, unsuccessful/unstable pilots, overlapping seeds and horizon mismatches. It does not silently reuse or pool the earlier development pilot. `rounds.json`, `comparison.json`, `summary.json`, `provenance.json` and the complete `run.log` are human-readable, uncompressed outputs; harness/controller/launcher/protocol copies accompany the run.

## Required metrics and interpretation

- `player_food`, `npc_food`: actual score/intake, reconciled against Cluster/Worm/Chunk totals
- `fish_win_fraction`: actual fish victories divided by all selected rounds, with incomplete seeds listed separately; unfinished rounds are not called completed losses
- `hook_events` / `hook_contacts`: original player-only attachment/contact counters
- `npc_hook_count`: actual NPC attachments, independently checked against observed target transitions
- `npc_escapes`, `npc_breaks`, `wrong_catches`: distinct NPC resolutions; wrong catches mean completed NPC lift/capture, never an NPC faction win
- `npc_hooked_seconds`: actual time the single line was occupied by NPC hook/landing handling
- `duration`: measured simulated elapsed time, checked against actual tick count
- `lifecycle_events` / rate per simulated minute: new bait identities after the initial population
- `no_food_seconds`, longest empty interval and longest player no-intake interval: descriptive resource-pressure/stall signals, not proofs of permanent supply deadlock
- `replacement_ids_allocated`: spent post-initial NPC IDs, not a claim that every allocation succeeded

The analyzer rejects negative/nonfinite/missing measured values, fractional event counts, mismatched type totals, inconsistent outcomes, unresolved NPC lifecycles, control-arm NPC hooks and passive food consumption. `NoNPC` and `PassiveNPC` exact non-NPC outcomes, stats, player intake, hook and bait-lifecycle equality are reported without filtering any mismatched seed. Six same-seed pairwise contrasts cover every arm pairing; the key P3.4 contrast is `HookableNPC minus ForagingNPC`.

Descriptive intervals use a fixed-seed paired bootstrap over complete seed-level differences (2,000 resamples). They describe sampling variation in this fixed controller/seed population, not causal generalization to human players. A no-hook sample is explicitly reported as lacking natural event coverage, rather than implying that wrong catches were tested or the true event rate is zero. There is no 50% win-rate target and no balance retuning based on this diagnostic.

## Separate gates

`tests/phase03_npc_hook_target.gd` supplies controlled physical witnesses for true and swept mouth contact, stable-ID targeting, player/NPC discrimination, correct line endpoint, free player movement/intake/HOME, ordinary W/S actuator use, automatic NPC struggle, no player-QTE RNG consumption, slack escape, line break, actual shore hold/lift/capture, delayed new-ID replacement, immunity, pause/terminal freezes and pre-contact privacy.

Snapshot replay, exact validation, real two-role ENet and native pixels are separate registered gates. The 1,000-seed × four-condition food-reachability gate remains separate from autonomous win-rate measurement. This diagnostic does not replace those tests, the user's P3.4 manual playtest, or the locked P3.5 ecology-balancing stage.
