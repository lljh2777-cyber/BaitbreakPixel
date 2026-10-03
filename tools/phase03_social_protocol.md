# P3.3 observation-only social-cue diagnostics

This is new P3.3 diagnostic evidence. Existing P3.2 competition outcomes, seed lists, source fingerprints and reports remain historical and must not be overwritten or relabeled as P3.3 results.

## Privacy and causal regression gate

`tests/phase03_npc_social.gd` exercises the actual world authority:

- Player `build` and ordinary `build_for` retain their old schema and do not carry NPC social cues
- Genuine nearby feeding actions can be perceived; remote actions and private intents alone cannot
- An actual `_enter_hook` then `_attach_hook` outcome supplies only position/tick, bounded to 150 pixels and 45 ticks; bait hook truth alone does not create an event
- Mutating an NPC's private feelings, decision state, RNG and injected secret does not alter either role's public projection or the player's actual next suspicion update while visible physics remain the same
- 3 hunger levels × 5 scenes × 12 actual NPC authority decisions = 180 matched pairs. Only the food's hidden hook flag changes; detached perception and the full NPC record, including movement, feeding, target, memory and local RNG, must remain identical
- Safe-food hesitation/fleeing, hooked-food approach/feed, starving risk taking and competition must all actually occur
- A separate 600-tick, real `advance_tick` pair includes genuine autonomous food consumption, rather than only frozen-scene decisions

The factorial scenarios hold bait physics constant on purpose. Continuing a counterfactual after actual physical hook consequences diverge would incorrectly label legitimate evidence as a privacy leak. The separate full-tick quiet pair has a distant player and verifies that no actual attachment divergence occurred. Explicitly seeded `visible_outcome` context is a controlled cue fixture; the separate hook-boundary test exercises the real outcome emitter.

Run the formal registered gate with `tools/run_tests.py --suite phase03_npc_social`. Brain/unit, snapshot, both-role network and native visual regressions remain separate gates.

## Offline-only data collection

`tools/phase03_social_diagnostics.gd` has two separate datasets:

1. Natural gameplay: default six seeds 63301–63306, three NPCs, actual default survival challenge at 60 Hz, unchanged detached P2 Mixed player and AnglerBrain, bounded to 1,800 ticks/30 seconds per seed. Every 18 ticks, record each active NPC's current public motion and private behavior state as an optimistic behavior-recognition proxy. All seeds and incomplete outcomes remain included; this is not a win-rate benchmark
2. Matched counterfactuals: four seeds 63201–63204 × hunger 70/20/5 × quiet/mild motion (6 px/s)/strong motion (90 px/s)/nearby feeding/visible outcome × 12 production NPC updates. The 720 matched pairs produce 1,440 rows. Each pair gets exactly one hooked and one unhooked label. Full observations and NPC authority records must match

No hook label enters production observation, NPC decisions, render state, network payloads or snapshots. The harness joins truth only after decisions. Natural food association is current target, then a surviving remembered social-food ID, then nearest publicly perceived edible food. The nearest-food fallback is only a diagnostic association; it does not establish which food caused a reaction. Unassociable samples are counted explicitly instead of inventing a label.

The harness fingerprints all production GDScript and the harness/controller before and after execution, and rejects changed-source runs. It refuses to overwrite an existing output. Counterfactual interventions are never pooled into natural-gameplay estimates.

## Classifier and warning thresholds

`tools/phase03_analyze_social.py` trains a fixed frequency-lookup classifier using only behavior state, feeding intent and public speed in 10 px/s bins. State tags and feeding intent are private instrumentation, not client-visible labels: treating them as perfectly recognizable is deliberately optimistic. No hook truth, seed identity, bait identity, hunger or event provenance enters classifier features.

The first half of each dataset's complete seeds train the model; the second half are held out. Splitting by seed keeps consecutive frames and both sides of a matched intervention out of opposite splits. Ties and unseen feature combinations use the training majority (ties favor unhooked). Data validation rejects seed overlap, duplicate observations, missing paired labels, changed paired features and missing/unstable source fingerprints.

For each dataset, report hooked/unhooked support, state-versus-truth counts, confusion matrix, raw accuracy, balanced accuracy, held-out majority baseline and independent held-out seed support. Performance over 90% raises a review flag; over 95% raises the corresponding stronger flag. High raw accuracy also explicitly requests class-balance review. Balanced accuracy is undefined when a class is absent, rather than misleadingly reported as zero or perfect.

An estimate is support-limited unless each class has at least 20 train and 20 held-out rows and appears in at least two held-out seeds. This is a minimum visibility check, not a statistical power guarantee. Repeated frames are correlated; no frame-level confidence interval or broad generalization claim is made.

Both datasets additionally separate:

- Predictive rows with no recently witnessed actual hook result
- Witnessed-result rows where this NPC's actual observed danger tick remains within the 45-tick public visibility window plus the production 2.4-second recovery duration; all controlled `visible_outcome` rows also belong here

Each partition gets its own classifier and behavior/truth table. A correctly observed hooked-fish outcome is legitimate post-result information, so it must not be conflated with detecting unseen hooks in advance. A near-perfect classifier is a prompt to inspect leakage or overstrong cues, not automatic proof of either.

False-positive avoidance on unhooked food and false-negative approach/feed on hooked food are recorded explicitly. They are causal witnesses in balanced counterfactuals and observed association counts in natural gameplay. Starving attempts under motion evidence are counted separately. Neither errors nor class balance are imposed on natural outcomes.

## Reproduction

Use an available Godot 4.7.2 executable and writable XDG directories on Linux:

```sh
export GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64
export XDG_DATA_HOME=/tmp/baitbreak-p33-social-data
export XDG_CACHE_HOME=/tmp/baitbreak-p33-social-cache
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
"$GODOT" --headless --path . --script tools/phase03_social_diagnostics.gd -- --seeds=6 --seed=63301 --max-ticks=1800 --output=res://artifacts/p33-social-diagnostic.json
python3 tools/phase03_analyze_social.py artifacts/p33-social-diagnostic.json --output artifacts/p33-social-analysis.json
python3 -m unittest discover -s tests/runner -p test_phase03_social.py -v
```

The Python fixtures test chance-level identical behavior, a synthetic perfect state oracle, misleading 99% majority accuracy, missing classes, seed-group leakage, immutable balanced pairs and witnessed-result separation. Synthetic fixtures validate analysis only and are not gameplay evidence. The bounded natural sample cannot validate long-run population balance or P3.4 NPC hook/catch behavior; unsupported NPC hook and wrong-catch measurements remain null.

## Frozen bounded result

`docs/test-reports/PHASE03-SOCIAL-DIAGNOSTIC.json.gz` contains the complete 3,159-row JSON, compressed with gzip mtime 0. `PHASE03-SOCIAL-ANALYSIS.json` contains source hashes, raw/compressed SHA-256 digests, episode outcomes, methodology and the full analysis. Decompression reproduces the original JSON bytes; no rows were trimmed. The analyzer also accepts the published `.json.gz` path directly.

The frozen six-seed sample completed in 12.088 wall-clock seconds. Natural gameplay produced 1,719 rows: 828 hooked / 891 unhooked. The predictive held-out partition had 611 hooked / 278 unhooked rows, with 33.41% raw and 51.36% balanced classifier accuracy against a 68.73% majority baseline. No >90% or >95% classifier alert fired. Natural witnessed-result evidence had only 11 hooked rows and no unhooked rows, so its balanced accuracy is undefined and support explicitly insufficient.

The 720 matched counterfactual pairs had zero observation/authority mismatches. Their 1,440 rows were exactly balanced and contained all six behaviors: WANDER, APPROACH_FOOD, HESITATE, FLEE, COMPETE and FEED. Both predictive and witnessed-result partitions were at 50% raw/balanced classifier accuracy. There were 340 safe-food avoidance rows, 352 hooked-food approach/competition/feed rows and 8 starving risk-taking rows under strong motion. These are repeated controlled-scene observations, not 700 independent fish or gameplay attempts.

One natural seed ended at tick 1,301 with a net loss; the other five reached the 1,800-tick horizon unfinished. This small experiment has no claimed human win-rate or long-run balance result. The registered integration suite passed 25 assertions; Python analysis/provenance passed 12 synthetic tests.
