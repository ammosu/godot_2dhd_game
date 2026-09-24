"""Measure original heroine PNGs and map reviewed poses; never edit image pixels."""
from pathlib import Path
import json
from inspect_action_atlases import measure
ROOT = Path(__file__).resolve().parents[2] / 'assets/generated/heroines'
data = {}
for name in ['traveler', 'archer', 'mage', 'thief']:
    main = measure(ROOT / (name + '.png'), expected=42 if name == 'mage' else 48)
    support = measure(ROOT / (name + '_support.png'), expected=12) if name != 'archer' else None
    # Review showed support poses in several generated rows facing the wrong way.
    # Replace those cells with a separately generated right/back support sheet.
    entries = []
    for facing in range(4):
        main_row = [0, 2, 4, 5 if name == 'mage' else 6][facing]
        idle = main['frames'][main_row * 6]
        for pose in range(12):
            sheet, flip = name, False
            index = main_row * 6 + pose
            height = idle[3]
            if support and pose >= 6 and (facing in [1, 2] or (name == 'mage' and facing == 3)):
                sheet = name + '_support'
                index = (6 if facing == 2 else 0) + pose - 6
                flip = facing == 3
                # Match the standing hurt body's height, avoiding raised weapons.
                reference_hurt = main['frames'][10][3]
                height = idle[3] * support['frames'][4 if facing != 2 else 10][3] / reference_hurt
            if name == 'mage' and facing == 2 and pose == 5:
                index = main_row * 6  # Back recovery returns to standing, not fallen.
            boxes = support['frames'] if sheet.endswith('_support') else main['frames']
            entries.append({'sheet': sheet, 'box': boxes[index], 'body_height': height, 'flip': flip})
    data['female_' + name] = entries
    print(name, len(entries), 'mapped poses')
(ROOT / 'regions.gd').write_text('extends RefCounted\n## Measured original PNG alpha bounds and reviewed pose mapping.\nconst DATA: Dictionary = ' + json.dumps(data, indent=2).replace('true', 'true').replace('false', 'false') + '\n')
