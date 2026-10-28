# Byte Rush — Correctness reviews

## Follow-up review: 0.4

This second pass found a finish-state defect: a racer finishing during a drift retained drift charge and continued emitting driving particles and drift audio. Finish registration now clears the same temporary driving state as recovery. Two new headless assertions failed before the fix and pass afterward; the native run first confirms that drift audio is actually playing, then checks that finishing stops it.

Inspection also found that the first autonomous race inherited saved difficulty and personal records, despite advertising Normal difficulty. Autotest mode is now selected before loading preferences, uses `validation_autotest_` files, explicitly starts at Normal, and clears in-memory records. The isolation fixture seeds its private profile with Hard difficulty and very fast records, then verifies the known baseline. The old code fails the separate-profile assertion. Test mode continues to suppress settings/record writes.

Fresh validation on the 0.4 source and rebuilt native app:

| Suite | Result |
| --- | --- |
| Source input/systems integration | 22 assertions passed |
| Source generated geometry | 14 assertions passed |
| Source correctness regressions | 16 assertions passed |
| Native graphical correctness regressions | 17 assertions passed, including active engine playback before pausing |
| Source lifecycle | 33 assertions passed |
| Native graphical lifecycle | 34 assertions passed, including active drift playback before finishing |
| Autotest isolation | 3 assertions passed |
| Full races, source and exported executable | All four suites passed in each run; 19 finishers, 57 kart laps and 684 gate validations per run |
| Native package | 0.4; arm64/x86_64; valid Info.plist and strict ad-hoc signature verification |

Lifecycle coverage includes ten successive pause → settings → back → restart → menu sequences, checking state resets and exactly one active menu kart. It also samples the actual generated service-bridge path with its tangent and the normal gate validator: both checkpoints (120 and 140) are accepted before rejoining. This is a route-projection check, not a manually driven shortcut or a collision test along its entire length. The source comment claiming the bridge rejoins before the next gate was corrected.

Evidence is in `tests/lifecycle_results.json`, `tests/native_lifecycle_results.json`, `tests/autotest_isolation_results.json`, the refreshed existing reports, and corresponding logs. `tests/review-baseline/lifecycle-before.log` and `isolation-before.log` preserve expected failures from the earlier code. Reproduction commands are in `README.md`.

The 4K frame capture, fullscreen-transition checks and performance measurement below were completed for 0.3. The display and geometry generation code did not change in this patch. Physical controller, Intel runtime and long-session manual testing remain unverified.

## Earlier review: 0.3

Reviewed and rebuilt on 26 October 2026 with Godot 4.5.1. This pass inspected race lifecycle, physics/checkpoint state, boosts and inventory, pause/restart, results UI, persistence and display transitions. It found reproducible bugs and added regression checks for them. Passing these checks is evidence for the covered behavior, not proof that every possible game state is bug-free.

## Findings and fixes

| Area | Defect | Corrected behavior |
| --- | --- | --- |
| Standings | Raw track distance wrapped at the starting line, putting a leader behind racers with the same gate count. | Ordered gate count is followed by remaining distance to the next required checkpoint. |
| Checkpoints | Gate validation could use the projection from before the kart moved. | Projection is refreshed after movement before validation; paused, finished and inactive racers cannot claim gates. |
| Boosts | A weaker drift turbo could replace an active Turbo Cell's stronger power. | Overlapping boosts retain the greater active strength and remaining duration; expired power clears. |
| Recovery | Drift charge and boost survived recovery; recovery input could move a finished kart. | Recovery clears those temporary states and rejects finished racers. |
| Items | Direct item calls could work while paused, and EMP could target finishers. | Item/attack methods guard race state and skip finished racers. AI passing and drafting also ignore finishers. |
| Pause/restart | Effect rings and announcements could leak across races; paused effects and engine playback continued. | Race cleanup removes effects and resets announcements. Pause freezes effect time, kart visual processing and kart audio playback. |
| Results | Each AI finish rebuilt the results menu, removing keyboard/controller focus. Duplicate finish callbacks were accepted. | Existing rows update in place; registration rejects duplicates and the race clock stops when everyone finishes. |
| Saved data | Wrong ConfigFile value types caused runtime errors; invalid record times could poison personal bests. | Numeric values must be finite and are clamped; incorrect types use defaults. Records must be finite positive times. |
| Fullscreen | macOS could ignore a rapid second fullscreen toggle or the requested window size during its animation. | A bounded reconciliation period reapplies the requested mode and size. It stops after the transition window. |
| Initialization | Reinstalling input mappings could duplicate initialization work. | Mapping setup replaces the game's actions before adding bindings. |

The baseline logs in `tests/review-baseline/` intentionally contain the failures observed before the fixes. Current test logs and JSON reports are directly under `tests/`.

## Completed validation

| Check | Result | Evidence |
| --- | --- | --- |
| Edge-case regression suite, headless source | 16 checks passed | `correctness_results.json`, `correctness_tests.log` |
| Edge-case regression suite, rebuilt native executable | 17 checks passed, including active engine playback before pause | `native_correctness_results.json`, `native_correctness_tests.log` |
| Real macOS window/fullscreen transitions | 4 checks passed | `window_transition_results.json`, `window_transition_tests.log` |
| Input, physics and systems integration | 22 checks passed | `systems_results.json`, `systems_tests.log` |
| Generated geometry | 14 checks passed | `geometry_results.json`, `geometry_tests.log` |
| Display with real GPU | 17 checks passed, including exact 3840 × 2160 readback | `display_results.json`, `display_tests.log` |
| Full races, source and exported native executable | Normal/Easy/Hard Grand Prix and solo Time Trial all passed in each run | `race_results.json`, `native_race_results.json` and corresponding logs |
| Rendered smoke test | 35 seconds; mean sampled 143.9 FPS, minimum 129 FPS at 1920 × 1080 on Apple M5 Max | `performance.json`, `presentation_tests.log`, viewport PNGs |
| App packaging | Version 0.3; arm64 and x86_64; valid Info.plist; strict ad-hoc signature verification passed | `release_validation.json` |

Each full-race run completed 19 racer entries, 57 kart laps and 684 ordered checkpoint validations. The test player uses the physical AI controller. These are autonomous simulations, not manually driven laps. A GPU 4K readback establishes resolution support, not a 4K performance guarantee.

## Reproduce

From a Godot installation, substitute the project path:

```sh
Godot --headless --path /path/to/ByteRush --fixed-fps 60 --script res://tests/correctness.gd
Godot --path /path/to/ByteRush --script res://tests/window_transitions.gd -- --windowed --mute
Godot --path /path/to/ByteRush --script res://tests/display.gd -- --windowed --mute
Godot --headless --path /path/to/ByteRush --fixed-fps 60 -- --autotest
```

For the native correctness run, the exported executable was launched with `--fixed-fps 60 --script /absolute/path/to/ByteRush/tests/correctness.gd -- --windowed --mute`. Its engine stream was confirmed playing before checking pause state; subjective audio quality was not assessed. Tests use private validation save prefixes and preserve real preferences and personal records. The window test requires a graphical macOS session.

## Limits

Physical controller handling, long-session manual driving and subjective audio listening remain unverified. The app is universal but this runtime validation took place on Apple Silicon, not an Intel Mac. The app remains ad-hoc signed and is not notarized for public distribution. Other hardware, unusual desktop layouts and rare race-state combinations may still reveal defects. Earlier scenery and geometry findings are documented in `CODE-AUDIT.md`.
