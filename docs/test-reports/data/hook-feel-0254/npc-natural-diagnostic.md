# Four-mode natural diagnostic, 0.25.4

All 100 actual 60 Hz rounds completed naturally, with no excluded loss or horizon-limited round. The final source-stable pilot uses seeds 64301–64304 (16 rounds); the final 25×4 sample deliberately repeats historical seeds 64401–64425 for paired source regression. It is not a new independent statistical holdout even though the existing launcher's phase label is `heldout`. Horizon remains 22,200 ticks / 370 s; unchanged P2 Mixed player, AnglerBrain and default survival challenge rules are used throughout.

## Natural outcomes

| Mode | Previous → current fish wins | Current mean food | Current mean duration | Current NPC hooks / completed catches |
|---|---:|---:|---:|---:|
| NoNPC |10/25 → 10/25|51.198|71.541 s|0 / 0|
| PassiveNPC |10/25 → 10/25|51.198|71.541 s|0 / 0|
| ForagingNPC |7/25 → 7/25|46.344|64.001 s|0 / 0|
| HookableNPC |12/25 → 7/25|50.412|64.614 s|29 / 28|

The faster NPC retrieval has a measurable cost in this controller/seed sample: Hookable fish wins decline from 48% to 28%, while player hook events increase from 3 to 8. This unfavorable result is retained. The sample does not establish human win rates, causality for every source change, or final balance acceptance, and it is not used to tune toward a 50% target.

NPC occupied-line time averages 9.467 → 5.665 s per round, approximately 40% shorter; the maximum drops 31.933 → 16.417 s. NPC hooks change 32 → 29, completed wrong catches 25 → 28. Both versions have actual NPC hooks in 19/25 rounds; completed captures occur in 14/25 → 18/25 rounds. Old accounting is 25 captures + 1 escape + 0 breaks + 6 still hooked when the player match ended = 32 hooks. Current accounting is 28 captures + 0 escapes + 0 breaks + 1 still hooked at player terminal = 29 hooks. The remaining current hook is seed 64424. These are not incomplete player rounds. Zero natural escapes/breaks are not path-coverage claims; controlled tests separately demonstrate both outcomes.

Current NoNPC and PassiveNPC controls are exact matches for every seed. Across historical versus current sources, their food, duration, player hooks, outcomes and other reported means remain identical. Their seed 64412 raw `stats.fish_total` changes from 5 to 4; all other row fields match. ForagingNPC historical/current rows match in full. Do not describe every historical control row as byte-identical.

## Adverse results and limitations

- Current Hookable retains all 18 losses. Minimum player food is 18.0; the full per-seed loss list is in `natural-source-comparison.json`
- Longest all-food-empty interval increases from 4.450 to 21.917 s (seed 64418). That round has 62.55 player food and ends with an angler landing win. An instrumented replay confirms all 1,315 empty-food ticks occur while the player already owns the hook (`npc-empty-food-64418.txt`); the normal supply routine is paused during player Hook handling. This is not evidence of permanent supply deadlock
- Longest player no-intake interval is 25.783 s, also seed 64418, versus previous maximum 31.2 s
- Maximum current NPC occupancy is 16.417 s in seed 64405, containing three separate actual captures
- Existing structural food-reachability tests and user manual checks remain separate. This diagnostic does not authorize broader Phase 3.5 balance changes

## Evidence and reproduction

`natural-diagnostic-rounds.json` retains all 100 full raw records; `natural-diagnostic-comparison.json` contains all six paired policy contrasts and fixed-seed bootstrap intervals. `natural-source-comparison.json` retains the historical/current per-mode counts, all raw-row mismatch seeds, and lifecycle closure. `natural-pilot-*` retains the separate 16-round pilot. Provenance files record matching source hashes before/after each accepted run; `natural-source-verification.json` verifies current-source identity and independently recomputes the saved comparison.

The first heldout attempt was interrupted after a network input fix changed its source fingerprints. Its local artifacts were retained but no rows entered the accepted final sample. Historical 0.25.3 evidence remains unchanged.

Reproduce on the final source with fresh output directories:

```sh
python3 tools/phase03_run_hook_diagnostics.py --godot "$GODOT" --phase pilot --rounds 4 --seed 64301 --max-ticks 22200 --output artifacts/hook-fix-pilot
python3 tools/phase03_run_hook_diagnostics.py --godot "$GODOT" --phase heldout --rounds 25 --seed 64401 --max-ticks 22200 --pilot artifacts/hook-fix-pilot --output artifacts/hook-fix-heldout
```

The launcher rejects changed-source pilots, overlapping seed sets, horizon mismatches, invalid measured values, missing outcomes and inconsistent lifecycle counts. It does not overwrite existing evidence.
