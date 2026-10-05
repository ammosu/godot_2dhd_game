# Blender-rigged characters: render and repaint

Created 2026-09-28. Original project art only; no third-party assets. Each
`<name>/` directory holds one character's `walk.png` (raw render), `painted.png`
(repaint), their `*_frames.tres`, `metrics.json` and the unmodified Codex outputs
in `source/` (excluded from the Web export).

| Directory | Class id | Style references |
| --- | --- | --- |
| `wanderer/` | traveler (no class) | `../wanderer_steady_walk.png`, `../wanderer_diagonal_walk.png` |
| `archer/`, `thief/`, `mage/` | archer, thief, mage | `../town/<id>.png` (+ `<id>_diagonal.png` where it exists) |
| `female_traveler/`, `female_archer/`, `female_mage/`, `female_thief/` | heroines | `../town/<id>.png` (+ `<id>_diagonal.png` where it exists) |

Every directory uses the nine-frame layout (standing pose + eight-frame walk,
wanderer 2026-10-05, the rest the same day) and is the exploration walk by
default: the unequipped traveler uses `wanderer/`, each class or heroine its
own directory; traveler gear upgrades keep their hand-painted atlases, and door
gestures and combat keep their existing art. `-- --legacy-hero` restores the
hand-painted exploration atlases.

Facings without diagonal art borrow the nearest cardinal sprite as the identity
reference (front for down-diagonals, profile for up-diagonals).

## Pipeline

1. `tools/art/blender/rig_common.py` holds the shared chibi rig (18 bones; skirt quarters follow the thighs), four-tone toon shading with brush-noise borders, per-material coloured inverted-hull outlines, the walk poses and one orthographic camera (20° elevation, 200 px/m, 352 px canvas). `characters/<name>.py` builds each character's parts (the heroines share `characters/heroine.py`'s ponytail head); `characters/<name>.json` names its painted style references and identity text.
2. `python3 tools/art/build_blender_character.py <name>` renders 8 facings × 9 frames: frame 0 is a dedicated standing pose (`metadata/pose = "stand"`), frames 1-8 one walk cycle of two steps, each passing → up → contact → down. Hips are re-grounded per pose, so the leg angles alone give the body bob (relative to contact: down −5 px, passing +2 px, up +4 px; about 3 % of stature). Every pixel maps to a 32-colour median-cut palette of the style sheets. Each facing is grounded as a whole on its standing sole (y=316): per-frame lowest-pixel grounding erased the bob, because the tilted camera draws a lifted near foot lowest. A stride frame's sole may sit above the line (a far planted foot) and at most `SOLE_SINK` (2 px) below it. Writes `walk.png` / `walk_frames.tres` (`-- --blender-hero`, for the current class). The rig's contact stride (ankle to ankle, currently 0.405 m) is stored as `metadata/step_length`; `player.gd` paces the cycle by that stride but never shorter than `MIN_CADENCE_STRIDE` (0.54 m, the hand-painted stride: at the 0.40 m rig stride a 1.9 m/s cutscene stroll looked hurried) and never above `MAX_STEPS_PER_SECOND` (7); the feet glide a little instead of scurrying.
3. `python3 tools/art/paint_blender_character.py <name>` sends each facing to Codex's built-in ImageGen as its own call: a 3 × 3 guide of the nine rendered frames plus the painted standing sprite of that facing from the style references. One call per facing keeps that facing's frames consistent. Unmodified outputs are kept in `source/<facing>.png`; `--repaint down,up` regenerates chosen facings.
4. The same script fits each painted cell at one median scale per facing (a per-cell scale shrank heads wherever ImageGen bent a knee less than the rig), centres the crown band over the rendered head, splits any remaining height error between crown and sole (standing sole exactly on y=316), keeps ImageGen's own colours (mapping them to the rig palette turned dark hair outlines brown, reading as a second layer of hair), drops alpha below 16 and writes `painted.png` / `painted_frames.tres` (`-- --blender-hero=painted`). It prints each facing's per-frame height error against the rig; facings above about 8-10 px were repainted, keeping the lower-error take unless the lower-error take turned the wrong way (the mage's left profile retake walked screen-right, so the earlier take stayed). Final errors stay within ±13 px. Height error does not catch a wrong facing: inspect every retake by eye.

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

`{identity}` is the `identity` text of `characters/<name>.json`.

> Use your built-in image generation tool to create ONE image, then save the resulting PNG file into the current working directory as painted.png (copy it from wherever the tool writes it). Do not write code to draw or edit the image; it must come from the image generation tool. Reply only with the saved path.
>
> Image generation prompt (pass both attached images as references: image 1 = pose guide, image 2 = identity and style):
>
> Use case: pose-locked repaint of a game walking animation. Image 1 is the POSE GUIDE: a 3x3 sheet of nine 3D-rendered frames of one chibi character, all in the same facing: {facing}. Read it left to right, top to bottom. Frame 1 (top-left): relaxed standing pose, feet together, arms at the sides. Frames 2-9 are one smooth eight-frame walk cycle of two steps: 2 passing (left leg swinging past the planted right leg, knee raised), 3 up (body at its highest, right foot pushing off on its toes, left leg reaching forward), 4 contact (left heel strikes in front, right foot behind on its toes), 5 down (body at its lowest, left knee bent taking the weight, right foot lifting behind), then 6-9 repeat passing, up, contact, down with the legs swapped. Arms swing opposite to the legs. The body really rises and sinks between frames: keep each frame's head height exactly as in image 1. Image 2 is the IDENTITY AND STYLE reference: the game's existing hand-painted pixel-art sprite of the SAME character standing, usually in this same facing; if its facing differs, take only identity and style from it, never its facing.
>
> Repaint all nine frames of image 1 as finished sprites of {identity}, in exactly the painted pixel-art style of image 2: same face, hair shape and hair highlights, outfit details, colour palette, dark brown outlines and soft painterly shading lit from the upper left. All nine frames must show the identical character with the identical face, hair silhouette, head size and outfit; only the legs, arms, coat hem and body height change between frames.
>
> Keep from image 1 for every frame: the exact facing angle, the exact leg and arm positions (which foot is forward, which knee is bent), the head position and height, the silhouette size and the feet position, and the 3x3 placement. The 3D guide's blocky hair and simplified shapes are only placeholders: replace them with the hair and cloth of image 2, but never change pose, facing or size, and never add knots, buns or tails of hair that image 2 does not have. Each sprite stays centred in its own cell with generous transparent margins.
>
> Genuine transparent RGBA background. Square output. No floor, no ground shadow, no text, no labels, no grid lines, no checkerboard, no extra characters.
