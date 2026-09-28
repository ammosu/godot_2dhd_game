"""Measure town atlas alpha bounds; preserve generated PNG pixels unchanged."""
from pathlib import Path
import json
from inspect_action_atlases import measure

ROOT = Path(__file__).resolve().parents[2] / "assets/generated/town"
WARDROBES = 7
# Empty-handed diagonal walk sheets (4 directions x neutral/contact A/contact B).
DIAGONAL_SUFFIX = "_diagonal"


def main():
    data = {}
    for path in sorted(ROOT.glob("*.png")):
        diagonal = path.stem.endswith(DIAGONAL_SUFFIX)
        data[path.stem] = measure(path, expected=12 if diagonal else 20, columns=4 if diagonal else 5)
        print(f"{path.stem}: measured town poses")
    wardrobes = [stem for stem in data if not stem.endswith(DIAGONAL_SUFFIX)]
    assert len(wardrobes) == WARDROBES, "Expected seven wardrobes"
    for stem in data:
        if stem.endswith(DIAGONAL_SUFFIX):
            assert stem.removesuffix(DIAGONAL_SUFFIX) in wardrobes, f"{stem} has no matching wardrobe"
    (ROOT / "regions.gd").write_text(
        "extends RefCounted\n## Measured alpha bounds; source PNGs are unchanged.\n"
        "const DATA: Dictionary = " + json.dumps(data, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
