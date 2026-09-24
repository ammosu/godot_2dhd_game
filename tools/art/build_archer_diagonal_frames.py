"""Measure the male archer's original RGBA diagonal atlas without editing pixels.

Requires Pillow. Run from the repository root after saving archer_diagonal_walk.png.
The column pivot and body scale remain fixed across each direction's walk cycle.
"""
from pathlib import Path
from inspect_action_atlases import measure

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/generated/classes'
DIRECTIONS = ['down_left', 'down_right', 'up_left', 'up_right']


def main():
    data = measure(ART / 'archer_diagonal_walk.png', expected=12, columns=4)
    boxes = data['frames']
    lines = ['[gd_resource type="SpriteFrames" load_steps=14 format=3]', '',
             '[ext_resource type="Texture2D" path="res://assets/generated/classes/archer_diagonal_walk.png" id="1"]', '']
    for column, direction in enumerate(DIRECTIONS):
        idle = boxes[column]
        # One source-space pivot per column; moving a foot must not move the body.
        pivot = idle[0] + idle[4]
        for row, pose in enumerate(['idle', 'walk_a', 'walk_b']):
            x, y, w, h, _ = boxes[row * 4 + column]
            lines += [f'[sub_resource type="AtlasTexture" id="{direction}_{row}"]',
                      'atlas = ExtResource("1")', f'region = Rect2({x}, {y}, {w}, {h})',
                      'filter_clip = true', f'metadata/ground_y = {float(h)}',
                      f'metadata/anchor_x = {float(pivot-x)}',
                      f'metadata/body_height = {float(idle[3])}',
                      f'metadata/pixel_size = {1.575 / idle[3]}',
                      f'metadata/pose = "{pose}"', f'metadata/direction = "{direction}"',
                      'metadata/variant = "class_archer"', '']
    lines += ['[resource]', 'animations = [']
    for column, direction in enumerate(DIRECTIONS):
        frames = ', '.join('{"duration": 1.0, "texture": SubResource("%s_%d")}' % (direction, row) for row in [0, 1, 0, 2])
        lines += [f'{{"frames": [{frames}], "loop": true, "name": &"{direction}", "speed": 8.0}}' + (',' if column < 3 else '')]
    lines += [']', '']
    (ART / 'archer_diagonal_frames.tres').write_text('\n'.join(lines))
    print('Measured 12 archer diagonal poses; fixed pivots and scale per facing')


if __name__ == '__main__':
    main()
