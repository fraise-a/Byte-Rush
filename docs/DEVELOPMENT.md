# Byte Rush — Development and Validation

Updated to **version 1.0** on 26 October 2026. See `CORRECTNESS-REVIEW.md` for the current state-handling fixes, `CODE-AUDIT.md` for the geometry fixes, and `VISUAL-UPDATE.md` for the earlier visual and resolution changes. Built with Godot 4.5.1 Standard / GDScript. The deliverable is a self-contained universal macOS app plus the editable project.

## Implemented

- One complete, closed 3D course, the Keyboard Kingdom, with the Mechanical Keyboard, Motherboard Motorway and Cooling Chamber. Procedural illuminated keyboard keys, circuit scenery, fans, cooling frames, ramps, elevation, barriers, checkpoints, electrical hazards, item rows, boost pads and an inside service bridge.
- Six physical karts, animated wheels and rims, distinct colours, emissive trim and canopy, drift sparks and tyre smoke, boost exhaust, shield bubble, collection rings and EMP waves.
- Acceleration, braking and reverse; smoothed keyboard and analogue steering; drift hop and lateral slide; three release-boost tiers; capacitor charging from drift, jumps and drafting; jump impulses, gravity, airborne steering, collisions and recovery to the last grounded point.
- Five AI opponents with three difficulty levels, look-ahead steering, bounded passing offsets, varying pace and item timing, hazard avoidance, corner speed control, shared items and recovery.
- Turbo Cell, EMP Burst and Hardlight Shield with real race effects. One-slot inventory and respawning pickups.
- Three-lap Grand Prix, countdown, live standings, ordered gate validation, race/lap times, non-blocking finishers and results. Solo Time Trial with persistent lap and total-time personal bests.
- Main menu, pause/restart/resume, settings, results, HUD, minimap, wrong-way indicator, announcements, capacitor and drift meters. Persistent difficulty, volume, sensitivity, fullscreen, resolution up to 4K UHD and 4× antialiasing settings.
- Keyboard and controller bindings, original generated engine/drift/collision/boost/UI/countdown/item sounds, and an original looping synth score.
- Native release export for Apple Silicon and Intel, with validated ad-hoc signature.

## Tests actually performed

### Full-race regression

`tests/race_results.json` and `tests/race_tests.log` document completed simulations of:

| Run | Racers | Laps per racer | Required gates per finisher |
| --- | ---: | ---: | ---: |
| Grand Prix / Normal | 6 | 3 | 36 |
| Grand Prix / Easy | 6 | 3 | 36 |
| Grand Prix / Hard | 6 | 3 | 36 |
| Time Trial | 1 | 3 | 36 |

All 19 racer entries finished: 57 individual kart laps and 684 ordered checkpoint validations. The player uses the same physical AI controller for this automation. These are simulated races, not a claim of 57 manually driven laps. Each suite also checks gate-order rejection, shield absorption, turbo and EMP effects, three drift tiers and recovery without checkpoint credit. The scripts report failures with a nonzero process exit code.

After repairing the final shortcut overlap, ordinary opponents required zero to one recovery over three laps. The player fixtures include an intentional recovery check. Recoveries do not advance the checkpoint sequence.

### Input and systems integration

`tests/systems_results.json` records 22 passing checks using actual Godot input actions and physics frames. They cover acceleration and physical displacement, ground support, braking into reverse, held drift, drift-release boost, capacitor spending and rejection at insufficient energy, pause/resume, pickup inventory and respawn, wrong-way rejection, duplicate/skip checkpoint rejection, road and barrier raycasts, keyboard/controller binding installation, saved settings and records, settings/results/menu transitions, and a parsed mouse event activating the Grand Prix button.

Save/load tests use separate `validation_` filenames. Autotests do not overwrite real personal records. Sound playback is skipped only for the headless dummy audio driver, whose rapidly terminating playback references otherwise caused shutdown warnings; the normal game retains audio playback.

### Rendered inspection and performance

The 35-second rendered test traversed all three zones with six physically simulated racers. Godot viewport captures are included as `tests/menu.png`, `tests/driving.png` and `tests/cooling.png`. The test explicitly forces drawing because macOS can suppress redraws of a covered OpenGL window.

`tests/performance.json` records version 0.3's Apple M5 Max test at 1920 × 1080 for both the window and 3D render target. The 35-second check averaged approximately 144 FPS across 28 one-second samples, with a 129 FPS minimum sampled value. This is a short local measurement, not a long-session benchmark or a guarantee for other Macs. The renderer uses GL Compatibility, 4× MSAA and directional shadows.

The resolution suite additionally validates all nine presets, persistence and the 4K cap. Its rendered run captures and reads back an exact 3840 × 2160 GPU frame. Those checks do not imply a 4K frame-rate guarantee. The UI is rendered separately at desktop scale, and the 3D scene is always bounded by the selected preset.

### Native package

The exported executable was inspected as a Mach-O universal binary containing arm64 and x86_64 architectures. The app's Info.plist validates. `codesign --verify --deep --strict` succeeds. The original version was launched on the Mac and its main menu inspected. Version 0.3 was checked with rendered viewport captures, the 4K display suite, actual macOS fullscreen transitions and native correctness regressions, including active engine playback before pausing. The exported executable was also used for the full headless race regression; all four native suites passed, and their report is supplied as `tests/native_race_results.json` with the corresponding log.

Native computer-use input delivery was inconsistent in this environment, so direct human-equivalent mouse/keyboard driving through that automation is not claimed. Input action simulation, a parsed mouse-button event, headless native races and rendered viewport captures provide the reproducible checks described above.

## Defects repaired during iteration

- Corrected road triangle winding to provide upward-facing collision surfaces.
- Moved jump impulses ahead of ramp leading edges so vehicles clear the physical wedge.
- Rebuilt shortcut entry/exit geometry and made overlapping road decks coplanar to eliminate edge stalls.
- Bounded passing offsets so opponents in a crowded pack cannot accumulate steering targets outside the road.
- Adjusted AI boost pace through tighter corners and Turbo Cell use to favour straights.
- Changed recovery to use the last grounded position rather than a point near the next gate.
- Made finished vehicles non-blocking so they cannot trap later finishers.
- Corrected looping audio import metadata, test-fixture typing and GUI input coordinate conversion.
- Fixed Apple Silicon texture-import/export settings and validated ad-hoc signing.

## Remaining limitations

- A physical controller was not available for a hands-on test. Standard controller mappings and analogue input definitions are implemented and inspected.
- The art uses original procedural geometry, with one circuit.
- AI can still bump barriers or rivals and use the recovery system. The completed full-race checks show they can finish under the shared checkpoint rules.
- No Apple Developer ID or notarization credentials were available. The local app is ad-hoc signed; public distribution would require the distributor's own signing/notarization workflow.
- Manual long-session driving, subjective audio listening and benchmarking other Mac models remain useful follow-up validation. None is represented here as completed.

## Reproduction

See `README.md` for controls, source launch, export and test commands. `tools/generate_audio.py` regenerates the original WAV assets with Python's standard library. `tools/build_macos.sh` builds with an installed Godot and matching export templates. No server, account or online service is required.

Version 0.2 adds 14 generated-geometry checks and focused scenery captures, including 4K. See `CODE-AUDIT.md` for specific findings and results.

Version 0.3 adds 16 edge-case regressions (plus a native playback precondition) and four real macOS window-transition checks. All passed. See `CORRECTNESS-REVIEW.md` for findings, reproduction commands and limits.

Version 0.4 fixes finish-state drive effects and isolates autonomous test preferences. Fresh checks include the existing systems, geometry and correctness suites, 33 lifecycle assertions (34 with the native audio precondition), three isolation assertions and all four source/native race suites. The lifecycle suite samples the generated bridge path through the normal checkpoint validator; it does not establish that a human driver completed that path. Rendering performance and display-transition measurements above remain the earlier 0.3 evidence; their code was unchanged in this patch.

Version 0.5 adds `scripts/controls.gd`, adaptive PlayStation/Xbox/Nintendo/keyboard prompts, explicit controller Confirm/Back bindings, navigation for every settings control, repeat for held stick/D-pad directions, reconnect support and safe disconnect pausing. Driving mappings accept every controller device index. Menu Back is restricted to menu contexts so Nintendo B can drift during a race. `CONTROLLER-AUDIO-UPDATE.md` records the revised audio gains, captured mix measurements, native controller-event checks and remaining physical-hardware testing limits. Earlier reports and screenshots remain historical where their filenames are retained; current release validation identifies freshly rerun suites.

Version 0.6 replaces visible button names with resolution-independent vector icons in `scripts/prompts.gd`. Source and native controller regressions were rerun; input mappings, race logic and audio are unchanged.

Version 0.9 adds a 67-assertion prompt audit across eight screen contexts and five independent input profiles, including live switching on open results screens and disconnect handoff. Source and exported native prompt/controller suites were rerun; race physics and audio are unchanged. See `INPUT-PROMPT-AUDIT.md`.

Version 0.10 fixes camera-relative kart jitter by interpolating physical kart transforms, following their displayed pose from a frame-driven camera, and clearing history after teleports. Motion tests cover 60/120/144/240 render cadences; source/native race and rendered smoke checks are recorded in `MOTION-FIX.md`. Earlier rendering measurements elsewhere in this document remain historical.

Version 1.0 removes the main-menu resolution promotion and centralizes cursor visibility by UI context and input mode. A focused native runtime check covers countdown, racing mouse movement, device handoff, pause/settings, resume, results and returning to the main menu.
