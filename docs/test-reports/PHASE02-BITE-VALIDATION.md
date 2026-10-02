# P2.1 automatic mouth Bite validation — v0.24.1

Date: 2026-10-02. Baseline: `811a8b83d2a7e7b3b14e486ff3b192f2e914d701` (`feature/dev`, v0.24.0, authority schema 14).

## User feedback implemented; playtest remains open

The user requested: “咬食不设置按键，鱼嘴靠近饵料后自动触发”. This revision implements that feedback. It does not close the subjective playtest gate or start P2.2/P2.3. The prior F-key implementation and its original validation are preserved unchanged in [v0.24.0 history](PHASE02-BITE-VALIDATION-0.24.0.md).

- No fish Bite key, input action, local input bit, or remote queued edge remains; angler F still means Untangle
- Authority automatically consumes eligible food within 18 px of the mouth, at most 4 grains per mouthful
- Sustained proximity repeats after the 0.40 s cooldown; moving away or exhausting food stops intake
- Only successful intake emits the 0.18 s mouth feedback and sound; empty/far/already-counted identities stay quiet
- No automatic Suck, lunge, target lock, hook dice or altered contact radius
- Manual Suck movement/peeling and real hook contact resolve before awards; automatic Bite has intake priority, otherwise Suck can award during cooldown. Never both in one tick
- Existing score, satiety, stamina, defaults, maps and Watergen remain unchanged
- Source only; no package generated or uploaded

## State and network boundary

Authority and public snapshot schema remain 14, with the same validated `bite_cooldown` and `bite_feedback_age` fields. Existing schema14 snapshots restore normally; countdowns and replay remain deterministic. Live peers must both use build 0.24.1. Legacy incoming Bite flags are stripped by normalization and cannot trigger, suppress or repeat automatic intake. Fish public packets retain strict hidden-hook/RNG clipping.

## Verification

Official Godot 4.7.2 stable (`ed1daf0bf`), Linux x86_64, binary SHA256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`.

- Current headless gate: all 38 suites plus editor import passed; 18,704 assertions/log markers, 0 failed/timeout/blocked entries
- Focused automatic Bite: 57/57 passed, including range, deterministic repeats, quiet empty/far states, pause/end, no input, no lunge, recoil boundary, movement-away and cross-bait contact arbitration
- Focused network: 132/132 passed, including actual ENet host-angler / remote-fish neutral input, automatic repeat, food/satiety/cooldown, hook-contact result, schema14 replay and privacy
- Native gate: all 18 current renderer suites plus editor import passed; 399 assertions/log markers, 0 failed/timeout/blocked entries; Bite native 18/18
- Native screenshots inspected at 640×360: automatic HUD with no F prompt, empty/far quiet states, intake, cooldown and recovery; equal hidden safe/hooked states have identical pixels in ready/active/cooldown states
- Python runner/capture-contract tests: 28/28 passed
- Independent reviewer edge probes: 26/26 passed, including exact recoil/starvation and later-bait hook cancellation of earlier deferred intake; core regressions retained in the committed suite

Native execution used the dot cloud Linux desktop, official 4.7.2 OpenGL compatibility and Dummy audio. The full native copy's `world_simulation.gd` SHA256 matched the final source (`048b9ce4af77ecfaa0f7506614587f6db5170d37963c6c6e37ac34e94c518bee`). Actual hardware sound was not verified.

Evidence in the validation workspace: `artifacts/test-runs/auto-bite-current-final/summary.json`, `artifacts/test-runs/automatic-bite-edges-verified`, `artifacts/test-runs/automatic-bite-focused-verified`; native `/workspace/shared/bait-native-auto0241/all-results/summary.json`. These are source-test evidence, not release packages. Current gates do not claim every historical suite passes. No packaged/PCK or Windows gate was run for this source-only revision.

### Regression found and fixed

An initial start-of-tick eligibility approach starved the existing 26 px gentle-Suck fixture: the displaced food was close enough to suppress Suck, but bait relaxation then moved it outside Bite range, yielding neither action. Final arbitration defers Suck awards until after motion/contact and gives a successful automatic Bite exclusive intake. The original `feeding_feel_v022` assertion is unchanged and passes 27/27 after the fix. Initial failed logs are retained in `artifacts/test-runs/auto-bite-current`; they are not claimed as a clean gate. Focused test construction also corrected food points and isolated counted-identity fixtures; these are fixture changes, not gameplay exceptions.

### Reproduce

```sh
python3 tools/run_tests.py --godot /path/to/Godot_v4.7.2 --import --profile current
python3 tools/run_tests.py --godot /path/to/Godot_v4.7.2 --profile native
python3 -m unittest discover -s tests/runner -v
```

## Human playtest — OPEN

Run synchronized source with Godot 4.7.2 and confirm menu v0.24.1.

1. Without any feeding key, approach existing food: the mouth should take at most four nearby grains and show a short snap/cooldown
2. Stay nearby: another mouthful occurs after about 0.40 seconds; swim away to stop. Empty/far water must not animate or click
3. Compare manual left-button Suck to automatic close-range intake, including held Suck while approaching and during cooldown; check no extra same-tick reward
4. Judge distance, repeat rhythm, mouth animation, food disappearance, score flash and actual audio clarity
5. Approach real hidden-hook contact and check that the outcome feels physically caused rather than randomly penalized
6. If convenient, use two same-build clients with a remote fish and compare automatic result, food, satiety and cooldown

Windows launch, physical two-computer networking, actual audio output and subjective feel remain user validation. Feedback is implemented and awaiting that playtest; do not start new bait types or balance expansion without the user's go-ahead.
