# Byte Rush 0.9 — Input-prompt audit

Reviewed and rebuilt on 27 October 2026. This pass searched the game's player-facing strings and inspected the shared prompt renderer, screen-specific instructions, tooltip descriptions, transient announcements and disconnect behavior.

## Findings repaired

1. **Results drift tip was hard-coded to Space.** Both Grand Prix and Time Trial showed the keyboard sentence for every controller. The tip is now an inline control showing the current **drift icon** from the same renderer as the HUD: PlayStation ×, Xbox A, Nintendo B, generic south-button position, or the keyboard spacebar. It redraws on device changes without rebuilding the results menu or moving focus. Its description follows the same binding.
2. **Generic-pad help borrowed Xbox labels.** Its trigger and shoulder descriptions said RT/LT/RB. They now use neutral position names in descriptions and position diagrams in the visible artwork. Recognized PlayStation, Xbox and Nintendo pads retain their own labels and symbols.
3. **Disconnect instructions could remain after switching to another pad.** The notification is now input-neutral, and selecting a usable controller clears it, including the already-open pause screen.

The source-only baseline in `tests/review-baseline/prompt-audit-before.log` preserves the reproduced failures before these changes. It intentionally contains failures. Current reports and logs are directly under `tests/`.

## Coverage

| UI context | Input profiles exercised |
| --- | --- |
| Main menu and driving guide | Keyboard/mouse, PlayStation, Xbox, Nintendo, generic pad |
| Settings opened from main menu | All five |
| Countdown HUD | All five |
| Driving HUD | All five |
| Pause menu and disconnect notification | All five |
| Settings opened from pause | All five |
| Grand Prix results and drift tip | All five |
| Time Trial results and drift tip | All five |

Each context switches through all profiles and back to keyboard using parsed input events while the screen stays open. Assertions check the active profile, foreign-device wording in UI text/descriptions, and preservation of the screen and focus. Separate binding expectations distinguish PlayStation, Xbox and Nintendo conventions; Nintendo's A-confirm/B-drift distinction is checked explicitly. Results tips are checked again for the active drift binding. Disconnect-to-keyboard fallback and handoff to another controller are checked too.

The runtime matrix contains **67 assertions**, all passing in both the source and exported graphical app. The existing **50 controller menu/physics assertions** also pass in both. The graphical run renders actual frames and captures Grand Prix and Time Trial results for all five profiles. These captures use deterministic finish-time fixtures to reach each UI state; they are not records of manually driven races. Captures and current reports include:

- `tests/prompt_audit_results.json` and `tests/prompt_audit_tests.log` — source matrix.
- `tests/native_prompt_audit_results.json` and matching log — rebuilt app matrix.
- `tests/controllers_results.json`, `tests/native_controllers_results.json` and matching logs — existing navigation/driving checks.
- `tests/playstation-results.png`, `xbox-results.png`, `nintendo-results.png`, `generic-results.png`, `keyboard-results.png` and corresponding `-tt` captures.

## Remaining content reviewed

Menu and HUD input artwork uses the shared per-family renderer. Main/settings driving-guide descriptions already updated when input changed. Pickup, boost, recovery, shield, lap, countdown and wrong-way announcements use device-neutral wording. In-world signs identify the course, zones, jumps and service bridge; the Keyboard Kingdom theme and decorative key legends describe the environment, not a keyboard control scheme. Those remain visible to all players intentionally.

The controller-name caption and unfamiliar footer navigation artwork remain removed. The keyboard footer retains Tab. Device switching continues to preserve menu focus.

## Reproduction and limits

Commands are in `README.md`. Reports use private validation settings/records. The matrix's test-only input gate filters incidental physical input so a real mouse movement during automation cannot invalidate a chosen synthetic profile. That gate is excluded from the app export with the rest of `tests/`.

Tests exercise parsed standard Godot/SDL controller events and real GUI rendering, not physical presses of every controller. These checks do not establish universal hardware/driver compatibility. The renderer contains distinct profiles rather than treating all controllers as Xbox controllers. The native build remains universal arm64/x86_64 and ad-hoc signed; audio and race physics are unchanged from the earlier releases. Older full-race, audio and geometry evidence is historical rather than freshly rerun for this prompt-only update.
