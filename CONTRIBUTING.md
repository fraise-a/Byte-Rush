# Contributing

Use Godot 4.5.1 Standard and Python 3.9 or newer. Import `project.godot` before running from a fresh checkout. No Python packages are needed.

## Making changes

Keep changes focused and preserve the existing GDScript tab indentation. Keep generated `.gd.uid` files and asset `.import` settings in version control; leave `.godot/` untracked. Do not put compiled apps, engine binaries, export templates, local save files or signing credentials in commits.

Run `python3 tools/test.py --godot /path/to/godot` before submitting a change. For gameplay, input, audio or rendering changes, also run the relevant native tests listed in [tests/README.md](tests/README.md) and describe the manual checks performed. Controller automation uses simulated events and cannot replace testing real controller hardware.

For bug reports, include the game version, macOS version, controller model, active screen, reproduction steps and any relevant error output. For pull requests, describe the behavior changed and how you verified it.

## Building and releasing

Use `tools/build_macos.sh` after installing matching export templates. The output is in the ignored `build/` directory. Keep the version in `scripts/game.gd` synchronized with `application/short_version` and `application/version` in `export_presets.cfg`; update `RELEASES.md` for a release. The test runner checks these fields agree.

Original code is MIT licensed. Retain the bundled font licence and third-party notices when redistributing. Historical audit notes are in [docs/](docs/README.md).
