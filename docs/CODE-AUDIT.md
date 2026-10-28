# Byte Rush 0.2 — Track and scenery audit

26 October 2026. This update addresses concrete code defects found after the remaining glitches were narrowed to track surfaces, signs and scenery.

## Defects found and repaired

| Finding | Repair |
| --- | --- |
| The 17-metre road ribbon was wider than the inside radius of the motherboard hairpin. Eight triangles inverted, and a projected-triangle audit found 125 overlapping pairs in that region. | The road generator now limits the inside offset to the bend radius and propagates that limit along the approaches. It preserves the route centreline and legitimate lap/checkpoint progression. Both independent Python polygon clipping and the checked-in Godot geometry test report zero inverted or overlapping road triangles after the correction. |
| Each railing box was centred on a path sample, extended into its neighbours and added 0.25 metres of overlap. Flat rail tops could occupy the same plane. | Rail bodies and neon strips are continuous swept meshes with shared section boundaries and properly oriented collision faces. Flat face normals replace the previous smoothing across rectangular rail corners. |
| Boost pads were flat boxes over a curved/elevated road. A thin marking could intersect the road plane near an edge or crest. | Painted markings are clipped from the actual road triangles, preserving their exact planes. Boost pads, lane marks and the starting grid sit 0.06 metres above the supporting surface. Arrow/checker shaders filter high-frequency edges. |
| The fan used seven large rectangular paddles with overlapping coplanar faces around its hub. Its solid ring also used transparency unnecessarily. | Swept, tapered blade meshes occupy disjoint sectors. The ring is opaque. Four rotating-fan captures were taken at different animation phases. |
| World labels had a 75-metre visibility cutoff while their backing boards remained visible. | The text-only cutoff is removed. Boards retain their separated front-facing lettering and distance-field font. |
| A narrow curve could leave a wide ramp hanging beyond the road edge. The old ramp was a thin tilted plate. | Ramp width derives from the surrounding road sections. Ramps are closed solid wedges with upward-facing driving surfaces and collision geometry. Jump triggers respect the ramp width. |
| Procedural fine grids retained patterns below a pixel, and a wrapped arrow coordinate was used for derivatives. | Grids fade below a stable sampling footprint. Arrow filtering uses the unwrapped coordinate; checker markings use integrated filtering. Small scenery particles do not cast unstable tiny shadows. |
| Fans, item timers and wind continued animating while the race was paused. | Track animation and pickup timers now respect the pause state. |
| Visual smoothing used unbounded linear factors during long frames. | Kart visual tilt and camera field-of-view smoothing now use bounded exponential factors. |

The previous service-bridge repair remains: its visible surface is raised while physical collision stays aligned with the road.

## Verification actually performed

- `tests/geometry.gd`: **14 passing checks** on generated resources, including zero inverted, degenerate or coplanar-overlapping road triangles; non-overlapping rail tops and fan faces; opaque fan rings; sign visibility; physical clearance of markings; supported, correctly oriented solid ramps; and paused animation.
- `tests/systems.gd`: all **22 input, collision, drift, capacitor, pause, pickup, save/load and menu checks passed**.
- Four full source race suites passed: six racers on Normal, Easy and Hard, and one solo Time Trial. All 19 racer entries completed three laps and 36 ordered gates each. The player fixtures deliberately trigger one recovery; ordinary opponents required zero or one in these runs.
- Focused GPU captures cover the hairpin, boost-pad slope, zone sign and four fan rotation phases. An additional hairpin capture is **3840 × 2160**. Logs are checked for script and shader errors.
- A normal rendered-race capture checks integration with the menu/HUD. The built native executable is separately run through the full headless race regression.
- The app is exported as universal macOS version **0.2**, and its ad-hoc signature is verified. The main-menu footer displays that version.

The machine-readable results and logs are in `tests/geometry_results.json`, `tests/race_results.json`, `tests/systems_results.json`, `tests/native_race_results.json` and their matching logs. Captures are named `tests/scenery-*.png`.

These checks establish that the specific defects above were corrected. They are not a guarantee that every possible visual artefact on every Mac is eliminated. Physical-controller and long-session manual playtesting remain outside the completed validation.
