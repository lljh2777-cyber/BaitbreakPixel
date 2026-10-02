# P2.3 real-tick feeding comparison

These are benchmark-only tools. They do not change production fish AI or disable
any physics, automatic mouth Bite, hook contact, hunger, opponent, or win rule.

## Policies and public information

`phase02_feeding_policy.gd` accepts only the detached, hint-only FishObservation.
It has no world reference, private bait records, hook labels, hook state, QTE state,
net state, replenishment queue, or hidden type data. Static public map/rule constants
supply the HOME location, goal, swim speed, suction range and default suction power.

- **SuckOnly**: aim from a 31 px mouth-to-food-center standoff and command suction
- **BiteOnly**: close to a 6 px mouth-to-food-center standoff; never command suction
- **Mixed**: use observed shape, self caution, hunger and loose-food state to choose
  those two actions. Unknown far-away types stay unknown

All policies retain target commitment, an 8 s no-food retarget timeout, movement
control and the same public home-goal rule. Their default power is the game's
standard 0.35. They never press QTE because that information is absent from the
permitted observation. Whole-match results therefore describe these limited bots,
not a fully capable fish player or a benchmark of escape skill.

**SuckOnly is a command policy, not an exclusive intake mechanism.** An unmodified
automatic Bite still consumes food that reaches the mouth range. Its successful
events are counted from actual feedback signals and reconciled against independent
authority statistics. No strategy name hides or suppresses those events.

## Experiment

Each paired seed creates three fresh real worlds with the standard survival rules
and the same existing AnglerBrain. Every step is `advance_tick` at exactly 1/60 s.
Rounds stop at the real terminal state or the declared 22,200-tick cap (370 s).
Incomplete rounds are recorded, never counted as completed or excluded.

```sh
python3 tools/run_tests.py --suite phase02_feeding_policies
python3 tools/phase02_test_analysis.py
python3 tools/phase02_run_feeding.py --phase pilot --rounds 4 --seed 21001 \
  --output artifacts/phase02-feeding-pilot
python3 tools/phase02_run_feeding.py --phase heldout --rounds 100 --seed 31001 \
  --pilot artifacts/phase02-feeding-pilot --timeout 1500 \
  --output artifacts/phase02-feeding-heldout-100
```

Existing output directories are refused to preserve earlier evidence. The held-out
runner requires a successful pilot, disjoint seed sets, identical tick cap, and
identical controller/harness/game-script hashes. Hashes are checked before and
after each execution. The controller and harness are copied beside raw outputs.
Python's existing bounded process runner isolates Godot user/cache directories,
records engine errors and nonzero exits, and terminates a timed-out process tree.

A held-out sample may be split into disjoint unchanged-source batches. Merge only
completed batches with the same pilot, horizon and source hashes:

```sh
python3 tools/phase02_merge_feeding.py artifacts/heldout-part1 artifacts/heldout-part2 \
  --output artifacts/heldout-combined
```

`rounds.json` retains every result, per-type intake and choice transition.
`comparison.json` contains per-policy means, completed/incomplete seeds, actual
outcome reasons, per-type means and all pairwise differences with deterministic
2,000-replicate paired bootstrap intervals. A merged run also exports `rounds.csv`.
No winner criterion, performance threshold or post-outcome seed filtering exists.

## Metric meanings and limits

- Food is actual unchanged score points, not inflated by satiety scaling
- Satiety final, time mean and minimum come from the actual world
- Per-type gross satiety is the uncapped reward; effective gain is the measured
  post-decay change, apportioned by gross gain when multiple types share a tick
- Hook contacts and hook events are separate; contact need not become attachment
- `feeding_attempts` is the existing count of effective suction-state sessions;
  automatic Bite ends that state on its tick and can create many short sessions
- Suction command attempts and duration separately describe the controller input
- Suction eligible ticks/intake ticks and Bite candidate attempts/intake events use
  different denominators. Bite candidate attempts occur after hook arbitration,
  so their near-100% success rate is not a risk-adjusted action-success probability
- Contact contexts can overlap and are not evidence that one action caused a hook
- Per-type food totals are independently reconciled with authority statistics
- Automatic Bite events and Bite food are reported for every policy, including
  SuckOnly. A single event involving multiple types participates in each type's
  event count, so type-event counts need not sum to the overall event count
- Initial seeds are paired, but decisions alter subsequent encounters. Per-type
  totals describe encountered food composition, not balanced causal type effects
- Actual fish wins and home wins are separate to prevent timeout wins being
  described as successful feeding-and-return behavior

Pilot outcomes and held-out outcomes stay separate. A disappointing Mixed policy
or better SuckOnly result is valid evidence, not a reason to alter hidden truth,
remove unsuccessful seeds, expand allowed observations, or force a desired winner.

Point-estimate weak dominance is reported separately: no worse on all five core
means (food, time-mean satiety, fish wins, hook contacts, hook events) and better on
at least one. A separate, stronger diagnostic requires all marginal95% paired
intervals to be strictly favorable; failing that diagnostic does not refute a
point-estimate dominance pattern or prove equivalence. Satiety is capped at100,
so rich-food gross rewards and realized physiological benefit can differ sharply.
