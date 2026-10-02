# Phase 2.0 / P2.1 Bite Vertical Slice

Baseline: `feature/dev @ 19178ccb572cce992624c934a1ad55c58cdced47`, v0.23.1, authority snapshot schema 13. Phase 1.5 is provisionally passed for progression and can reopen on user feedback.

## Scope and gate

Implement only existing-food Bite in v0.24.1. Stop at the user playtest gate. No bait archetypes, FoodProfile, P2.2/P2.3 balance, map changes, Watergen changes, AI extensions, or Phase 1 default retuning. Source commits only; no packaged deliverables.

## Schema 14 plan

Upgrade authority schema 13 to 14 once for `bite_cooldown` and `bite_feedback_age`. Both are deterministic countdown state; capture/restore and strict fish presentation carry them, validated before mutation. Old schema 13 is rejected, not silently defaulted. Same-build v0.24.1 peers only. No speculative bait_type or future-feature fields are implemented in P2.1. Future Phase 2 additions should prefer a documented compatible migration within 14 where safely possible, never invent old replay state.

## Bite contract

v0.24.1 incorporates the user's playtest feedback: fish Bite has no key or command flag. The authority triggers it when the mouth is near edible food. Angler F remains Untangle. Local input, InputMap and remote command aggregation no longer expose Bite input.

All normal movement and physical hook-contact resolution run first. Held manual Suck still moves/peels food, but its food awards are deferred until every bait has resolved contact. An eligible automatic Bite then owns intake for this tick: up to four uneaten, not-already-counted grains within 18 px of the mouth, sorted by exact squared distance, bait lifecycle ID, then stable grain order. If Bite is cooling down or has no candidate, deferred Suck intake proceeds (unless actual mouth/hook contact blocks it). Thus there is no same-tick double intake or range-edge starvation when a suction-displaced bait relaxes. This does not activate suction automatically or move the fish for Bite.

Cooldown is 0.40 s; sustained proximity repeats after cooldown, without input. Successful intake alone produces the 0.18 s snap and cue. Empty/out-of-range/previously counted food does not animate or start cooldown. Invalid/terminal states cannot feed. Snapshot schema remains 14 with the same validated countdown fields; the network build changes to 0.24.1, so live mixed-build peers are rejected. Existing schema14 state can still be restored.
The range, cooldown and intake count are developer tuning only. Intake uses the existing per-grain score, satiety and stamina accounting. No hook truth influences eligibility, feedback or cooldown; only the unchanged mouth/tip swept-contact code attaches hooks. No new simulation or visual RNG calls.
