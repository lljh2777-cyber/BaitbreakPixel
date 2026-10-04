# P3.5 final current headless gate

61 current headless suites + editor import: 62 passed, 0 failed, 0 timed out. 245,119 summary-counted assertions. No completion markers are added to this assertion total.

Elapsed wrapper time: 689.69 seconds. 298 runtime/assets/scenes/current-suite/runner/registry/project inputs retained exact SHA-256 values before and after.

Command: python3 tools/run_tests.py --godot /workspace/shared/baitbreak-toolchain-472/Godot_v4.7.2-stable_linux.x86_64 --import --profile current --output-directory artifacts/p35-headless-final

This is the registered current source gate only. Historical/retired tests, native rendering, Windows exports, audio devices and cross-device/public-NAT checks are separate. Both real same-machine ENet role gates are included.

| Suite | Assertions | Seconds | Result |
|---|---:|---:|---|
| editor-import | 0 | 9.292 | passed |
| architecture_v020 | 46 | 8.139 | passed |
| bait_suction_v0212 | 41 | 0.925 | passed |
| effort_v013 | 31 | 2.628 | passed |
| feeding_feel_v022 | 29 | 0.768 | passed |
| feeding_movement_v0221 | 28 | 0.819 | passed |
| fish_orbit_v021 | 160 | 23.859 | passed |
| grass_binding_v021 | 70 | 13.715 | passed |
| line_motion_v021 | 29 | 2.372 | passed |
| net_animation_v0201 | 44 | 2.426 | passed |
| net_network_v020 | 13 | 20.371 | passed |
| net_network_v021 | 13 | 19.169 | passed |
| net_v021 | 43 | 1.768 | passed |
| network_rules_v012 | 26 | 0.465 | passed |
| obstacle_art | 92 | 1.868 | passed |
| plant_art | 16579 | 1.016 | passed |
| pond_v021 | 31 | 1.868 | passed |
| reeling_v0122 | 20 | 2.420 | passed |
| rod_load_v017 | 11 | 0.465 | passed |
| rules_network_v019 | 9 | 18.007 | passed |
| rules_v020 | 256 | 5.226 | passed |
| tackle_dynamics_v021 | 28 | 1.517 | passed |
| untangle_network_v018 | 6 | 14.653 | passed |
| untangle_v021 | 44 | 2.520 | passed |
| water_art | 14 | 1.367 | passed |
| wood_fade | 57 | 1.367 | passed |
| wood_junctions | 20 | 2.421 | passed |
| phase01_entities | 13 | 0.467 | passed |
| phase01_observation | 22 | 0.467 | passed |
| phase01_statistics | 13 | 1.219 | passed |
| phase01_satiety | 14 | 0.365 | passed |
| phase01_instinct | 81 | 0.365 | passed |
| phase01_suspicion | 11 | 0.365 | passed |
| phase01_random_hooks | 508 | 1.018 | passed |
| phase01_policies | 5 | 0.366 | passed |
| phase01_network | 44 | 12.653 | passed |
| phase15_controls | 131 | 3.422 | passed |
| phase02_bite | 57 | 0.917 | passed |
| phase02_bite_network | 136 | 14.069 | passed |
| phase02_bait_types | 6564 | 9.590 | passed |
| phase02_food_profiles | 158 | 0.365 | passed |
| phase02_observation | 59 | 0.365 | passed |
| phase02_bait_network | 94 | 17.105 | passed |
| phase02_feeding_balance | 204 | 0.816 | passed |
| phase02_feeding_policies | 29 | 0.366 | passed |
| phase03_npc_observation | 209 | 0.666 | passed |
| phase03_npc_network | 497 | 42.681 | passed |
| phase03_npc_rng | 7043 | 17.465 | passed |
| phase03_npc_entities | 7274 | 2.119 | passed |
| phase03_npc_snapshot | 5463 | 21.122 | passed |
| phase03_npc_ambient | 194441 | 29.692 | passed |
| phase03_npc_statistics | 2141 | 15.722 | passed |
| phase03_npc_foraging | 80 | 11.950 | passed |
| phase03_food_reachability | 25 | 215.783 | passed |
| phase03_npc_foraging_brain | 397 | 0.265 | passed |
| phase03_npc_social | 25 | 1.116 | passed |
| phase03_npc_social_brain | 963 | 0.264 | passed |
| phase03_npc_hook_target | 69 | 0.916 | passed |
| phase03_npc_hook_pacing | 243 | 7.787 | passed |
| player_hook_entry | 46 | 0.565 | passed |
| player_hook_network | 76 | 29.692 | passed |
| phase03_ecology_balance | 244 | 65.998 | passed |

Raw .log files remain local under artifacts/p35-headless-final. headless-log-manifest.json retains exact hashes and byte sizes. headless-summary.json retains commands and per-suite counts; headless-provenance.json records raw input fingerprints. Only the small new ecology integration log is copied.

Python full discover separately passed 202 tests; see python-runner.txt and python-provenance.json. The parser-error strings in that Python log are intentional invalid-argument rejection fixtures, followed by passing assertions and overall OK.
