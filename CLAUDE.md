# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Godot 4.7 project for the Hiroshima AI Game Jam (team 4). It is currently an **empty starter**: no scenes, no scripts, no main scene configured. Everything below the engine config is still to be built.

## Engine / toolchain

Godot **4.7.1-stable** is not on `PATH`. The binary lives at:

```
C:\Users\you-r\Desktop\Godot_v4.7.1-stable_win64.exe
```

This is the GUI executable, so `$LASTEXITCODE` comes back empty when invoked from PowerShell — **judge success by parsing stdout/stderr for `ERROR`/`SCRIPT ERROR`, not by exit code.**

### Commands

```powershell
$godot = "C:\Users\you-r\Desktop\Godot_v4.7.1-stable_win64.exe"
$proj  = "c:\work\godot\hiroshima-ai-game-jam-team-4"

# Reimport assets + regenerate .godot/ (run after adding any new asset or .tscn)
& $godot --headless --path $proj --import

# Headless smoke test: boot the main scene, run ~3s, quit. Primary verify loop.
& $godot --headless --path $proj --quit-after 180

# Run the game with a window
& $godot --path $proj

# Open the editor
& $godot -e --path $proj
```

Until `run/main_scene` is set in [project.godot](project.godot), any `--quit`/`--quit-after` run fails with `Can't run project: no main scene defined`.

## Working conventions

- **Author `.tscn` / `.gd` files directly** rather than driving the editor GUI, then verify headlessly with the commands above. The `godot-vibe-coding` skill covers the scene-file format and the traps that produce a loadable-but-broken project — load it before hand-writing scene files.
- After hand-writing a `.tscn`, run `--headless --import` before the smoke test; skipping it leaves stale `.import`/UID state and scenes load with missing resources.
- `.godot/` is generated and gitignored — never edit or commit it.
- Not currently a git repository (`git init` has not been run).

## Project settings that affect gameplay code

- **Stretch**: `canvas_items` / `expand` — design 2D UI against the base viewport size and let the engine scale; avoid hardcoding pixel positions off the window size.
- **3D physics**: Jolt (not Godot Physics) — collision/solver behavior and some `PhysicsServer3D` parameters differ from the default engine.
- **Renderer**: Forward+ with the D3D12 driver on Windows — shaders must be Forward+ compatible; Compatibility-renderer-only assumptions will break.
- Text files are UTF-8 with LF endings ([.editorconfig](.editorconfig), [.gitattributes](.gitattributes)).
