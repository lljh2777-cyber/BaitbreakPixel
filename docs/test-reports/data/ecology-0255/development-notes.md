# Exploratory checks kept separate

These are harness/fixture setup findings, not game changes or final passing evidence.

1. First 60-tick×48-cell smoke launched Godot directly without isolated XDG paths. It completed the rows but produced user-data/log-directory write errors. The formal bounded launcher uses writable isolated XDG directories; this direct run is not a passing gate.
2. Second smoke had stable sources and produced all48 rows, but the first analyzer incorrectly equated the new pre-tick player satiety mean with legacy post-tick RoundStats, and correctly failed its then-written check. These are different sampling definitions. The analyzer now validates each bounded measure separately, preserves both raw values, and still requires actual score/hook/intake counter reconciliation. The source was then frozen. Final smoke3 passes; later formal pilot/heldout use the corrected immutable implementation.
3. The first integrated density/lifecycle fixture reported236pass/3fail because it demanded that another NPC's ID still exist after20seconds; that NPC could legitimately have been captured/replaced later. The corrected invariant requires live peer activity during the original NPC's occupied-line interval. No production edit or failure threshold relaxation was used. The final gate adds five actual-net positive/negative assertions and passes244/244.
4. Initial ordinary-UI capture overlapped version/registry edits. Its provenance reports source_unchanged=false. It is preliminary, never substituted for the later frozen22-suite gate and15-record real-UI review.
5. A prepilot full1-seed/48-cell exploratory matrix checked instrumentation and running time. It is outside pilot73501–73504 and heldout73601–73625 and not pooled into either. The frozen baseline comparison uses separate regression seed73402, also never pooled into heldout.

The prototype paths and failed-run metadata remain in the local task artifacts. Published final source fingerprints, bounded launcher output, all selected formal rows and per-suite summaries are the reproducible evidence used in the report. No outcome in the formal heldout selection is removed because it is inconvenient.
