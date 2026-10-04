# P3.5 ecology balance protocol (predeclared)

Baseline: `dfdd9af72e3700c4b82fcf32419ff998231d7ef9`, whose production gameplay is identical to 0.25.4 `ae23fea`. Preserve its Windows-release documentation. This phase evaluates the complete ecology; it does not assume a retune is necessary, seek a 50% win rate, or accept human feel automatically. NPC net capture remains deferred. No multi-rod, new map or Watergen merge.

## Frozen matrix and samples

- Four paired arms: NoNPC (0); PassiveNPC (3, no feeding/hooks); ForagingNPC (3, feeding/social, no NPC hooks); HookableNPC (3, full ecology)
- Each seed crosses survival/duel × challenge/practice × the unchanged P2 SuckOnly/BiteOnly/Mixed policies: 12 strata, 48 rows per seed
- Pilot: fresh seeds 73501–73504 (192 rounds); final heldout: fresh seeds 73601–73625 (1,200 rounds). Seed is the paired/cluster resampling unit across all strata. Old 64401–64425 data is historical regression, never fresh evidence
- All runs use real 60 Hz authority up to 22,200 ticks (370 s), stop only at an actual terminal result, keep defeats and incomplete rounds. A practice horizon is censoring, not a loss
- Do not tune on heldout. If a runtime correction is necessary after inspection, disclose it, re-freeze/re-pilot and allocate new untouched heldout seeds. Exploratory/failed runs remain preserved
- Inspect all twelve strata rather than pooling distinct game objectives. In survival challenge timeout awards angler; in duel challenge timeout awards fish. Report reasons, home wins, goal reach and censoring alongside fish wins

## Actors and explicit adapters

Player input is solely detached FishObservation. The three existing P2 policies are unchanged and have no QTE/escape adapter. The controller receives a copied public rules dictionary with food_goal equal to the current public objective (60 challenge /18 practice); world.rules and world.food_target remain unchanged. This is necessary because the original benchmark assumed challenge only. Its one-shot home request can be blocked by a hook and is not retried; stalled/unfinished rounds are diagnostics of this imperfect policy, not proof of human impossibility or supply deadlock.

Survival uses the existing AnglerBrain unchanged. Duel adds a fixed, time-only `deploy=true` command at tick 0 and every 120 ticks, through the ordinary command and cast authority. This enables normal casts/rehangs after captures without teleporting fish/tackle, reading hook truth, modifying food, skipping cooldowns or selecting a private target. Existing auto-reel/auto-net/patrol/QTE behavior is retained, so this is a specified synthetic opponent, not a model of human skill or fairness.

Practice NoNPC/Passive retain the original no-refill behavior; practice Foraging/Hookable activate existing ecology refill. Thus that contrast combines true competition and the already-approved supply response, not a pure food-removal intervention.

## Measurements and boundaries

Every row preserves the P3.4 raw metrics: actual player/NPC intake by food type, original player hook contacts/attachments, distinct NPC hook/capture/escape/break events, line-occupied seconds, successful terminal reason, real tick duration, new bait identities/rate, no-food and player no-intake intervals. No NPC winner is possible.

New metrics use pre-tick exposure: summed active-NPC seconds, NPC satiety integral/minimum and critical/starving exposure, time in each active behavior, player satiety mean/minimum/final, player critical exposure, and NPC-occupied ticks. Social reaction entries are post-tick state transitions. Record production feeding/contest/switch counters. NPC satiety still evolves when player hunger assistance is off, per current design.

Successful respawns count actual previously unseen IDs in the ecology, not allocator growth. Record captured slots still awaiting replacement. Successful + pending replacements must reconcile captures. Goal-reach tick and actual home-command attempts expose objective/controller stalls.

Player intake while an NPC occupies the line counts score gained on ticks whose pre-tick target is NPC. It is an observed opportunity metric, not proof that the NPC caused that intake. Likewise occupied time is an attention-pressure proxy, not a measured human attention score.

All no-food exposure and longest-empty intervals use pre-tick food, aligning the eligibility partition; legacy RoundStats player satiety remains post-tick and is not equated to the new pre-tick mean.

Supply-eligible seconds mirror only the top-level existing `_step_supply` gate, including player-hook/net and practice guards; a bound slot may still wait. Eligible no-food exposure is separate from hooked/busy gaps. Structural food-goal reachability remains the 1,000 distinct seeds ×4 conditions production refill witness, not this bot experiment.

## Analysis

Retain all 48 rows per seed. Reject malformed/missing/duplicate rows, nonfinite/negative/impossible measurements, non-60 Hz durations, unfinished below the horizon, changed authority rules/goals, impossible hook/respawn accounting, and control hooks/food intake. Report passive-control mismatches without removing seeds. Ratios with zero exposure are null with support, never disguised as zero.

Provide all six paired arm contrasts and 2,000-replicate deterministic seed bootstrap marginal 95% intervals per stratum. An equal-weight-strata descriptive aggregate resamples whole seed clusters; it never treats 1,200 correlated rows as independent samples. Primary interpretations are Foraging minus Passive and Hookable minus Foraging. No p-value hunt, multiplicity-adjusted claim, desired winner percentage or automated balance pass/fail. With only 25 independent seeds intervals can be broad and rare-event zeros are coverage gaps.

## Reproduction and separate gates

```
python3 tools/phase03_run_ecology.py --phase pilot --seed 73501 --rounds 4 --output artifacts/p35-ecology-pilot
python3 tools/phase03_run_ecology.py --phase heldout --seed 73601 --rounds 25 --pilot artifacts/p35-ecology-pilot --output artifacts/p35-ecology-heldout
```

Set GODOT to the verified engine. The launcher protects existing outputs, isolates profiles, fingerprints runtime and harness before/after, and requires the successful pilot's source/horizon for heldout. It retains readable rows, summaries, raw run log and source provenance. Failed or changing-source work is not formal evidence.

Separate final gates: current headless Phase1/2/3; registered native pixel/UI suite; Python runner/analysis integrity; 4,000 structural supply cases; normal 2/3/4-density integrated lifecycle checks; snapshot/hidden-truth/network privacy; actual same-machine ENet for both roles; real native screen review. Preserve Bite10px/0.80s, original QTE risk and 1.8 NPC-only retrieval gain. STOP at final Phase3 user playtest; NPC net and Phase4 remain locked.
