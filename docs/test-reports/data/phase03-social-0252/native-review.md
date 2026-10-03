# P3.3 native verification, 0.25.2

- Full `tools/run_tests.py --import --profile native`: 20/20 renderer suites and editor import passed. 597 summary assertions plus 2 visual completion markers, 0 failure/error/timeout. `phase03_npc_native` contributes 117 assertions.
- Engine: Godot 4.7.2 stable, X11 desktop, GL Compatibility, Mesa llvmpipe (LLVM 19.1.7). Actual cloud desktop window was inspected through CUA at 1280x720; renderer captures are the 640x360 game canvas. Dummy audio does not validate actual speakers.
- Each actual HESITATE/FLEE/COMPETE authority fixture passed strict restore, native pixel purity, hidden hook and private social/caution canaries, and exact six-public-field `swim` replica equivalence in fish, shore and net-observation views. NPC-free controls confirmed unchanged HUD. Motion continued without new labels, meters, numeric NPC caution, Hook or capture outcomes.
- Inspected final PNGs for all three states, later motion, shore/observation, and real `advance_tick` preview captures. The small muted blue-gray NPC is visually distinct from the larger gold player. Shore shadows remain faint and observation remains approximate. No new status symbol or numeric NPC caution was visible.
- Bounded 18 simulation-second preview: HESITATE produced a small lateral/slowing movement, then actual FEED and food depletion, then WANDER. FLEE visibly moved away from the food from x=650 to about x=607, recovered to APPROACH_FOOD, then returned to FEED. HESITATE is deliberately subtle and is clearer in motion than in a still.
- Additional bounded 8 simulation-second competition preview used 12 visible loose grains and a nearby actively sucking player outside immediate Bite reach. COMPETE moved NPC x=650→674 by tick60; FEED was reached at tick120, then WANDER after player food depletion. The NPC lost this particular contest (NPC food0, player food12); this is evidence of the shared-resource motion/depletion flow, not an NPC-win or balance claim. Preview script hashes and logs are preserved.
- These controlled visual observations do not replace the user's subjective legibility, feel, fun or balance gate. No Windows native run, physical-device/public-network multiplayer, long stress run or actual sound-card check was performed.

## Source provenance

Pre-run manifest has 425 files; post-run has 426. The only differences are measurement tooling: `tests/runner/test_phase03_social.py`, `tools/phase03_analyze_social.py`, and new `tools/phase03_social_protocol.md`. Runtime scripts, assets, scenes, project/export configuration, native test scripts, test runner and suite registry are byte-identical. See immutable `native-source-manifest.json`, `native-after-source-manifest.json`, `native-provenance-verification.json`, and scoped `native-consumed-provenance.json`.

## Performance and warnings

Frozen 640x360 redraw-to-frame-post-draw, 45 samples each: 0/3/6 NPC mean16.11/16.44/16.99ms; p95 24.04/22.67/25.74ms. These include display pacing and scheduler delay, with headless regression running concurrently; they are not isolated simulation/GPU costs or a performance regression verdict.

The software driver cannot change V-Sync. Four older suites retain ObjectDB exit warnings (2/2/3/5 instances in bait_suction_native_v0211, bait_suction_native_v0212, pond_native_v021, effort_native_v013). The new NPC native suite has no ObjectDB warning. No SCRIPT ERROR, engine ERROR, assertion failure or timeout occurred.

## Retained compact evidence

- [Hesitation](social-hesitate-fish.png)
- [Actual retreat](preview-flee-090.png)
- [Actual competition approach](competition-060.png)
- [Approximate observation view](social-compete-observation.png)

Full captures remain local; the formal native test and retained pixel evidence establish the stated checks. They do not close the manual playtest gate.
