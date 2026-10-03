# NPC hook-to-capture pacing, 0.25.4

The immutable b739fda baseline and final 0.25.4 runtime each ran 162 identical controlled cases at actual 60 Hz: seeds 64317/64404/64423, duel/survival, start y=130/240/390, horizontal anchor offsets=0/160/320, and held W / W-S reversal / auto-reel. Every case begins with real mouth-hook contact. After attachment, the probe only sends ordinary commands and observes state; it never moves the NPC toward shore or adjusts the line to produce a capture.

Timer, hunger, water motion and player instinct are disabled for isolation. All capture fixtures retain default line, pull, landing, tension and failure rules. The W/S controller includes a 0.2-second release at ticks 30–41 and otherwise chooses S only if public tension≥0.84. This is a controlled pacing witness, not natural event frequency or human balance evidence.

## Results

All 162 cases captured both before and after, with no unfinished or filtered cases. Across paired cases, mean capture-time reductions are 32.97% for W, 31.71% for W/S, and 41.09% for auto-reel. Post-change ranges are 2.55–8.47 s, 2.85–8.83 s, and 2.95–12.10 s respectively. Maximum observed hooked movement is 1.709 px/tick; no jump or forced shore placement is used. The full 63-tick (1.05 s) lift animation remains intact.

Representative duel seed 64317, measured from physical contact to completed capture:

| Start / horizontal offset | W before → after | Auto before → after |
|---|---:|---:|
| Shallow y 130 /0 px |3.100→2.567 s|4.233→2.983 s|
| Mid y 240 /0 px |6.167→4.267 s|9.750→5.750 s|
| Deep y 390 /0 px |10.283→6.550 s|16.283→9.300 s|
| Deep y 390 /320 px |13.550→8.433 s|21.367→11.983 s|

## Failure paths remain real

- Held S produces actual slack escape in both modes across all three seeds
- W/S reversal still retrieves from the deep, 320 px-offset start
- With entirely default line rules, holding W while walking left/away in duel sustains high tension and breaks at 3.383 s after contact; the observed high-tension duration reaches 3.000 s. W alone captures from the same start. Player match and player break counters remain untouched
- For a stationary anchor in either mode, a valid practice line-force 0.1 setting plus ordinary held W yields a sustained-high break at 3.433 s. The default 3.0 s break threshold is not shortened. This configured-force witness is separate from default-rule pacing
- The old zero-rope mobile fixture immediately projects the target near shore, so it is not used as evidence for full-distance retrieval or default practical break behavior

## Regression and reproducibility

The standalone registered `phase03_npc_hook_pacing` gate passes 243/243 assertions. Against the frozen b739fda runtime the same gate has 201 passes and 42 expected failures: 36 speed budgets and 6 deep W/S duration budgets. Existing success, slack and sustained-high assertions are not weakened. The budget includes one 60 Hz tick of numerical/frame tolerance.

`npc-pacing-before.json` and `npc-pacing-after.json` retain every measured case and per-second trajectory; `npc-pacing-comparison.json` contains all paired differences. Both runs have before/after source fingerprints with `source_stable=true`. The baseline runtime manifest identifies b739fda. Gate outputs and their summaries accompany these files.

Reproduce current measurements with `godot --headless --audio-driver Dummy --path . --script res://tools/phase03_npc_hook_pacing.gd -- --test-profile --full --output=/fresh/writable/result.json`, using isolated XDG data/config/cache directories on Linux. The probe refuses to overwrite an existing result. For the regression use `python3 tools/run_tests.py --godot "$GODOT" --suite phase03_npc_hook_pacing`.

The original baseline capture test placed an already-hooked NPC near shore, which covered hold/lift/capture but did not measure retrieval time. These new tests close that gap. No claim is made about human feel, network latency, overall ecology balance, or future Phase 3.5/4 work.
