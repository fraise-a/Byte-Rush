# Byte Rush 0.1 — Neon Kingdom

Updated 26 October 2026. The app and source ZIPs have been rebuilt from this project.

## Visual changes

- Saturated sunset sky with an original striped sun, colourful rainbow keycaps, oversized trackside keys, a motherboard circuit city, RAM towers, processor plaza and floating data particles.
- Brighter road palette, alternating coloured kerbs, clear track grid markings, stronger silhouettes, balanced lighting and reduced overexposed highlights.
- Rounded kart bodies, robot helmets, contrasting visors, wheel details and body-coloured accents. Existing physical handling is preserved.
- Rotating hollow item cages and geometric electrical symbols replace tiny text hidden inside objects. Turn arrows use solid geometry. Zone and jump signs have high-contrast backing and correctly separated lettering.
- Space Grotesk typography with explicitly selected weights and distance-field rendering. The font is bundled under the SIL Open Font License.
- Fading collection/EMP rings, a subtler shield bubble, drift smoke and sparks, coloured exhaust and peripheral boost streaks. The menu now frames the player's kart against the live circuit.

## Flicker and readability repairs

The main road and service bridge previously had overlapping visible surfaces at identical depth. The service bridge now renders 0.055 metres above the road while its physical collision remains coplanar. This removes depth fighting without introducing a collision step.

Sign text is placed in front of its backing surface, rather than intersecting it. Floating billboard labels were replaced with oriented signboards and geometric symbols. Filtered distance-field text and heavier actual font weights improve readability at distance and across resolution changes. Thin procedural grid lines and sky stripes use derivative-based filtering.

## Resolution settings

Settings → Resolution offers:

| Preset | Shape |
| --- | --- |
| 1280 × 720 | 16:9 |
| 1280 × 800 | 16:10 |
| 1440 × 900 | 16:10 |
| 1600 × 900 | 16:9 |
| 1920 × 1080 | 16:9 |
| 1920 × 1200 | 16:10 |
| 2560 × 1440 | 16:9 |
| 2560 × 1600 | 16:10 |
| **3840 × 2160 — 4K UHD** | **16:9** |

The choice is saved locally. There is no option above 4K. The new display module renders 3D into an explicitly bounded viewport, so a Retina or fullscreen desktop cannot silently increase the 3D render resolution beyond the selected budget. Fullscreen adapts that budget to the monitor's aspect ratio without stretching the world. The interface is drawn separately and remains sharp at the operating system's desktop scale. The OS compositor may still use its native display dimensions; that does not increase the 3D render target beyond 4K.

Windowed mode fits the available desktop. Resize limits are set to 3840 × 2160. Antialiasing now applies 4× MSAA to the selected 3D target. Existing controls, fullscreen preferences and Time Trial records are preserved.

## Verification completed

- All four source race suites passed: six racers over three laps on Normal, Easy and Hard, then a solo three-lap Time Trial. All 19 racer entries completed 36 ordered gates each.
- All 22 input, physics, menu and persistence integration checks passed.
- All nine resolution presets applied within their bounds. Save/load, invalid-selection clamping, fullscreen bounds and the dedicated race viewport passed.
- A real GPU frame was rendered and read back at **exactly 3840 × 2160**. `tests/gameplay-4k.png` is the captured frame. `tests/settings.png` shows the 4K selection.
- Rendered menu, driving and cooling-section captures were inspected. A 35-second windowed test at 1920 × 1080 on an Apple M5 Max averaged approximately **139 FPS** over 28 one-second samples, with a minimum sampled value of 107 FPS. Screenshot readbacks are included in this short smoke test; this is not a long-session benchmark or a 4K performance claim.
- The universal arm64/x86_64 app exports as version 0.1 and passes strict ad-hoc signature verification. The exported executable is also run through the full headless race regression, with its separate report and log in `tests/native_race_results.json` and `tests/native_race_tests.log`.

Reports and reproducible scripts are under `tests/`. Screenshots there are excluded from Godot's asset import and the exported game. The original five gameplay modules are retained, with `scripts/display.gd` added for resolution control.

## Remaining validation limits

A physical controller was not available for hands-on testing. The app remains ad-hoc signed rather than Apple notarized. Manual long-session playtesting and performance on other Mac models remain useful follow-up checks.
