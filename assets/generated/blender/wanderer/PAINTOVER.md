# Blender traveler: render and repaint

Created 2026-09-28. Original project art only; no third-party assets.

## Pipeline

1. `tools/art/blender/rig_common.py` holds the shared chibi rig (18 bones; skirt quarters follow the thighs), four-tone toon shading with brush-noise borders, per-material coloured inverted-hull outlines, the walk poses and one orthographic camera (20° elevation, 200 px/m, 352 px canvas). `characters/wanderer.py` builds this character's parts; `characters/wanderer.json` names its painted style sheets and identity text.
2. `python3 tools/art/build_blender_character.py wanderer` renders 8 facings × 4 walk frames, maps every pixel to a 32-colour median-cut palette of the style sheets, puts each frame's lowest opaque pixel on y=316 and writes `walk.png` / `walk_frames.tres` (`-- --blender-hero`). The rig's contact stride (ankle to ankle, currently 0.474 m) is stored as `metadata/step_length`; `player.gd` advances one frame per half of it, so the planted foot does not slide.
3. `python3 tools/art/paint_blender_character.py wanderer` sends each facing to Codex's built-in ImageGen as its own call: a 2 × 2 guide of the four rendered frames plus the painted standing sprite of that facing (row 0 of `../../wanderer_steady_walk.png` or `../../wanderer_diagonal_walk.png`). One call per facing keeps that facing's frames consistent. Unmodified outputs are kept in `source/<facing>.png`; `--repaint down,up` regenerates chosen facings.
4. The same script fits each painted cell to its rendered frame (crown-to-sole height, crown-band centroid, y=316 sole), re-applies the palette and writes `painted.png` / `painted_frames.tres` (`-- --blender-hero=painted`).

## Repaint prompt

`{facing}` is one of:

```
"down": "front view, facing the viewer",
    "up": "back view, facing directly away from the viewer (no face visible)",
    "left": "side profile facing screen-left (face in profile on the left side of the head)",
    "right": "side profile facing screen-right (face in profile on the right side of the head)",
    "down_left": "front three-quarter view turned toward screen-left",
    "down_right": "front three-quarter view turned toward screen-right",
    "up_left": "back three-quarter view walking away toward screen-left (only a sliver of cheek visible)",
    "up_right": "back three-quarter view walking away toward screen-right (only a sliver of cheek visible)",
```

`{identity}` is the `identity` text of `characters/wanderer.json`.

> Use your built-in image generation tool to create ONE image, then save the resulting PNG file into the current working directory as painted.png (copy it from wherever the tool writes it). Do not write code to draw or edit the image; it must come from the image generation tool. Reply only with the saved path.
>
> Image generation prompt (pass both attached images as references: image 1 = pose guide, image 2 = identity and style):
>
> Use case: pose-locked repaint of a game walking animation. Image 1 is the POSE GUIDE: a 2x2 sheet of four 3D-rendered frames of one chibi character, all in the same facing: {facing}. Top-left: passing pose, left foot planted, right leg lifting slightly. Top-right: contact pose, right foot forward on its heel, left foot behind on its toes. Bottom-left: passing pose, right foot planted, left leg lifting slightly. Bottom-right: contact pose, left foot forward on its heel, right foot behind on its toes. Arms swing opposite to the legs. Image 2 is the IDENTITY AND STYLE reference: the game's existing hand-painted pixel-art sprite of the SAME character standing in this same facing.
>
> Repaint all four frames of image 1 as finished sprites of {identity}, in exactly the painted pixel-art style of image 2: same face, hair shape and hair highlights, outfit details, colour palette, dark brown outlines and soft painterly shading lit from the upper left. All four frames must show the identical character with the identical face, hair silhouette and outfit; only the legs, arms and a slight body bob change between frames.
>
> Keep from image 1 for every frame: the exact facing angle, the exact leg and arm positions (which foot is forward), the head position, the silhouette size and the feet position, and the 2x2 placement. The 3D guide's blocky hair and simplified shapes are only placeholders: replace them with the hair and cloth of image 2, but never change pose, facing or size, and never add knots, buns or tails of hair that image 2 does not have. Each sprite stays centred in its own quadrant with generous transparent margins, feet on the same baseline.
>
> Genuine transparent RGBA background. Square output. No floor, no ground shadow, no text, no labels, no grid lines, no checkerboard, no extra characters.
