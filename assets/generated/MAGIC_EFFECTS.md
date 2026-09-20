# Frost nova — 2026-09-20

`frost_nova.png`: original built-in ImageGen 1254 × 1254 RGBA, unchanged source. Four equal 627-square cells: gathering, impact burst, expanded fragments, fading motes. `scripts/ui/magic_burst.gd` plays each cell for 0.16 seconds with nearest filtering and transparent blending; impact emits once at the second frame and the node frees after 0.64 seconds. Radius sets its display bounds; a cast-range ring is shown during gathering.

`scripts/gameplay/area_skill.gd` is a pure battle-space radius query, including boundary targets and excluding allies, defeated or invalid actors. `scripts/systems/party_battle.gd`, owned by GameState, now uses it for the main 3-versus-3 encounter. `party_battle_ui.gd` maps battle positions/radii with the same 56 px/unit scale, previews affected targets and resolves damage on the burst impact signal. Moon Bolt reuses the gathering frame as a traveling single-target projectile followed by a smaller burst. This is local party combat, not network multiplayer.

Tests: `tests/area_skill_test.gd`, `tests/magic_burst_test.gd`.

## Final built-in ImageGen prompt

> Use case: stylized-concept. Original production pixel-art JRPG magic explosion sprite sheet, square 2x2 atlas, exactly four animation keyframes read left to right then next row. Spell: frost star nova, cyan ice shards with pale lavender edge accents and small ivory star core. TOP LEFT small gathering icy star, TOP RIGHT energetic radial burst of jagged ice shards, BOTTOM LEFT expanded thin ring of scattered ice fragments with empty transparent center, BOTTOM RIGHT few fading tiny crystal motes. Fixed common center and generous transparent padding inside each equal quadrant, never cross cell boundaries. TRUE transparent RGBA background throughout, no checkerboard. Crisp deliberate pixel clusters, limited cool palette, no smooth glow cloud, no text, grid, characters, landscape, ground, shadows, weapon or border. All stages separate and fully inside own quadrant. Consistent pixel scale across frames, designed for readable 2D game VFX.
