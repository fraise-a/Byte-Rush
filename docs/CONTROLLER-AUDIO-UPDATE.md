# Byte Rush 0.5 — Controller and audio update

Built and validated on 27 October 2026. The current menu footer displays **1.0**.

## Symbol correction: 0.6

Button names in visible prompts were replaced with vector artwork: PlayStation × / ○ / □ / △, menu glyphs, D-pad and stick icons, keyboard keycaps and return/shift/space/mouse symbols. Xbox and Nintendo buttons carry their physical printed letters. Main menu and Settings guides, pause/results action bars, and all HUD input hints use the same icon renderer. Font coverage cannot turn a PlayStation icon into a missing-character box. Semantic names remain in the controls API for descriptions and tests.

The 50 controller checks were rerun against the source and rebuilt app. PlayStation, Xbox, Nintendo and keyboard layouts were rendered and visually inspected through the presentation captures; generic pad prompts were exercised by the native controller suite. Earlier gameplay/audio/4K measurements below describe 0.5; those systems did not change in this icon-only patch.

## What was wrong

A native probe detected the attached **DualSense Wireless Controller**. In this macOS build, Godot's default `ui_accept` and `ui_cancel` actions had keyboard events but no joypad Confirm or Back events. The game's own joypad actions also used the default device index, so reconnecting or using another controller index could break driving. Instructions were permanently written as keyboard/Xbox labels.

The original source mix was heavily attenuated before the master slider: music -16 dB, race engine -29 dB, drift -24 dB, menu/countdown -12 dB and kart effects -10 dB. Raising the master slider could not restore those source levels. The project's bus-layout key also did not point Godot at the supplied layout.

## Behavior now

- Explicit, per-device Confirm/Back mappings: PlayStation Cross/Circle, Xbox A/B and Nintendo A/B using Nintendo's east-button confirm convention. Generic pads use south/east.
- Driving events accept every controller index. A connected pad is recognized on launch, hot-plug or first meaningful input using its name, raw name and vendor ID. Keyboard or mouse input restores keyboard prompts. Small stick noise does not change input mode.
- Every menu has focus navigation and a contextual action bar. The stick and D-pad navigate, held directions repeat after a deliberate delay, and dropdowns, sliders, checkbuttons and Back work through controller events. Focus is recovered if a mouse click previously removed it.
- Controller Options/Menu/+ starts a quick Grand Prix from the main menu, pauses/resumes driving, and races again from Results. Confirm activates the focused choice.
- Main menu, Settings, pause/results footers and driving HUD show the active controller's buttons. Nintendo B is Back in menus and Drift in gameplay; menu Back is not processed during driving.
- Disconnecting the active controller pauses an unfinished race, releases driving actions and offers keyboard/mouse fallback. Reconnection updates prompts while leaving the race paused for the player to resume.
- Revised mix: music +3 dB, race engine -3 dB, idle/finished engine -12 dB, drift 0 dB, menu/countdown +3 dB and kart effects +2 dB. Master zero fully mutes; maximum uses the full mix. A correctly loaded master hard limiter has a -1 dB ceiling. The slider displays its percentage. Startup applies saved gain/mute before starting playback.

Recognition follows the identity exposed by the driver. A controller emulating another brand may expose that other brand's name. Specialized or unmapped controllers are not claimed universally compatible.

## Validation completed

| Suite | Result |
| --- | --- |
| Source controller integration | 50 assertions passed |
| Exported app, graphical controller integration | 50 assertions passed |
| Exported app, real audio capture | 4 assertions passed |
| Source input/systems | 22 assertions passed |
| Source generated geometry | 14 assertions passed |
| Source correctness / native graphical correctness | 16 / 17 assertions passed |
| Source lifecycle / autotest isolation | 33 / 3 assertions passed |
| GPU display | 17 assertions passed, including exact 3840 × 2160 readback |
| Source and native full races | Four suites passed in each run; all 19 racer entries finished |
| Native package | Universal arm64/x86_64, valid Info.plist, strict ad-hoc signature verification passed |

Controller integration sends **parsed standard Godot/SDL joypad events** through the actual menu GUI and kart physics using virtual device IDs 8–11. It checks all four profile families, lost-focus activation, D-pad/stick navigation, held-direction repeat, dropdown opening/closing, slider adjustment, checkbutton activation, race start/pause/resume, physical acceleration and steering, drifting, item use, input-mode switching and disconnect fallback. The attached DualSense's identity was enumerated on this Mac. A person did not physically press every controller's buttons during validation; Bluetooth/USB, third-party mappings and all hardware variants are not represented as hands-on tested.

Native audio capture compared the old and new music/engine gains through the same real audio driver. At full mix gain, the sampled race mix changed from approximately **-39.2 dBFS RMS to -18.2 dBFS RMS**, about **21 dB stronger**. A busy mix of music, engine, drift, collision and countdown stayed at or below **-1 dBFS peak**. The measurement bus used the same limiter and routed through a muted master, so these are PCM measurements rather than a subjective listening test. Exact captured levels are in `tests/native_audio_mix_results.json`.

Current reports and matching logs are in `tests/`, especially `native_controllers_results.json`, `controllers_results.json`, `native_audio_mix_results.json` and `release_validation.json`. The source menu/presentation captures include `playstation-menu.png`, `playstation-settings.png`, `playstation-driving.png`, `playstation-pause.png`, `xbox-menu.png`, `nintendo-menu.png` and `keyboard-menu.png`. Test settings/records use private validation prefixes.

See `README.md` for the complete controls table and reproduction commands. The app remains ad-hoc signed and is not notarized. Intel runtime, physical-controller connection variants and long-session manual driving remain unverified.

## Implementation references

Godot's [standard controller button positions](https://docs.godotengine.org/en/4.5/classes/class_@globalscope.html#enum-globalscope-joybutton), [controller support](https://docs.godotengine.org/en/4.5/tutorials/inputs/controllers_gamepads_joysticks.html), [device identity API](https://docs.godotengine.org/en/4.5/classes/class_input.html) and [hard limiter](https://docs.godotengine.org/en/4.5/classes/class_audioeffecthardlimiter.html) informed the implementation. SDL's normalized input is used directly; an `is_joy_known()` result alone is not used to reject a controller.

Version 0.7 removes the device-family name from the bottom action bar. The bar now starts directly with navigation and action icons. Input mappings and controller detection are unchanged.

Version 0.8 removes the arrow-cluster and controller navigation glyphs from the footer. The keyboard footer retains Tab; controller footers omit the navigation glyphs. This changes only visible hints.

Version 0.9 audits every UI context for mixed input instructions, replaces the results-screen Space tip with a live drift-button icon, removes Xbox names from generic-pad help and clears stale disconnect notices on controller handoff. See `INPUT-PROMPT-AUDIT.md`.
