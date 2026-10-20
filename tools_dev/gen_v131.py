"""Night Harvest 1.3.1 / 1.4 generated art.
Run: python3 tools_dev/gen_v131.py   (writes Assets/Generated/v131/*.png)
"""
import random, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_props import PAL, sprite, strip
PAL.update({"I": "ffa640", "Q": "e66a1e", "X": "9a3e14"})

OUT = os.path.join(os.path.dirname(__file__), "..", "Assets", "Generated", "v131")
os.makedirs(OUT, exist_ok=True)


def save(img, name):
    img.save(os.path.join(OUT, name))


# --- Tilled soil: 16 neighbour masks (N=1 E=2 S=4 W=8) x 2 pattern variants ----------
# No furrow direction: clods and pebbles are scattered evenly, and the outline only
# appears on the sides that border untilled ground, so neighbouring tiles join up.
def soil_sheet():
    W = 16
    sheet = Image.new("RGBA", (16 * W, 2 * W), (0, 0, 0, 0))
    base = (122, 82, 50)
    dark = (96, 62, 37)
    light = (146, 103, 64)
    rim = (74, 47, 28)
    rim_in = (104, 69, 42)
    for var in range(2):
        rnd = random.Random(1300 + var * 77)
        pat = [[base for _ in range(W)] for _ in range(W)]
        for _ in range(22):
            x, y = rnd.randrange(W), rnd.randrange(W)
            pat[y][x] = dark
            if rnd.random() < 0.5:
                pat[y][(x + 1) % W] = dark
        for _ in range(12):
            x, y = rnd.randrange(W), rnd.randrange(W)
            pat[y][x] = light
        for mask in range(16):
            n, e, s, w = mask & 1, mask & 2, mask & 4, mask & 8
            for y in range(W):
                for x in range(W):
                    c = pat[y][x]
                    edge = None
                    if not n and y == 0 or not s and y == W - 1 or not w and x == 0 or not e and x == W - 1:
                        edge = rim
                    elif not n and y == 1 or not s and y == W - 2 or not w and x == 1 or not e and x == W - 2:
                        edge = rim_in
                    if edge:
                        c = edge
                    sheet.putpixel((mask * W + x, var * W + y), c + (255,))
            # rounded outer corners
            for (cx, cy, a, b) in ((0, 0, n, w), (W - 1, 0, n, e), (0, W - 1, s, w), (W - 1, W - 1, s, e)):
                if not a and not b:
                    sheet.putpixel((mask * W + cx, var * W + cy), (64, 40, 24, 255))
    save(sheet, "soil.png")


# --- Lantern (replaces the torch look): icon + 4 flicker frames -------------------
LANTERN = [
    "................",
    "......oooo......",
    ".....oh..ho.....",
    ".....o....o.....",
    "...oooooooooo...",
    "...occccccCCo...",
    "...oooooooooo...",
    "...ofgGGGGgfo...",
    "...ofGGWWGGfo...",
    "...ofGWWWWGfo...",
    "...ofGGWWGGfo...",
    "...ofgGGGGgfo...",
    "...ofggggggfo...",
    "...oooooooooo...",
    "..obbbbbbbbBBo..",
    "..oooooooooooo..",
]


def lantern_img(glow=1.0, flame_shift=0):
    pal = {
        "o": (34, 26, 22), "h": (96, 88, 82), "c": (128, 110, 94), "C": (88, 74, 64),
        "f": (72, 62, 56), "b": (104, 90, 78), "B": (66, 56, 48),
        "g": (int(236 * glow), int(160 * glow), int(64 * glow)),
        "G": (min(255, int(255 * glow)), int(212 * glow), int(118 * glow)),
        "W": (255, 250, 214),
    }
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(LANTERN):
        assert len(row) == 16, (y, len(row))
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            c = pal[ch]
            if ch == "W" and flame_shift and y == 8:
                c = pal["G"]
            img.putpixel((x, y), c + (255,))
    return img


def lantern_assets():
    save(lantern_img(), "lantern.png")
    sheet = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    for i, (g, f) in enumerate(((1.0, 0), (0.93, 1), (1.0, 1), (0.88, 0))):
        sheet.paste(lantern_img(g, f), (i * 16, 0))
    save(sheet, "lantern_frames.png")


# --- Woven rugs (2x2 cells) ----------------------------------------------------------
def rug(name, base, dark, light):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    edge = tuple(max(0, c - 40) for c in dark)
    for y in range(2, 30):
        for x in range(1, 31):
            c = base
            if x in (1, 30) or y in (2, 29):
                c = edge
            elif x in (3, 28) or y in (4, 27):
                c = light
            elif (x + y) % 8 == 0 or (x - y) % 8 == 0:
                if 6 <= x <= 25 and 7 <= y <= 24:
                    c = dark
            img.putpixel((x, y), c + (255,))
    # fringe on the short sides
    for x in range(2, 30, 2):
        img.putpixel((x, 1), light + (255,))
        img.putpixel((x, 30), light + (255,))
    save(img, name)


# --- Crops that were drawn with the wrong tiles (v1.3.1) ---------------------------
SEED = ["................"] * 9 + ["......o..o......", ".....odoodo.....", "......o..o......"] + ["................"] * 4
SPROUT = ["................"] * 7 + ["......o.oo......", ".....ofoFfo.....", ".....oFfofo.....", "......ooeo......", ".......oeo......", ".....oodDoo.....", "................", "................", "................"]


def crops_v131():
    out = {}
    out["crop_tomato"] = strip([sprite(SEED), sprite(SPROUT), sprite([
        "................",
        "................",
        "................",
        ".....oo..oo.....",
        "....ofFooFfo....",
        "...ofFfyofFfo...",
        "...oefFffFfeo...",
        "..oofeyFFeffoo..",
        ".ofFfeffffeFfo..",
        ".oeeffeffeffeeo.",
        "..ooeefeefeoo...",
        "....ooeeeeoo....",
        "......ooeo......",
        ".....oodDoo.....",
        "................",
        "................",
    ]), sprite([
        "................",
        "................",
        ".....oo..oo.....",
        "....ofFooFfo....",
        "...ofoRoofRro...",
        "..ofoRlRofRlro..",
        "..oforRrofrRro..",
        ".ofFfoofffoofo..",
        ".oefoRRofoRRoeo.",
        ".oeforlRoRlRoeo.",
        "..oeorrRoorRo...",
        "...ooeoofeoo....",
        ".....ooeeoo.....",
        ".....oodDoo.....",
        "................",
        "................",
    ])])
    out["crop_potato"] = strip([sprite(SEED), sprite(SPROUT), sprite([
        "................",
        "................",
        "................",
        "................",
        ".....oo.oo......",
        "....ofFofFo.....",
        "...ofFffFffo....",
        "..oofeFfffeoo...",
        ".ofFffeffeFffo..",
        ".oeffeefffeeffo.",
        "..ooeefeeefeoo..",
        "....oooeeooo....",
        "......oeeo......",
        "....oodDDdoo....",
        "................",
        "................",
    ]), sprite([
        "................",
        "................",
        "................",
        ".....oo.oo......",
        "....ofFofFo.....",
        "...ofFffFffo....",
        "..oofeFfffeoo...",
        ".oeffeefffeeffo.",
        "..ooeefeeefeoo..",
        "...oowwooowwoo..",
        "..owWWwoowWwwo..",
        "..owwjwoowjWwo..",
        "...oowwddwwoo...",
        "....oodDDdoo....",
        "................",
        "................",
    ])])
    out["crop_watermelon"] = strip([sprite(SEED), sprite(SPROUT), sprite([
        "................",
        "................",
        "................",
        "................",
        "................",
        "....oo....oo....",
        "...ofFo..oFfo...",
        "...oeFfooFfeo...",
        "....oefeefeo....",
        "..oo.oefFeo.oo..",
        ".ofFoofFfeFooFfo",
        ".oeffeofeeofeffo",
        "..oeeooeoooeeo..",
        "......oddo......",
        "................",
        "................",
    ]), sprite([
        "................",
        "................",
        "................",
        "......oo........",
        ".....oFfoooooo..",
        "...oooeooefFffo.",
        "..oeFfefFfeFfeo.",
        ".oefFfefFfefFfeo",
        ".oeFfeFfefFfefeo",
        ".oefFfefFfefFfeo",
        ".oeFfeFfefFfeFeo",
        "..oefFfeFfefFeo.",
        "...oooooooooooo.",
        "................",
        "................",
        "................",
    ])])
    out["crop_corn"] = strip([sprite(SEED), sprite(SPROUT), sprite([
        "................",
        "................",
        "................",
        ".......oo.......",
        "......oFfo......",
        "......ofFo......",
        "....oo.ofo.oo...",
        "...oFfoofooFfo..",
        "....oefofofeo...",
        "......ofFo......",
        ".....oofFfoo....",
        "....oFfofFfeo...",
        ".....oeofeeo....",
        "......oofo......",
        ".....oodDoo.....",
        "................",
    ]), sprite([
        ".......oo.......",
        "......ojjo......",
        "......oFfo......",
        "....oo.ofo.oo...",
        "...oFfoofooFfo..",
        "....oefoyyoeo...",
        "......oyhyo.....",
        ".....ooyyhoo....",
        "....oFfohyoFeo..",
        "...oFfeoyyoefo..",
        "....ooeofeoeo...",
        "......oofFo.....",
        ".....oFfofFo....",
        "......oeofeo....",
        ".....oodDDoo....",
        "................",
    ])])
    return out


def produce_icons():
    out = {}
    out["icon_tomato"] = sprite([
        "................",
        "......o.o.......",
        ".....ofoFo......",
        "....oofFfoo.....",
        "...orRRoRRro....",
        "..orRlRRRRRro...",
        "..oRlRRRRRRRo...",
        "..oRRRRRRRRro...",
        "..oRRRRRRRrro...",
        "..orRRRRRrrro...",
        "...orrrrrrro....",
        "....ooooooo.....",
        "................",
        "................",
        "................",
        "................",
    ])
    out["icon_potato"] = sprite([
        "................",
        "................",
        "................",
        ".....oooooo.....",
        "....owWWWWwo....",
        "...owWWdWWWwo...",
        "..owWWWWWWdWwo..",
        "..owWdWWWWWWwo..",
        "..owWWWWWdWWwo..",
        "...owWWWWWWwo...",
        "....owwwwwwo....",
        ".....oooooo.....",
        "................",
        "................",
        "................",
        "................",
    ])
    out["icon_baked_potato"] = sprite([
        "................",
        "................",
        "................",
        ".....oooooo.....",
        "....owwHHwwo....",
        "...owHHlHHHwo...",
        "..owwHHHHHHwwo..",
        "..owWHHHHHHWwo..",
        "..owWWHHHHWWwo..",
        "...owWWWWWWwo...",
        "...osggggggso...",
        "..osllllllllso..",
        "...osssssssso...",
        "....oooooooo....",
        "................",
        "................",
    ])
    out["icon_watermelon"] = sprite([
        "................",
        "................",
        "................",
        ".....oooooo.....",
        "...ooeFfFefoo...",
        "..oeFfeFfeFfeo..",
        ".oefFeFfeFfeFeo.",
        ".oeFfeFfeFfeFfo.",
        ".oefFeFfeFfeFeo.",
        ".oeFfeFfeFfeFfo.",
        "..oefFeFfeFfeo..",
        "...ooeeeeeeoo...",
        ".....oooooo.....",
        "................",
        "................",
        "................",
    ])
    out["icon_corn"] = sprite([
        "................",
        ".......ooo......",
        "......oyhyo.....",
        ".....oyyhyyo....",
        ".....ohyyhyo....",
        ".....oyhyyho....",
        "....ofoyyhyfo...",
        "...oFfohyyoFfo..",
        "...oefoyyhofeo..",
        "....oefoyofeo...",
        ".....oeFfFeo....",
        "......oeFeo.....",
        ".......oeo......",
        "........o.......",
        "................",
        "................",
    ])
    out["icon_wheat"] = sprite([
        "................",
        "....o..o..o.....",
        "...oyooyooyo....",
        "...ohyohyohyo...",
        "...oyhoyhoyho...",
        "....ohyohyohyo..",
        ".....ojoojoojo..",
        "......ojojojo...",
        ".......ojjjo....",
        "......orrrrro...",
        ".......ojjjo....",
        "......ojojojo...",
        ".....ojo.ojo....",
        ".....oo...oo....",
        "................",
        "................",
    ])
    out["icon_pumpkin_pie"] = sprite([
        "................",
        "................",
        "................",
        "................",
        "....oooooooo....",
        "...oWQQIQQQWo...",
        "..oWQIQQQIQQWo..",
        "..oWQQQIQQQQWo..",
        "..oWWWWWWWWWWo..",
        "..ojWjWjWjWjjo..",
        "...osssssssso...",
        "..osllllllllso..",
        "...osssssssso...",
        "....oooooooo....",
        "................",
        "................",
    ])
    for name, col, dark in [("tomato", "R", "r"), ("potato", "W", "w"), ("watermelon", "f", "e"), ("corn", "y", "j")]:
        out[f"icon_{name}_seed"] = sprite([
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
    return out


STEAK = [
    "................",
    "................",
    "................",
    "....oooooo......",
    "...oAAAAAAoo....",
    "..oAaAAAAAAAo...",
    "..oAAAAalAAAAo..",
    "..oAAAAAAAAaAo..",
    "...oAaAAAAAAAo..",
    "....oAAAAAAAoTTo",
    ".....ooAAAAoTllT",
    ".......oooo.oTTo",
    "................",
    "................",
    "................",
    "................",
]
LEG = [
    "................",
    "................",
    "................",
    ".....ooooo......",
    "....oAAAAAo.....",
    "...oAAalAAAo....",
    "...oAAAAAAAo....",
    "...oAaAAAAAo....",
    "....oAAAAAo.....",
    ".....oAAAo......",
    "......oTTo......",
    ".....oTlTTo.....",
    "....oTo.oTo.....",
    ".....o...o......",
    "................",
    "................",
]


def meat_icons():
    out = {}
    raw = {"A": "d84a52", "a": "f08a8a", "l": "ffd0d0"}
    cooked = {"A": "9a5a30", "a": "c8864a", "l": "e8b878"}
    kinds = {"raw_beef": (STEAK, raw), "steak": (STEAK, cooked),
             "raw_pork": (STEAK, {"A": "f08a9a", "a": "ffb8c4", "l": "fff0f2"}), "cooked_pork": (STEAK, cooked),
             "raw_mutton": (STEAK, {"A": "c84a5a", "a": "e88a90", "l": "ffd8d8"}), "cooked_mutton": (STEAK, {"A": "8a4a2a", "a": "b87a40", "l": "e0b070"}),
             "venison": (STEAK, {"A": "a83040", "a": "d06070", "l": "f0b0b0"}), "cooked_venison": (STEAK, {"A": "7a3c22", "a": "aa6a3a", "l": "d8a468"}),
             "raw_chicken": (LEG, {"A": "f4b8a8", "a": "ffd8cc", "l": "fff4ee"}), "cooked_chicken": (LEG, {"A": "c87a36", "a": "e8a85a", "l": "f8d890"}),
             "raw_rabbit": (LEG, {"A": "e89a9a", "a": "ffc4c4", "l": "fff0f0"}), "cooked_rabbit": (LEG, {"A": "b06a34", "a": "d89a58", "l": "f0c888"})}
    for k, (tmpl, pal) in kinds.items():
        PAL.update(pal)
        out["icon_" + k] = sprite(tmpl)
    PAL.update({"A": "f9a875", "a": "e07438", "l": "ffffff"})
    out["icon_leather"] = sprite([
        "................",
        "................",
        "...oo......oo...",
        "..owwoooooowwo..",
        "...owWWWWWWwo...",
        "...owWwWWWWwo...",
        "..owWWWWWwWWwo..",
        "..owWWWWWWWWwo..",
        "...owWWwWWWwo...",
        "...owWWWWWWwo...",
        "..owwoooooowwo..",
        "...oo......oo...",
        "................",
        "................",
        "................",
        "................",
    ])
    out["icon_wool"] = sprite([
        "................",
        "................",
        "................",
        ".....ooo.ooo....",
        "....ozzzozzzo...",
        "...ozllzzzlzzo..",
        "..ozzzzZzzzzzzo.",
        "..ozlzzzzzZzlzo.",
        "..ozzzZzzlzzzzo.",
        "...ozzzzzzzzZo..",
        "....oZzzoZzzo...",
        ".....ooo.ooo....",
        "................",
        "................",
        "................",
        "................",
    ])
    out["icon_feather"] = sprite([
        "................",
        "...........oo...",
        "..........ollo..",
        ".........ollzo..",
        "........ollzo...",
        ".......ollzo....",
        "......ollzo.....",
        ".....ollzo......",
        "....olzzo.......",
        "...olzZo........",
        "...ozZo.........",
        "..ojoo..........",
        ".oj.............",
        ".o..............",
        "................",
        "................",
    ])
    return out


FISH = [
    "................",
    "................",
    "................",
    "................",
    "......oooo......",
    "....ooAAAAoo..oo",
    "...oAAaAAAAAooAo",
    "..oAlkAAAaAAAAAo",
    "..oAAAAAAAAAAAoo",
    "...oBBBBBBBBBoAo",
    "....ooBBBBBoo.oo",
    "......oooo......",
    "................",
    "................",
    "................",
    "................",
]


def fish_icons():
    out = {}
    # body A, stripe/spots a, belly B
    kinds = {
        "minnow": ("9ab4c4", "7a94a8", "d8e4ea"),
        "perch": ("8aa848", "4e6a2a", "e8d878"),
        "trout": ("8a9a7a", "d86a6a", "e8dcc8"),
        "catfish": ("6a6050", "4a4238", "a89a80"),
        "salmon": ("b8c0c8", "e88a6a", "f0e4dc"),
        "golden_carp": ("f0b830", "f8e070", "fff0b0"),
        "sea_bass": ("6a7a9a", "4a5a7a", "c8d0dc"),
        "tuna": ("3a5a8a", "2a3a5a", "c8d4e0"),
        "pufferfish": ("e8c860", "a88a30", "f8f0c0"),
        "grilled_perch": ("b07a40", "8a5428", "d8a868"),
        "grilled_trout": ("b8844a", "8a5428", "dcb070"),
        "smoked_salmon": ("d8784a", "a84a2a", "f0b080"),
        "grilled_sea_bass": ("a8783e", "7a4a24", "d4a464"),
    }
    for k, (a, aa, b) in kinds.items():
        PAL.update({"A": a, "a": aa, "B": b, "k": "101018"})
        out["icon_" + k] = sprite(FISH)
    PAL.update({"A": "f9a875", "a": "e07438", "B": "8fd3ff", "k": "625565", "l": "ffffff"})
    out["icon_fishing_rod"] = sprite([
        "................",
        "............oo..",
        "...........ojo..",
        "..........ojo.l.",
        ".........ojo..l.",
        "........ojo...l.",
        ".......ojo....l.",
        "......ojo.....l.",
        ".....ojo......l.",
        "....owo.......l.",
        "...owo........R.",
        "..odo.........o.",
        ".odo............",
        ".oo.............",
        "................",
        "................",
    ])
    out["icon_seaweed"] = sprite([
        "................",
        "......o...o.....",
        ".....ofo.ofo....",
        ".....oFo.oFo....",
        "......ofooFo....",
        ".....ofFoofo....",
        ".....oFfofFo....",
        "......ofoFo.....",
        ".....oFfoFfo....",
        ".....ofFofFo....",
        "......oefeo.....",
        "......oefeo.....",
        ".......oeo......",
        "................",
        "................",
        "................",
    ])
    out["icon_old_boot"] = sprite([
        "................",
        "................",
        "......ooooo.....",
        "......owwwo.....",
        "......owdwo.....",
        "......owwwo.....",
        "......owdwo.....",
        "......owwwoo....",
        "....oowwwwwwo...",
        "...owwwdwwwwwo..",
        "...owwwwwwdwwo..",
        "...oDDDDDDDDDo..",
        "....ooooooooo...",
        "................",
        "................",
        "................",
    ])
    return out


def saplings():
    out = {}
    out["sapling"] = sprite([
        "................",
        "................",
        "................",
        ".....oooo.......",
        "....ofFFfo......",
        "...ofFfFFfoo....",
        "...oefFfeFFfo...",
        "....oefeoefeo...",
        ".....ooweooo....",
        "......owo.......",
        "......owo.......",
        "......owo.......",
        ".....odwdo......",
        "....oddDddo.....",
        ".....ooooo......",
        "................",
    ])
    out["pine_sapling"] = sprite([
        "................",
        "................",
        ".......oo.......",
        "......oFfo......",
        ".....oFffeo.....",
        "......oefo......",
        ".....oFffeo.....",
        "....oFfffeeo....",
        ".....ooefoo.....",
        "....oFffffeo....",
        "...ooeeefeeoo...",
        "......owo.......",
        "......owo.......",
        ".....oddddo.....",
        "......oooo......",
        "................",
    ])
    return out


if __name__ == "__main__":
    for k, im in list(saplings().items()) + list(meat_icons().items()) + list(fish_icons().items()):
        save(im, k + ".png")
    for k, im in list(crops_v131().items()) + list(produce_icons().items()):
        save(im, k + ".png")
    soil_sheet()
    lantern_assets()
    rug("rug_red.png", (156, 52, 48), (110, 30, 32), (226, 170, 96))
    rug("rug_blue.png", (52, 86, 156), (30, 52, 110), (206, 196, 140))
    print("ok")
