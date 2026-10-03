#!/usr/bin/env python3
"""Offline behavior/truth diagnostic; never imported by production GDScript."""
from __future__ import annotations
import argparse
import gzip
from collections import Counter, defaultdict
import json
from pathlib import Path

FORMAT = "phase03-social-diagnostics-v1"
STATES = {"WANDER", "APPROACH_FOOD", "HESITATE", "FLEE", "COMPETE", "FEED"}


def validate(report):
    if report.get("format") != FORMAT or report.get("source_stable") is not True:
        raise ValueError("Unsupported format or changing source; retain as exploratory only")
    if not report.get("source_hashes"):
        raise ValueError("Missing source fingerprints")
    if report.get("mismatched_counterfactual_pairs") != 0:
        raise ValueError("Hidden-truth counterfactual mismatch")
    groups = defaultdict(list)
    seen = set()
    splits = {}
    for row in report["rows"]:
        if row["dataset"] not in {"natural", "counterfactual"} or row["split"] not in {"train", "heldout"}:
            raise ValueError("Invalid dataset/split")
        if row["state"] not in STATES or type(row["hook_truth"]) is not bool or type(row["feeding"]) is not bool:
            raise ValueError("Invalid behavior or diagnostic label")
        seed_key = (row["dataset"], row["seed"])
        if seed_key in splits and splits[seed_key] != row["split"]:
            raise ValueError("Seed leaked across train/heldout")
        splits[seed_key] = row["split"]
        key = (row["dataset"], row["episode"], row["fish_id"], row["tick"], row["hook_truth"] if row["dataset"] == "counterfactual" else None)
        if key in seen:
            raise ValueError("Duplicate sampled observation")
        seen.add(key)
        if row["dataset"] == "counterfactual":
            groups[key[:-1]].append(row)
    if len(groups) != report["matched_counterfactual_pairs"]:
        raise ValueError("Counterfactual pair count does not match rows")
    for pair in groups.values():
        if len(pair) != 2 or {r["hook_truth"] for r in pair} != {False, True}:
            raise ValueError("Missing balanced counterfactual label partner")
        a, b = pair
        # Labels are the only permitted paired row difference. Production authority
        # including vectors, private memory and RNG is also checked in the harness.
        if {k: v for k, v in a.items() if k != "hook_truth"} != {k: v for k, v in b.items() if k != "hook_truth"}:
            raise ValueError("Counterfactual observable/decision mismatch")


def class_counts(rows):
    counts = Counter(r["hook_truth"] for r in rows)
    return {"unhooked": counts[False], "hooked": counts[True]}


def feature(row):
    # Explicit allowlist: no truth, bait IDs, seed IDs, cue provenance or hunger.
    return row["state"], row["feeding"], min(3, int(row["speed"] // 10))


def classifier(rows):
    train = [r for r in rows if r["split"] == "train"]
    test = [r for r in rows if r["split"] == "heldout"]
    bins = defaultdict(Counter)
    for row in train:
        bins[feature(row)][row["hook_truth"]] += 1
    train_counts = Counter(r["hook_truth"] for r in train)
    default = train_counts[True] > train_counts[False]
    predictions = []
    for row in test:
        bucket = bins.get(feature(row), Counter())
        predictions.append(default if bucket[True] == bucket[False] else bucket[True] > bucket[False])
    tp = sum(p and r["hook_truth"] for p, r in zip(predictions, test))
    tn = sum(not p and not r["hook_truth"] for p, r in zip(predictions, test))
    fp = sum(p and not r["hook_truth"] for p, r in zip(predictions, test))
    fn = sum(not p and r["hook_truth"] for p, r in zip(predictions, test))
    accuracy = (tp + tn) / len(test) if test else None
    balanced = (tp / (tp + fn) + tn / (tn + fp)) / 2 if tp + fn and tn + fp else None
    counts = class_counts(test)
    baseline = max(counts.values()) / len(test) if test else None
    support = {label: len({r["seed"] for r in test if r["hook_truth"] == truth}) for label, truth in [("unhooked", False), ("hooked", True)]}
    sufficient = min(counts.values(), default=0) >= 20 and min(support.values(), default=0) >= 2 and min(class_counts(train).values(), default=0) >= 20
    flags = []
    # Even small/imbalanced data must visibly flag apparently near-perfect raw
    # performance; balance and independent seed support explain its limitations.
    if accuracy is not None and accuracy > .95:
        flags.append("RAW_ACCURACY_ABOVE_95_REVIEW_BALANCE")
    elif accuracy is not None and accuracy > .90:
        flags.append("RAW_ACCURACY_ABOVE_90_REVIEW_BALANCE")
    if balanced is not None and balanced > .95:
        flags.append("BALANCED_ACCURACY_ABOVE_95_CRITICAL_REVIEW")
    elif balanced is not None and balanced > .90:
        flags.append("BALANCED_ACCURACY_ABOVE_90_REVIEW")
    if not sufficient:
        flags.append("INSUFFICIENT_CLASS_OR_SEED_SUPPORT")
    if baseline is not None and baseline > .90:
        flags.append("HIGH_MAJORITY_BASELINE")
    return {"features": ["offline_behavior_state", "feeding_intent", "public_speed_bin_10px"],
            "train_rows": len(train), "heldout_rows": len(test), "train_classes": class_counts(train),
            "heldout_classes": counts, "heldout_class_seed_support": support,
            "train_seeds": sorted({r["seed"] for r in train}), "heldout_seeds": sorted({r["seed"] for r in test}),
            "accuracy": accuracy, "balanced_accuracy": balanced, "heldout_majority_baseline": baseline,
            "confusion": {"tp": tp, "tn": tn, "fp": fp, "fn": fn}, "sufficient_support": sufficient,
            "behavior_truth": {state: class_counts([r for r in rows if r["state"] == state]) for state in sorted(STATES)},
            "flags": flags, "unseen_feature_rows": sum(feature(r) not in bins for r in test)}


def summarize(report):
    validate(report)
    result = {"format": "phase03-social-analysis-v1", "source_hashes": report["source_hashes"], "datasets": {},
              "counterfactual_pairs": report["matched_counterfactual_pairs"],
              "interpretation": "Review flags are diagnostics, not proof of cheating or human-readable certainty. Repeated frames are correlated; no frame-level confidence interval is claimed. Counterfactual and natural estimates stay separate."}
    for dataset in ("natural", "counterfactual"):
        rows = [r for r in report["rows"] if r["dataset"] == dataset]
        by_state = {}
        for state in sorted(STATES):
            subset = [r for r in rows if r["state"] == state]
            by_state[state] = {"rows": len(subset), **class_counts(subset)}
        result["datasets"][dataset] = {"rows": len(rows), "classes": class_counts(rows), "behavior_truth": by_state,
            "false_positive_avoidance_unhooked": sum(not r["hook_truth"] and r["state"] in {"HESITATE", "FLEE"} for r in rows),
            "false_negative_approach_or_feed_hooked": sum(r["hook_truth"] and r["state"] in {"APPROACH_FOOD", "COMPETE", "FEED"} for r in rows),
            "starving_risk_with_motion_cues": sum(r["satiety"] <= 10 and r["scene"] == "motion" and r["state"] in {"APPROACH_FOOD", "COMPETE", "FEED"} for r in rows),
            "classifier": classifier(rows),
            "predictive_without_witnessed_result": classifier([r for r in rows if not r.get("witnessed_danger_recent", False) and r["scene"] != "visible_outcome"]),
            "witnessed_result": classifier([r for r in rows if r.get("witnessed_danger_recent", False) or r["scene"] == "visible_outcome"])}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    payload = gzip.decompress(args.report.read_bytes()).decode("utf-8") if args.report.suffix == ".gz" else args.report.read_text()
    result = summarize(json.loads(payload))
    payload = json.dumps(result, indent=2, sort_keys=True)
    if args.output:
        with args.output.open("x") as file:
            file.write(payload + "\n")
    print(payload)


if __name__ == "__main__":
    main()
