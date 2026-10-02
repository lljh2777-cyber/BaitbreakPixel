# Phase 1.5 native / packed visual verification — 2026-10-02

## Frozen inputs and execution
- Source commit: `82977998f2ce154855d4560522bfc22394c78e75`
- Godot: official 4.7.2 stable Linux x86_64, binary SHA256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`
- PCK: `Releases/BaitbreakPixel-0.23.1/BaitbreakPixel.pck`, SHA256 `796a8f1e0512f582e4d42784c6a814eb195824873accc4b8554051557e6c57af`
- Dot cloud native desktop, DISPLAY=:0, OpenGL compatibility, Dummy audio; actual rendered images 640×360. Source archived before testing; no game code edited by this verifier.
- Source command: `python3 tools/run_tests.py --godot <official-4.7.2> --import --profile native --output-directory <source-results>`
- Packed command: same runner `--profile native --pack <above-PCK> --output-directory <packed-results>`; test scripts loaded externally, game resources from PCK.

## Results
- Source: import plus all 17 current renderer suites passed (18 green runner entries), 381 recorded pass assertions/log markers, zero failures/timeouts/blocked suites.
- Packed: all 17 renderer suites passed, 381 recorded pass assertions/log markers, zero failures/timeouts/blocked suites.
- Phase 1.5 targeted native: 25/0 in each mode.
- All 17 Phase 1.5 PNGs are pixel-identical source versus packed; comparison JSON preserves PNG hashes and dimensions.
- This is the current native profile, not a claim that every historical test passes.

## Visual inspection and acceptance evidence
- PF001: fish HUD caution row, full-size caution label, instinct label and right clock remain separated at actual 640×360; low-satiety plus alarmed plus instinct frame inspected.
- PF002: satiety 0/5/20/50/100 gives 0/3/14/35/70 filled pixels of a 70px bar; bounded, monotonic and driven by permitted self satiety. Each full-size frame inspected.
- PF003: fresh undeployed and actual reset frames have no own float or line despite ambient hook population; Q produces owned line and float. Both render and rig ownership assertion pass.
- PF005/PF006: idle, reel two keyframes, release two keyframes, stopped and restart full-size frames inspected. Reel/release UI labels and hand/spool poses differ; reel and release periodic crop differences asserted. Neutral returns to still idle pose. Native assertions require signed actual free-line velocity rather than a held input flag.
- PF004: +25% A/D numerical movement is covered by implementer phase15_controls; native screenshots alone do not prove speed. No independent numeric movement rerun claimed here.
- Safe-truth boundary: phase01_native passes exact pixel equality after flipping only hidden hook flags/IDs, in both source and PCK, while permitted own satiety remains visible.

## Evidence directory
`/workspace/shared/bait-phase15-native/`
- source-results/summary.json and per-suite logs
- packed-results/summary.json and per-suite logs
- source-results/captures/phase15_native/ and packed-results/captures/phase15_native/
- phase15-pixel-comparison.json
- source-console.log, packed-console.log and exit files (both 0)

## Remaining limits
- Windows EXE was not executed. Packed-resource Linux rendering does not establish Windows runtime compatibility.
- Dummy audio does not validate sound output.
- Automated state fixtures plus pixel inspection do not replace the user's hands-on comfort/playability acceptance or multi-machine interactive playtesting.
