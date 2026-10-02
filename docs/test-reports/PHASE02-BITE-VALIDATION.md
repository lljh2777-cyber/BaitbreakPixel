# P2.0 / P2.1 Bite validation — v0.24.0

Date: 2026-10-02. Starting commit: `19178ccb572cce992624c934a1ad55c58cdced47` (`feature/dev`, v0.23.1, authority schema 13).

## Scope

Phase 1.5 is provisionally passed for progression, not permanently closed. This change implements only P2.0 preparation and P2.1 existing-food Bite. P2.2 bait archetypes and P2.3 balance are not started. No package is produced or uploaded: the user synchronizes source locally.

- F = one fish Bite attempt; angler F remains Untangle
- Accepted intake: nearest mouth-range grains, radius 18 px, up to 4 grains, cooldown 0.40 s
- Exact-distance ties: bait lifecycle ID, then stable grain-array order
- No automatic movement, targeting, added hook dice, or modified hook-contact radius
- Same-tick Bite suppresses all Suck intake, even if Bite is cooling down
- Empty/far attempts: neutral short snap, zero reward, no successful-intake cooldown
- Neutral 0.18 s jaw animation, short synthesized cue, food flash and ready/cooldown HUD
- Existing per-grain score/satiety/stamina values unchanged

## Replay and information boundary

Authority schema is now 14, with validated `bite_cooldown` and `bite_feedback_age`; schema 13 is explicitly rejected. Both fields are public neutral action state and separately allowlisted in fish presentation. Fish clients still receive no hooks, hook IDs, simulation RNG, reserve order or authority truth events. Commands and countdowns are type/range checked before state mutation. Same-build peers only: 0.24.0.

The legacy `net_aim` compatibility assertion in `architecture_v020` was updated from exact schema 13 to exact schema 14; retention and nondefault roundtrip checks remain intact. This is the planned schema migration, not removal of a failing behavior assertion.

## Verification

Release validation uses official Godot 4.7.2 stable (`ed1daf0bf`), Linux x86_64, binary SHA256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`. The downloaded archive was checked against the official release SHA512 list. Preliminary 4.6.3 runs were diagnostics only.

- `phase02_bite`: 41 passed, 0 failed, including range, cooldown, input, deterministic sorting, terminal gates, no lunge, unchanged RNG, and full safe/hooked pre-contact observation equality
- `phase02_bite_network`: 130 passed, 0 failed, including strict malformed-command/snapshot rejection, replay, queue/duplicate/lease handling, and actual ENet host-angler/remote-fish input, food, satiety, cooldown, no-repeat and physical hook-QTE results
- Full current headless profile: all 38 suites passed, 18,686 passed assertions/log markers, 0 failed/timeout/blocked suites
- Python runner/capture-contract unit tests: 28 passed
- Official native import plus all 18 current renderer suites: 397 passed assertions/log markers, 0 failures/timeouts/blocked entries; after adding two explicit far-grain visibility checks, focused Bite native rerun: 18 passed, 0 failed
- Native screenshots inspected at 640×360: ready, empty, far, intake, cooldown and recovered; HUD has no overlap; equal hidden safe/hooked states have identical pixels
- Independent command/network/contact/snapshot review found no remaining blocker

Native execution was the dot cloud Linux desktop on actual `DISPLAY=:0`, OpenGL compatibility, Dummy audio. The synthesized Bite cue is implemented, but Dummy audio does not verify audible hardware output. Full-profile native evidence used the final gameplay implementation, followed by the two-assertion test-only strengthening and focused rerun.

Reproduce source gates:

```sh
python3 tools/run_tests.py --godot /path/to/Godot_v4.7.2 --import --profile current
python3 tools/run_tests.py --godot /path/to/Godot_v4.7.2 --profile native
python3 -m unittest discover -s tests/runner -v
```

Evidence directories in the verification workspace: `artifacts/test-runs/phase02-current-gate-472`, `artifacts/test-runs/phase02-bite-tests-enet-official`; native runner `all-results/summary.json` and focused rerun were kept separately. Generated screenshots/logs are not uploaded or included as distributable packages. The current profile does not claim every historical suite is passing.

### Failures encountered and resolved

- Malformed Bite values exposed `Commands.flag` comparing non-bool Variants to `true`, generating script errors despite an assertion summary. The shared command flag helper now accepts only actual bool values; error-aware runner reruns are clean.
- `architecture_v020` intentionally hardcoded schema 13. Its exact-version expectation migrated to 14 while preserving field retention, roundtrip and rejected-unknown-schema assertions; targeted rerun 46/46.
- One full-profile run hit the existing `net_network_v021` six-frame intermediate capture-state assumption (12 pass/1 fail), although both peers later settled the same net victory. Earlier full run and unchanged isolated rerun both passed 13/13. The fixture now polls for convergence for at most 30 simulated frames and additionally requires exactly one catch on the client as well as the host; it preserves the original capture-state assertion and adds diagnostics. No gameplay/network protocol change was made for this fixture. The final whole-profile gate is rerun below, and original failed logs are retained.
- The Python capture-manifest count was increased by one for the new native test; per-file validation remains in place, and all 28 Python tests pass.

### Contract audit

- All 147 existing catalog default values match baseline exactly; only developer-only `bite_range`, `bite_cooldown`, `bite_intake` are added
- `pond_layout.gd` is byte-identical to baseline: map ID, SIZE, WATER, FLOOR, HOME, SPAWN, SOLIDS, PLANTS, BAIT_SITES and WOOD_GROUPS unchanged
- Water/environment visual files and `fish_observation.gd` unchanged; no new simulation/visual RNG call
- Hook attachment remains in the existing physical swept mouth/tip contact path; Bite never tests bait hook truth to decide intake or feedback
- No FoodProfile, bait_type, extra maps, Watergen geometry, economy, AI fish, or P2.2/P2.3 scope

## Human playtest gate — OPEN

Automated pass does not establish good game feel. Stop further expansion here. Run synchronized source with Godot 4.7.2 and confirm menu v0.24.0.

1. Try F in empty water and on nearby existing food; check clear response and visibly shorter reach than Suck
2. Hold F: one attempt only. Release and press again; check the 0.40 s successful-intake cooldown
3. Compare left-button Suck and F: gradual/cancellable versus an immediate small mouthful; simultaneous input must not double-feed
4. Check mouth snap, sound, food disappearance, score flash and cooldown readability
5. Judge whether Bite is overpowered, tedious, or useful in particular situations; does the F key feel natural?
6. Approach actual hidden-hook contact and judge whether the result feels caused by close physical commitment
7. If convenient, join as fish from another same-build client and compare input/result/food/satiety feedback

Real Windows launch, physical two-computer networking, real audio-device output and subjective feel remain user validation. P2.2 must not begin until the user clears this gate.
