"""Measure town atlas alpha bounds; preserve generated PNG pixels unchanged."""
from pathlib import Path
import json
from inspect_action_atlases import measure

ROOT = Path(__file__).resolve().parents[2] / "assets/generated/town"


def main():
    data = {}
    for path in sorted(ROOT.glob("*.png")):
        diagonal = path.stem == "archer_diagonal"
        data[path.stem] = measure(path, expected=12 if diagonal else 20, columns=4 if diagonal else 5)
        print(f"{path.stem}: measured town poses")
    assert len(data) == 8, "Expected seven wardrobes and archer diagonals"
    (ROOT / "regions.gd").write_text(
        "extends RefCounted\n## Measured alpha bounds; source PNGs are unchanged.\n"
        "const DATA: Dictionary = " + json.dumps(data, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
