#!/usr/bin/env python3
"""Summarize paired real-tick feeding evidence without declaring a winner."""
from __future__ import annotations
import argparse
import json
import random
import statistics
from itertools import combinations
from pathlib import Path

POLICIES = ('SuckOnly', 'BiteOnly', 'Mixed')
TYPES = ('cluster', 'worm', 'chunk')
METRICS = {
    'fish_win_rate': lambda r: float(r['winner'] == 'fish'),
    'home_win_rate': lambda r: float(r['home_win']),
    'food_consumed': lambda r: r['food_consumed'],
    'satiety_final': lambda r: r['satiety_final'],
    'satiety_mean': lambda r: r['satiety_mean'],
    'satiety_min': lambda r: r['satiety_min'],
    'hook_contacts': lambda r: r['hook_contacts'],
    'hook_events': lambda r: r['hook_events'],
    'hook_event_rate': lambda r: float(r['hook_events'] > 0),
    'feeding_attempts': lambda r: r['feeding_attempts'],
    'feeding_seconds': lambda r: r['feeding_seconds'],
    'suction_command_attempts': lambda r: r['suction_command_attempts'],
    'suction_command_seconds': lambda r: r['suction_command_seconds'],
    'automatic_bite_events': lambda r: r['automatic_bite_events'],
    'automatic_bite_while_suction_command': lambda r: r['automatic_bite_while_suction_command'],
    'duration': lambda r: r['duration'],
    'suck_eligible_ticks': lambda r: r['stats']['suck_attempts'],
    'suck_intake_ticks': lambda r: r['stats']['suck_successes'],
    'bite_candidate_attempts': lambda r: r['stats']['bite_attempts'],
    'bite_intake_events': lambda r: r['stats']['bite_successes'],
    'suction_context_hook_contacts': lambda r: r['stats']['suck_hook_contacts'],
    'mouth_context_hook_contacts': lambda r: r['stats']['bite_hook_contacts'],
}


def summarize(rows: list[dict], bootstrap: int = 2000) -> dict:
    if bootstrap < 100:
        raise ValueError('At least 100 bootstrap replicates required')
    by_policy = {name: {} for name in POLICIES}
    phases = {row['phase'] for row in rows}
    if len(phases) != 1:
        raise ValueError('Do not pool pilot and held-out rows')
    for row in rows:
        if row['seed'] in by_policy[row['policy']]:
            raise ValueError('Duplicate policy/seed row')
        by_policy[row['policy']][row['seed']] = row
        if abs(row['ticks'] / 60.0 - row['duration']) > 1e-6:
            raise ValueError('Duration not generated from actual 60 Hz ticks')
        if abs(sum(v['food'] for v in row['per_type'].values()) - row['food_consumed']) > 1e-6:
            raise ValueError('Per-type food does not reconcile')
        if row['automatic_bite_events'] != row['stats']['bite_successes']:
            raise ValueError('Bite event measurement differs from authority stats')
        for kind in TYPES:
            type_row = row['per_type'][kind]
            for measured, recorded in [('food', 'food_by_type'), ('suction_food', 'suck_intake_by_type'), ('automatic_bite_food', 'bite_intake_by_type')]:
                if abs(type_row[measured] - row['stats'][recorded][kind]) > 1e-6:
                    raise ValueError('Per-type intake differs from independent authority stats')
        if row['policy'] == 'BiteOnly' and row['suction_command_seconds']:
            raise ValueError('BiteOnly issued suction')
    seeds = sorted(by_policy[POLICIES[0]])
    if not seeds or any(set(by_policy[name]) != set(seeds) for name in POLICIES):
        raise ValueError('Complete paired seed sets required')
    result = {
        'phase': phases.pop(), 'seeds': seeds, 'paired_seeds': len(seeds),
        'bootstrap_replicates': bootstrap,
        'note': 'No winning policy is imposed. Seed-sample uncertainty is not a human-playability verdict; fish QTE is unavailable through FishObservation. Per-type outcome composition is descriptive, not randomized within-type treatment evidence.',
        'policies': {}, 'paired_differences': {},
    }
    for name, mapping in by_policy.items():
        samples = list(mapping.values())
        entry = {'completed': sum(r['completed'] for r in samples),
                 'incomplete_seeds': [r['seed'] for r in samples if not r['completed']],
                 'outcome_reasons': {},
                 'metrics': {metric: statistics.mean(fn(r) for r in samples) for metric, fn in METRICS.items()},
                 'per_type': {},
                 'mode_choices': {mode: sum(r['mode_choices'][mode] for r in samples) for mode in ('suck', 'bite')},
                 'mode_seconds': {mode: statistics.mean(r['mode_seconds'][mode] for r in samples) for mode in ('suck', 'bite', 'seek', 'home')}}
        for row in samples:
            reason = row['reason'] or 'incomplete'
            entry['outcome_reasons'][reason] = entry['outcome_reasons'].get(reason, 0) + 1
        for kind in TYPES:
            entry['per_type'][kind] = {key: statistics.mean(r['per_type'][kind][key] for r in samples)
                                      for key in samples[0]['per_type'][kind]}
        suction_attempts = sum(r['stats']['suck_attempts'] for r in samples)
        bite_attempts = sum(r['stats']['bite_attempts'] for r in samples)
        entry['action_diagnostics'] = {
            'suck_intake_ticks_per_eligible_tick': sum(r['stats']['suck_successes'] for r in samples) / suction_attempts if suction_attempts else None,
            'bite_intake_events_per_candidate_attempt': sum(r['stats']['bite_successes'] for r in samples) / bite_attempts if bite_attempts else None,
            'note': 'Different denominators: suction counts eligible ticks; Bite counts candidate attempts after hook arbitration. The near-100% Bite rate is not a risk-adjusted feeding success rate. Hook-contact contexts can overlap and do not establish action causality.',
        }
        result['policies'][name] = entry
    rng = random.Random(203103)
    for left, right in combinations(POLICIES, 2):
        comparison = {}
        for metric, fn in METRICS.items():
            differences = [fn(by_policy[right][seed]) - fn(by_policy[left][seed]) for seed in seeds]
            samples = sorted(statistics.mean(rng.choices(differences, k=len(seeds))) for _ in range(bootstrap))
            comparison[metric] = {'mean': statistics.mean(differences),
                                  'paired_bootstrap_95_percent': [samples[int(bootstrap * .025)], samples[int(bootstrap * .975) - 1]]}
        result['paired_differences'][f'{right} minus {left}'] = comparison
    # A stringent diagnostic, not a required acceptance result. Duration and
    # attempt counts have no universally favorable direction and are excluded.
    directions = {'food_consumed': 1, 'satiety_mean': 1, 'fish_win_rate': 1, 'hook_contacts': -1, 'hook_events': -1}
    dominance = []
    weak_dominance = []
    for pair, metrics in result['paired_differences'].items():
        right, left = pair.split(' minus ')
        for candidate, other, sign in [(right, left, 1), (left, right, -1)]:
            point_effects = [metrics[metric]['mean'] * directions[metric] * sign for metric in directions]
            if all(value >= -1e-9 for value in point_effects) and any(value > 1e-9 for value in point_effects):
                weak_dominance.append({'candidate': candidate, 'other': other})
            if all(min(value * directions[metric] * sign for value in metrics[metric]['paired_bootstrap_95_percent']) > 0
                   for metric in directions):
                dominance.append({'candidate': candidate, 'other': other})
    result['strict_dominance'] = {
        'criterion': 'Every paired95% bootstrap interval strictly favorable on food, time-mean satiety, fish wins, hook contacts and hook events; exploratory marginal intervals, not simultaneous confidence.',
        'directions': directions, 'qualifying_pairs': dominance,
        'point_estimate_weak_dominance': {'criterion': 'Mean no worse on every dimension and strictly better on at least one; tolerance1e-9, descriptive point estimates only.', 'qualifying_pairs': weak_dominance},
        'note': 'Point-estimate dominance is reported even when confidence intervals overlap. Failure of the stringent interval criterion is neither equivalence nor proof of no dominance. No minimum win rate or forced winner.',
    }
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rounds', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = summarize(json.loads(args.rounds.read_text()))
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
