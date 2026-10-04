# Independent P3.5 ecology/state/privacy review

Date: 2026-10-04 UTC. Working branch feature/dev. Gameplay baseline ae23fea; docs-only remote dfdd9af was preserved. Only the primary owner updated version/display labels to 0.25.5. This review made no production, map, Phase4, NPC-net, registry, commit or push changes.

## Result

No confirmed production ecology bug or justified retune was found. Keep the existing defaults: three NPCs, initial satiety 70, shared Bite 10 px /0.8 s, and the 0.25.4 NPC-only retrieval gain of 1.8. Normal 2/3/4 densities are test coverage, not an added player-facing setting. No claim of human balance or final playtest approval.

## Frozen final gates

Final registered current source gates: **61 headless suites + editor import passed; 245,119 assertions, zero failures/timeouts**. All 298 recorded inputs were byte-stable before/after. See [per-suite summary](headless-summary.json), [run provenance](headless-provenance.json), [readable gate review](headless-review.md) and [raw-log hashes](headless-log-manifest.json). Full Python discover separately passed **202/202**, with all 25 recorded Python tool/test/registry inputs stable; see [output](python-runner.txt) and [provenance](python-provenance.json).

## Earlier focused guarantees rerun

Nine existing focused suites passed, 7441 assertions, zero failures/timeouts. Commands, durations and counts are in existing-gates/summary.json. Coverage includes:

- phase03_npc_snapshot: 5,463 assertions; exact authoritative replay plus malformed-state atomic rejection
- phase03_npc_network: 497 assertions; both strict role projections, hidden-state contamination, actual same-machine ENet peer connect/reconnect/target/food behavior
- phase03_npc_social and social_brain: 25 + 963 assertions; legal public cues, hidden-truth counterfactuals, bounded reactions/recovery
- phase03_npc_foraging: 80 assertions; shared typed physical intake/cooldown, ownership, local random source isolation
- phase03_food_reachability: 25 aggregate assertions over all 4,000 retained scenarios. Complete source-produced artifact copied to food-reachability-4000.json before any later rerun can replace it. This is controlled structural supply/goal reachability, not autonomous or human guaranteed victory
- phase03_npc_hook_target and hook_pacing: 69 +243 assertions; player independence, genuine contact, normal retrieval/outcomes/replacement, and preserved player QTE/random state
- player_hook_network: 76 assertions; actual ENet plus same-batch validated input behavior

These diagnostic reruns preceded the frozen final full headless gate above; use the final source-stable run as the release-gate evidence. Actual ENet here means separate UDP peers on this machine, not cross-device or public-NAT testing.

## New integration gate

Owned deliverables: tests/phase03_ecology_balance.gd and its Godot-generated UID. Marker PHASE03_ECOLOGY_BALANCE_TESTS. Final direct execution: **244 passed /0 failed**, 69.14 seconds. All scripts/*.gd and test source hashes stayed unchanged during the final run; see integration-final/provenance.json. The registered headless timeout is 180 seconds.

The suite uses all 24 count(2/3/4) × survival/duel × challenge/practice × hunger-on/off configurations, each for 1,200 real 60 Hz ticks. Mixed initial NPC satiety 5/35/70/100 is an explicitly controlled stress fixture, not the default-start statistical population. It:

- freezes full ecology/supply during pause
- validates record/ID legality, exact authoritative restore and both role allowlists at 21 checkpoints per case (504 total)
- restores and compares every byte of the final 120 ticks per case
- checks unchanged player food goal, separate scoring, established hunger-toggle behavior and valid aggregate statistics
- runs six normal-density/mode contact-to-capture-to-respawn fixtures for 1,200 ticks each, retaining live foraging peers; 40 authority/role/replay checkpoints per case (240 total)
- verifies the existing eight-second replacement delay (observed 481 ticks in each controlled case), fresh IDs, separate player awards/result, and peer activity during the occupied line
- commits the same real net lane twice: NPC overlap truly passes within 20 px and yields no capture/result, while the ordinary player-overlap positive control still captures

All per-case states/intake/hooks and capture/replacement ticks are in [compact case evidence](headless-ecology-cases.json), with the [final registered 244/244 log](headless-ecology-balance.log). The earlier direct-run source fingerprint is [also preserved](headless-ecology-provenance.json). The gate does not change production food profiles, density defaults, controller input, NPC speed, map or net target rules. Human feel and the broad paired statistical study remain separate evidence.

An initial exploratory run was preserved under integration/ and reported 236 pass/3 fail. All three were an overstrong test assumption that a peer ID must still exist after 20 seconds; those peers had legitimately been captured and replaced later. The corrected invariant records peer activity while the first target actually owns the line. No production behavior or assertion threshold was changed to hide a failure. The final suite additionally adds the five net positive/negative assertions.

## Production audit details

1. Appetite and feeding: npc_fish_state.gd retains 70 initial satiety and six maximum authority records. npc_fish_brain.gd uses seek/rest hysteresis (82/94), bounded appetite-weighted search/concern and fixed decision cadence; world_simulation.gd owns actual shared mouth/candidate/capacity/cooldown/typed nutrition and de-duplication. NPC intake never credits player score or stamina. No additional AI intake formula was introduced.
2. Hunger assistance: NPC satiety decays/replenishes even when player hunger is disabled. NPC observer then reports NORMAL like the player, so bonus risk tolerance differs; this is explicitly asserted by the existing foraging-brain suite. Do not silently retune that established contract under P3.5.
3. Supply: practice enables the old refill lifecycle when foraging is enabled and the NPC array is nonempty. Captured records remain in the array until replacement, so capture cannot disable practice supply. NPC line ownership excludes the bound bait while other slots remain eligible. Player-hook and active-net states intentionally block supply. Those contextual empty intervals are not proof of permanent supply deadlock.
4. Hooks/respawn: NPC enter requires actual mouth contact and an unowned line. Retrieval consumes ordinary W/S/auto-reel commands with the existing 1.8 factor; release/capture do not award a player win, player food or player hook statistics. Captured records wait eight seconds and receive new stable IDs; respawn RNG is ID-local. A live NPC line does not block player feeding or home victory (existing hook-target gate).
5. Social caution/privacy: decisions consume detached self/public food/action/event observations; hidden hook truth does not enter selection. Social reaction/recovery latches are bounded. Both role wires retain six NPC presentation facts, phase-only public hook state and realized result only. Private satiety, targets, suspicion, memory, RNG, future hook timers and NPC aggregates stay out. Authoritative replay and malformed-state guards remain separate from rendering wire schemas.
6. Angler attention/net: net_simulation.gd continues to operate only on player fish authority; no NPC target collection was added. Busy net handling gates NPC reel actuation and landing. Occupied-line duration is a synthetic attention-pressure proxy, not human attention measurement or an independent new balancing knob.

## Remaining P3.5 evidence boundaries

The owner's broad four-arm, twelve-stratum policy matrix, its heldout analysis, separately reported native gate/inspection and user's final Phase3 playtest remain separate evidence. The frozen final headless/Python gates are recorded above. This independent audit alone does not approve a retune, claim automatic 50% balance, approve NPC net, or unlock Phase4.

## Final supply/performance artifacts

- [Structural supply explanation and four-condition summary](headless-food-review.md), [all 4,000 original case rows](headless-food-cases.jsonl), [metadata/hashes](headless-food-summary.json)
- [0/3/6 simulation/payload measurement summary](headless-npc-statistics-review.md) and [all original raw measurements](headless-npc-statistics.json)
