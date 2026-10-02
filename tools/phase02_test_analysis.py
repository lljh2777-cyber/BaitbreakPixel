#!/usr/bin/env python3
"""Small deterministic regression tests for feeding-evidence analysis."""
import copy
import unittest
from phase02_compare_feeding import summarize, POLICIES, TYPES


def rows_fixture():
    rows = []
    for seed in (10, 11):
        for index, policy in enumerate(POLICIES):
            food = 10.0 - index  # Mixed may lose; analysis must retain that result.
            per_type = {kind: {'grains': 0, 'food': 0.0, 'satiety_gross': 0.0,
                              'satiety_effective': 0.0, 'automatic_bite_events': 0,
                              'automatic_bite_grains': 0, 'automatic_bite_food': 0.0,
                              'suction_grains': 0, 'suction_food': 0.0} for kind in TYPES}
            per_type['cluster'].update(grains=1, food=food, automatic_bite_events=1,
                                       automatic_bite_grains=1, automatic_bite_food=food)
            stats = {'bite_attempts': 1, 'bite_successes': 1, 'suck_attempts': 0, 'suck_successes': 0,
                     'suck_hook_contacts': 0, 'bite_hook_contacts': 0,
                     'food_by_type': {'cluster': food, 'worm': 0.0, 'chunk': 0.0},
                     'bite_intake_by_type': {'cluster': food, 'worm': 0.0, 'chunk': 0.0},
                     'suck_intake_by_type': {kind: 0.0 for kind in TYPES}}
            rows.append({'phase': 'heldout', 'seed': seed, 'policy': policy, 'ticks': 60, 'duration': 1.0,
                         'completed': seed == 10, 'winner': 'fish' if seed == 10 else '',
                         'reason': 'home' if seed == 10 else '', 'home_win': seed == 10,
                         'food_consumed': food, 'satiety_final': 70.0, 'satiety_mean': 80.0, 'satiety_min': 60.0,
                         'hook_contacts': 0, 'hook_events': 0, 'feeding_attempts': 0, 'feeding_seconds': 0.0,
                         'suction_command_attempts': 0, 'suction_command_seconds': 0.0,
                         'automatic_bite_events': 1, 'automatic_bite_while_suction_command': 0,
                         'per_type': per_type, 'stats': stats,
                         'mode_choices': {'suck': 0, 'bite': 1},
                         'mode_seconds': {'suck': 0.0, 'bite': 1.0, 'seek': 0.0, 'home': 0.0}})
    return rows


class AnalysisTests(unittest.TestCase):
    def setUp(self):
        self.rows = rows_fixture()

    def test_paired_negative_and_incomplete_retained(self):
        result = summarize(self.rows, 100)
        self.assertEqual(result['paired_seeds'], 2)
        self.assertEqual(result['policies']['Mixed']['incomplete_seeds'], [11])
        self.assertEqual(result['paired_differences']['Mixed minus SuckOnly']['food_consumed']['mean'], -2.0)
        self.assertEqual(result['strict_dominance']['qualifying_pairs'], [])

    def test_point_dominance_with_equal_risk_is_preserved(self):
        result = summarize(self.rows, 100)
        pairs = result['strict_dominance']['point_estimate_weak_dominance']['qualifying_pairs']
        self.assertIn({'candidate': 'SuckOnly', 'other': 'Mixed'}, pairs)
        self.assertEqual(result['strict_dominance']['qualifying_pairs'], [])

    def test_duplicate_refused(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            summarize(self.rows + [self.rows[0]], 100)

    def test_missing_pair_refused(self):
        with self.assertRaisesRegex(ValueError, 'paired seed'):
            summarize(self.rows[:-1], 100)

    def test_pilot_mixing_refused(self):
        self.rows[0]['phase'] = 'pilot'
        with self.assertRaisesRegex(ValueError, 'pool pilot'):
            summarize(self.rows, 100)

    def test_actual_timestep_required(self):
        self.rows[0]['ticks'] = 61
        with self.assertRaisesRegex(ValueError, '60 Hz'):
            summarize(self.rows, 100)

    def test_per_type_score_reconciliation(self):
        self.rows[0]['food_consumed'] += 1
        with self.assertRaisesRegex(ValueError, 'food does not reconcile'):
            summarize(self.rows, 100)

    def test_independent_action_reconciliation(self):
        self.rows[0]['per_type']['cluster']['automatic_bite_food'] += 1
        with self.assertRaisesRegex(ValueError, 'independent authority'):
            summarize(self.rows, 100)

    def test_automatic_bite_not_disabled_for_suckonly(self):
        result = summarize(self.rows, 100)
        self.assertEqual(result['policies']['SuckOnly']['metrics']['automatic_bite_events'], 1)

    def test_biteonly_suction_refused(self):
        self.rows[1]['suction_command_seconds'] = 1.0
        with self.assertRaisesRegex(ValueError, 'BiteOnly issued suction'):
            summarize(self.rows, 100)

    def test_deterministic_intervals(self):
        self.assertEqual(summarize(self.rows, 100), summarize(copy.deepcopy(self.rows), 100))


if __name__ == '__main__':
    unittest.main(verbosity=2)
