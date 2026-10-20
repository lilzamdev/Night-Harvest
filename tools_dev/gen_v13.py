"""Night Harvest 1.3 art: endless-world terrain tiles and props, building blocks,
wooden/stone tool tiers, zombie drops, boss summons and boss weapons.

Run: python3 tools_dev/gen_v13.py  -> Assets/Generated/v13/*.png
Terrain tiles are recolours of the game's own 3x6 autotile sheets, so edges match
the hand-built village. Tools are recolours of Assets/Items/tools.png. Everything
else is drawn from ASCII templates in the shared palette (gen_props.py).
"""
import os, sys, random
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_props import PAL, sprite, strip, ROOT

OUT = os.path.join(ROOT, "Assets/Generated/v13")
TOOLS = Image.open(os.path.join(ROOT, "Assets/Items/tools.png")).convert("RGBA")
PATH_T = Image.open(os.path.join(ROOT, "Assets/Tiles/Path_Tile.png")).convert("RGBA")
WATER_T = Image.open(os.path.join(ROOT, "Assets/Tiles/Water_Tile.png")).convert("RGBA")
S = {}

PAL.update({
    "1": "f4f8ff",  # snow light
    "2": "d6e2f2",  # snow mid
    "3": "a9bcd6",  # snow shade
    "4": "7f93b3",  # snow dark
    "5": "9fb36a",  # rotten flesh light
    "6": "6d8a44",  # rotten flesh mid
    "7": "4a5e2c",  # rotten flesh dark
    "8": "c4603f",  # brick
    "9": "8a3a28",  # brick dark
    "0": "e48a62",  # brick light
    "m": "7a7486",  # stone
    "M": "a39fae",  # stone light
    "N": "4a4452",  # stone dark
    "K": "2a2530",  # darkest
    "T": "f3f0e6",  # bone
    "E": "c9c2a8",  # bone shade
    "L": "86d05a",  # slime / plague green
    "u": "7b4ec9",  # violet
    "U": "3a2a6e",  # violet dark
    "v": "5fd4d0",  # cyan
    "a": "e07438",  # orange
    "I": "d9c9a0",  # mortar
})


def rgb(ch):
    c = PAL[ch]
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def recolor(im, mapping):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y] in mapping:
                px[x, y] = mapping[px[x, y]]
    return im


# ------------------------------------------------------------------ terrain tiles
def terrain():
    # Path_Tile (tan dirt in grass, 3x6) -> snow in grass
    sand = {}
    for y in range(PATH_T.height):
        for x in range(PATH_T.width):
            p = PATH_T.getpixel((x, y))
            if p[3] and p[0] > p[2] + 40 and p[0] > 150:
                sand[p] = sand.get(p, 0) + 1
    tans = sorted(sand.keys(), key=lambda c: -(c[0] + c[1] + c[2]))
    ramp = [rgb("1"), rgb("2"), rgb("3"), rgb("4")]
    m = {}
    for i, c in enumerate(tans):
        m[c] = ramp[min(i, len(ramp) - 1)]
    S["snow_tile"] = recolor(PATH_T, m)
    # A few sparkles on the plain snow centre tiles
    snow = S["snow_tile"]
    px = snow.load()
    rnd = random.Random(7)
    for (tx, ty) in [(1, 1), (0, 5), (1, 5), (2, 5)]:
        for _ in range(3):
            x = tx * 16 + rnd.randint(3, 12)
            y = ty * 16 + rnd.randint(3, 12)
            if px[x, y] == rgb("1") or px[x, y] == rgb("2"):
                px[x, y] = (255, 255, 255, 255)
    # Water_Tile -> frozen lake (ice)
    blues = {}
    for y in range(WATER_T.height):
        for x in range(WATER_T.width):
            p = WATER_T.getpixel((x, y))
            if p[3] and p[2] > p[0] + 60:
                blues[p] = blues.get(p, 0) + 1
    order = sorted(blues.keys(), key=lambda c: -(c[0] + c[1] + c[2]))
    ice = [(214, 244, 255, 255), (178, 226, 245, 255), (140, 198, 228, 255), (110, 168, 205, 255)]
    m2 = {c: ice[min(i, 3)] for i, c in enumerate(order)}
    S["ice_tile"] = recolor(WATER_T, m2)
    ipx = S["ice_tile"].load()
    for (tx, ty) in [(1, 1), (0, 5), (1, 5), (2, 5)]:
        x0, y0 = tx * 16, ty * 16
        for k in range(5):  # crack lines
            ipx[x0 + 4 + k, y0 + 6 + (k // 2)] = (240, 252, 255, 255)
        ipx[x0 + 11, y0 + 10] = (240, 252, 255, 255)
        ipx[x0 + 12, y0 + 11] = (240, 252, 255, 255)


# ------------------------------------------------------------------ world props
def props():
    S["cactus"] = sprite([
        "......oo........",
        ".....offo.......",
        ".....offo.......",
        "..oo.offo.......",
        ".offooffo.......",
        ".offoFffo..oo...",
        ".offoFffo.offo..",
        ".offfFffooFffo..",
        "..offFfffFffo...",
        "...ooFffeooo....",
        ".....Fffe.......",
        ".....offe.......",
        ".....offe.......",
        ".....offe.......",
        "....oFffeo......",
        "...oooooooo.....",
    ])
    S["dead_bush"] = sprite([
        "................",
        "................",
        "....o.....o.....",
        "...od.o..od.....",
        "....od.o.d..o...",
        ".o...dood..od...",
        ".do...dd..od....",
        "..dd..dd.dd.....",
        "...ddodddd...o..",
        "....dddd...ood..",
        "..oo.ddd.odd....",
        ".....dDdd.......",
        "......dD........",
        ".....oDDo.......",
        "....oooooo......",
        "................",
    ])
    S["berry_bush"] = sprite([
        "................",
        "......oooo......",
        "....ooFFffoo....",
        "...oFfRfffFfo...",
        "..oFfffffRffeo..",
        "..ofRffFffffeo..",
        ".oFffffffRfffeo.",
        ".offRfFfffffReo.",
        ".offfffffRfffeo.",
        ".oeffRffffffeeo.",
        "..oeffffRfeeeo..",
        "..ooeeeeeeeeoo..",
        "....oodDDdoo....",
        "......oDDo......",
        ".....oooooo.....",
        "................",
    ])
    picked = S["berry_bush"].copy()
    pp = picked.load()
    for y in range(16):
        for x in range(16):
            if pp[x, y] == rgb("R"):
                pp[x, y] = rgb("f")
    S["berry_bush_picked"] = picked
    # Snowy pine (32x48)
    rows = []
    w = 32
    for y in range(40):
        half = 2 + int((y % 13) * 0.9) + y // 5
        half = min(half, 14)
        row = ["."] * w
        for x in range(16 - half, 16 + half):
            row[x] = "e"
        if 16 - half - 1 >= 0:
            row[16 - half - 1] = "o"
        if 16 + half < w:
            row[16 + half] = "o"
        rows.append(row)
    # shading: lit left side, dark right edge, snow caps on each tier
    for y, row in enumerate(rows):
        xs = [x for x in range(w) if row[x] == "e"]
        if not xs:
            continue
        x0, x1 = xs[0], xs[-1]
        span = x1 - x0 + 1
        for x in xs:
            t = (x - x0) / max(1, span - 1)
            tier_y = y % 13
            if tier_y == 12 or y == 39:
                row[x] = "o"
            elif tier_y <= 1:
                row[x] = "1"
            elif tier_y == 2 and (x % 3) != 0:
                row[x] = "2"
            elif t < 0.38:
                row[x] = "F" if (x + y) % 5 == 0 else "f"
            elif t > 0.8:
                row[x] = "e"
            else:
                row[x] = "f" if (x * 7 + y * 3) % 11 == 0 else "e"
    rows[0] = list("." * 15 + "oo" + "." * 15)
    for y in range(40, 48):
        r = ["."] * w
        if y < 46:
            r[14], r[15], r[16], r[17] = "o", "d", "D", "o"
        else:
            for x in range(11, 21):
                r[x] = "o" if y == 47 else "."
            r[13], r[14], r[15], r[16], r[17], r[18] = "o", "d", "d", "D", "D", "o"
        rows.append(r)
    S["pine_snow"] = sprite(["".join(r) for r in rows])
    green = S["pine_snow"].copy()
    gp = green.load()
    for y in range(48):
        for x in range(32):
            if gp[x, y] == rgb("1"):
                gp[x, y] = rgb("F") if (x + y) % 2 else rgb("f")
            elif gp[x, y] == rgb("2"):
                gp[x, y] = rgb("f")
    S["pine"] = green
    # Cave mouth (32x24): a dark hole in a rocky mound
    S["cave_mouth"] = sprite([
        "................................",
        "...........oooooooooo...........",
        "........oooMMMMmmmmmmooo........",
        "......ooMMMMmmmmmmmmmNNNoo......",
        ".....oMMMmmmmmmmmmmmmmmNNNo.....",
        "....oMMmmmmmmmmmmmmmmmmmmNNo....",
        "...oMMmmmmmmmoooooommmmmmmNNo...",
        "...oMmmmmmmooKKKKKKoommmmmmNo...",
        "..oMMmmmmooKKKKKKKKKKoommmmNNo..",
        "..oMmmmmoKKKKKKKKKKKKKKommmmNo..",
        "..oMmmmoKKKKKKKKKKKKKKKKommmNo..",
        ".oMMmmoKKKKKKKKKKKKKKKKKKommNNo.",
        ".oMmmmoKKKKKKKKKKKKKKKKKKommmNo.",
        ".oMmmoKKKKKKKKKKKKKKKKKKKKommNo.",
        ".oMmmoKKKKKKKKKKKKKKKKKKKKommNo.",
        "oMMmmoKKKKKKKKKKKKKKKKKKKKommNNo",
        "oMmmmoKKKKKKKKKKKKKKKKKKKKommmNo",
        "oMmmmoKKKKKKKKKKKKKKKKKKKKommmNo",
        "oMmmNoKKKKKKKKKKKKKKKKKKKKoNmmNo",
        "oNmNNoKKKKKKKKKKKKKKKKKKKKoNNmNo",
        "oNNNoKKKKKKKKKKKKKKKKKKKKKKoNNNo",
        ".ooooNNNmmNNNNNNNNNNmmNNNNNoooo.",
        "...ooooooooooooooooooooooooooo..",
        "................................",
    ])
    S["poison_blob"] = sprite([
        "..oooo..",
        ".oLLLLo.",
        "oLlLLLLo",
        "oLLLLL6o",
        "oLLLL66o",
        "o6LL666o",
        ".o6666o.",
        "..oooo..",
    ])
    S["rotten_chunk"] = sprite([
        "..oooo..",
        ".o5556o.",
        "o556666o",
        "o566767o",
        "o666677o",
        "o677777o",
        ".o7777o.",
        "..oooo..",
    ])


# ------------------------------------------------------------------ building blocks
def _outline(im):
    """Adds the dark outline around an opaque block."""
    px = im.load()
    w, h = im.size
    o = rgb("o")
    for x in range(w):
        for y in range(h):
            if px[x, y][3] and (x in (0, w - 1) or y in (0, h - 1)):
                px[x, y] = o
    return im


def wall(kind):
    im = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if kind == "wood":
        top, face, dark, light = rgb("W"), rgb("w"), rgb("d"), rgb("W")
        d.rectangle([0, 0, 15, 7], fill=top)
        for y in (2, 5):
            d.line([1, y, 14, y], fill=rgb("w"))
        d.rectangle([0, 8, 15, 23], fill=face)
        for x in (4, 8, 12):
            d.line([x, 8, x, 22], fill=dark)
        for x in (1, 5, 9, 13):
            d.line([x, 9, x, 21], fill=light)
        d.point([(2, 12), (6, 17), (10, 13), (14, 19)], fill=rgb("D"))
        d.line([0, 8, 15, 8], fill=rgb("D"))
    elif kind == "stone":
        d.rectangle([0, 0, 15, 7], fill=rgb("M"))
        d.point([(3, 2), (9, 4), (12, 2), (6, 5)], fill=(200, 196, 210, 255))
        d.rectangle([0, 8, 15, 23], fill=rgb("m"))
        for y in (12, 16, 20):
            d.line([1, y, 14, y], fill=rgb("N"))
        for i, y0 in enumerate((8, 12, 16, 20)):
            off = 0 if i % 2 == 0 else 4
            for x in range(off + 4, 16, 8):
                d.line([x, y0 + 1, x, y0 + 3], fill=rgb("N"))
            for x in range(off, 16, 8):
                d.point((x + 1, y0 + 1), fill=rgb("M"))
        d.line([0, 8, 15, 8], fill=rgb("N"))
    else:  # brick
        d.rectangle([0, 0, 15, 7], fill=rgb("0"))
        for y in (3, 6):
            d.line([1, y, 14, y], fill=rgb("8"))
        d.rectangle([0, 8, 15, 23], fill=rgb("8"))
        for y in range(11, 23, 3):
            d.line([1, y, 14, y], fill=rgb("I"))
        for i, y0 in enumerate(range(8, 23, 3)):
            off = 0 if i % 2 == 0 else 3
            for x in range(off + 3, 16, 6):
                d.line([x, y0 + 1, x, y0 + 2], fill=rgb("I"))
            for x in range(off, 16, 6):
                d.point((x + 1, y0 + 1), fill=rgb("0"))
        d.line([0, 8, 15, 8], fill=rgb("9"))
    return _outline(im)


def floor(kind):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if kind == "wood":
        d.rectangle([0, 0, 15, 15], fill=rgb("w"))
        for y in (3, 7, 11, 15):
            d.line([0, y, 15, y], fill=rgb("d"))
        for y, x in ((0, 9), (4, 3), (8, 12), (12, 6)):
            d.line([x, y, x, y + 2], fill=rgb("d"))
            d.line([0, y, 15, y], fill=rgb("W")) if y == 0 else None
        for y in (1, 5, 9, 13):
            d.point([(2, y), (7, y), (13, y)], fill=rgb("W"))
    elif kind == "stone":
        d.rectangle([0, 0, 15, 15], fill=rgb("m"))
        d.line([0, 7, 15, 7], fill=rgb("N"))
        d.line([0, 15, 15, 15], fill=rgb("N"))
        d.line([7, 0, 7, 15], fill=rgb("N"))
        d.line([15, 0, 15, 15], fill=rgb("N"))
        for (x, y) in ((1, 1), (9, 1), (1, 9), (9, 9)):
            d.line([x, y, x + 4, y], fill=rgb("M"))
            d.line([x, y, x, y + 3], fill=rgb("M"))
    else:  # brick / tiled
        d.rectangle([0, 0, 15, 15], fill=rgb("8"))
        for y in (3, 7, 11, 15):
            d.line([0, y, 15, y], fill=rgb("9"))
        for i, y0 in enumerate((0, 4, 8, 12)):
            off = 0 if i % 2 == 0 else 4
            for x in range(off + 7, 16, 8):
                d.line([x, y0, x, y0 + 2], fill=rgb("9"))
            for x in range(off, 16, 8):
                d.point((x + 1, y0), fill=rgb("0"))
    return im


def doors():
    closed = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(closed)
    d.rectangle([0, 0, 15, 23], fill=rgb("d"))       # frame
    d.rectangle([2, 2, 13, 23], fill=rgb("w"))       # door slab
    for x in (5, 9):
        d.line([x, 3, x, 22], fill=rgb("d"))
    d.line([3, 7, 12, 7], fill=rgb("D"))
    d.line([3, 17, 12, 17], fill=rgb("D"))
    d.point([(11, 12), (11, 13)], fill=rgb("y"))
    d.point([(3, 3), (3, 4)], fill=rgb("W"))
    _outline(closed)
    S["door_wood"] = closed
    opened = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(opened)
    d.rectangle([0, 0, 15, 23], fill=rgb("d"))
    d.rectangle([2, 2, 13, 23], fill=rgb("K"))       # dark doorway
    d.rectangle([2, 2, 4, 23], fill=rgb("w"))        # slab swung in, seen edge-on
    d.line([4, 2, 4, 23], fill=rgb("D"))
    _outline(opened)
    S["door_wood_open"] = opened
    # The open doorway leaves the bottom row walkable: clear the bottom outline middle
    op = S["door_wood_open"].load()
    for x in range(5, 14):
        op[x, 23] = rgb("K")


def fence():
    S["fence_wood"] = sprite([
        "................",
        "................",
        "..oo........oo..",
        ".oWwo......oWwo.",
        ".oWwoooooooowWo.",
        ".oWwWWWWWWWWwwo.",
        ".oWwddddddddwwo.",
        ".oWwoooooooowwo.",
        ".oWwo......owwo.",
        ".oWwoooooooowwo.",
        ".oWwWWWWWWWWwwo.",
        ".oWwddddddddwwo.",
        ".oWwoooooooowwo.",
        ".odDo......odDo.",
        ".oooo......oooo.",
        "................",
    ])


def blocks():
    for k in ("wood", "stone", "brick"):
        S["wall_" + k] = wall(k)
        S["floor_" + k] = floor(k)
    doors()
    fence()
    # Block icons: the front of each wall / a floor tile with an outline
    for k in ("wood", "stone", "brick"):
        w = S["wall_" + k]
        ic = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        ic.alpha_composite(w.crop((0, 4, 16, 20)), (0, 0))
        _outline(ic)
        S["icon_wall_" + k] = ic
        f = S["floor_" + k].copy()
        fi = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        fi.alpha_composite(f.crop((0, 0, 14, 10)).resize((14, 10)), (1, 4))
        d = ImageDraw.Draw(fi)
        d.rectangle([0, 3, 15, 14], outline=rgb("o"))
        S["icon_floor_" + k] = fi
    di = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    di.alpha_composite(S["door_wood"].resize((11, 16), Image.NEAREST), (2, 0))
    S["icon_door_wood"] = di
    S["icon_fence_wood"] = S["fence_wood"]
    S["brick_item"] = sprite([
        "................",
        "................",
        "................",
        "................",
        "...oooooooooo...",
        "..o0000000088o..",
        ".o088888888889o.",
        ".o888888888899o.",
        ".o888888888899o.",
        ".o889999999999o.",
        "..oooooooooooo..",
        "................",
        "................",
        "................",
        "................",
        "................",
    ])


# ------------------------------------------------------------------ tools & items
METAL = [(240, 245, 255, 255), (165, 180, 200, 255), (100, 115, 135, 255), (225, 230, 240, 255), (155, 165, 180, 255)]
TIER = {
    "wooden": [(222, 176, 112, 255), (176, 124, 64, 255), (112, 72, 36, 255), (206, 160, 98, 255), (150, 104, 54, 255)],
    "stone": [(214, 212, 206, 255), (150, 148, 146, 255), (92, 90, 96, 255), (196, 194, 190, 255), (128, 126, 128, 255)],
}


def tools():
    # tools.png: 0 sword, 1 axe, 2 watering can, 3 pickaxe, 4 hoe
    for tier in ("wooden", "stone"):
        m = dict(zip(METAL, TIER[tier]))
        for col, name in ((0, "sword"), (1, "axe"), (3, "pickaxe"), (4, "hoe")):
            S[f"icon_{tier}_{name}"] = recolor(TOOLS.crop((col * 16, 0, col * 16 + 16, 16)), m)


def misc_items():
    S["icon_rotten_flesh"] = sprite([
        "................",
        "................",
        "................",
        ".....oooo.......",
        "....o5556oo.....",
        "...o5566667oo...",
        "..o556666767o...",
        "..o5667667777o..",
        "..o66767777T7o..",
        "...o6777777TTo..",
        "...o77777777o...",
        "....oo7777oo....",
        "......oooo......",
        "................",
        "................",
        "................",
    ])
    S["icon_berries"] = sprite([
        "................",
        "................",
        ".......oo.......",
        "......ofeo......",
        ".....offe.......",
        "....oooeooo.....",
        "...oRRo.oRRo....",
        "..oRlRRooRlRo...",
        "..oRRRkooRRko...",
        "...okkoRRokko...",
        "....oooRlRooo...",
        ".......oRRko....",
        "........okko....",
        ".........oo.....",
        "................",
        "................",
    ])
    S["icon_rotten_totem"] = sprite([
        "................",
        ".....oooooo.....",
        "....o566665o....",
        "...o5oo66oo7o...",
        "...o5oRooRo7o...",
        "...o566666677o..",
        "...o6oTTTTo7o...",
        "....o6ToTo7o....",
        "....oo6667oo....",
        ".....oddddo.....",
        "....odwwwwdo....",
        "....odwddwdo....",
        "....odwwwwdo....",
        "...odddddddDo...",
        "...oooooooooo...",
        "................",
    ])
    S["icon_plague_idol"] = sprite([
        "................",
        "......oooo......",
        ".....oLLLLo.....",
        "....oLoLLoLo....",
        "....oLLLLLLo....",
        "....o6LuuL6o....",
        ".....o6LL6o.....",
        "....oouuuuoo....",
        "...ouyuuuuyuo...",
        "...ouuUuuUuuo...",
        "....ouuuuuuo....",
        ".....oUuuUo.....",
        "....oyyyyyyo....",
        "...oggggggggo...",
        "...oooooooooo...",
        "................",
    ])
    S["icon_bone_cleaver"] = sprite([
        "................",
        "........ooooo...",
        ".......oTTTTEo..",
        "......oTTTTTEo..",
        ".....oTTTTTEo...",
        "....oTTTTTEEo...",
        "....oETTTEEo....",
        "....ooEEEEo.....",
        "...odooooo......",
        "..odDo..........",
        ".odDo...........",
        "odDo............",
        "oDo.............",
        ".o..............",
        "................",
        "................",
    ])
    S["icon_plague_scythe"] = sprite([
        "................",
        ".......oooooo...",
        ".....ooLLLLLLo..",
        "....oLLooooLLLo.",
        "...oLoo....oLLo.",
        "...oo.....odoLo.",
        "..........odooo.",
        ".........odo....",
        "........odo.....",
        ".......odo......",
        "......odo.......",
        ".....oDo........",
        "....oDo.........",
        "...ouo..........",
        "...oo...........",
        "................",
    ])
    S["icon_giant_heart"] = sprite([
        "................",
        "................",
        "...ooo...ooo....",
        "..o566o.o566o...",
        ".o56666o66666o..",
        ".o5666666666Ro..",
        ".o6666666666ko..",
        ".o666666666kko..",
        "..o6666666kko...",
        "...o66666kko....",
        "....o666kko.....",
        ".....o6kko......",
        "......oko.......",
        ".......o........",
        "................",
        "................",
    ])
    S["icon_bed"] = sprite([
        "................",
        "................",
        "................",
        ".oo.............",
        ".odo............",
        ".odoooooooooooo.",
        ".odzzzzRRRRRRRo.",
        ".odzzzzRRRRRRRo.",
        ".odooooooooooooo",
        ".odwwwwwwwwwwwdo",
        ".odddddddddddddo",
        ".odo.........odo",
        ".ooo.........ooo",
        "................",
        "................",
        "................",
    ])


def pad(im, w, h):
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(im, ((w - im.width) // 2, (h - im.height) // 2))
    return out


def station_icons():
    v12 = os.path.join(ROOT, "Assets/Generated/v12")
    wb = Image.open(os.path.join(v12, "workbench.png")).convert("RGBA")
    S["icon_workbench"] = pad(wb, 34, 34)
    fu = Image.open(os.path.join(v12, "furnace.png")).convert("RGBA").crop((0, 0, 24, 16))
    S["icon_furnace"] = pad(fu, 24, 24)
    an = Image.open(os.path.join(v12, "anvil.png")).convert("RGBA")
    S["icon_anvil"] = pad(an, 24, 24)
    ch = Image.open(os.path.join(ROOT, "Assets/Outdoor decoration/Chest.png")).convert("RGBA")
    S["icon_chest"] = pad(ch, max(ch.width, ch.height), max(ch.width, ch.height))


def extras():
    S["icon_fiber"] = sprite([
        "................",
        "................",
        "......o..o......",
        ".....ofoofo.....",
        "....ofeofeo.o...",
        "..o.ofeofeoofo..",
        ".ofoofeoFeofeo..",
        ".ofeoFeoFeoFeo..",
        "..ofeFeFeFeFeo..",
        "...oFFeFeFeeo...",
        "...ohhhhhhhho...",
        "...ojjjjjjjjo...",
        "....oFeFeFeo....",
        "....oFeFeFeo....",
        ".....oooooo.....",
        "................",
    ])
    S["signpost"] = sprite([
        "................",
        "...oooooooooo...",
        "..oWWWWWWWWWWo..",
        ".oWwwwwwwwwwwdo.",
        "oWwdddwwddwwwwdo",
        ".oWwwwwwwwwwwdo.",
        "..odddddddddoo..",
        "...oooodDoooo...",
        "......odDo......",
        "......odDo......",
        "......odDo......",
        "......odDo......",
        "......odDo......",
        "......odDo......",
        ".....oodDoo.....",
        "....oooooooo....",
    ])
    # Watch tower: 32 x 64, a wooden lookout on four legs with a railed platform
    w, h = 32, 64
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    o, wd, wl, dk, dd = rgb("o"), rgb("w"), rgb("W"), rgb("d"), rgb("D")
    # roof
    d.polygon([(2, 12), (16, 2), (29, 12)], fill=rgb("9"), outline=o)
    d.line([4, 11, 16, 3], fill=rgb("8"))
    d.rectangle([2, 12, 29, 13], fill=o)
    # roof posts
    for x in (4, 26):
        d.rectangle([x, 14, x + 1, 22], fill=dk)
    # platform + railing
    d.rectangle([1, 22, 30, 27], fill=wd, outline=o)
    d.line([2, 23, 29, 23], fill=wl)
    for x in range(4, 29, 4):
        d.line([x, 24, x, 26], fill=dk)
    d.rectangle([1, 28, 30, 30], fill=dk, outline=o)
    # legs and cross braces
    for x in (4, 25):
        d.rectangle([x, 31, x + 2, 62], fill=wd, outline=o)
    d.line([7, 33, 24, 50], fill=dk, width=2)
    d.line([24, 33, 7, 50], fill=dk, width=2)
    d.line([7, 52, 24, 52], fill=dk, width=2)
    # ladder
    d.rectangle([13, 31, 18, 62], outline=dd)
    for y in range(34, 62, 4):
        d.line([14, y, 17, y], fill=wl)
    d.rectangle([2, 62, 29, 63], fill=(0, 0, 0, 90))
    S["watch_tower"] = im
    ic = Image.new("RGBA", (34, 64), (0, 0, 0, 0))
    ic.alpha_composite(im, (1, 0))
    S["icon_watch_tower"] = ic


def main():
    os.makedirs(OUT, exist_ok=True)
    terrain()
    props()
    blocks()
    tools()
    misc_items()
    station_icons()
    extras()
    for k, im in S.items():
        im.save(os.path.join(OUT, k + ".png"))
    print("wrote", len(S), "images to", OUT)


if __name__ == "__main__":
    main()
