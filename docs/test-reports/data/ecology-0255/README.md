# 0.25.5 ecology evidence

All files here contain game-specific validation, not user credentials or unrelated desktop data. They are source evidence, not a playable package. Automated/native inspection does not close the final Phase 3 human playtest.

## Reproduction and statistical meaning

- [Predeclared protocol](../../../../tools/phase03_ecology_protocol.md): four arms × twelve strata, 192 pilot rounds, 1,200 heldout rounds, 25 independent heldout seed clusters
- [Main Chinese report and manual checklist](../../PHASE03-ECOLOGY-VALIDATION-0.25.5.md)
- [Frozen baseline comparison](baseline-comparison.json): one paired regression seed, 48 identical raw rows per version; full runtime source comparison separately proves only three display/build labels differ
- [Baseline run provenance](baseline-provenance.json), [current pair provenance](baseline-current-provenance.json), [baseline readable rows](baseline-rows/manifest.json), [raw byte/canonical hash binding](baseline-rows-verification.json), [baseline actual run log](baseline-run.txt)
- [Pilot descriptive results](pilot-description.json), [pilot provenance](pilot-provenance.json), [192 pilot raw rows](pilot-rows/manifest.json), [pilot raw hash binding](pilot-rows-verification.json), [pilot run log](pilot-run.txt). Pilot is never pooled into heldout
- [Independent statistical/methodology review](methodology-review.md)
- [Heldout analysis](heldout-comparison.json), [complete merge provenance](heldout-merge-provenance.json), [1,200 heldout raw rows](heldout-rows/manifest.json), [heldout raw hash binding](heldout-rows-verification.json)

Raw row bundles use uncompressed JSONL per game-mode/challenge/policy stratum. Every original number, outcome, type total, state exposure and complete legacy stat remains; only identical `rules` is stored once. The index restores original ordering. SHA-256 checks bind each file and canonical reconstructed rows to the source run; the verification JSON separately records the original pretty-printed `rounds.json` byte hash. There is no opaque compressed payload.

```sh
python3 tools/phase03_ecology_evidence.py verify docs/test-reports/data/ecology-0255/heldout-rows --analysis-output artifacts/ecology-reconstructed-analysis.json
```

All six paired arm contrasts retain marginal 95% bootstrap intervals. Inspect each of the twelve strata; an artificial equal-weight aggregate is not a player-population average. Different timeout objectives, practice supply rules, imperfect QTE-less policies, right-censored rounds and zero-event support remain explicit.

- [Exploratory failures and setup corrections](development-notes.md), separate from formal results

## Mechanical and network validation

- [Independent state/privacy review](invariant-review.md)
- [Final headless per-suite summary](headless-summary.json), [source provenance and raw-log hashes](headless-provenance.json)
- [244 new integration assertions](headless-ecology-balance.log), [per-case evidence](headless-ecology-cases.json)
- [Food witness method and limits](headless-food-review.md), [four-condition supply summary](headless-food-summary.json), [all 4,000 raw structural case rows](headless-food-cases.jsonl)
- [Current 0/3/6 simulation and network measurement](headless-npc-statistics.json)
- [202 Python test output](python-runner.txt), [Python source stability](python-provenance.json)

The registered current suite includes the 4,000-case structural supply gate, both-role same-machine real ENet, hidden-truth/allowlist/renderer equivalence and exact snapshot replay. Structural mouth-placement/refill witnesses are not autonomous travel, human win or permanent fairness guarantees. No raw log containing hundreds of thousands of repeated PASS lines is published; per-suite counts/commands/errors and source/local-log hashes remain available in the summary/provenance.

## Native game pixels and ordinary UI

- [Native review and limitations](native-review.md)
- [22-suite results](native-summary.json), [native provenance](native-provenance.json), [all warning lines](native-warnings.txt)
- [15 ordinary-UI state/capture records](native-ui-records.json), [UI provenance](native-ui-provenance.json), [12 evidence consistency checks](native-evidence-audit.json)
- [0/3/6 frozen-frame timings](native-frame-costs.json), [original PNG hashes](native-image-sha256.json)
- [Version/phase title](native-ui-title.png), [three NPCs](native-fish-count-3.png), [six-NPC stress](native-fish-count-6.png), [social flee](native-social-flee-fish.png), [NPC line target](native-hooked-fish.png), [player foreground overlap](native-hooked-player-in-front.png), [shore lift](native-landing-angler.png)
- [Ordinary food intake](native-ui-feeding.png), [pause](native-ui-pause-before.png), [deployed rod](native-ui-angler-deployed.png), [observation cancellation](native-ui-observation-cancelled.png), [focus pause](native-ui-focus-paused.png)

Only game viewport PNGs are published. No unrelated desktop or terminal pixels are included. Driver/ObjectDB/import warnings are preserved; no Windows export, real soundcard, public NAT or cross-physical-device claim is made. The assistant's normal-UI observations do not replace the user's subjective playtest.
