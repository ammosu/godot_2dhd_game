"""Measure the 3-column, 8-direction atlases; never modify source pixels."""
from pathlib import Path
import json
from inspect_action_atlases import measure

ROOT = Path(__file__).resolve().parents[2] / 'assets/generated/enemy_movement'


def main():
    data = {}
    for name in ('moss_wolf', 'guardian', 'eclipse_mage', 'dusk_bat', 'ash_warden'):
        data[name] = measure(ROOT / f'{name}.png', expected=24, columns=3, expand_bat=False)
        print(f'{name}: 8 directions x 3 measured poses')
    data['dusk_bat']['rear'] = measure(ROOT / 'dusk_bat_rear.png', expected=6, columns=3, expand_bat=False)
    serialized = json.dumps(data, indent=2)
    (ROOT / 'regions.json').write_text(serialized + '\n')
    (ROOT / 'regions.gd').write_text('extends RefCounted\n## Generated alpha bounds; PNG pixels are unchanged.\nconst DATA: Dictionary = ' + serialized + '\n')


if __name__ == '__main__':
    main()
