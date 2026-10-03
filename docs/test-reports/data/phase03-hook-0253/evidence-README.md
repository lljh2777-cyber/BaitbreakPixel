# 0.25.3 evidence

`headless-summary.json` and `native-summary.json` list every registered current suite, command, duration and count basis. Import is separate from gameplay suites; native `visuals` contributes two completion markers, not assertions. Runtime and consumed-native hashes are recorded separately. Headless-only social guard migration did not change runtime/native-consumed code.

Focused logs are readable text. The copied network log strips trailing whitespace only; original and published SHA-256 digests are recorded in headless provenance. Selected PNGs show the actual native renderer. No opaque compressed runner logs are added. Bulk temporary logs, interrupted/source-mismatched attempts and the full social diagnostic rows remain under ignored artifacts; the bounded social summary/analysis are published with source hashes and a reproducible tool.

`diagnostic-pilot-*` contains all 16 pilot rows; `diagnostic-heldout-*` contains all 100 disjoint heldout rows, including every loss. Neither is a human balance result. Source and recomputed comparison equivalence are checked in `diagnostic-source-verification.json`.

`independent-review-probe.gd.txt` is an unchanged additional state-machine probe rerun against final production sources. Rename/copy to `.gd` in a temporary location to run its recorded command; it is not a registered aggregate or renderer replacement.
