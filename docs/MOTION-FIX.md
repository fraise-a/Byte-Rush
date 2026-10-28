# Byte Rush 0.10 — Kart motion correction

Reproduced, repaired and rebuilt on 28 October 2026.

## Finding

Physical karts moved at 60 updates per second without render interpolation, while the camera repositioned on every rendered frame and aimed at the latest raw physics pose. Between physics ticks, a kart could remain in place while the camera continued moving, then jump on the next tick. The controlled rendered test reproduced the rapid camera-relative alternation that can look like ghosting.

The repair interpolates the displayed kart transforms and has the camera follow the same interpolated position **and heading**. Physics continues at 60 ticks per second, preserving race handling and checkpoint calculations.

## Changes

- Physical karts explicitly enable physics interpolation. Frame-animated scenery and effects keep interpolation disabled; their transforms continue updating per render frame.
- The independent camera uses a frame callback and follows `get_global_transform_interpolated()` rather than a raw tick position. Automatic camera interpolation is disabled to keep its timing consistent.
- Spawn and recovery call `reset_physics_interpolation()` after placing the kart. Regression checks verify both the kart root and an actual body mesh at the next rendered sample, including a sample before another physics tick at high render rates.
- Minimap dots use the displayed kart poses too.

## Before/after reproduction

The GPU fixture moves all six real kart models at identical constant velocity. It uses the game's camera callback, warms up for 1.5 simulated seconds, then measures projected screen-space positions for 2.5 seconds. The render target is 1920 × 1080. This isolates presentation timing from steering and collision variability. These are projected trajectory measurements from Godot's displayed-transform API, not optical tracking of a recording.

At a controlled 144-render-frame / 60-physics-tick cadence:

| Metric | Before (0.9) | Rebuilt app (0.10) |
| --- | ---: | ---: |
| Intermediate frames where the displayed kart moves | 0 / 210 | 210 / 210 |
| RMS screen-position second difference, pixels | 0.369296 | 0.000042 |
| Spawn root/body history error, metres | Interpolation inactive | 0.000000 / 0.000000 |
| Recovery root/body history error, metres | Interpolation inactive | 0.000000 / 0.000000 |

The jitter metric is the RMS length of the screen-position second difference. Lower is smoother. The residual is below a thousandth of a pixel in this fixture. The failing original log and report are retained in `tests/review-baseline/motion-before.*`.

Source GPU checks also passed at these controlled render cadences:

| Render frames per simulated second | Intermediate frames with movement | Jitter metric, pixels |
| --- | ---: | ---: |
| 60 | 0 / 0 | 0.000040 |
| 120 | 150 / 150 | 0.000040 |
| 144 | 210 / 210 | 0.000044 |
| 240 | 450 / 450 | 0.000035 |

At 60/60 there are no intermediate render samples, so that column is 0/0. These are controlled frame cadences, not a claim of benchmarking four physical monitors or sustaining 240 FPS on every machine.

## Additional validation

- **Source functional regressions:** systems 22, correctness 16, controller 50 and lifecycle 33 checks passed.
- **Full races, source and exported app:** all four suites passed in each run — Easy/Normal/Hard Grand Prix and solo Time Trial. Each run completed all 19 racer entries, 57 kart laps and 684 ordered checkpoint validations.
- **Exported graphical motion suite:** all six checks passed, including root/body placement and recovery history.
- **Exported rendered race:** 35.0 seconds, 31.3 racing seconds, all six karts present, no unexplained position jumps above the diagnostic's 2-metre-per-tick threshold. The largest ordinary step was 0.647 metres; no kart recovered in this smoke run. Pack, motherboard and cooling captures are supplied as `tests/motion_race_*.png`.
- **Local rendered smoke performance:** sampled mean 117.4 FPS and minimum 70 FPS at 1920 × 1080 on this Apple M5 Max. This short local measurement does not establish a 4K frame-rate guarantee or long-session performance.
- **Package:** universal arm64/x86_64, version 0.10, valid Info.plist and strict ad-hoc signature verification. The app remains unnotarized.

Reports and logs are under `tests/`, including `motion_60_results.json`, `motion_120_results.json`, `motion_144_results.json`, `motion_240_results.json`, `native_motion_results.json`, `native_motion_race_results.json` and the source/native race reports. `README.md` contains reproduction commands. Test saves use private validation prefixes.

This pass reproduces and fixes a specific render-timing defect. It is not a claim that every possible visual issue on every display/driver has been eliminated. The rendered race uses the physical AI controller for the player, not hands-on driving.

## Engine references

The implementation follows Godot 4.5's [physics interpolation setup and teleport resets](https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/using_physics_interpolation.html) and [frame-driven camera guidance](https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/advanced_physics_interpolation.html). The displayed-pose query is documented on [Node3D](https://docs.godotengine.org/en/4.5/classes/class_node3d.html#class-node3d-method-get-global-transform-interpolated).
