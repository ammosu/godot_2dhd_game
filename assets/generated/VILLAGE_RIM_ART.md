# Village rim art

Original art generated on 2026-09-29 with the Codex CLI built-in imagegen tool
(`codex exec`, one call per asset), using `village_oak.png` as style reference
and an in-game village screenshot as mood reference. No third-party sources.
Imported with `python3 tools/art/build_village_rim_art.py <source-dir>`
(alpha crop, nearest-neighbour halving only). Lossless import with mipmaps.

| File | Size | Used by |
| --- | --- | --- |
| `village_gate_plaque.png` | 1086 × 362 RGBA | east gate name plaque (text is a Label3D) |
| `village_gate_timber.png` | 627 × 627 RGB, tileable | east gate posts, beams and fence |
| `village_rim_foliage.png` | 1448 × 1086 RGBA, 4 × 3 cells | `rim_foliage.gd`: shrubs, ferns/grass, mossy stones |
| `village_mountains.png` | 1086 × 338 RGBA, tiles horizontally | `village_surroundings.gd` distant ranges ring |

Raw outputs: `exec-38fd1d70-abd9-4912-a950-5932478d1fa2.png` (plaque),
`exec-999abec9-7039-4f69-95cb-47ae4eb7c02b.png` (timber),
`exec-8f589086-07a7-4ff0-8af7-30cd94ace843.png` (foliage),
`exec-ac5a5095-7d46-4903-be70-8a2d74d0fd49.png` (mountains), under
`~/.codex/generated_images/`.

Prompts (each prefixed with the save-to-file instruction and reference notes):

- Plaque: horizontal weathered dark cedar name plaque for a rural fantasy village
  gate, front-on, raised carved border, iron corner brackets, two hanging rings,
  faint moss; empty flat central field for overlaid text; HD-2D pixel art, 3:1,
  no text or background.
- Timber: seamless tiling albedo of weathered dark oak planks, vertical grain,
  knots, cracks, silvered edges, evenly lit, no text or metal.
- Foliage: 4 × 3 transparent atlas; row 1 four shrubs (round, wide low, pale
  flowers, holly), row 2 ferns and grass tufts, row 3 mossy stones (boulder,
  slab, cluster, standing rock); side view matching the oak, no ground or shadows.
- Mountains: 3:1 panorama of layered moonlit ranges, snow-capped far peaks and
  forested near ridges, transparent sky, bottom fading to #263f40, seamless
  left/right edges, no moon, stars, clouds or text.
