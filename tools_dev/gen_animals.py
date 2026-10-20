"""Night Harvest 1.4 wild animals (same 2x2 sheet of 32x32 frames as Assets/Animals/*).
Run: python3 tools_dev/gen_animals.py -> Assets/Generated/v131/animal_<name>.png
All face LEFT like the original animal art.
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "Assets", "Generated", "v131")


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def draw(rows, pal):
    h = len(rows)
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != "." and ch in pal:
                im.putpixel((x, y), hexc(pal[ch]))
    return im


def sheet(frames, name, shadow_w):
    out = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        cx, cy = (i % 2) * 32, (i // 2) * 32
        sh = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(sh)
        d.ellipse([16 - shadow_w // 2, 26, 16 + shadow_w // 2, 30], fill=(20, 40, 20, 70))
        out.alpha_composite(sh, (cx, cy))
        x = cx + (32 - fr.width) // 2
        y = cy + 29 - fr.height
        out.alpha_composite(fr, (x, y))
    out.save(os.path.join(OUT, "animal_%s.png" % name))


def legs(rows, a, b):
    """Two walk poses: replace the last two rows."""
    return rows[:-2] + a, rows[:-2] + b


RABBIT_BODY = [
    "..oo.oo..........",
    ".obPobPo.........",
    ".obPobPo.........",
    ".obbobbo.........",
    "..obbbbboooo.....",
    ".obkbbbbbbbboo...",
    "obbbbbbbbbbbbbo..",
    "onBbbbbbbbbbbbWo.",
    ".oBBbbbbbbbbbWWo.",
    "..oBBBbbbbbbbbo..",
]
RABBIT_A = ["...obbo..obbo....", "...ooo....ooo...."]
RABBIT_B = ["..obbo....obbo...", "..ooo......ooo..."]


def rabbit(name, base, light, dark, ear="f2a0a8"):
    pal = {"o": dark, "b": base, "B": light, "k": "2a1a14", "P": ear, "n": "f2a0a8", "W": "f8f4ec"}
    a, b = legs(RABBIT_BODY + ["x", "x"], RABBIT_A, RABBIT_B)
    sheet([draw(a, pal), draw(a, pal), draw(a, pal), draw(b, pal)], name, 12)


DUCK = [
    "...ooo.........",
    "..oGGGo........",
    ".oGkGGo........",
    "oyyGGGo........",
    ".oooGGo.....o..",
    "...oWWWooooowo.",
    "..oWWWWWWWWWWo.",
    "..oWWWWwwwWWWo.",
    "...oWWWwwwWWo..",
    "....oWWWWWWo...",
    "x",
    "x",
]
DUCK_A = [".....oyo.oyo...", ".....oyy.oyy..."]
DUCK_B = ["....oyo...oyo..", "....oyy...oyy.."]


def duck():
    pal = {"o": "4a3a30", "G": "2f8f5a", "k": "101010", "y": "f0a830", "W": "f2eee4", "w": "c9c2b4"}
    a, b = legs(DUCK, DUCK_A, DUCK_B)
    sheet([draw(a, pal), draw(a, pal), draw(a, pal), draw(b, pal)], "duck", 12)


GOAT = [
    "..oo...................",
    ".ogo...................",
    ".ogoo..................",
    "..oWWo.................",
    "..oWWWoooooooooooo.....",
    ".oWkWWWWWWWWWWWWWWoo...",
    "oWWWWWWWWWWWWWWWWWWWo..",
    "onWWWWWWWWWWWWWWWWWWWo.",
    ".ooWWWWWsWWWWWWsWWWWWo.",
    "..oWWbWWWWWWWWWWWWWWo..",
    "..obboWWWWWWWWWWWWWo...",
    "...oo.oWWWWWWWWWWWo....",
    "x",
    "x",
]
GOAT_A = ["......oWo.oWo..oWo.oWo.", "......oko.oko..oko.oko."]
GOAT_B = [".....oWo...oWo.oWo...oWo", ".....oko...oko.oko...oko"]


def goat():
    pal = {"o": "5a5048", "W": "e8e2d6", "s": "c8c0b2", "g": "9a8e7e", "k": "2a2020", "n": "c89a8a", "b": "d8d0c2"}
    a, b = legs(GOAT, GOAT_A, GOAT_B)
    sheet([draw(a, pal), draw(a, pal), draw(a, pal), draw(b, pal)], "goat", 18)


DEER = [
    "o..o.o..................",
    ".oaoao..................",
    "..oao...................",
    "...ooo..................",
    "..obbbo.................",
    ".obkbbbo................",
    "onbbbbbooooooooo........",
    ".ooobbbbbbbbbbbbbo......",
    "....obBbbBbbbBbbbWo.....",
    "....obbbbbbbbbbbbWo.....",
    "....oBBbbbbbbbbbbbo.....",
    ".....oBBBbbbbbbbbo......",
    "x",
    "x",
    "x",
]
DEER_A = [".....obo.obo...obo.obo..", ".....obo.obo...obo.obo..", ".....okk.okk...okk.okk.."]
DEER_B = ["....obo...obo.obo...obo.", "....obo...obo.obo...obo.", "....okk...okk.okk...okk."]


def deer():
    pal = {"o": "4a2c1c", "b": "b0723e", "B": "e0b07a", "k": "1a1010", "n": "2a1a14", "a": "d8c49a", "W": "f4ece0"}
    body = DEER[:-3]
    a = body + DEER_A
    b = body + DEER_B
    sheet([draw(a, pal), draw(a, pal), draw(a, pal), draw(b, pal)], "deer", 18)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    rabbit("rabbit", "a8784e", "d4aa7c", "5e3c26")
    rabbit("snow_hare", "eceae6", "ffffff", "8a8a96", "e8b4bc")
    duck()
    goat()
    deer()
    print("ok")
