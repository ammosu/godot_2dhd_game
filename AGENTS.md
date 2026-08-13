# AGENTS.md

This file defines the repository-wide working agreement for coding agents. It applies to every file in this repository unless a more specific `AGENTS.md` exists in a subdirectory.

## Project overview

- Project: **Wanderlight: Moon Shard**, an HD-2D JRPG vertical slice.
- Engine: **Godot 4.7.1 stable** using typed GDScript.
- Main scene: `res://scenes/main.tscn`.
- Desktop renderer: Forward+.
- Web renderer: Compatibility (`gl_compatibility`), single-threaded export.
- Web deployment: GitHub Pages through `.github/workflows/deploy-pages.yml`.

## Repository map

- `project.godot`: project, input, renderer, and autoload configuration.
- `scenes/`: Godot scenes. `main.tscn` is the playable world; `player.tscn` owns the player scene.
- `scripts/world.gd`: map construction, encounters, HUD, and end-to-end smoke test.
- `scripts/systems/game_state.gd`: authoritative quest, inventory, player stats, map state, and save/load data.
- `scripts/player.gd`: movement and player presentation.
- `scripts/camera_rig.gd`: camera following, rotation, zoom, and renderer-specific camera effects.
- `scripts/gameplay/`: reusable interaction behavior.
- `scripts/ui/`: dialogue and battle flows.
- `shaders/`: canvas post-processing shaders.
- `assets/third_party/`: third-party art and its local license files.
- `THIRD_PARTY_ASSETS.md`: required manifest for all third-party assets.
- `export_presets.cfg`: Web export preset.

## Development rules

- Keep GDScript typed. Add explicit parameter, return, and member types when the type is not already unambiguous.
- Keep `GameState` authoritative for persistent gameplay state. UI nodes should display or request state changes, not maintain competing copies.
- Preserve the existing scene/script boundaries. Move reusable gameplay behavior out of `world.gd` when it becomes an independent system.
- Do not hand-edit generated files inside `.godot/`, and never commit that directory.
- Do not commit `build/` Web exports. CI creates and publishes them.
- Preserve pixel-art nearest-neighbor filtering unless a specific asset calls for another mode.
- Treat saves as versioned data. If the save schema changes, update `SAVE_VERSION` and provide deliberate compatibility or migration behavior.
- Use `user://` for runtime save data; tests must not overwrite a player's normal save.

## Renderer and Web constraints

- Do not replace the desktop Forward+ renderer merely to fix Web behavior. Use platform-specific configuration when possible.
- Godot Web requires Compatibility rendering. Test renderer-sensitive changes in both Forward+ and `gl_compatibility`.
- Compatibility does not support depth-of-field blur. Guard unsupported effects instead of allowing runtime warnings.
- Keep the Web export single-threaded unless the hosting configuration is also updated for cross-origin isolation.
- UI fonts used by the Web build must be bundled with the project; do not depend on operating-system font fallback.

## Verification

Run checks from the repository root.

Full playthrough smoke test on the desktop renderer:

```bash
godot --headless --path . --rendering-method forward_plus -- --playthrough-test
```

Full playthrough smoke test with Web-compatible rendering:

```bash
godot --headless --path . --rendering-method gl_compatibility -- --playthrough-test
```

Successful runs must contain:

```text
PLAYTHROUGH_TEST_PASS dialogue quest maps save battle
```

Verify the Web export when changing rendering, assets, project settings, export settings, or deployment code:

```bash
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
```

Before declaring work complete:

- Check command output for both `ERROR:` and `SCRIPT ERROR:`; exit code alone is not sufficient for Godot checks.
- Run `git diff --check`.
- Review `git status --short` and keep unrelated user changes untouched.

## Assets and licensing

- Do not add assets copied from commercial games or sources without a clear redistribution license.
- For every new third-party asset, record the author, canonical source, source revision or version, acquisition date, license, local file paths, and any attribution requirement in `THIRD_PARTY_ASSETS.md`.
- Store required license text beside the corresponding third-party assets.
- Prefer original, CC0, or permissively licensed assets. Do not assume that a publicly accessible file is reusable.

## Documentation and delivery

- Update `README.md`, `tests/README.md`, or `docs/ROADMAP.md` when commands, gameplay flow, architecture, or deployment behavior changes.
- Do not commit, push, publish, or change repository settings unless the user explicitly asks.
- When asked to commit, use a focused commit message and include only files relevant to the requested change.
