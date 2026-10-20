"""Night Harvest character sheet generator.

Builds new 32x32-cell character sheets from Ken's sheet (Assets/Player/character.png)
so every new character shares Ken's exact animation layout (idle/walk/swing/water/harvest
in 4 directions). Each variant recolors body parts and can add long hair, a ponytail,
a hat or a beard. Run:  python3 tools_dev/gen_chars.py
"""
from PIL import Image
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Assets/Player/character.png")
OUT_DIR = os.path.join(ROOT, "Assets/Characters")

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

OUTLINE = H("2e222f")
HAIRPANTS = {H("7f708a"): "hi", H("625565"): "mid", H("3e3546"): "dark"}
PART_COLORS = {
    "skin": {H("ab947a"): "hi", H("966c6c"): "mid", H("694f62"): "dark"},
    "shirt": {H("ffffff"): "hi", H("c7dcd0"): "mid"},
    "vest": {H("4d9be6"): "hi", H("4d65b4"): "mid", H("484a77"): "dark", H("323353"): "deep"},
    "shoes": {H("753c54"): "mid", H("45293f"): "dark"},
}

# Row -> facing. Rows follow Scenes/ken.tscn.
ROW_DIR = {0: "front", 1: "front", 2: "back", 3: "back", 4: "right", 5: "right",
           6: "left", 7: "left", 8: "front", 9: "front", 10: "back", 11: "right",
           12: "left", 13: "front", 14: "right", 15: "left", 16: "back"}


def tone(base, kind):
    return base[kind] if kind in base else base["mid"]


def components(px, pts):
    pts = set(pts)
    comps = []
    while pts:
        start = pts.pop()
        stack, comp = [start], [start]
        while stack:
            x, y = stack.pop()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) in pts:
                    pts.remove((nx, ny))
                    stack.append((nx, ny))
                    comp.append((nx, ny))
        comps.append(comp)
    return comps


def segment(frame):
    """Returns dict (x,y) -> (part, tone) for a 32x32 frame."""
    px = frame.load()
    seg = {}
    opaque = [(x, y) for y in range(32) for x in range(32) if px[x, y][3] > 0]
    if not opaque:
        return seg, None
    top = min(y for _, y in opaque)
    hp = [(x, y) for (x, y) in opaque if px[x, y] in HAIRPANTS]
    for comp in components(px, hp):
        miny = min(y for _, y in comp)
        part = "hair" if miny <= top + 4 else "pants"
        for p in comp:
            seg[p] = (part, HAIRPANTS[px[p]])
    # Water from the watering can reuses the vest blues; keep any blue cluster
    # that touches the light water colour.
    water_hi = {H("8fd3ff")}
    blues = [(x, y) for (x, y) in opaque if px[x, y] in PART_COLORS["vest"]]
    for comp in components(px, blues):
        cs = set(comp)
        touches = False
        for (x, y) in comp:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if 0 <= q[0] < 32 and 0 <= q[1] < 32 and px[q] in water_hi:
                        touches = True
        if touches:
            for p in comp:
                seg[p] = ("water", "mid")
    for (x, y) in opaque:
        c = px[x, y]
        if (x, y) in seg:
            continue
        if c == OUTLINE:
            seg[(x, y)] = ("outline", "mid")
            continue
        for part, cmap in PART_COLORS.items():
            if c in cmap:
                seg[(x, y)] = (part, cmap[c])
                break
    return seg, top


def hair_box(seg):
    pts = [p for p, (part, _) in seg.items() if part == "hair"]
    if not pts:
        return None
    xs = [x for x, _ in pts]
    ys = [y for _, y in pts]
    return min(xs), min(ys), max(xs), max(ys)


def recolor(frame, seg, pal):
    out = frame.copy()
    o = out.load()
    for (x, y), (part, t) in seg.items():
        if part in pal:
            o[x, y] = tone(pal[part], t)
    return out


def put(o, x, y, c, only_empty=False):
    if 0 <= x < 32 and 0 <= y < 32:
        if only_empty and o[x, y][3] > 0:
            return
        o[x, y] = c


def outline_pass(o, mask):
    """Adds outline pixels around `mask` points where the frame is empty."""
    for (x, y) in list(mask):
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in mask and 0 <= nx < 32 and 0 <= ny < 32 and o[nx, ny][3] == 0:
                o[nx, ny] = OUTLINE


def add_long_hair(out, seg, facing, hair, length=6):
    hb = hair_box(seg)
    if not hb:
        return
    x0, y0, x1, y1 = hb
    o = out.load()
    mask = set()
    hi, mid, dark = hair["hi"], hair["mid"], hair["dark"]
    if facing == "front":
        for side, xs in (("l", (x0 - 1, x0)), ("r", (x1, x1 + 1))):
            for x in xs:
                for y in range(y1 - 2, y1 + length):
                    edge = x in (x0 - 1, x1 + 1)
                    put(o, x, y, dark if edge else mid)
                    mask.add((x, y))
    elif facing == "back":
        for y in range(y1 - 1, y1 + length):
            inset = 1 if y > y1 + length - 3 else 0
            for x in range(x0 + inset, x1 + 1 - inset):
                c = mid if (x - x0) % 3 else dark
                if y == y1 + length - 1:
                    c = dark
                put(o, x, y, c)
                mask.add((x, y))
    else:
        # Hair falls behind the head: for a right-facing sprite that is the left edge.
        xs = (x0 - 1, x0, x0 + 1) if facing == "right" else (x1 - 1, x1, x1 + 1)
        for y in range(y1 - 2, y1 + length - 1):
            for x in xs:
                put(o, x, y, dark if x in (x0 - 1, x1 + 1) else mid)
                mask.add((x, y))
    outline_pass(o, mask)


def add_ponytail(out, seg, facing, hair):
    hb = hair_box(seg)
    if not hb:
        return
    x0, y0, x1, y1 = hb
    o = out.load()
    mask = set()
    mid, dark, hi = hair["mid"], hair["dark"], hair["hi"]
    if facing == "back":
        cx = (x0 + x1) // 2
        for y in range(y1 - 1, y1 + 5):
            for x in (cx, cx + 1):
                put(o, x, y, mid if y < y1 + 3 else dark)
                mask.add((x, y))
    elif facing in ("left", "right"):
        bx = x0 - 1 if facing == "right" else x1 + 1
        step = -1 if facing == "right" else 1
        pts = [(bx, y0 + 4), (bx, y0 + 5), (bx + step, y0 + 5), (bx + step, y0 + 6),
               (bx + step, y0 + 7), (bx + step, y0 + 8), (bx, y0 + 8), (bx + step, y0 + 9)]
        for i, (x, y) in enumerate(pts):
            put(o, x, y, mid if i < 5 else dark)
            mask.add((x, y))
        put(o, bx, y0 + 4, hi)
    outline_pass(o, mask)


def add_hat(out, seg, facing, hat):
    hb = hair_box(seg)
    if not hb:
        return
    x0, y0, x1, y1 = hb
    o = out.load()
    cx = (x0 + x1) / 2.0
    brim_y = y0 + 3
    mask = set()
    lt, mid, dk, band = hat["hi"], hat["mid"], hat["dark"], hat["band"]
    bw = (x1 - x0) // 2 + 3
    for x in range(int(cx - bw), int(cx + bw) + 2):
        put(o, x, brim_y, mid)
        put(o, x, brim_y + 1, dk)
        mask.add((x, brim_y)); mask.add((x, brim_y + 1))
    cw = (x1 - x0) // 2
    for y in range(brim_y - 4, brim_y):
        for x in range(int(cx - cw) + 1, int(cx + cw) + 1):
            c = lt if y == brim_y - 4 or x == int(cx - cw) + 1 else mid
            if y == brim_y - 1:
                c = band
            put(o, x, y, c)
            mask.add((x, y))
    outline_pass(o, mask)


def add_beard(out, seg, facing, hair):
    if facing == "back":
        return
    o = out.load()
    skin = [(x, y) for (x, y), (p, _) in seg.items() if p == "skin"]
    if not skin:
        return
    top = min(y for _, y in skin)
    face = [(x, y) for (x, y) in skin if y <= top + 7]
    if not face:
        return
    fy = max(y for _, y in face)
    for (x, y) in face:
        if y >= fy - 1:
            o[x, y] = hair["mid"] if (x + y) % 2 else hair["dark"]


def build(variant):
    src = Image.open(SRC).convert("RGBA")
    W, Hh = src.size
    out = Image.new("RGBA", (W, Hh), (0, 0, 0, 0))
    for row in range(Hh // 32):
        facing = ROW_DIR.get(row, "front")
        for col in range(W // 32):
            fr = src.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32))
            seg, top = segment(fr)
            if top is None:
                continue
            nf = recolor(fr, seg, variant["pal"])
            for extra in variant.get("extras", []):
                if extra == "long_hair":
                    add_long_hair(nf, seg, facing, variant["pal"]["hair"], variant.get("hair_len", 6))
                elif extra == "ponytail":
                    add_ponytail(nf, seg, facing, variant["pal"]["hair"])
                elif extra == "hat":
                    add_hat(nf, seg, facing, variant["hat"])
                elif extra == "beard":
                    add_beard(nf, seg, facing, variant["pal"]["hair"])
            out.paste(nf, (col * 32, row * 32))
    return out


def P(hi, mid, dark=None, deep=None):
    d = {"hi": H(hi), "mid": H(mid), "dark": H(dark or mid)}
    if deep:
        d["deep"] = H(deep)
    return d


VARIANTS = {
    # Playable
    "mira": {
        "pal": {
            "hair": P("e6904e", "cd683d", "9e4539"),
            "skin": P("f6ca9f", "e69c69", "b86f50"),
            "shirt": P("fbf4e4", "e8d8b4"),
            "vest": P("5ac54f", "239063", "1e5a3c", "16402d"),
            "pants": P("a0703e", "7a4b2a", "5a3420"),
            "shoes": P("6e4a2a", "4a2f1c"),
        },
        "extras": ["long_hair"],
        "hair_len": 6,
    },
    "rico": {
        "pal": {
            "hair": P("4a3a33", "2f2523", "1c1414"),
            "skin": P("f0c49b", "c98b6a", "9a5e4a"),
            "shirt": P("f2e6c8", "d6c49c"),
            "vest": P("e83b3b", "ae2334", "6e2727", "4a1c22"),
            "pants": P("4d65b4", "3b4a8a", "29366f"),
            "shoes": P("6e4a2a", "4a2f1c"),
        },
        "extras": ["hat"],
        "hat": {"hi": H("fbe7a0"), "mid": H("e9c46a"), "dark": H("b8863b"), "band": H("ae2334")},
    },
    # Villagers
    "rosa": {
        "pal": {
            "hair": P("5a4a52", "3b2d33", "241a1f"),
            "skin": P("f6ca9f", "d89a72", "a86a52"),
            "shirt": P("ffffff", "dfe6ea"),
            "vest": P("f68181", "c33c5a", "8a2a44", "5e1c30"),
            "pants": P("8e5bab", "6b3e75", "4a2a52"),
            "shoes": P("6e2727", "45293f"),
        },
        "extras": ["long_hair"],
        "hair_len": 7,
    },
    "ben": {
        "pal": {
            "hair": P("b3b9d1", "8b93af", "5d6176"),
            "skin": P("c09473", "8a5a45", "5e3a2e"),
            "shirt": P("c7cfcc", "9babb2"),
            "vest": P("8a6040", "6b4630", "4a2e20", "33201a"),
            "pants": P("5d5d6e", "45455a", "2e2e3a"),
            "shoes": P("3e3546", "2e222f"),
        },
        "extras": ["beard"],
    },
    "pedro": {
        "pal": {
            "hair": P("e6e6e6", "c7cfcc", "92a1b9"),
            "skin": P("eab08a", "c98b6a", "8f5d4a"),
            "shirt": P("f2e6c8", "d6c49c"),
            "vest": P("91db69", "5a9a3a", "3a6a2a", "254a1e"),
            "pants": P("a08662", "7a6448", "574530"),
            "shoes": P("6e4a2a", "4a2f1c"),
        },
        "extras": ["hat", "beard"],
        "hat": {"hi": H("c28d5a"), "mid": H("a0703e"), "dark": H("6e4a2a"), "band": H("3b2d33")},
    },
    "lina": {
        "pal": {
            "hair": P("fbe7a0", "f9c22b", "c8952a"),
            "skin": P("f9d5b5", "eab08a", "b97a60"),
            "shirt": P("ffffff", "dfe6ea"),
            "vest": P("a884f3", "7a5ad0", "4a3a8a", "33285e"),
            "pants": P("4d9be6", "4d65b4", "323353"),
            "shoes": P("753c54", "45293f"),
        },
        "extras": ["ponytail"],
    },
}


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, v in VARIANTS.items():
        img = build(v)
        img.save(os.path.join(OUT_DIR, f"{name}.png"))
        print("wrote", name)
