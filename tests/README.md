# Testing Byte Rush

Run the default checks from the repository root:

```sh
python3 tools/test.py --godot /path/to/godot
```

The runner requires Godot 4.5.1 Standard and Python 3.9 or newer. It imports the project, checks release-version consistency, then runs these suites sequentially at a fixed 60-frame cadence:

| Suite | Coverage |
| --- | --- |
| `controllers` | Simulated controller events, device switching, navigation and audio settings |
| `systems` | Driving, drifting, items, checkpoints, collisions and persistence |
| `geometry` | Mesh integrity, surface overlap and scenery |
| `correctness` | Race standings and edge cases |
| `lifecycle` | Pause, restart, finish, menus and malformed settings |
| `autotest_isolation` | Separate automated-race preferences and records |
| `display` | Resolution choices, bounded rendering and settings persistence |
| `prompt_audit` | Five input profiles across eight screen contexts |
| `races` | Normal/Easy/Hard Grand Prix and solo Time Trial |

To run selected suites, add `--suite controllers prompt_audit`. Logs and the runner's summary are saved in `build/test-results/`, which Git ignores. Individual test programs also write reports to Godot's user-data folder, printed in their output. Tests use validation save prefixes; automated races suppress saves to the real player profile.

## Native checks

Headless runs do not validate displayed pixels, real mixed audio or the behavior of physical controller hardware. On a Mac with a display and audio device, run the relevant checks directly:

```sh
godot --path . --script res://tests/cursor.gd -- --windowed --mute
godot --path . --script res://tests/audio_mix.gd -- --windowed --mute
godot --path . --fixed-fps 144 --disable-vsync --script res://tests/motion.gd -- --windowed --mute
godot --path . --script res://tests/window_transitions.gd -- --windowed --mute
godot --path . --script res://tests/display.gd -- --windowed --mute
godot --path . --script res://tests/prompt_audit.gd -- --windowed --mute
```

`audio_mix.gd` captures actual mixed PCM while muting speaker output. `motion.gd` compares presentation frames with 60 Hz physics; repeat at 60, 120 and 240 FPS where relevant. The window test changes fullscreen/windowed state. Display and presentation tests may write ignored PNG/JSON files under `tests/`; other native tests write to user data.

`presentation.gd`, `controller_presentation.gd`, `scenery.gd` and `motion_race.gd` produce rendered evidence for manual inspection. Use real PlayStation, Xbox and Nintendo hardware to check button operation, hot-plugging and disconnect recovery before a public release.
