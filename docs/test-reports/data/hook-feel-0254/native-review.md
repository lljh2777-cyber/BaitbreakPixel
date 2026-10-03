# Native review: 0.25.4 hook entry and NPC pacing

## Final gate

- 22/22 current renderer suites passed; editor import also passed
- Raw count: **803 reported passes, 0 failures**. Of these, 801 are summary assertions and 2 are legacy `visuals` log markers. Per-suite counts and commands are preserved in `native-summary.json`
- New focused player suite: **116/0**; updated effort-native suite: **25/0**
- Godot 4.7.2 Linux, X11, OpenGL Compatibility, Mesa llvmpipe, Dummy audio. The fixed canvas was 640×360; the desktop window used a 2× transform
- Final run: 2026-10-03 14:28:30–14:30:30 UTC. All **176** recorded runtime/source/current-renderer/runner/registry files were unchanged before/after; see `native-provenance.json` and both source manifests

## Verified behavior

Six repeated entry starts and six wrap starts cover ignored warning-period Space, held keys and repeat echoes, fresh green-zone success, visible off-zone penalties, and last-warning-tick edges. The untouched entry timeout lasted 145 ordinary 60 Hz ticks (2.4167 s for a configured 2.4 s warning+sweep). Contact loss shows an explicit interruption message and counts a skill failure only after the visible sweep. Pause, focus loss, Continue-Space, held-key mouse resume, and reset require neutral input before a new deliberate judgment.

The earlier native investigation reproduced Continue-Space also becoming a gameplay judgment. The final 116/0 gate includes the corrected behavior. The first full aggregate after adding held-focus mouse coverage instead had **115/1** in the new suite: its synthetic click used a logical button center as physical window coordinates and missed Continue. The test now applies `root.get_final_transform()`; assertions were retained. The six-case coordinate diagnostic confirms `menu=false`, an active entry check, zero result age, a held Space and an armed release gate, followed by success on a fresh press. Preserve `native-initial-*` and `native-held-coordinate-diagnostic.log` as this correction trail. The first run's sole recorded source-manifest delta was creation of the new test UID during import; it is not the final verified run.

## Continuous rendered NPC witness

`native-npc-review.gd` establishes real mouth contact before starting ordinary 60 Hz ticks, one tick per renderer frame. There are no post-contact NPC-position or line-length edits. Screenshots briefly pause simulation to capture a still. Seed 64317, starting NPC (960,390), anchor (640,53):

- **Duel, physical held W through local input:** landing 7.38333333333333 s; capture 8.43333333333333 s; largest observed hooked step 1.4420166015625 px/tick
- **Survival, auto-reel:** landing 11.0 s; capture 12.05 s; largest observed hooked step 0.82682991027832 px/tick
- Both retain the complete **1.05 s lift**, record one wrong catch, and leave the player's match running

The 12.05 s native auto-reel result exactly matches the **survival** row in `npc-pacing-after.json` for this seed/location/control. The **duel** headless row is 11.9833333333333 s (four ticks shorter); these are different ruleset fixtures, not interchangeable numbers. No pointer/aim causal attribution is claimed.

The three selected unmodified native PNGs show the warning-only entry panel, successful wrap/coil, and NPC shore lift. Other inspected native captures showed green timing, visible failure, explicit contact interruption, intermediate retrieval, and post-capture line cleanup.

## Warnings and limits

`native-warnings.txt` preserves every warning from the final native gate. All 22 renderer suites report unsupported V-Sync control on the software driver. Exit-time ObjectDB warnings remain in both bait-suction suites (2 instances each), effort-native (2), and pond-native (3). Import also reports an ignored nested baseline project under artifacts. The final focused player log has no ObjectDB warning. No final engine/script ERROR was reported.

This is source-native automation plus visual inspection, not human feel/difficulty acceptance, Windows input QA, real sound verification, or packaged-game validation. Continuous timings are simulation time, not measured human reaction time.
