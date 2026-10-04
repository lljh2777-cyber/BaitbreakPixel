# P3.5 native ecology review — 0.25.5

## Final results

- **22/22 current renderer suites passed**, plus editor import; 0 failed, timed out or blocked
- **801 summary assertions + 2 legacy completion markers**, not 803 assertions; per-suite counts and commands are in [native-summary.json](native-summary.json)
- NPC ecology renderer **117/0**, NPC Hook renderer **86/0**, player Hook entry renderer **116/0**; focused raw logs are preserved in `native-npc-renderer.txt`, `native-npc-hook-renderer.txt`, and `native-player-hook-renderer.txt`
- Gate: **2026-10-04 01:34:14–01:36:04 UTC**; ordinary UI: **01:36:43–01:39:10 UTC**. Both exited 0
- All **177** recorded native dependency files stayed identical before/after both sessions and across the two sessions. This validates the frozen 0.25.5 working tree above base `dfdd9af`; it does not pretend that base commit alone contains 0.25.5. See [gate provenance](native-provenance.json), [UI provenance](native-ui-provenance.json), and their complete before/after manifests
- Ordinary UI review saved **15** timestamped game-viewport/state records with no entity placement or gameplay modification. Selected original PNGs are published; hashes are in [native-image-sha256.json](native-image-sha256.json)

The independent [evidence consistency audit](native-evidence-audit.json) passed 12/12 checks (hashes, capture sizes, pause/cancel/reset records and error scan); these are not additional gameplay assertions.

Only registered current renderer gates are claimed, not historical/retired/manual suites, human acceptance, Windows build validation or package testing.

## Method and audit

Godot 4.7.2 Linux/X11, OpenGL Compatibility on Mesa llvmpipe, Dummy audio; 640×360 game canvas, 1280×720 desktop game window. The existing Godot binary is used; no new download, export, Windows package, or Release artifact is made.

The source manifest records runtime scripts/scenes/assets/import descriptors; project.godot; current renderer test bodies/UIDs; runner/registry; and the evidence-only UI recorder. Generated Godot cache, documentation and headless-only tests are outside this dependency set. The initial UI session deliberately remains preliminary: parallel metadata/registry edits were detected and its provenance reports source_unchanged=false. It is not relabeled final evidence.

### Existing renderer scope

`phase03_npc_native` checks 0/3/6 physical NPC sprites, three distinct variants, smaller silhouettes than the player, stable overlap ordering with player pixels in front, no extra names/status/HUD pixels, rendering purity, real food disappearance, actual HESITATE/FLEE/COMPETE, authority/public-only/hidden-state pixel equivalence, shore and limited observation visibility.

`phase03_npc_hook_native` establishes actual NPC mouth contact and verifies the exact NPC line endpoint, free and unposed protagonist, player pixels on top, Hook/lift/capture/escape/break cleanup and respawn, and role/public/private pixel equivalence. Its landing setup is a controlled landing-boundary fixture, not a continuous full-distance timing witness. The existing pacing tests and 0.25.4 rendered continuous retrieval evidence make that separate check.

Frame costs use 45 frozen-scene wall-clock redraw-to-frame-post-draw samples for each of 0/3/6 NPCs. They include display pacing/scheduler and concurrent cloud load; they are not isolated GPU measurements, active simulation costs, sustained FPS guarantees, or user-device predictions. Active simulation costs are covered separately by the statistics suite.

### Ordinary UI method

`native-manual-ui-recorder.gd` instantiates the unmodified normal main scene and records game-only viewport PNGs/state on F12. It does not place entities, move food, reset the world, disable normal processing, set capture mode, or inject controls. All reviewed actions use CUA native mouse/keyboard. Deliberate non-movement keys use 100 ms holds because normal polled controls may miss sub-frame synthetic taps. XDG and --test-profile isolate the save. No unrelated desktop/terminal screenshot is published.

## Ordinary UI observations on the frozen tree

The final title visibly reads 0.25.5 / ecology balance / awaiting final playtest. CUA entered free fish practice and moved with held D/W, then aimed and held left-click to feed. The orange protagonist stayed distinct from the small muted NPCs in motion. At capture `ui-04`, player score was **2.1**, NPC intake **26.4**, with three live NPCs; these are separate quantities. On resume, player intake reached **6.15**, demonstrating actual ordinary-UI food gain, not a score assignment.

Esc pause captures `ui-05` and `ui-06` have exactly equal elapsed time (**19.5 s**), player position, player score, NPC positions/states and NPC intake. Continue-Space resumes; R resets score/intake and starts a fresh round. The pause menu switches to angler practice with an undeployed rod; Q deploys it, W/S inputs are exercised, E opens the existing observation view, and a fresh E cancels it before its timer ends (`ui-11` observing=true at 15.35 s, `ui-12` false at 16.2833 s). This UI recorder is not a quantitative line-length test; normal W/S mechanics remain covered by the existing gates.

Actual Alt-Tab moves focus to the desktop terminal and back; the game automatically opens pause (`ui-13`). Mouse Continue and R still work; Return-to-title and the normal Exit button close the game cleanly. No NPC Hook/capture occurred in this final ordinary-UI session, so that outcome is supported by the controlled native Hook suite, not claimed as a manual catch. The preliminary session additionally observed an AI fish home result, but it is not substituted for final-tree evidence.

See [native-ui-records.json](native-ui-records.json). Diagnostic state in this evidence file includes private QA fields; it is not a public network packet or proposed UI. No numeric NPC state/HUD was added.

## Pixel inspection and timing

Actual pixels were inspected from the final 0/3/6 stills, social flee, hooked fish, exact-overlap player-front image, NPC shore lift, ordinary feeding, and observation views. At 640×360 the protagonist is orange and larger; NPCs use small muted physical sprites with no labels. The Hook line ends at the NPC while the protagonist remains free in the separated-target still; the overlap still preserves the protagonist body. The lift is visible in the shore scene. These are visual inspections plus exact pixel assertions, not a claim that every human will perceive the distinction equally well.

Frozen-frame samples (45 per count), mean / p50 / p95 milliseconds:

| NPC count | Mean | p50 | p95 |
|---|---:|---:|---:|
| 0 | 16.210 | 16.607 | 26.206 |
| 3 | 16.175 | 16.647 | 18.567 |
| 6 | 16.134 | 16.623 | 18.462 |

These descriptive observations do **not** establish that six NPCs are faster than zero; display scheduling/cloud load dominate this paced metric. Original values and measurement description are in [native-frame-costs.json](native-frame-costs.json).

## Warnings retained

[native-warnings.txt](native-warnings.txt) preserves all warnings from the gate. All 22 renderer suites report unsupported V-Sync control on this software driver. Exit ObjectDB warnings report 2 instances in each bait-suction suite, 5 in effort-native, and 4 in player-hook-entry-native. Counts differ from the prior report; they are disclosed without inferring a gameplay failure or claiming their cause was diagnosed. No final engine/script ERROR occurred.

Import also warns that the nested baseline project is ignored, and that the existing P3.2 headless diagnostic `tools/phase03_diagnose_supply.gd` had a missing `.uid` file, which was recreated from cache during import. That headless diagnostic is outside the recorded native dependency set. The ordinary-UI session has the software-driver V-Sync warning and no engine/script error.

## Reproduction

Use the supported bounded entry from a real graphical desktop:

```sh
python3 tools/run_tests.py --godot "$GODOT" --import --profile native --output-directory artifacts/p35-native-repeat
```

For ordinary UI recording, use `native-manual-ui-recorder.gd` as an external script with `--path` pointing to the project, `--audio-driver Dummy --rendering-method gl_compatibility`, and `-- --test-profile --ui-record-output=/absolute/writable/directory`. F12 records without changing the scene. `native-evidence-runner.py` archives the exact cloud-session wrapper (including its environment-specific paths), not a portable replacement for the repository runner.

## Human acceptance remains open

Automated pixels, assistant-operated normal UI and paired statistics cannot approve ecology feel or fairness. The user still needs to judge:

1. Three NPCs leave readable chances to eat and return home; sustained low-food periods feel recoverable
2. Compete/hesitate/flee look natural without reliably revealing hidden hook truth
3. The protagonist remains identifiable in overlap and six-NPC stress
4. Wrong-catch handling has a reasonable cost while the player can use the opportunity
5. Same-build clients with swapped roles feel consistent in actual multiplayer

No human approval, real audio, Windows export/input QA, public NAT or cross-device latency claim follows from this Linux source-native review. P3.5 is not marked closed here.
