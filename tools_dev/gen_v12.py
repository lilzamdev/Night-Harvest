"""Night Harvest 1.2 art: ores, tiered tools, critters, mine tiles & props, crafting
stations, new crops, cave enemies and boss parts.

Run: python3 tools_dev/gen_v12.py  -> Assets/Generated/v12/*.png
Recolours reuse the game's own sprites (tools.png, Outdoor_Decor_Free.png) so the
new items sit in the same palette. Everything else is drawn from ASCII templates
with the shared palette from gen_props.py.
"""
import os, sys, random
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_props import PAL, sprite, strip, ROOT

OUT = os.path.join(ROOT, "Assets/Generated/v12")
TOOLS = Image.open(os.path.join(ROOT, "Assets/Items/tools.png")).convert("RGBA")
DECOR = Image.open(os.path.join(ROOT, "Assets/Outdoor decoration/Outdoor_Decor_Free.png")).convert("RGBA")
S = {}

PAL.update({
    "a": "e07438",  # copper mid
    "A": "f9a875",  # copper light
    "i": "8a4a2a",  # copper dark
    "v": "5fd4d0",  # crystal cyan
    "V": "c8fff4",  # crystal light
    "u": "7b4ec9",  # crystal violet
    "U": "3a2a6e",  # crystal dark
    "m": "7a7486",  # cave stone
    "M": "a39fae",  # cave stone light
    "N": "4a4452",  # cave stone dark
    "K": "2a2530",  # cave darkest
    "T": "f3f0e6",  # bone
    "E": "c9c2a8",  # bone shade
    "L": "86d05a",  # slime / moss
    "I": "ffa640",  # pumpkin light
    "Q": "e66a1e",  # pumpkin mid
    "X": "9a3e14",  # pumpkin dark
})

METAL = [(240, 245, 255, 255), (165, 180, 200, 255), (100, 115, 135, 255)]
TIERS = {
    "copper": [(255, 206, 160, 255), (222, 124, 62, 255), (138, 70, 40, 255)],
    "gold": [(255, 241, 170, 255), (240, 190, 50, 255), (170, 110, 30, 255)],
    "crystal": [(214, 255, 247, 255), (110, 210, 222, 255), (110, 70, 190, 255)],
    "steel": [(225, 250, 255, 255), (120, 200, 235, 255), (45, 105, 160, 255)],
}


def recolor(im, mapping):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y] in mapping:
                px[x, y] = mapping[px[x, y]]
    return im


def tool(col, tier):
    a = TOOLS.crop((col * 16, 0, col * 16 + 16, 16))
    return recolor(a, dict(zip(METAL, TIERS[tier])))


def decor(col, row, w=1, h=1):
    return DECOR.crop((col * 16, row * 16, (col + w) * 16, (row + h) * 16))


def hue_map(im, fn):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = fn(r, g, b) + (a,)
    return im


def gold_to(target):
    # Map the decor sheet's gold ramp (by brightness) onto another metal ramp.
    def fn(r, g, b):
        if not (r > g > b and r - b > 60):
            return (r, g, b)
        lum = (r + g + b) / 3
        lo, mid, hi = target[2][:3], target[1][:3], target[0][:3]
        if lum > 175:
            return hi
        if lum > 120:
            return mid
        return lo
    return fn


def grey_to(rgb_hi, rgb_mid, rgb_lo):
    def fn(r, g, b):
        if abs(r - g) < 22 and abs(g - b) < 40 and b >= r - 10:
            lum = (r + g + b) / 3
            if lum > 165:
                return rgb_hi
            if lum > 105:
                return rgb_mid
            if lum > 60:
                return rgb_lo
        return (r, g, b)
    return fn


# ------------------------------------------------------------------ ores & items
def ores():
    stone_rock = decor(1, 3)
    S["rock_stone_a"] = decor(0, 3)
    S["rock_stone_b"] = stone_rock
    S["rock_stone_c"] = decor(2, 3)
    # Copper: gold rocks recoloured
    for i in range(3):
        S[f"rock_copper_{'abc'[i]}"] = hue_map(decor(i, 5), gold_to(TIERS["copper"]))
        S[f"rock_gold_{'abc'[i]}"] = decor(i, 5)
    # Iron: grey rocks with rusty-pink veins
    for i in range(3):
        base = decor(i, 3).copy()
        px = base.load()
        rnd = random.Random(40 + i)
        for _ in range(9):
            x, y = rnd.randrange(3, 13), rnd.randrange(5, 14)
            if px[x, y][3] and px[x, y][0] > 80:
                px[x, y] = (214, 160, 140, 255)
                if px[x + 1, y][3]:
                    px[x + 1, y] = (160, 98, 88, 255)
        S[f"rock_iron_{'abc'[i]}"] = base
    # Crystal clusters (silver crystal recoloured to cyan/violet)
    S["rock_crystal"] = hue_map(decor(3, 3), grey_to((214, 255, 247), (95, 212, 208), (123, 78, 201)))
    S["rock_gem"] = hue_map(decor(3, 3), grey_to((255, 214, 240), (232, 90, 160), (140, 40, 110)))
    # Item icons
    S["icon_copper_ore"] = hue_map(decor(0, 6), gold_to(TIERS["copper"]))
    S["icon_iron_ore"] = decor(1, 4)
    S["icon_gold_ore"] = decor(0, 6)
    S["icon_crystal"] = hue_map(decor(1, 4), grey_to((214, 255, 247), (95, 212, 208), (123, 78, 201)))
    S["icon_gem"] = hue_map(decor(1, 6), gold_to([(255, 214, 240, 255), (232, 90, 160, 255), (140, 40, 110, 255)]))
    S["icon_copper_bar"] = hue_map(decor(2, 6), gold_to(TIERS["copper"]))
    S["icon_iron_bar"] = decor(2, 4)
    S["icon_gold_bar"] = decor(2, 6)


def tools():
    # tools.png: 0 sword, 1 axe, 2 watering can, 3 pickaxe, 4 hoe
    for tier in ("copper", "gold", "crystal", "steel"):
        S[f"icon_{tier}_sword"] = tool(0, tier)
        S[f"icon_{tier}_pickaxe"] = tool(3, tier)
        S[f"icon_{tier}_axe"] = tool(1, tier)
    S["icon_gold_can"] = recolor(TOOLS.crop((32, 0, 48, 16)), {(145, 25, 25, 255): (170, 110, 30, 255), (210, 45, 45, 255): (240, 190, 50, 255), (240, 80, 80, 255): (255, 241, 170, 255)})


def misc_icons():
    S["icon_bone"] = sprite([
        "................",
        "................",
        "..oo........oo..",
        ".oTTo......oTTo.",
        ".oTEToooooooTEo.",
        "..oTTTTTTTTTTo..",
        "..oETEEEEEEETo..",
        ".oTEToooooooTEo.",
        ".oTTo......oTTo.",
        "..oo........oo..",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ])
    S["icon_slime_gel"] = sprite([
        "................",
        "................",
        "................",
        "......oooo......",
        ".....oFFLLo.....",
        "....oFlFLLLo....",
        "...oFLLLLLLeo...",
        "...oLLLLLLLeo...",
        "..oLLLLLLLLLeo..",
        "..oeLLLLLLLeeo..",
        "...oeeeeeeeeo...",
        "....oooooooo....",
        "................",
        "................",
        "................",
        "................",
    ])
    S["icon_journal"] = sprite([
        "................",
        "...oooooooooo...",
        "..odDDDDDDDDdo..",
        "..odzzzzzzzzdo..",
        "..odzZZZZZzzdo..",
        "..odzzzzzzzzdo..",
        "..odzZZZZzzzdo..",
        "..odzzzzzzzzdo..",
        "..odzZZZZZZzdo..",
        "..odzzzzzzzzdo..",
        "..odzzzzrrzzdo..",
        "..odzzzzrrzzdo..",
        "..odDDDDDDDDdo..",
        "...oooooooooo...",
        "................",
        "................",
    ])
    S["icon_crown"] = sprite([
        "................",
        "................",
        "................",
        "..o....oo....o..",
        ".oyo..oYYo..oyo.",
        ".oyyooyyyyooyyo.",
        ".oyYyyyvvyyyYyo.",
        ".oyyyyvVVvyyyyo.",
        ".ogyyyyvvyyyygo.",
        ".oggggggggggggo.",
        ".oyYyYyYyYyYyyo.",
        ".oGGGGGGGGGGGGo.",
        "..oooooooooooo..",
        "................",
        "................",
        "................",
    ])
    S["icon_hammer"] = sprite([
        "................",
        "...ooooooooo....",
        "..oSSSSSSSSso...",
        "..oSsssssssto...",
        "..otttdwtttto...",
        "...ooodwoooo....",
        "......dwo.......",
        "......dwo.......",
        "......dwo.......",
        "......dwo.......",
        "......dwo.......",
        "......dwo.......",
        "......dDo.......",
        "......ooo.......",
        "................",
        "................",
    ])
    S["icon_hollow_blade"] = sprite([
        "............ooo.",
        "...........oVvo.",
        "..........oVvuo.",
        ".........oVvuo..",
        "........oVvuo...",
        ".......oVvuo....",
        "......oVvuo.....",
        "..oo.oVvuo......",
        "..ouoVvuo.......",
        "...ouuuo........",
        "...ouuo.........",
        "..oqqoyo........",
        ".oqqo.oyo.......",
        "oqqo...oo.......",
        "oyo.............",
        "oo..............",
    ])


# ------------------------------------------------------------------ critters
def critters():
    wing_up = [
        ".......",
        "oo...oo",
        "oXo.oXo",
        "oXXoXXo",
        ".oXoXo.",
        "..ooo..",
    ]
    wing_dn = [
        ".......",
        ".......",
        "oo.o.oo",
        "oXXoXXo",
        "oXXoXXo",
        ".ooooo.",
    ]
    for name, col in [("b1", "y"), ("b2", "B"), ("b3", "R"), ("b4", "P")]:
        a = sprite([r.replace("X", col) for r in wing_up])
        b = sprite([r.replace("X", col) for r in wing_dn])
        S[f"butterfly_{name}"] = strip([a, b])
    # Sparrow: idle, peck, fly1, fly2 (10x8)
    idle = sprite([
        "..........",
        "....ooo...",
        "...oddDo..",
        "..oddddoyo",
        ".ooddwwdo.",
        "oddwwwwdo.",
        ".oowwwoo..",
        "...o.o....",
    ])
    peck = sprite([
        "..........",
        "..........",
        "....oooo..",
        "..ooddddo.",
        ".oddwwddoo",
        "oddwwwwdoy",
        ".oowwwoo..",
        "...o.o....",
    ])
    fly1 = sprite([
        "o........o",
        "do......od",
        "ddo.oo.odd",
        ".ddoddodd.",
        "..oddwdo..",
        "...owwoyo.",
        "....oo....",
        "..........",
    ])
    fly2 = sprite([
        "..........",
        "..........",
        "....oo....",
        "..ooddoo..",
        ".oddwwddo.",
        "oddowwoddo",
        "oo..oo..oy",
        "..........",
    ])
    S["bird"] = strip([idle, peck, fly1, fly2])
    S["fish"] = strip([sprite([
        "........",
        ".oooo.o.",
        "oBbbboBo",
        "obblbbbo",
        ".oooo.o.",
    ]), sprite([
        "....o...",
        "..oobo..",
        ".obbbo..",
        ".oblbo..",
        "..obo...",
    ])])
    S["leaf"] = strip([sprite(["....", ".ff.", "fFfe", ".ee."]), sprite(["..f.", ".fFe", "fFe.", ".e.."]), sprite(["....", ".hj.", "hHhj", ".jj."])])
    S["splash"] = strip([
        sprite(["......", "......", "..B...", ".B..B.", "......"]),
        sprite(["......", ".B..B.", "B....B", "......", ".BBBB."]),
        sprite(["B....B", "......", "......", ".B..B.", "B....B"]),
    ])
    S["ripple"] = strip([
        sprite(["........", "........", "...BB...", "..B..B..", "...BB...", "........"]),
        sprite(["........", "..BBBB..", ".B....B.", "B......B", ".B....B.", "..BBBB.."]),
    ])
    S["dust"] = strip([
        sprite(["......", "......", "..ZZ..", ".ZzzZ.", "..ZZ..", "......"]),
        sprite(["......", ".ZZZZ.", "Zz..zZ", "Z....Z", ".ZZZZ.", "......"]),
        sprite(["Z....Z", "......", "......", "......", "......", "Z....Z"]),
    ])
    bat1 = sprite([
        "o..........o",
        "Oo........oO",
        "OOo.oooo.oOO",
        ".OOoqrrqoOO.",
        "..OOqqqqOO..",
        "....oOOo....",
        "....o..o....",
        "............",
    ])
    bat2 = sprite([
        "............",
        "............",
        "....oooo....",
        "..ooqrrqoo..",
        ".oOOqqqqOOo.",
        "oOO.oOOo.OOo",
        "oO..o..o..Oo",
        "o..........o",
    ])
    S["bat"] = strip([bat1, bat2])


# ------------------------------------------------------------------ mine tiles & props
def cave_tiles():
    rnd = random.Random(7)
    def tile(base, light, dark, speck, n=10):
        im = Image.new("RGBA", (16, 16), base)
        px = im.load()
        for _ in range(n):
            x, y = rnd.randrange(16), rnd.randrange(16)
            px[x, y] = rnd.choice([light, dark, speck])
            if rnd.random() < 0.5 and x < 15:
                px[x + 1, y] = dark
        return im
    floors = []
    for k in range(4):
        floors.append(tile((74, 62, 72, 255), (96, 84, 94, 255), (58, 48, 58, 255), (110, 96, 100, 255), 14 + k * 3))
    # Floor with a few pebbles / cracks
    f = floors[3].copy()
    for x, y in [(4, 5), (5, 5), (11, 10), (12, 11)]:
        f.putpixel((x, y), (40, 34, 42, 255))
    floors[3] = f
    S["cave_floor"] = strip(floors)
    tops = []
    for k in range(3):
        tops.append(tile((46, 38, 52, 255), (64, 54, 72, 255), (34, 28, 40, 255), (78, 66, 84, 255), 16))
    S["cave_wall_top"] = strip(tops)
    # Wall face: the visible cliff under a wall that has floor below it (16x16)
    face = Image.new("RGBA", (16, 16), (88, 76, 92, 255))
    px = face.load()
    for x in range(16):
        px[x, 0] = (122, 110, 124, 255)
        px[x, 1] = (106, 94, 108, 255)
        px[x, 15] = (40, 32, 44, 255)
        px[x, 14] = (58, 48, 62, 255)
    for x, y0, h in [(3, 3, 6), (8, 5, 7), (12, 2, 5), (5, 10, 3)]:
        for y in range(y0, y0 + h):
            px[x, y] = (62, 52, 66, 255)
            if x + 1 < 16:
                px[x + 1, y] = (110, 98, 112, 255)
    S["cave_wall_face"] = face
    S["ladder"] = sprite([
        "................",
        "....KKKKKKKK....",
        "...KoooooooooK..",
        "...KowdDDDdwoK..",
        "...KoWwwwwwWoK..",
        "...KowdDDDdwoK..",
        "...KoWwwwwwWoK..",
        "...KowdDDDdwoK..",
        "...KoWwwwwwWoK..",
        "...KowdDDDdwoK..",
        "...KoWwwwwwWoK..",
        "...KowdDDDdwoK..",
        "...KoooooooooK..",
        "....KKKKKKKK....",
        "................",
        "................",
    ])
    S["rope"] = sprite([
        "......oo........",
        ".....ohjo.......",
        "......oho.......",
        "......ojo.......",
        "......oho.......",
        "......ojo.......",
        "......oho.......",
        "......ojo.......",
        "......oho.......",
        "......ojo.......",
        "......oho.......",
        "......ojo.......",
        ".....ohjho......",
        "....ojhjhjo.....",
        "....oojjjoo.....",
        "......ooo.......",
    ])
    S["mine_entrance"] = sprite([
        "................................................",
        "..........oooooooooooooooooooooooooo............",
        ".........oWWWWWWWWWWWWWWWWWWWWWWWWWWo...........",
        ".........owwwwwwwwwwwwwwwwwwwwwwwwwwo...........",
        ".........odddddddddddddddddddddddddo............",
        ".........oooooooooooooooooooooooooooo...........",
        "..........owdo..................owdo............",
        "..........owdo..oooooooooooooo..owdo............",
        "..........owdo.oKKKKKKKKKKKKKKo.owdo............",
        "..........owdooKKKKKKKKKKKKKKKKoowdo............",
        "..........owdoKKKKKKKKKKKKKKKKKKowdo............",
        "..........owdoKKKKKKKKKKKKKKKKKKowdo............",
        "..........owdoKKKKKKKKKKKKKKKKKKowdo............",
        "..........owdoKKKKKKKKKKKKKKKKKKowdo............",
        "..........owdoKKKKKKKKKKKKKKKKKKowdo............",
        "..........owdoKKKKKKKKKKKKKKKKKKowdo............",
        "..........owdoKKKKKKKKKKKKKKKKKKowdo............",
        "..........owdoKKKKKKKKKKKKKKKKKKowdo............",
        "..........owdoKKKKKKKKKKKKKKKKKKowdo............",
        "........mMowdoKKKKKKKKKKKKKKKKKKowdoMm..........",
        "......mMMmowdoKKKKKKKKKKKKKKKKKKowdomMMm........",
        ".....mMmmNowdoKKKKKKNNNNNNKKKKKKowdoNmmMm.......",
        "....mMmmmNowdoKKKKNNmmmmmmNNKKKKowdoNmmmMm......",
        "...mMmmmNNowdoKKKNmmmmmmmmmmNKKKowdoNNmmmMm.....",
        "..oooooooooooooooooooooooooooooooooooooooooo....",
    ])
    S["minecart"] = sprite([
        "................",
        "................",
        "................",
        "..oooooooooooo..",
        "..oMmmmmmmmmMo..",
        "..otsssssssstо..".replace("о", "o"),
        "..otmNmNmNmNto..",
        "..otsssssssstо..".replace("о", "o"),
        "...otttttttto...",
        "...oooooooooo...",
        "...oOo....oOo...",
        "...ooo....ooo...",
        "................",
        "................",
        "................",
        "................",
    ])
    S["crate"] = sprite([
        "................",
        "..oooooooooooo..",
        "..oWWWWWWWWWWo..",
        "..owdwwwwwwdwo..",
        "..owwdwwwwdwwo..",
        "..owwwdwwdwwwo..",
        "..owwwwddwwwwo..",
        "..owwwwddwwwwo..",
        "..owwwdwwdwwwo..",
        "..owwdwwwwdwwo..",
        "..owdwwwwwwdwo..",
        "..odddddddddddo.",
        "..oooooooooooo..",
        "................",
        "................",
        "................",
    ])
    S["wall_torch"] = sprite([
        "....",
        ".yY.",
        "yYRy",
        ".rR.",
        ".dw.",
        ".dw.",
        ".Dd.",
        "....",
    ])


def stations():
    S["workbench"] = sprite([
        "................................",
        "................................",
        "......sS..............oo........",
        ".....osSo............oyyo.......",
        ".....otso...ooo.....oyyo........",
        "......oo...oWWWo...oyo..........",
        "oooooooooooooooooooooooooooooooo",
        "oWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWo",
        "owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwo",
        "odddddddddddddddddddddddddddddddo",
        "oooooooooooooooooooooooooooooooo",
        ".odwo....................odwo...",
        ".odwo..oooooooooooooooo..odwo...",
        ".odwo..oWWWWWWWWWWWWWWo..odwo...",
        ".odwo..owwwwwwwwwwwwwwo..odwo...",
        ".odwo..odddddddddddddddo.odwo...",
        ".odwo..oooooooooooooooo..odwo...",
        ".odwo....................odwo...",
        ".oDDo....................oDDo...",
        ".oooo....................oooo...",
    ])
    S["anvil"] = sprite([
        "........................",
        "........................",
        "..oooooooooooooooooooo..",
        ".oSSSSSSSSSSSSSSSSSSSso.",
        "ooSssssssssssssssssssto.",
        "otttttttttttttttttttto..",
        ".oooootttttttttttoooo...",
        ".....otssssssssto.......",
        ".....otssssssssto.......",
        "....ootssssssssToo......".replace("T", "t"),
        "...oOOOOOOOOOOOOOOo.....",
        "..oOOOOOOOOOOOOOOOOo....",
        "..oooooooooooooooooo....",
        "........................",
    ])
    furnace = []
    for a, b in (("yR", "Ry"), ("Ry", "yR")):
        rows = [
            "........................",
            "........oooooooo........",
            "........oNmmmmNo........",
            "........oNmmmmNo........",
            "....oooooooooooooooo....",
            "...oMmmmmmmmmmmmmmmMo...",
            "...oMmNNNNNNNNNNNNmMo...",
            "...omNoooooooooooNmmo...",
            "...omNoKKKKKKKKKKoNmo...",
            "...omNoK" + a * 5 + "oNmo...",
            "...omNo" + b * 5 + "KoNmo...",
            "...omNo" + a * 5 + "yoNmo...",
            "...omNoooooooooooNmmo...",
            "...oMmmmmmmmmmmmmmmMo...",
            "...oNNNNNNNNNNNNNNNNo...",
            "...oooooooooooooooooo...",
        ]
        rows = [r[:24].ljust(24, ".") for r in rows]
        furnace.append(sprite(rows))
    S["furnace"] = strip(furnace)
    S["quest_board"] = sprite([
        "................................",
        "..oooooooooooooooooooooooooooo..",
        ".oWWWWWWWWWWWWWWWWWWWWWWWWWWWWo.",
        ".owddddddddddddddddddddddddddwo.",
        ".owdzzzzzd.dZZZZZZd..dzzzzzzdwo.",
        ".owdzZZZzd.dzzzzzzd..dzZZZzzdwo.",
        ".owdzzzzzd.dzZZZZzd..dzzzzzzdwo.",
        ".owdzZZzzd.dzzzzzzd..dzZZzzzdwo.",
        ".owdzzzzzd.dzZZzzzd..dzzzzzzdwo.",
        ".owdddddddddddddddddddddddddddwo.",
        ".owdd..dzzzzzzzd...dzzzzzzzzddwo.",
        ".owdd..dzZZZZZzd...dzZZZZZZzddwo.",
        ".owdd..dzzzzzzzd...dzzzzzzzzddwo.",
        ".owddddddddddddddddddddddddddwo.",
        ".oWWWWWWWWWWWWWWWWWWWWWWWWWWWWo.",
        "..oooooooooooooooooooooooooooo..",
        ".......odwo..........odwo.......",
        ".......odwo..........odwo.......",
        ".......odwo..........odwo.......",
        ".......odwo..........odwo.......",
        ".......oDDo..........oDDo.......",
        ".......oooo..........oooo.......",
    ])


def placeables():
    S["stone_wall"] = sprite([
        "................",
        ".oooooooooooooo.",
        ".oMMMMoMMMMMMMo.",
        ".ommmmommmmmmmo.",
        ".oNNNNoNNNNNNNo.",
        ".oooooooooooooo.",
        ".oMMMMMMMoMMMMo.",
        ".ommmmmmmommmmo.",
        ".oNNNNNNNoNNNNo.",
        ".oooooooooooooo.",
        ".oMMMoMMMMMMMMo.",
        ".ommmommmmmmmmo.",
        ".oNNNoNNNNNNNNo.",
        ".oooooooooooooo.",
        "................",
        "................",
    ])
    S["iron_spikes"] = sprite([
        "................",
        "................",
        "................",
        "...o...o...o....",
        "..oSo.oSo.oSo...",
        "..oSo.oSo.oSo...",
        ".osSsosSsosSso..",
        ".ostsostsostso..",
        "..o.o..o.o..o.o.",
        ".o.o..o.o..o.o..",
        "oSo..oSo..oSo...",
        "osSoosSsoosSso..",
        "otttttttttttttto",
        "oOOOOOOOOOOOOOOo",
        "oooooooooooooooo",
        "................",
    ])
    S["lantern_post"] = sprite([
        "......oooo......",
        ".....oOOOOo.....",
        "....oOooooOo....",
        "....ooYyyYoo....",
        "....oyYYYYyo....",
        "....oyYllYyo....",
        "....oyYYYYyo....",
        "....ooyyyyoo....",
        ".....oOOOOo.....",
        "......oOOo......",
        "......oOOo......",
        "......otOo......",
        "......otOo......",
        "......otOo......",
        "......otOo......",
        "......otOo......",
        "......otOo......",
        "......otOo......",
        ".....otOOOo.....",
        "....ooooooooo...",
    ])
    spr = []
    for k in range(2):
        rows = [
            "................",
            "................",
            "........b.......",
            ".....b.bBb.b....",
            "....B.bBBBb.B...",
            ".......oBo......",
            "......osSso.....",
            ".....oasSSao....",
            ".....oaAAAao....",
            ".....oiaaaio....",
            "......ooooo.....",
            "................",
        ]
        if k == 1:
            rows[2] = "......b...b....."
            rows[3] = "....b..bBb..b..."
            rows[4] = "...B..bBBBb..B.."
        spr.append(sprite(rows))
    S["sprinkler"] = strip(spr)
    S["icon_sprinkler"] = spr[0]
    S["icon_stone_wall"] = S["stone_wall"]
    S["icon_iron_spikes"] = S["iron_spikes"]
    S["icon_lantern_post"] = S["lantern_post"].crop((0, 0, 16, 16))


# ------------------------------------------------------------------ crops
def crops():
    seed = [
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "......o..o......",
        ".....odoodo.....",
        "......o..o......",
        "................",
        "................",
        "................",
        "................",
    ]
    sprout = [
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "......o.oo......",
        ".....ofoFfo.....",
        ".....oFfofo.....",
        "......ooeo......",
        ".......oeo......",
        ".....oodDoo.....",
        "................",
        "................",
        "................",
    ]
    # Pumpkin
    S["crop_pumpkin"] = strip([sprite(seed), sprite(sprout), sprite([
        "................",
        "................",
        "................",
        "................",
        "....oo....oo....",
        "...ofFo..oFfo...",
        "...ofFfooFfeo...",
        "....oeffffeo....",
        "..oo.oefFeo.oo..",
        ".ofFooffeffoFfo.",
        ".oeffeefffeffeo.",
        "..oeeoQIQoeeoo..",
        "...oooQQXooo....",
        "......ooo.......",
        "................",
        "................",
    ]), sprite([
        "................",
        "................",
        "................",
        "......ooo.......",
        "....ooeFfoo.....",
        "...oFfoeoofo....",
        "..ooooodooooo...",
        ".oIIoQIIIQoIIo..",
        "oIIQoQIIIQoQIIo.",
        "oIQQoQQIQQoQQIo.",
        "oQQQoQQQQQoQQQo.",
        "oQQXoQQQQXoXQXo.",
        ".oXXoXXXXXoXXo..",
        "..ooooooooooo...",
        "................",
        "................",
    ])])
    S["icon_pumpkin"] = S["crop_pumpkin"].crop((48, 0, 64, 16))
    # Strawberry
    S["crop_strawberry"] = strip([sprite(seed), sprite(sprout), sprite([
        "................",
        "................",
        "................",
        "................",
        "................",
        ".....oo..oo.....",
        "....ofFooFfo....",
        "...ofFfoofFfo...",
        "..oofeFeeFefoo..",
        ".ofFfeollofeFfo.",
        ".oeeffeooeffeeo.",
        "..ooeefooofeoo..",
        "....oooeeooo....",
        "................",
        "................",
        "................",
    ]), sprite([
        "................",
        "................",
        "................",
        "................",
        ".....oo..oo.....",
        "....ofFooFfo....",
        "...ofFfoofFfo...",
        "..oorfeFeeforo..",
        ".orRrooffoorRro.",
        ".orlrRoeeorlrRo.",
        ".orRrkoffoorRko.",
        "..okkooeforkko..",
        "...oo.oRro.oo...",
        "......olRo......",
        ".......oo.......",
        "................",
    ])])
    S["icon_strawberry"] = sprite([
        "................",
        "................",
        "......oooo......",
        ".....ofFfeo.....",
        "....ooeffeoo....",
        "...orrooooRro...",
        "..orRlRrrRlRro..",
        "..orRRrlRRrRro..",
        "..okRrRRrRlRko..",
        "...okRRlRRrko...",
        "...okkRRrRkko...",
        "....okkRrkko....",
        ".....okkkko.....",
        "......oooo......",
        "................",
        "................",
    ])
    # Sunflower
    S["crop_sunflower"] = strip([sprite(seed), sprite(sprout), sprite([
        "................",
        "................",
        "......oo........",
        ".....ofFo.......",
        "......ofFo......",
        ".......oeo..o...",
        "...oo..oeo.ofo..",
        "..ofFo.oeooFfo..",
        "...oeFooeoFeo...",
        "....ooeoeoeo....",
        "......ooeo......",
        ".......oeo......",
        ".......oeo......",
        ".....oodDoo.....",
        "................",
        "................",
    ]), sprite([
        "......oooo......",
        "....ooyYYyoo....",
        "...oyYyooyYyo...",
        "..oyYoDddDoYyo..",
        "..oYyoddDdoyYo..",
        "..oyYoDdddoYyo..",
        "...oyYyooyYyo...",
        "....ooyYYyoo....",
        "...oo.oeeo.oo...",
        "..ofFooeoooFfo..",
        "...oeFoeooFeo...",
        "....ooeoeoeo....",
        "......ooeo......",
        ".......oeo......",
        ".....oodDoo.....",
        "................",
    ])])
    S["icon_sunflower"] = S["crop_sunflower"].crop((48, 0, 64, 8)).resize((16, 8))
    S["icon_sunflower"] = sprite([
        "................",
        "......oooo......",
        "....ooyYYyoo....",
        "...oyYyooyYyo...",
        "..oyYoDddDoYyo..",
        "..oYyoddDdoyYo..",
        "..oyYoDdddoYyo..",
        "...oyYyooyYyo...",
        "....ooyYYyoo....",
        "......oeeo......",
        ".....ofeo.......",
        "....ofFeo.......",
        ".....ooeo.......",
        ".......oeo......",
        ".......ooo......",
        "................",
    ])
    # Moonflower: glows, only grows at night
    S["crop_moonflower"] = strip([sprite(seed), sprite([r.replace("f", "u").replace("F", "p") for r in sprout]), sprite([
        "................",
        "................",
        "................",
        "................",
        ".......oo.......",
        "......opPo......",
        ".....opPPqo.....",
        "......oqqo......",
        "...oo..oeo..oo..",
        "..ouuo.oeo.ouuo.",
        "...ouuooeoouuo..",
        "....oooeeooo....",
        "......ooeo......",
        ".....oodDoo.....",
        "................",
        "................",
    ]), sprite([
        "................",
        "......o..o......",
        ".....oVooVo.....",
        "...oovVVVVvoo...",
        "..oVVvVllVvVVo..",
        "...ovVlBBlVvo...",
        "..oVVvVllVvVVo..",
        "...oovVVVVvoo...",
        ".....oVooVo.....",
        "..oo..oeeo..oo..",
        ".ouuoooeooouuo..",
        "..ouuuoeouuuo...",
        "....oooeeooo....",
        "......ooeo......",
        ".....oodDoo.....",
        "................",
    ])])
    S["icon_moonflower"] = S["crop_moonflower"].crop((48, 0, 64, 16))
    # Seed packets
    for name, col, dark in [("pumpkin", "Q", "X"), ("strawberry", "R", "k"), ("sunflower", "y", "g"), ("moonflower", "v", "u")]:
        S[f"icon_{name}_seed"] = sprite([
            "................",
            "...oooooooooo...",
            "..ozzzzzzzzzzo..",
            "..oZZZZZZZZZZo..",
            "..ozzzzzzzzzzo..",
            "..ozzzXXXXzzzo..".replace("X", col),
            "..ozzXXllXXzzo..".replace("X", col),
            "..ozzXXXXXXzzo..".replace("X", col),
            "..ozzzYYYYzzzo..".replace("Y", dark),
            "..ozzzzfFzzzzo..",
            "..ozzzzzfzzzzo..",
            "..ozzzzzzzzzzo..",
            "..oZZZZZZZZZZo..",
            "...oooooooooo...",
            "................",
            "................",
        ])


def boss():
    # Crown overlay drawn on the boss zombie's head (frames are 64x64)
    S["boss_crown"] = sprite([
        "o..oo..o",
        "oyoYYoyo",
        "oyyvvyyo",
        "oggggggo",
        "oooooooo",
    ])


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    ores(); tools(); misc_icons(); critters(); cave_tiles(); stations(); placeables(); crops(); boss()
    for name, im in S.items():
        im.save(os.path.join(OUT, name + ".png"))
    print("wrote", len(S), "sprites")
