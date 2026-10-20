"""Night Harvest 1.4.2 art: 1x2 bed (head up), 1-block furnace (2 frames) and anvil,
wooden bridge tiles (horizontal / vertical span) and the Sunforged Greatsword.
Run: python3 tools_dev/gen_v142.py   (writes Assets/Generated/v131/)"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "Assets", "Generated", "v131")


def hx(h, a=255):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def draw(rows, pal, w=None):
    h = len(rows)
    w = w or max(len(r) for r in rows)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != "." and ch in pal:
                px[x, y] = pal[ch]
    return im


# --- bed: 16 x 32, headboard at the top --------------------------------------
BED = [
    "................",
    ".kkkkkkkkkkkkkk.",
    ".kWWWWWWWWWWWWk.",
    ".kWwwwwwwwwwwWk.",
    ".kWWWWWWWWWWWWk.",
    ".kkkkkkkkkkkkkk.",
    ".kWkppppppppkWk.",
    ".kWkPPPPPPPPkWk.",
    ".kWkPpppppppkWk.",
    ".kWkPppppppPkWk.",
    ".kWkPPPPPPPPkWk.",
    ".kWkkkkkkkkkkWk.",
    ".kWkRRRRRRRRkWk.",
    ".kWkrrrrrrrrkWk.",
    ".kWkRRRRRRRRkWk.",
    ".kWkRRRRRRRRkWk.",
    ".kWkRRRRRRRRkWk.",
    ".kWkRRRdRRRRkWk.",
    ".kWkRRRRRRRRkWk.",
    ".kWkRRRRRRdRkWk.",
    ".kWkRRRRRRRRkWk.",
    ".kWkRdRRRRRRkWk.",
    ".kWkRRRRRRRRkWk.",
    ".kWkRRRRRRRRkWk.",
    ".kWkRRRRRdRRkWk.",
    ".kWkRRRRRRRRkWk.",
    ".kWkdddddddddWk.",
    ".kWkkkkkkkkkkWk.",
    ".kWWWWWWWWWWWWk.",
    ".kwkkkkkkkkkkwk.",
    ".kk..........kk.",
    "................",
]
pal_bed = {"k": hx("3a2416"), "W": hx("9b6438"), "w": hx("c58a52"), "p": hx("f2efe6"), "P": hx("cfd2dc"),
           "R": hx("b8323a"), "r": hx("e0565a"), "d": hx("8c2230")}
draw(BED, pal_bed).save(os.path.join(OUT, "bed_1x2.png"))
icon = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
icon.alpha_composite(draw(BED, pal_bed).resize((8, 16), Image.NEAREST), (4, 0))

# --- furnace 16x16, two frames (fire flickers) ----------------------------------
FUR = [
    "................",
    "...kkkkkkkkkk...",
    "..kSSsSSSSsSSk..",
    ".kSsSSSSsSSSsSk.",
    ".kSSSSsSSSSSSSk.",
    ".kSsSSSSSSsSSSk.",
    ".kSSSkkkkkkSSsk.",
    ".kSSkDDDDDDkSSk.",
    ".kSskDfffffDkSk.",
    ".kSSkDfFFFfDkSk.",
    ".kSSkDFYYYFDkSk.",
    ".kSskDFYyYFDksk.",
    ".kSSkkkkkkkkkSk.",
    ".kSSSSsSSSSsSSk.",
    ".kkkkkkkkkkkkkk.",
    "................",
]
pal_f = {"k": hx("2a2830"), "S": hx("8a8794"), "s": hx("6c6a76"), "D": hx("241c1c"),
         "f": hx("c2431c"), "F": hx("f07a1e"), "Y": hx("ffc23a"), "y": hx("fff2a8")}
f1 = draw(FUR, pal_f)
pal_f2 = dict(pal_f, f=hx("f07a1e"), F=hx("ffc23a"), Y=hx("fff2a8"), y=hx("ffffff"))
f2 = draw(FUR, pal_f2)
strip = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
strip.alpha_composite(f1, (0, 0))
strip.alpha_composite(f2, (16, 0))
strip.save(os.path.join(OUT, "furnace_1x1.png"))

# --- anvil 16x16 ----------------------------------------------------------------
ANV = [
    "................",
    "................",
    "................",
    "................",
    "kkkkkkkkkkkkk...",
    "kHHHHHHHHHHHHk..",
    "kMMMMMMMMMMMMMk.",
    ".kkMMMMMMMMMkkk.",
    "...kMMMMMMk.....",
    "....kMMMMk......",
    "....kMmmMk......",
    "...kMMMMMMk.....",
    "..kMMmmmmMMk....",
    "..kkkkkkkkkk....",
    "..WWWWWWWWWW....",
    "................",
]
pal_a = {"k": hx("1e1e26"), "H": hx("b6bccb"), "M": hx("5c6070"), "m": hx("474a58"), "W": hx("6b4527")}
anv = draw(ANV, pal_a)
anv2 = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
anv2.alpha_composite(anv, (1, 0))
anv2.save(os.path.join(OUT, "anvil_1x1.png"))

# --- bridge tiles ----------------------------------------------------------------
def bridge_h():
    """A bridge you cross left <-> right: planks run up-down, ropes along top and bottom."""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    plank = [hx("a8743f"), hx("94632f"), hx("b9834a"), hx("8a5b2c")]
    for x in range(16):
        col = plank[(x // 4) % 4]
        for y in range(3, 13):
            px[x, y] = col
        if x % 4 == 3:
            for y in range(3, 13):
                px[x, y] = hx("5a3a1c")
        px[x, 3] = hx("6b4526")
        px[x, 12] = hx("4e3218")
    for x in range(16):   # ropes
        px[x, 1] = hx("d9c08a")
        px[x, 14] = hx("c2a56c")
        px[x, 2] = hx("7a5a30", 200)
        px[x, 15] = hx("3a2414", 160)
    for x in (0, 15):     # posts
        for y in range(0, 4):
            px[x, y] = hx("5a3a1c")
        for y in range(12, 16):
            px[x, y] = hx("4a2f17")
    return im

bh = bridge_h()
bh.save(os.path.join(OUT, "bridge_h.png"))
bv = bh.rotate(90, expand=True)
# light should still come from the top-left: swap the shading of the two ropes
bv.save(os.path.join(OUT, "bridge_v.png"))
bh.save(os.path.join(OUT, "icon_bridge_wood.png"))

# --- Sunforged Greatsword 16x16 ---------------------------------------------------
SW = [
    "............kk..",
    "...........kYWk.",
    "..........kYWk..",
    ".........kYWk...",
    "........kYWk....",
    ".......kYWk.....",
    "......kYWk......",
    ".....kYWk.......",
    "..k.kYWk........",
    "..kGkWk.........",
    "...kGGk.........",
    "...kRGGk........",
    "..kGk.kGk.......",
    ".kGk............",
    "kGk.............",
    "kk..............",
]
pal_s = {"k": hx("3a2a10"), "Y": hx("ffe28a"), "W": hx("fffbe6"), "G": hx("e0a526"), "R": hx("d8402c")}
draw(SW, pal_s).save(os.path.join(OUT, "icon_sunforged_greatsword.png"))
print("v142 art ok")
