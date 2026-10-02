# P2.3 feeding-policy evidence

## Result

100 unchanged-source, paired held-out seeds (31001–31100) produced 300 completed real 60 Hz rounds. The prior pilot used disjoint seeds21001–21004 (12 rounds). No outcomes were discarded; no policy or physics tuning occurred between pilot and held-out.

**This benchmark exposes a balance concern, not a balance pass.** SuckOnly point-estimate weakly dominates both other policies across food, time-mean satiety, fish wins, hook contacts and hook events. Mixed also point-estimate dominates BiteOnly. SuckOnly and Mixed have favorable marginal95% paired intervals against BiteOnly on all five dimensions. SuckOnly versus Mixed remains uncertain in win rate and time-mean satiety, while food and hook metrics favor SuckOnly.

| Metric, mean per round | SuckOnly | BiteOnly | Mixed |
|---|---:|---:|---:|
| Fish/home win rate | 0.600 | 0.170 | 0.590 |
| Food score | 57.585 | 43.554 | 56.075 |
| Time-mean satiety | 90.118 | 87.085 | 89.872 |
| Final satiety | 73.548 | 64.925 | 71.935 |
| Minimum satiety | 68.302 | 62.470 | 67.485 |
| Hook contacts | 0.110 | 0.800 | 0.150 |
| Hook events | 0.100 | 0.760 | 0.150 |
| World suction-state sessions | 29.970 | 0.000 | 23.490 |
| Suction command sessions | 2.270 | 0.000 | 1.840 |
| Automatic Bite events | 29.670 | 13.150 | 25.760 |
| Bite events during suction command | 29.460 | 0.000 | 23.090 |
| Effective suction seconds | 24.274 | 0.000 | 19.169 |
| Round duration, seconds | 45.746 | 28.790 | 41.665 |

All wins were actual home wins; no timeout wins or incomplete rows occurred. Shorter BiteOnly rounds commonly ended in loss and are not evidence of better feeding.

## Paired uncertainty

Difference direction is Mixed minus SuckOnly. Deterministic percentile paired bootstrap uses2,000 resamples; these are marginal exploratory intervals, not simultaneous confidence or proof of general human-play superiority.

| Metric | Mean difference | 95% interval |
|---|---:|---:|
| food_consumed | -1.51050 | [-2.89350, -0.23850] |
| satiety_mean | -0.24684 | [-0.74424, 0.20018] |
| fish_win_rate | -0.01000 | [-0.07000, 0.05000] |
| hook_contacts | 0.04000 | [0.01000, 0.08000] |
| hook_events | 0.05000 | [0.01000, 0.10000] |

Equal risk is allowed by point-estimate weak dominance (no worse in all five dimensions; strictly better in at least one). The stronger all-intervals-favorable diagnostic is reported separately. Failure of that diagnostic cannot be used to claim no dominance or equivalence.

## Actual intake mechanisms and saturation

SuckOnly is a standoff suction-command policy with the normal automatic mouth Bite retained. It is not a pure-Suck ingestion ablation. The approach-only BiteOnly never sends suction; Mixed chooses from public shape/caution/satiety cues.

| Per-round quantity | SuckOnly | BiteOnly | Mixed |
|---|---:|---:|
| Food awarded through automatic Bite | 46.794 | 43.554 | 46.394 |
| Food awarded through Suck | 10.791 | 0.000 | 9.681 |
| Gross satiety before cap | 148.692 | 115.641 | 145.574 |
| Effective measured satiety gain | 85.396 | 35.316 | 73.806 |

The100-point satiety ceiling discards much of the rich-food gross reward. Effective gain is the measured post-decay reward, apportioned by gross reward if several food types share a tick. Gross nutrition cannot be substituted for realized survival benefit.

Existing feeding_attempts counts effective suction-state sessions; automatic Bite ends that state on its tick and fragments a continuing suction command into many sessions. New suction attempts count eligible ticks; Bite attempts count candidate intake after contact arbitration. Their raw attempt/success rates have different units and are not comparable risk-adjusted action-success probabilities. Contact-context counters can overlap and do not establish causation.

## Food-type composition

| Actual food points per round | SuckOnly | BiteOnly | Mixed |
|---|---:|---:|
| cluster | 20.1495 | 12.1665 | 18.4935 |
| worm | 21.6345 | 17.5290 | 22.0440 |
| chunk | 15.8010 | 13.8585 | 15.5370 |

Type totals reconcile with independent world food/Suck/Bite statistics. Initial seeds are paired but subsequent actions change encounters; these composition totals are not a balanced causal comparison of types or hook assignment.

## Controller limitations

Only detached FishObservation is supplied to the controller. No hidden bait type/hook truth, hook state, QTE/net state or legacy escape AI is used. All fish QTE commands are false because QTE information is absent from that contract. Whole-round wins therefore measure these limited bots, not complete player capability or human fun. Public map/goal constants are shared. Physical profiles, opponent and automatic Bite remain unchanged across policies.

## Files and reproduction

- `pilot/`: all12 pilot rows and original summary/provenance; separate analysis
- `heldout-initial-12/`: first36 held-out rows
- `heldout-extension-88/`: remaining264 held-out rows
- `heldout-100/`: all300 rows, CSV, merged provenance and paired comparison

Every directory retains full rounds, summary, source fingerprints and comparison. Original runtime artifacts remain under `artifacts/phase02-feeding-*`. The original absolute provenance paths describe the execution workspace; repository-relative evidence is listed here for portability.

Reproduction instructions and exact metric definitions: [feeding protocol](../../../../tools/phase02_feeding_protocol.md). Analysis: [comparison](../../../../tools/phase02_compare_feeding.py), [merge](../../../../tools/phase02_merge_feeding.py).

Validation: registered `phase02_feeding_policies` suite29/29; Python analysis tests11/11, including negative results/incomplete retention, no hidden auto-Bite suppression, pairing, timestep and independent measurement reconciliation. Pilot/heldout overlap is refused. All game/controller/harness hashes matched before and after every run.
