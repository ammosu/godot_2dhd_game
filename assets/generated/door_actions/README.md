# Door hand actions

Original AI-generated character artwork created with built-in ImageGen on
2026-09-22, using this project's existing traveler walking art as identity and
wardrobe references. These are new articulated arm poses, not affine distortions
of the standing sprite. No third-party source was added.

Each transparent PNG is a 4 × 4 atlas with measured, slightly nonuniform row gutters. First two rows are raised-elbow reach;
last two rows are extended-hand contact. Direction order is down/up/left/right,
then down-left/down-right/up-left/up-right. Runtime measures each cell's opaque
head/boot bounds and foot center, normalizes body height and anchors the boots.
The original unsplit atlases and native alpha are retained without image editing.
Hands are empty; weapons stay sheathed. Four loadouts have independent atlases.

| File | Built-in generated source |
| --- | --- |
| base.png | exec-66ef868f-42d7-4e92-a7fd-b9fc07d1b26a.png |
| moonward.png | exec-d9e1ee90-b062-4412-85d5-3b8755746697.png |
| saber.png | exec-e58354c7-7420-4efe-8321-6c7cc8012b08.png |
| moonward_saber.png | exec-05fdb781-1053-4797-a93d-7fc17afe4e57.png |

Source directory:
`/Users/cwchang/.codex/generated_images/01a0c803-7e2b-78d0-83f7-76c963bd3ec3/`.

Prompt specifications: preserve silver-haired traveler's proportions, face,
clothes and planted feet; draw visibly articulated right elbow/forearm and empty
hand reaching for a door handle, bent anticipation and extended contact in eight
views; 16 equal cells, real RGBA transparency, no doors, labels, floor or shadows.
Moonward edit changes clothing only to violet moon cape, silver pauldrons and
teal clasp. Saber edits change only the sheathed weapon to navy curved scabbard,
silver crescent hilt and turquoise gem. Runtime uses short reach/contact/reach
beats and restores the ordinary walking art after releasing the door.

`tests/door_action_art_test.gd` exercises all four loadouts, grounding metadata,
and actual player contact-before-swing order, and can capture the running game.
