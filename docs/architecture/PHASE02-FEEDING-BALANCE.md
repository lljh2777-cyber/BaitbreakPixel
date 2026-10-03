# 0.24.5 mouth tuning addendum

Default mouth radius14→12px; accepted-intake cooldown.40→.60s. Capacity4/6/8, smooth suction field, all profile multipliers, hook physics, maps and RNG unchanged. Developer cooldown range now .30–.80s.

Authority schema14/guard3 and public guard1 remain: physics code is identical and snapshots carry explicit normalized rules/countdowns, so prior guard3 snapshots keep their original14/.4 values and replay semantics. Network peers require exact build0.24.5. Only personal ConfigFile profiles migrate old defaults sequentially at feeding-defaults revision2; named presets and snapshot rules are not migrated. Unstamped18 follows18→14→12; stamped revision1 explicit18 survives. Prior14/.4 migrate independently; new revision2 saves retain later explicit old values. Old hand-entered values identical to old defaults cannot be distinguished and migrate once.

See [bounded validation and open manual gate](../test-reports/PHASE02-BITE-TUNING-VALIDATION.md). No new full-balance claim or Phase3 work.

# 0.24.4 distance tuning addendum

Automatic Bite defaults to 14 px. The original longitudinal field 1−0.4d (60% at far edge) is replaced by t²(3−2t), t=1−clamp(depth/range,0,1). Existing cone length, width, lateral factor and physical hook-contact radius are unchanged. Loose-grain velocity now includes this same field once; peel progress and whole-bait displacement target already used it. Body target remains limited by mouth distance and existing response speed; stronger field does not imply larger actual displacement after reaching the mouth.

Authority schema14 profile guard3 rejects earlier physics; public guard1 unchanged. Exact build0.24.4. Profile tables and 4/6/8 capacity/.4s cooldown unchanged. Legacy unstamped personal rules18 migrates to14; explicit other values preserved, new saves stamped. Named rule presets keep their explicit settings.

The following is the historical 0.24.3 design record:

# P2.3 Feeding Choice Balance — 0.24.3

Base: `f82f535ae3931d7e013ad7827c782cef5a7366be` on `feature/dev` (published 0.24.2). Scope is the authorized P2.3 step. Final human gate remains open; Phase 3 is not authorized.

## Concentrated tuning

| Profile | Suction efficiency | Bite efficiency | Satiety scale | Fragmentation |
|---|---:|---:|---:|---:|
| Cluster | 1.00 | 1.00 | 1.00 | 1.00 |
| Worm | 0.65 | 1.50 | 1.30 | 0.65 |
| Chunk | 0.40 | 2.00 | 1.65 | 0.35 |

`FoodProfile` is the only definition. Cluster retains legacy physics. Suction efficiency scales whole-bait displacement, attached-grain peel progress, and loose-grain speed. Fragmentation scales the existing detachment token supply, not grain creation, point value, or a new random fragmentation event. Baits keep their 44 original grains and total score budget. No extra random numbers are consumed.

Automatic mouth Bite remains enabled, 18 px, base capacity 4 and successful-intake cooldown 0.40 seconds. Each nearest candidate costs `1 / bite_efficiency` of the same capacity: homogeneous Cluster/Worm/Chunk can take 4/6/8 whole grains. Candidate order remains distance, stable bait ID, stable grain order. Mixed older loose grains use their own `visual_kind`, not the replacement bait's type. The first unaffordable grain ends the attempt; no skipping, fractional grains, rounding-up rewards or saved budget between bites. An empty or unaffordable attempt produces no cooldown/feedback. Score, stamina recovery and identity de-duplication stay per-grain; only satiety gain multiplies by profile scale, capped at 100. Hunger disabled still suppresses satiety awards.

Bite never moves the fish and has no hook probability roll. The existing swept mouth/tip check still resolves before automatic Bite. Suction and Bite cannot award the same tick twice. During Bite cooldown, suction can still ingest arriving grains. Players choose position, power and whether to hold suction, not a Bite button or a disable-Bite switch.

## Authority-only measurements

- `food_by_type`, `suck_intake_by_type`, `bite_intake_by_type`: sum original grain points; each type conserves suck + bite = total. These are food/score units, not grain counts
- `suck_attempts`: eligible suction simulation ticks; `suck_successes`: distinct ticks with suction intake. Legacy `feeding_attempts` counts actual feeding transitions, including interruption by automatic Bite; do not compare its raw count to Bite events as equivalent user inputs
- `bite_attempts`: cooldown-ready automatic attempts with candidates; `bite_successes`: those that consumed at least one whole grain. Normally equal under supported rules; empty water is not an attempted button press
- `suck_hook_contacts`: physical entry while suction is active. `bite_hook_contacts`: physical entry while automatic Bite is cooldown-ready with mouth-range food. They may overlap, do not sum them, and they are contact contexts rather than proof which action caused attachment
- Existing `hook_contacts` and `hook_events` distinguish entry from actual attachment. Contact interrupted by hook entry may never become a Bite attempt; no hidden attempt is fabricated

Statistics are saved for deterministic authority replay and validated recursively, including type keys, finite nonnegative totals, conservation, event count bounds and no future suction-accounting tick. The fish network projection retains its existing exact stat allowlist and contains none of the new metrics or tuning. Public-stat validation is deliberately separate from full authority-stat validation.

## Compatibility and contracts

- Authority schema stays 14. Mandatory `bait_profile_version=2` rejects old neutral-physics snapshots rather than promising replay under altered mechanics. Profile definition version is also 2
- Fish visual/presentation guard stays 1 because visible shape/hint wire fields are unchanged. Both peers require exact network build 0.24.3
- No type-specific risk rules, hidden-truth lookups in policies, new hook rolls or simulation RNG draws
- Map ID/geometry, Watergen, Visual RNG, suspicion model, all three suction powers, food types and game AI remain unchanged

## Benchmark is not a new game AI

`tools/phase02_feeding_policy.gd` accepts detached `FishObservation` plus public rules only. It does not receive World, hook assignments or private QTE state. `SuckOnly` means standoff suction preference; automatic Bite remains possible as food arrives. `BiteOnly` means approach food without issuing suction. `Mixed` chooses from visible shape, hunger and caution. These names never imply a player can switch automatic Bite off.

All policies share observation-only targeting, movement damping, a stalled-target retry, and the existing food goal/HOME return. No QTE or hidden-state rescue is used. This restriction makes the benchmark a feeding-policy diagnostic, not a prediction of skilled-player win rates. The simulation nevertheless advances real 60 Hz ticks to terminal results or an explicit 370-second cap. Hook contact, attachments and terminal outcomes are not replaced by probabilistic surrogates. The harness records authority data only after commands are chosen.

Pilot and held-out paired seeds are disjoint. Source fingerprints and horizon must match before held-out runs; negative, failed and censored rounds are retained. The test does not prescribe Mixed as the winner. See the validation report for exact runs, limitations and the final manual checklist.
