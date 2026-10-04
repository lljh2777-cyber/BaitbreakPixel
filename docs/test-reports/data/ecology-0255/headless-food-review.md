# P3.5 final structural food-supply witness

The final current gate reran all 4,000 cases: 1,000 distinct seeds 51001–52000 × survival/duel × challenge/practice. All six competitors exhaust initial food and three later supplies through shared authoritative intake; existing warning/refill/redeploy creates real new food IDs. A controlled shared-mouth Bite witness claims later real food to the unchanged objective.

| Mode | Objective | Seeds | Failures | Minimum player food | Minimum NPC food | Minimum fresh bait lifecycles | Maximum empty supply ticks |
|---|---|---:|---:|---:|---:|---:|---:|
| survival | challenge 60 | 1000 | 0 | 60 | 180 | 5 | 423 |
| survival | practice 18 | 1000 | 0 | 30 | 180 | 4 | 423 |
| duel | challenge 60 | 1000 | 0 | 60 | 150 | 5 | 423 |
| duel | practice 18 | 1000 | 0 | 30 | 150 | 4 | 423 |

423 ticks is 7.05 seconds of this isolated supply-only fixture. It is not a bound on the duration of food absence in live play. The fixture does not simulate travel, live competing AI, hunger, hook contact or escape; it controls player mouth placement and resets Bite cooldown. Practice intake of 30 overshoots the unchanged 18 goal because the witness claims whole replenished food batches. No food-goal reduction, invented food or forced match winner is used.

The headless suite reports 24 aggregate invariants plus artifact write =25 assertions. Seed/tick loops are not inflated into assertions. This witness proves structural resource reachability after adversarial depletion; it does not guarantee autonomous-policy or human victory and does not replace the paired ecology experiment or user playtest.

Every original case field is preserved in [headless-food-cases.jsonl](headless-food-cases.jsonl). [Metadata and four-condition summaries](headless-food-summary.json) retain the original source hash and publication hash. Serialization was round-tripped and compared against all 4,000 original rows.
