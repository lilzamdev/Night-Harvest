"""Night Harvest 1.4 biome building blocks (recoloured from the v1.3 blocks + details).
Run: python3 tools_dev/gen_blocks14.py  (writes Assets/Generated/v131/)
"""
import os, random
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "Assets", "Generated")
V13 = os.path.join(ROOT, "v13")
OUT = os.path.join(ROOT, "v131")


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp_recolor(src, ramp, keep_dark=40):
    """Maps each pixel's brightness onto a colour ramp (dark -> light)."""
    im = src.convert("RGBA").copy()
    px = im.load()
    lums = sorted({int(0.3 * r + 0.59 * g + 0.11 * b) for (r, g, b, a) in im.getdata() if a > 0 and (0.3 * r + 0.59 * g + 0.11 * b) > keep_dark})
    lo, hi = (lums[0], lums[-1]) if lums else (0, 255)
    cols = [hexc(c) for c in ramp]
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            l = 0.3 * r + 0.59 * g + 0.11 * b
            if l <= keep_dark:
                continue   # keep the dark outline
            t = (l - lo) / max(1, hi - lo)
            i = min(len(cols) - 1, int(t * len(cols)))
            px[x, y] = cols[i] + (a,)
    return im


def sprinkle(im, cols, n, seed, rows=None, only_on=None):
    rnd = random.Random(seed)
    px = im.load()
    for _ in range(n):
        x = rnd.randrange(im.width)
        y = rnd.randrange(*(rows or (0, im.height)))
        r, g, b, a = px[x, y]
        if a == 0 or (0.3 * r + 0.59 * g + 0.11 * b) < 45:
            continue
        px[x, y] = hexc(rnd.choice(cols)) + (255,)
        if rnd.random() < 0.5 and x + 1 < im.width and px[x + 1, y][3] and (0.3 * px[x + 1, y][0] + 0.59 * px[x + 1, y][1]) > 45:
            px[x + 1, y] = hexc(rnd.choice(cols)) + (255,)
    return im


def load13(n):
    return Image.open(os.path.join(V13, n + ".png")).convert("RGBA")


SETS = {
    # name: (base wall, base floor, ramp, extra)
    "sandstone": ("wall_stone", "floor_stone", ["8a6238", "b58650", "d3a96a", "e8c88e", "f4dfae"], "sand"),
    "ice": ("wall_stone", "floor_stone", ["4f86b0", "79b3d8", "a6d6ef", "cfeefb", "f2fcff"], "ice"),
    "mossy": ("wall_stone", "floor_stone", ["4e5258", "6a6e72", "868a8c", "a0a4a2", "b9bcb6"], "moss"),
    "driftwood": ("wall_wood", "floor_wood", ["6f675c", "8f877a", "aca393", "c7bfae", "ddd6c6"], "drift"),
    "pine": ("wall_wood", "floor_wood", ["4a2618", "653423", "814630", "9b5a3d", "b4714c"], "pine"),
}
for name, (wb, fb, ramp, extra) in SETS.items():
    wall = ramp_recolor(load13(wb), ramp)
    floor = ramp_recolor(load13(fb), ramp)
    icon_w = ramp_recolor(load13("icon_" + wb), ramp)
    icon_f = ramp_recolor(load13("icon_" + fb), ramp)
    if extra == "moss":
        for im, s in ((wall, 1), (floor, 2), (icon_w, 3), (icon_f, 4)):
            sprinkle(im, ["4f7a34", "679a40", "3d612a"], 26 if im.height > 16 else 18, s)
        # moss creeping over the top of the wall
        sprinkle(wall, ["5d8c3a", "77ab48"], 18, 9, rows=(0, 9))
    elif extra == "ice":
        for im, s in ((wall, 11), (floor, 12), (icon_w, 13), (icon_f, 14)):
            sprinkle(im, ["ffffff", "e9fbff"], 10, s)
    elif extra == "sand":
        for im, s in ((wall, 21), (floor, 22), (icon_w, 23), (icon_f, 24)):
            sprinkle(im, ["a87a46", "c99a5c"], 12, s)
    elif extra == "drift":
        for im, s in ((wall, 31), (floor, 32)):
            sprinkle(im, ["9c9384", "5f584e"], 10, s)
    wall.save(os.path.join(OUT, "wall_%s.png" % name))
    floor.save(os.path.join(OUT, "floor_%s.png" % name))
    icon_w.save(os.path.join(OUT, "icon_wall_%s.png" % name))
    icon_f.save(os.path.join(OUT, "icon_floor_%s.png" % name))

# raw materials, recoloured from the stone / log icons
STONE_ICON = os.path.join(V13, "..", "..", "Sprites")  # unused, kept for reference
mats = {
    "sandstone": ("stone", ["7a5530", "a87a46", "cfa266", "ecd09a"]),
    "ice_chunk": ("stone", ["4f86b0", "8cc6e6", "c4ebfa", "ffffff"]),
    "mossy_cobble": ("stone", ["3f5a2c", "62804a", "8c9686", "b0b4aa"]),
    "driftwood": ("wood", ["6a6257", "948b7d", "bdb4a3", "ddd6c6"]),
    "pine_log": ("wood", ["40200f", "6a3622", "92553a", "b8794f"]),
}
SHEET = Image.open(os.path.join(os.path.dirname(__file__), "..", "Assets", "Outdoor decoration", "Outdoor_Decor_Free.png")).convert("RGBA")
bases = {"stone": SHEET.crop((32, 32, 48, 48)), "wood": SHEET.crop((0, 112, 32, 128))}
for name, (base, ramp) in mats.items():
    im = ramp_recolor(bases[base], ramp)
    if name == "mossy_cobble":
        sprinkle(im, ["4f7a34", "679a40"], 14, 41)
    if name == "ice_chunk":
        sprinkle(im, ["ffffff"], 6, 42)
    im.save(os.path.join(OUT, "icon_%s.png" % name))
print("ok")
