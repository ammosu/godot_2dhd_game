"""User-authorized deterministic compositing of approved equipment sprites.

Run from any directory with Pillow installed. Original sheets stay untouched.
NPC mask coordinates use the 2048-wide review view; converted to native pixels.
Defeated weapons are isolated below the body silhouette, retaining new armor.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops

ROOT = Path(__file__).resolve().parents[1] / "assets/generated/equipment"


def mask(image, points, scale=1):
    result = Image.new("L", image.size)
    ImageDraw.Draw(result).polygon([(round(x * scale), round(y * scale)) for x, y in points], fill=255)
    return result


def replace_region(base, source, points, scale=1):
    base.paste(source, (0, 0), mask(base, points, scale))


def npc():
    armor = Image.open(ROOT / "party_armor_npc.png").convert("RGBA")
    weapons = Image.open(ROOT / "party_weapon_npc.png").convert("RGBA")
    out = armor.copy()
    scale = armor.width / 2048
    # Head/shaft silhouettes lie outside the body or over the same shaft.
    # Erase the hanging lantern (not part of the new staff).
    empty = Image.new("RGBA", armor.size)
    replace_region(out, empty, [(208, 108), (303, 108), (303, 290), (213, 290)], scale)
    elder = Image.new("RGBA", armor.size)
    region = mask(weapons, [(205, 65), (321, 65), (321, 178), (288, 221), (287, 553), (293, 567), (293, 639), (253, 639), (253, 567), (260, 553), (260, 222), (205, 178)], scale)
    elder.paste(weapons, (0, 0), region)
    elder = ImageChops.offset(elder, round(12 * scale), 0)
    out.alpha_composite(elder)
    # Preserve the elder's gripping hand; only skin pixels, not the old shaft.
    hand = mask(armor, [(258, 299), (287, 296), (301, 305), (296, 346), (260, 347), (253, 332)], scale)
    out.paste(armor, (0, 0), hand)
    # Noah's new spear shifts left to align with the armored hand.
    spear = Image.new("RGBA", armor.size)
    region = mask(weapons, [(1490, 0), (1595, 0), (1595, 165), (1563, 187), (1563, 635), (1520, 635), (1520, 187), (1490, 165)], scale)
    spear.paste(weapons, (0, 0), region)
    spear = ImageChops.offset(spear, round(-15 * scale), 0)
    # Remove exposed old steel pommel below the new spear's point.
    replace_region(out, empty, [(1512, 599), (1546, 599), (1546, 645), (1512, 645)], scale)
    out.alpha_composite(spear)
    hand = mask(armor, [(1513, 279), (1546, 276), (1561, 291), (1560, 319), (1550, 334), (1513, 337)], scale)
    out.paste(armor, (0, 0), hand)
    out.save(ROOT / "party_both_npc.png")


def defeated():
    armor = Image.open(ROOT / "party_armor_defeated.png").convert("RGBA")
    weapons = Image.open(ROOT / "party_weapon_defeated.png").convert("RGBA")
    out = armor.copy()
    # Follow empty space between armored hands/body and the dropped weapons.
    replace_region(out, weapons, [(360, 739), (815, 737), (815, 726), (1038, 724), (1040, 687), (1210, 687), (1210, 815), (360, 815)])
    replace_region(out, weapons, [(480, 1130), (780, 1109), (930, 1095), (1015, 1093), (1025, 1010), (1190, 1010), (1190, 1235), (480, 1235)])
    out.save(ROOT / "party_both_defeated.png")


if __name__ == "__main__":
    npc()
    defeated()
    print("Composited party_both_npc.png and party_both_defeated.png")
