#!/usr/bin/env python3
"""Offline P3.5 factorial ecology validation and seed-cluster inference.

No instrumentation or estimator is imported by gameplay. Marginal descriptive
intervals do not constitute a balance target, causal mechanism test or human
win-rate estimate. Every selected seed must retain its complete 48-round grid.
"""
from __future__ import annotations

import argparse
from collections import Counter
import itertools
import json
import math
from pathlib import Path
import random
import statistics

MODES = ('NoNPC', 'PassiveNPC', 'ForagingNPC', 'HookableNPC')
GAME_MODES = ('survival', 'duel')
POLICIES = ('SuckOnly', 'BiteOnly', 'Mixed')
STATES = ('WANDER', 'APPROACH_FOOD', 'FEED', 'HESITATE', 'FLEE', 'COMPETE', 'HOOKED', 'LANDING')
STRATA = tuple(f'{game}/{"challenge" if challenge else "practice"}/{policy}'
               for game in GAME_MODES for challenge in (True, False) for policy in POLICIES)
BASE_METRICS = (
    'player_food', 'npc_food', 'hook_events', 'hook_contacts', 'duration',
    'player_hooked_seconds', 'npc_hook_count', 'npc_escapes', 'npc_breaks',
    'wrong_catches', 'npc_hooked_seconds', 'lifecycle_events',
    'lifecycle_per_sim_minute', 'no_food_seconds', 'longest_no_food_seconds',
    'longest_player_no_intake_seconds', 'replacement_ids_allocated')
EXTRA_METRICS = (
    'player_satiety_final', 'player_satiety_min', 'player_satiety_mean',
    'player_critical_seconds', 'npc_active_seconds', 'npc_satiety_integral',
    'npc_critical_seconds', 'npc_starving_seconds', 'npc_social_reaction_entries',
    'npc_feeding_events', 'player_npc_food_contests', 'npc_target_switches',
    'successful_respawns', 'pending_respawns', 'supply_eligible_seconds',
    'no_food_supply_eligible_seconds', 'player_food_while_npc_hooked',
    'player_intake_ticks_while_npc_hooked', 'npc_occupied_ticks', 'player_home_attempts')
METRICS = BASE_METRICS + EXTRA_METRICS
COUNTERS = (
    'hook_events', 'hook_contacts', 'npc_hook_count', 'npc_escapes', 'npc_breaks',
    'wrong_catches', 'lifecycle_events', 'replacement_ids_allocated',
    'npc_social_reaction_entries', 'npc_feeding_events', 'player_npc_food_contests',
    'npc_target_switches', 'successful_respawns', 'pending_respawns',
    'player_intake_ticks_while_npc_hooked', 'npc_occupied_ticks', 'player_home_attempts')
TIME_METRICS = ('player_hooked_seconds', 'npc_hooked_seconds', 'no_food_seconds',
                'longest_no_food_seconds', 'longest_player_no_intake_seconds',
                'player_critical_seconds', 'supply_eligible_seconds', 'no_food_supply_eligible_seconds')
EPS = 1e-6
BOOTSTRAP_SEED = 735736


def _number(value, key, *, maximum=None):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
        raise ValueError(f'Invalid nonnegative finite metric: {key}')
    if maximum is not None and value > maximum + EPS:
        raise ValueError(f'Metric exceeds allowed exposure/range: {key}')
    return value


def _integer(value, key, *, minimum=0):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or int(value) != value or value < minimum:
        raise ValueError(f'Invalid integer: {key}')
    return int(value)


def _equal(a, b, description):
    if abs(a - b) > EPS:
        raise ValueError(f'Does not reconcile: {description}')


def stratum_key(row):
    return f'{row["game_mode"]}/{"challenge" if row["challenge"] else "practice"}/{row["policy"]}'


def validate_rows(rows, seeds, max_ticks=22200):
    """Require complete design and physically coherent measured raw round rows."""
    if not seeds or any(type(seed) is not int for seed in seeds) or len(set(seeds)) != len(seeds):
        raise ValueError('Require nonempty distinct integer paired seeds')
    if type(max_ticks) is not int or max_ticks < 1:
        raise ValueError('Invalid maximum tick horizon')
    grouped = {key: {mode: {} for mode in MODES} for key in STRATA}
    reference_rules = None
    for row in rows:
        if row['game_mode'] not in GAME_MODES or type(row['challenge']) is not bool or row['policy'] not in POLICIES:
            raise ValueError('Unsupported game mode, challenge flag or player policy')
        key = stratum_key(row)
        if row['stratum_key'] != key:
            raise ValueError('Inconsistent stratum key')
        mode, seed = row['mode'], row['seed']
        if mode not in MODES or type(seed) is not int or seed not in seeds:
            raise ValueError('Unknown arm or unselected seed')
        if seed in grouped[key][mode]:
            raise ValueError('Duplicate stratum/arm/seed row')
        grouped[key][mode][seed] = row
        if type(row['npc_count']) is not int or row['npc_count'] != (0 if mode == 'NoNPC' else 3):
            raise ValueError('Wrong configured NPC population')
        if not isinstance(row['rules'], dict) or not row['rules']:
            raise ValueError('Missing frozen rules')
        if reference_rules is None:
            reference_rules = row['rules']
        if row['rules'] != reference_rules:
            raise ValueError('Production rules differ across arms, strata or seeds')
        for name in METRICS:
            _number(row[name], name)
        for name in COUNTERS:
            _integer(row[name], name)
        ticks = _integer(row['ticks'], 'ticks', minimum=1)
        if ticks > max_ticks or row.get('max_ticks', max_ticks) != max_ticks:
            raise ValueError('Round exceeds or disagrees with selected horizon')
        _equal(row['duration'], ticks / 60, 'actual 60 Hz duration')
        if type(row['completed']) is not bool or row['winner'] not in ('', 'fish', 'angler') or not isinstance(row['reason'], str):
            raise ValueError('Invalid outcome')
        if row['completed'] != bool(row['winner']) or row['completed'] != bool(row['reason']):
            raise ValueError('Incomplete round must not masquerade as a completed outcome')
        if not row['completed'] and ticks != max_ticks:
            raise ValueError('Unfinished round stopped before selected horizon')
        if type(row['home_win']) is not bool or row['home_win'] != (row['winner'] == 'fish' and row['reason'] == 'home'):
            raise ValueError('Inconsistent home victory')
        if row['reason'] == 'timeout':
            expected_winner = 'fish' if row['game_mode'] == 'duel' else 'angler'
            if not row['challenge'] or row['winner'] != expected_winner:
                raise ValueError('Timeout outcome contradicts game-mode rules')
        goal = _number(row['food_goal'], 'food_goal')
        _equal(goal, row['rules']['food_goal' if row['challenge'] else 'practice_goal'], 'public effective food goal')
        goal_tick = _integer(row['player_food_goal_tick'], 'player_food_goal_tick', minimum=-1)
        if goal_tick > ticks or (goal_tick >= 0) != (row['player_food'] >= goal - .001):
            raise ValueError('Goal-reached tick contradicts monotonic food total')
        if row['home_win'] and goal_tick < 0:
            raise ValueError('Home victory without effective food goal')
        for total, typed in [('player_food', 'player_food_by_type'), ('npc_food', 'npc_food_by_type')]:
            if not isinstance(row[typed], dict) or set(row[typed]) != {'cluster', 'worm', 'chunk'}:
                raise ValueError('Missing or unknown food type')
            for name, value in row[typed].items():
                _number(value, f'{typed}.{name}')
            _equal(row[total], sum(row[typed].values()), f'{total} typed intake')
        observed = _integer(row['observed_npc_attachments'], 'observed_npc_attachments')
        _equal(observed, row['npc_hook_count'], 'observed hook transitions')
        target = _integer(row['final_hook_target_fish_id'], 'final_hook_target_fish_id', minimum=-1)
        if target == 0:
            raise ValueError('Invalid zero hook target')
        unresolved = row['npc_hook_count'] - sum(row[name] for name in ('npc_escapes', 'npc_breaks', 'wrong_catches'))
        _equal(unresolved, int(target > 1), 'NPC hook lifecycle closure')
        _equal(row['successful_respawns'] + row['pending_respawns'], row['wrong_catches'], 'capture/respawn closure')
        if row['successful_respawns'] > row['replacement_ids_allocated'] or row['pending_respawns'] > row['npc_count']:
            raise ValueError('Impossible successful/pending respawn population')
        _equal(row['npc_occupied_ticks'] / 60, row['npc_hooked_seconds'], 'pre-tick NPC occupied authority time')
        _equal(row['lifecycle_per_sim_minute'], row['lifecycle_events'] * 60 / row['duration'], 'bait lifecycle rate')
        for name in TIME_METRICS:
            _number(row[name], name, maximum=row['duration'])
        _number(row['longest_no_food_seconds'], 'longest_no_food_seconds', maximum=row['no_food_seconds'])
        _number(row['no_food_supply_eligible_seconds'], 'no_food_supply_eligible_seconds', maximum=min(row['no_food_seconds'], row['supply_eligible_seconds']))
        _number(row['player_food_while_npc_hooked'], 'player_food_while_npc_hooked', maximum=row['player_food'])
        _number(row['player_intake_ticks_while_npc_hooked'], 'player_intake_ticks_while_npc_hooked', maximum=row['npc_occupied_ticks'])
        if (row['player_food_while_npc_hooked'] > EPS) != (row['player_intake_ticks_while_npc_hooked'] > 0):
            raise ValueError('Occupied player intake amount/ticks disagree')
        _number(row['minimum_available_food'], 'minimum_available_food')
        for name in ('player_satiety_final', 'player_satiety_min', 'player_satiety_mean'):
            _number(row[name], name, maximum=100)
        if row['player_satiety_min'] > min(row['player_satiety_final'], row['player_satiety_mean']) + EPS:
            raise ValueError('Player minimum satiety exceeds mean/final')
        _number(row['npc_active_seconds'], 'npc_active_seconds', maximum=row['npc_count'] * row['duration'])
        _number(row['npc_satiety_integral'], 'npc_satiety_integral', maximum=100 * row['npc_active_seconds'])
        _number(row['npc_critical_seconds'], 'npc_critical_seconds', maximum=row['npc_active_seconds'])
        _number(row['npc_starving_seconds'], 'npc_starving_seconds', maximum=row['npc_critical_seconds'])
        if not isinstance(row['npc_state_seconds'], dict) or set(row['npc_state_seconds']) != set(STATES):
            raise ValueError('Missing/unknown NPC active state exposure')
        for state, value in row['npc_state_seconds'].items():
            _number(value, 'npc_state_seconds.' + state)
        _equal(sum(row['npc_state_seconds'].values()), row['npc_active_seconds'], 'NPC active state exposure')
        if mode == 'NoNPC':
            if row['npc_satiety_min'] is not None or row['npc_active_seconds'] != 0:
                raise ValueError('NoNPC must have null NPC minimum and zero exposure')
        else:
            minimum = _number(row['npc_satiety_min'], 'npc_satiety_min', maximum=100)
            if row['npc_active_seconds'] <= 0 or minimum > row['npc_satiety_integral'] / row['npc_active_seconds'] + EPS:
                raise ValueError('NPC minimum exceeds exposed mean or no NPC exposure')
        if mode != 'HookableNPC':
            for name in ('npc_hook_count', 'npc_escapes', 'npc_breaks', 'wrong_catches', 'npc_hooked_seconds',
                         'replacement_ids_allocated', 'successful_respawns', 'pending_respawns',
                         'npc_occupied_ticks', 'player_food_while_npc_hooked', 'player_intake_ticks_while_npc_hooked'):
                if row[name] != 0:
                    raise ValueError('Nonhookable control reports NPC hook consequences')
        if mode in ('NoNPC', 'PassiveNPC'):
            for name in ('npc_food', 'npc_feeding_events', 'player_npc_food_contests', 'npc_target_switches', 'npc_social_reaction_entries'):
                if row[name] != 0:
                    raise ValueError('Nonforaging control reports active NPC behavior')
        stats_aliases = {'player_food': 'food_consumed', 'npc_food': 'npc_food_consumed',
                         'player_hooked_seconds': 'hooked_seconds'}
        for name in ('hook_events', 'npc_hook_count', 'npc_escapes', 'npc_breaks', 'wrong_catches',
                     'npc_hooked_seconds', 'npc_feeding_events', 'player_npc_food_contests', 'npc_target_switches'):
            stats_aliases[name] = name
        if not isinstance(row['stats'], dict):
            raise ValueError('Missing authority stats')
        for metric, stat in stats_aliases.items():
            _number(row['stats'][stat], 'stats.' + stat)
            _equal(row[metric], row['stats'][stat], metric + ' authority stats')
    if any(set(grouped[key][mode]) != set(seeds) for key in STRATA for mode in MODES):
        raise ValueError('Incomplete factorial sample; require all 48 rows per selected seed')
    return grouped


def _ratio(numerator, denominator):
    return numerator / denominator if denominator else None


def _metrics(row):
    values = {key: row[key] for key in METRICS}
    values.update(
        fish_win_fraction=float(row['winner'] == 'fish'),
        home_win_fraction=float(row['home_win']),
        completion_fraction=float(row['completed']),
        fish_win_upper_bound=float(row['winner'] == 'fish' or not row['completed']),
        player_hook_fraction=float(row['hook_events'] > 0),
        npc_hook_fraction=float(row['npc_hook_count'] > 0),
        wrong_catch_fraction=float(row['wrong_catches'] > 0),
        food_goal_reached_fraction=float(row['player_food_goal_tick'] >= 0),
        npc_occupied_fraction=row['npc_occupied_ticks'] / row['ticks'],
        npc_satiety_mean=_ratio(row['npc_satiety_integral'], row['npc_active_seconds']),
        npc_critical_exposure_fraction=_ratio(row['npc_critical_seconds'], row['npc_active_seconds']),
        npc_starving_exposure_fraction=_ratio(row['npc_starving_seconds'], row['npc_active_seconds']),
        no_food_supply_eligible_fraction=_ratio(row['no_food_supply_eligible_seconds'], row['supply_eligible_seconds']),
    )
    values.update({f'npc_state_seconds_{state}': row['npc_state_seconds'][state] for state in STATES})
    return values


class _Bootstrap:
    """Reuse one seed resampling scheme for every stratum/arm/metric."""
    def __init__(self, n, resamples):
        rng = random.Random(BOOTSTRAP_SEED)
        self.weights = [tuple(Counter(rng.randrange(n) for _ in range(n)).items()) for _ in range(resamples)]
        self.n = n
        self.resamples = resamples
        self.cache = {}

    def estimate(self, diffs):
        support = sum(value is not None for value in diffs)
        # Undefined opportunity denominators do not justify selected-pair CIs.
        if support != self.n:
            return {'mean': None, 'paired_bootstrap_95_percent': None, 'paired_seeds': support,
                    'selected_seeds': self.n, 'status': 'undefined_denominator_in_selected_pairs'}
        values = tuple(diffs)
        if values in self.cache:
            return self.cache[values].copy()
        mean = statistics.mean(values)
        interval = None
        if self.n >= 2:
            if min(values) == max(values):
                interval = [mean, mean]
            else:
                boot = sorted(sum(values[index] * count for index, count in weights) / self.n for weights in self.weights)
                interval = [boot[int(self.resamples * .025)], boot[int(self.resamples * .975) - 1]]
        result = {'mean': mean, 'paired_bootstrap_95_percent': interval,
                  'paired_seeds': support, 'selected_seeds': self.n,
                  'status': 'constant_observed_differences' if min(values) == max(values) else 'descriptive',
                  'independent_seed_warning': 'Single seed cannot estimate sampling variation' if self.n < 2 else None}
        self.cache[values] = result
        return result.copy()


def _mean_metrics(samples):
    return {name: {'mean': statistics.mean(present) if present else None, 'defined_rounds': len(present),
                   'selected_rounds': len(samples)}
            for name in samples[0] for present in [[sample[name] for sample in samples if sample[name] is not None]]}


def _paired(mode_values, seeds, bootstrap):
    effects = {}
    for left, right in itertools.combinations(MODES, 2):
        effects[f'{right} minus {left}'] = {
            name: bootstrap.estimate([None if mode_values[left][i][name] is None or mode_values[right][i][name] is None
                                      else mode_values[right][i][name] - mode_values[left][i][name]
                                      for i in range(len(seeds))])
            for name in mode_values[left][0]}
    return effects


def _coverage(samples):
    return {
        'npc_hooks': sum(row['npc_hook_count'] for row in samples),
        'npc_escapes': sum(row['npc_escapes'] for row in samples),
        'npc_breaks': sum(row['npc_breaks'] for row in samples),
        'wrong_catches': sum(row['wrong_catches'] for row in samples),
        'successful_respawns': sum(row['successful_respawns'] for row in samples),
        'pending_respawns': sum(row['pending_respawns'] for row in samples),
        'occupied_intake_rounds': sum(row['player_food_while_npc_hooked'] > 0 for row in samples),
        'hook_event_seed_support': len({row['seed'] for row in samples if row['npc_hook_count'] > 0}),
        'note': 'A measured zero does not demonstrate the mechanism or a zero population event rate; controlled gates remain separate.'}


def summarize(rows, seeds, bootstrap=2000, max_ticks=22200):
    if type(bootstrap) is not int or bootstrap < 40:
        raise ValueError('At least 40 integer bootstrap resamples required')
    grouped = validate_rows(rows, seeds, max_ticks)
    estimator = _Bootstrap(len(seeds), bootstrap)
    result = {
        'format': 'phase03-ecology-analysis-v1', 'seeds': list(seeds), 'paired_seeds': len(seeds),
        'rounds': len(rows), 'strata_count': len(STRATA), 'max_ticks': max_ticks,
        'bootstrap': {'resamples': bootstrap, 'random_seed': BOOTSTRAP_SEED, 'unit': 'complete seed across all 12 strata and four arms',
                      'interval': 'marginal percentile 95%; not multiplicity-adjusted; no significance/balance acceptance claims'},
        'primary_contrasts': ['ForagingNPC minus PassiveNPC', 'HookableNPC minus ForagingNPC'],
        'strata': {},
        'interpretation': [
            'All rounds retained. Fish wins/all selected rounds is a finite-horizon observed fraction, not a completed-only win rate.',
            'Fish win fraction and fish_win_upper_bound bracket unresolved outcomes; no survival extrapolation is made.',
            'Twelve policies/settings for one seed are correlated, not twelve independent seeds.',
            'Equal-weight aggregate is an artificial design summary, not player-population prevalence. Inspect every stratum.',
            'Duel timeout awards fish; survival timeout awards angler. Home wins and outcome reasons remain separate.',
            'Practice supply eligibility differs structurally for no/passive versus foraging populations under existing rules.',
            'Conditional exposure rates describe opportunities; they are not adjusted causal effects.',
            'Constant empirical bootstrap intervals and zero counts do not imply population certainty.',
            'No 50% target; no bot-specific tuning or human balance acceptance is performed.'],
    }
    all_values = {}
    control_keys = ('player_food', 'player_food_by_type', 'winner', 'reason', 'completed', 'hook_events',
                    'hook_contacts', 'duration', 'lifecycle_events', 'stats', 'player_food_goal_tick', 'player_home_attempts')
    for key in STRATA:
        mode_values = {mode: [_metrics(grouped[key][mode][seed]) for seed in seeds] for mode in MODES}
        all_values[key] = mode_values
        modes = {}
        for mode in MODES:
            samples = [grouped[key][mode][seed] for seed in seeds]
            modes[mode] = {
                'completed': sum(row['completed'] for row in samples),
                'incomplete_seeds': [row['seed'] for row in samples if not row['completed']],
                'outcome_reasons': dict(sorted(Counter(row['reason'] or 'incomplete' for row in samples).items())),
                'metrics': _mean_metrics(mode_values[mode]),
                'totals': {name: sum(row[name] for row in samples) for name in COUNTERS},
                'pooled_exposure_rates': {
                    'npc_hooks_per_sim_minute': 60 * sum(row['npc_hook_count'] for row in samples) / sum(row['duration'] for row in samples),
                    'npc_food_per_active_npc_minute': _ratio(60 * sum(row['npc_food'] for row in samples), sum(row['npc_active_seconds'] for row in samples)),
                    'player_food_per_npc_occupied_second': _ratio(sum(row['player_food_while_npc_hooked'] for row in samples), sum(row['npc_hooked_seconds'] for row in samples)),
                    'npc_hooked_fraction': sum(row['npc_hooked_seconds'] for row in samples) / sum(row['duration'] for row in samples)},
                'event_coverage': _coverage(samples)}
        result['strata'][key] = {
            'modes': modes, 'paired_differences': _paired(mode_values, seeds, estimator),
            'passive_control_mismatched_seeds': [seed for seed in seeds if any(grouped[key]['NoNPC'][seed][name] != grouped[key]['PassiveNPC'][seed][name] for name in control_keys)]}
    aggregate_values = {}
    for mode in MODES:
        aggregate_values[mode] = []
        for i, _seed in enumerate(seeds):
            values = {}
            for name in all_values[STRATA[0]][mode][i]:
                selected = [all_values[key][mode][i][name] for key in STRATA]
                values[name] = statistics.mean(selected) if all(value is not None for value in selected) else None
            aggregate_values[mode].append(values)
    result['overall_equal_weight_strata'] = {
        'independent_seed_clusters': len(seeds), 'stratum_weight': 1 / len(STRATA),
        'modes': {mode: {'metrics': _mean_metrics(aggregate_values[mode]),
                         'event_coverage': _coverage([row for row in rows if row['mode'] == mode])} for mode in MODES},
        'paired_differences': _paired(aggregate_values, seeds, estimator)}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rounds', type=Path)
    parser.add_argument('--seeds', type=int, nargs='+', required=True)
    parser.add_argument('--max-ticks', type=int, default=22200)
    parser.add_argument('--bootstrap', type=int, default=2000)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Preserve existing evidence; choose a new output path')
    report = summarize(json.loads(args.rounds.read_text()), args.seeds, args.bootstrap, args.max_ticks)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')


if __name__ == '__main__':
    main()
