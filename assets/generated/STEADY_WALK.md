# Default traveler: steadier cardinal walk

Created 2026-09-24 with the built-in image_gen tool, editing the project's original
wanderer_walk.png. The selected output is wanderer_steady_walk.png (1254 × 1254
RGBA). The original atlas remains available for existing equipment replacements.

The repair targets the default traveler's changing head shape and face angle when
walking down, left or right. Four cardinal directions use the revised atlas;
diagonals retain their existing alternating-contact art. Each column is registered
by the upper head's alpha centroid, so swinging hands, cape and feet cannot shift
the whole head sideways. The shared 352 × 352 presentation canvas places visible
feet at y=316, preserving the player's existing offset (140) and pixel scale.
Natural differences in stride height remain; this is not a rigidly frozen head.

Rebuild atlas metadata from the unmodified PNG with:

```sh
python3 tools/art/build_steady_wanderer_frames.py
```

The generator edits only Godot texture regions/margins, never image pixels. It
copies the diagonal definitions from wanderer_frames.tres. Equipment variations
continue to use their original matched crops rather than applying the new crop
coordinates to incompatible artwork. Palette styles use the revised default art.

## Generation prompts

Initial edit (intermediate image was not selected):

Use case: precise-object-edit. Asset type: production transparent RGBA walking spritesheet for an HD2D game. Edit target: provided wanderer_walk.png. Fix the distracting head wobble during walking. Preserve this exact silver-haired young traveler, teal coat, cream scarf, brown boots/gloves, belt/pouch and sheathed sword, rendering style and body proportions.
Output a square transparent 4-column x 4-row atlas. Columns left to right: front/down, back/up, left facing, right facing. Rows are four phases of ONE calm walk cycle: neutral passing, left-foot contact, neutral passing, right-foot contact. All 16 full-body sprites must remain separate with clear transparent gutters.
CRITICAL: within each column, use the EXACT SAME head drawing, hair shape, face expression, head width/height, neck angle and facing in all four rows. The face MUST NOT swivel or tilt between steps. Keep the head centered on the same body axis and at the exact same height above the foot baseline across all frames. No side-to-side head wobble, no head resizing, no leaning torso, no bouncing head. Animate ONLY arms and legs, small natural alternating strides; idle/passing frames 1 and 3 share the same head and upright torso. Side-facing sprites must also retain exactly the same face direction between frames. Keep identical body height and scale across all rows and columns. No shadows, floor, labels, grid lines, background, motion blur or new accessories. Genuine alpha transparency.

Final targeted edit of the initial result, using built-in image_gen:

Use case: precise-object-edit. Correct the supplied transparent RPG walking animation atlas. This is an animation registration repair, not an illustration redesign. Keep 4 columns, 4 rows, same silver-haired traveler and costume, clear RGBA transparency and same painted pixel-art aesthetic.
For each column, COPY THE HEAD AND SCARF FROM THE FIRST ROW EXACTLY into the corresponding other three rows. Absolutely identical facial direction, identical hair outline, identical eyes, identical head size, identical head tilt, identical scarf position. Faces do not turn during a walking cycle. All heads in a column occupy the exact same position relative to each cell.
Register ALL sixteen sprites to a uniform cell grid with a COMMON FOOT BASELINE per row and IDENTICAL HEAD HEIGHT. Current bottom row characters are too short: correct this. The upright torso does not sway. Only the arms and legs change, alternating left and right leg forward on the second/fourth rows, neutral passing on first/third. Preserve full separated sprites in order: front, back, left, right columns. Same clothing, weapon and scale in all cells. Fit full characters with empty gutters. No foot shadows, no text, no grid, no background. Make it usable as a stable walk cycle with no visible head wobble, no breathing head size, no head-height jumps.

