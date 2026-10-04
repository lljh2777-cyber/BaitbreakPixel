# P4.2 independent authority equivalence gate

The historical P4.0 driver, 0.25.5 lock, deterministic GDScript harness and
inherited net diagnostic remain byte-identical. This separate gate compares
committed 0.26.0 legacy authority against the reviewed 0.26.1 MapContext migration.

## Source locks

- Commit: `0a3e5af3dc3ca26f0909644505ff24a1de1fe06d`
- Tree: `3bc012c3e84f2ad79872757c7d574c3a0234dab1`
- Archive SHA-256: `6635f95a7cb5282c5560e9cef3c1b9c5400675c6d45e0f322f0cbe7d6d8b5737`
- `authority_baseline_0a3e5af.json` locks all 138 committed runtime files and the
  unchanged harness, historical driver/lock, net diagnostic and bounded runner
- `authority_reviewed_runtime.json` records exact independently reviewed hashes
  and reasons for the twelve authority context/geometry/consumer files and UIDs

There is no blanket map-directory or whole-file exception. Snapshot, Network
shape/validation, presentation, assets and other runtime bytes remain locked.
The four exact 0.26.0→0.26.1 project/build/menu/log substitutions are separately
checked. A pending review, missing required migration, new unexpected runtime
file, or stale reviewed hash fails the gate.

## Reproduce

```sh
python3 tools/phase04_compare_authority.py \
  --godot /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --require-engine 4.7.2 \
  --output artifacts/p42-authority-comparison-new
python3 -m unittest discover -s tests/runner -p test_phase04_authority.py -v
```

The tool creates or verifies `artifacts/p42-frozen-baseline-0a3e5af`, refuses
existing output directories, and launches the unchanged frozen external harness
against both projects using the same executable and isolated user-data paths.
`--freeze-only` verifies archive identity without executing Godot. Development
engines are explicitly labelled and do not satisfy the official 4.7.2 gate.

The exact eight scenarios, 2,100 input ticks and 86 checkpoints are required,
including full every-tick authority hashes, deterministic input/intervention
hashes, RNG integer strings, snapshot bytes, visual/decision/social observations,
NPC private state, bait, Hook/QTE/wrap, net, statistics, both role wire projections
and compressed authority. The report contains 1,690 assertions before its own
output-write check; the final console reports 1,691. Pause, restoration and
second-half replay checks remain unchanged. No rounded-float comparison replaces
Variant-byte authority evidence.

A separate run of the unchanged inherited net diagnostic must preserve both the
same-tick `net_action.age` integer-zero fish-wire rejection and staged-input
acceptance. It is retained as an inherited defect witness, not a passing gameplay
suite and not an authorization to repair or weaken a network guard.

Outputs preserve full source hashes before and after, engine path/version/hash,
commands, bounded process results, the archive manifest, review lock, exact
comparison, and inherited-edge comparison. Source or executable changes during
execution fail the run. Native renderer pixels and real network transport are
separate gates; this deterministic comparison makes no human-playtest, export,
new-map gameplay or statistical balance claim.

## Native capture cursor setup

`authority_native_cursor_fixture.gd.txt` is an external subclass template for
`phase03_npc_native` and `phase03_npc_hook_native`. Substitute the suite name for
`@SUITE@` and run the same resulting script bytes externally against each project.
It pins the live desktop pointer to logical HUD coordinate (4,4) before calling
the unchanged harness render method, records pointer readback and verifies both
noninteractive location and exact authority preservation. Original assertions
and complete image pixels are retained. The other two paired suites are
`wood_fade_native` and `net_native_v020`; their unchanged harnesses control their
own relevant inputs. Compare all 106 complete RGBA frames without masks,
tolerances or crop exclusions. Offscreen positioning alone is unreliable on
Linux window managers that clamp the window or pointer.
