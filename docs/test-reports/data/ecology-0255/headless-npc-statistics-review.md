# P3.5 final headless NPC statistics

Current 0.25.5 production measurement; authority schema15; Godot 4.7.2-stable (official) on Linux. This rerun is part of the source-stable final current gate (2,141 assertions).

Single-threaded headless live authority with default foraging enabled plus explicit passive controls; per configuration 240 warmup + 1200 timed ticks; commands prepared before timer; serialization excluded from tick timing; production role state packet sampled every 60 measured ticks. Packet bytes include protocol envelope; chunked bytes include 800-byte fragmentation envelopes but exclude ENet/IP/UDP headers. Wall-time samples are machine-specific, not a comparative performance guarantee. Live fish-view payloads need not grow monotonically with NPC count because eaten grains leave the visible-food projection; passive controls isolate public NPC record cost.

| Control | Role | NPCs | Mean tick µs | p95 tick µs | Authority bytes mean | Role bytes mean | Deflate bytes mean | Packet bytes mean | Chunked application bytes mean |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Passive | fish | 0 | 644.31 | 875 | 63687.4 | 31443.8 | 5534.1 | 5823.4 | 7647.4 |
| Passive | fish | 3 | 693.07 | 1055 | 66914.8 | 31983.8 | 5693.9 | 5983.4 | 7807.4 |
| Passive | fish | 6 | 807.91 | 1507 | 70142.6 | 32523.8 | 5807.8 | 6097.6 | 7921.6 |
| Passive | angler | 0 | 713.05 | 1062 | 63983.6 | 63315.6 | 8063.9 | 8353.4 | 10861.4 |
| Passive | angler | 3 | 783.40 | 1163 | 67211.0 | 63855.6 | 8224.4 | 8514.2 | 11022.2 |
| Passive | angler | 6 | 866.25 | 1611 | 70438.8 | 64395.6 | 8336.0 | 8625.8 | 11133.8 |
| Live foraging | fish | 0 | 725.60 | 1180 | 63687.4 | 31443.8 | 5534.1 | 5823.4 | 7647.4 |
| Live foraging | fish | 3 | 812.49 | 1316 | 67615.8 | 27553.0 | 5285.9 | 5575.4 | 7217.0 |
| Live foraging | fish | 6 | 842.62 | 1726 | 71419.4 | 27536.4 | 5275.4 | 5564.8 | 7263.4 |
| Live foraging | angler | 0 | 715.13 | 1060 | 63983.6 | 63315.6 | 8063.9 | 8353.4 | 10861.4 |
| Live foraging | angler | 3 | 816.80 | 1319 | 68026.6 | 64270.6 | 8347.4 | 8637.0 | 11145.0 |
| Live foraging | angler | 6 | 873.86 | 1888 | 71993.2 | 65207.6 | 8482.6 | 8772.2 | 11371.4 |

These are one-machine, one-seed synthetic measurements, not long-term, cross-device or real-player performance guarantees. Other diagnostics ran concurrently; timing is not an isolated comparative benchmark. The 6-NPC case is stress coverage; production default is3 and normal-density invariants cover2/3/4. Native frame timing is reported separately, not inferred from this headless measurement.

Full original per-tick and payload samples, methods, machine metadata and all summaries are preserved byte-for-byte in [headless-npc-statistics.json](headless-npc-statistics.json). SHA-256: a6347f2518f39c6a2edc228d81ac04a967dd0bee0a4acef1b9e1e7648330842b.
