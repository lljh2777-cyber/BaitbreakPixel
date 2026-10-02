# Phase 2.0 / P2.1 Bite Vertical Slice

Baseline: `feature/dev @ 19178ccb572cce992624c934a1ad55c58cdced47`, v0.23.1, authority snapshot schema 13. Phase 1.5 is provisionally passed for progression and can reopen on user feedback.

## Scope and gate

Implement only existing-food Bite in v0.24.0. Stop at the user playtest gate. No bait archetypes, FoodProfile, P2.2/P2.3 balance, map changes, Watergen changes, AI extensions, or Phase 1 default retuning. Source commits only; no packaged deliverables.

## Schema 14 plan

Upgrade authority schema 13 to 14 once for `bite_cooldown` and `bite_feedback_age`. Both are deterministic countdown state; capture/restore and strict fish presentation carry them, validated before mutation. Old schema 13 is rejected, not silently defaulted. Same-build v0.24.0 peers only. No speculative bait_type or future-feature fields are implemented in P2.1. Future Phase 2 additions should prefer a documented compatible migration within 14 where safely possible, never invent old replay state.

## Bite contract

F uses the independent `bite` action in fish context; angler F remains Untangle. Local input queues one non-echo press and consumes it once. Network input treats it as a one-shot and never reuses it as held input.

Bite suppresses Suck for the entire input tick, including cooldown-rejected attempts. It does not move the fish or bait. After normal movement and existing physical hook-contact resolution, an eligible attempt consumes up to four uneaten grains within 18 px of the mouth, sorted by exact squared distance, bait lifecycle ID, then stable grain order. Cooldown is 0.40 s. Empty/out-of-range attempts give a neutral 0.18 s snap, award no food, and do not start the feeding cooldown (§12 requires nearby edible food). Invalid/terminal states cannot feed.

The range, cooldown and intake count are developer tuning only. Intake uses the existing per-grain score, satiety and stamina accounting. No hook truth influences eligibility, feedback or cooldown; only the unchanged mouth/tip swept-contact code attaches hooks. No new simulation or visual RNG calls.
