"""Hand-authored pixel art for Night Harvest props and icons (ASCII templates).

Palette matches the game's existing art (Resurrect-style, outline #2e222f).
Run: python3 tools_dev/gen_props.py  -> writes Assets/Generated/*.png
"""
from PIL import Image
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Assets/Generated")

PAL = {
    ".": None,
    "o": "2e222f",  # outline
    "O": "3e3546",  # soft outline / iron dark
    "w": "a0703e",  # wood mid
    "W": "c28d5a",  # wood light
    "d": "6e4a2a",  # wood dark
    "D": "4a2f1c",  # wood darkest
    "s": "9babb2",  # steel mid
    "S": "c7dcd0",  # steel light
    "t": "625565",  # steel dark
    "y": "f9c22b",  # gold
    "Y": "fbe7a0",  # gold light
    "g": "c8952a",  # gold dark
    "G": "8a5a1c",  # gold darkest
    "r": "ae2334",  # red
    "R": "e83b3b",  # red light
    "k": "6e2727",  # red dark
    "f": "5ac54f",  # leaf
    "F": "91db69",  # leaf light
    "e": "239063",  # leaf dark
    "h": "e9c46a",  # straw
    "H": "fbe7a0",  # straw light
    "j": "b8863b",  # straw dark
    "b": "4d9be6",  # blue
    "B": "8fd3ff",  # blue light
    "n": "4d65b4",  # blue dark
    "c": "f6ca9f",  # bread light
    "C": "d08159",  # bread mid
    "x": "9e4539",  # bread dark
    "p": "a884f3",  # purple
    "P": "e0c8ff",  # purple light
    "q": "6b3e75",  # purple dark
    "l": "ffffff",
    "z": "ece2c6",  # paper
    "Z": "c9b794",  # paper dark
}


def sprite(rows):
    h = len(rows)
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            c = PAL.get(ch)
            if c:
                px[x, y] = tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    return im


def strip(frames):
    w = sum(f.width for f in frames)
    h = max(f.height for f in frames)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = 0
    for f in frames:
        im.paste(f, (x, h - f.height))
        x += f.width
    return im


SPRITES = {}

# ---------------------------------------------------------------- coin (4-frame spin, 8x8)
SPRITES["coin"] = strip([sprite(r) for r in [
    ["..oooo..",
     ".oyYYyo.",
     "oyYyygyo",
     "oyYygGyo",
     "oyYygGyo",
     "oyyggGyo",
     ".oygGGo.",
     "..oooo.."],
    ["..ooo...",
     ".oYyyo..",
     ".oYygo..",
     ".oYygo..",
     ".oYygo..",
     ".oyygo..",
     ".oyGGo..",
     "..ooo..."],
    ["...oo...",
     "..oYyo..",
     "..oYgo..",
     "..oYgo..",
     "..oYgo..",
     "..oygo..",
     "..oyGo..",
     "...oo..."],
    ["...ooo..",
     "..oyyYo.",
     "..ogyYo.",
     "..ogyYo.",
     "..ogyYo.",
     "..ogyyo.",
     "..oGGyo.",
     "...ooo.."],
]])

# ---------------------------------------------------------------- icons 16x16
SPRITES["icon_coin"] = sprite([
    "................",
    "................",
    ".....oooooo.....",
    "....oYYYYyyo....",
    "...oYYyyyyygo...",
    "..oYYyoooogygo..",
    "..oYyoyyyyogyo..",
    "..oYyoyggyogyo..",
    "..oYyooggyogyo..",
    "..oYyyyoggogyo..",
    "..oyyoooooogGo..",
    "...oyyyyyyyGo...",
    "....ogggggGo....",
    ".....oooooo.....",
    "................",
    "................",
])

SPRITES["barricade"] = strip([sprite(r) for r in [
    [  # healthy
        "..o..........o..",
        ".oWo........oWo.",
        ".oWwo......owWo.",
        "..owwo....owwo..",
        "oooowwooooowoooo",
        "oWWWWWWWWWWWWWWo",
        "owwwwwwwwwwwwwwo",
        "oddddddddddddddo",
        "ooooowwooowwoooo",
        "...owwo..owwo...",
        "oooowooooowooooo",
        "oWWWWWWWWWWWWWWo",
        "owwwwdwwwwwdwwwo",
        "oddddddddddddddo",
        "oDooDooooooDooDo",
        ".o..o......o..o.",
    ],
    [  # cracked
        "..o..........o..",
        ".oWo........oWo.",
        ".oWwo......owWo.",
        "..owwo....owwo..",
        "oooowwooooowoooo",
        "oWWWWWoWWWWWWWWo",
        "owwwwwodwwwwwwwo",
        "oddddddoddddddDo",
        "ooooowwooowwoooo",
        "...owwo..owwo...",
        "oooowooooowooooo",
        "oWWWWWWWWoWWWWWo",
        "owwwwdwwwodwwwwo",
        "oddddddddoddDddo",
        "oDooDooooooDooDo",
        ".o..o......o..o.",
    ],
    [  # broken
        "................",
        "................",
        ".............o..",
        "............oWo.",
        "...........owwo.",
        "oWWWWo....owwo..",
        "owwwwwo..oowoooo",
        "odddddDo.oWWWWWo",
        "ooooowwooowwwwwo",
        "...owwo..odddddo",
        "oooowooooowooooo",
        "oWWWWWoWWoWWWWWo",
        "owwwwdodwodwwwwo",
        "odddddDoddoddDdo",
        "oDooDooooooDooDo",
        ".o..o......o..o.",
    ],
]])

SPRITES["spikes"] = strip([sprite(r) for r in [
    [  # armed
        "................",
        "................",
        "................",
        "...o...o...o....",
        "..oSo.oSo.oSo...",
        "..oso.oso.oso...",
        ".oSsto.Ssto.Sto.",
        ".oosoooosoooosoo",
        ".oWWWWWWWWWWWWWo",
        ".owwSwwwSwwwSwwo",
        ".odddddddddddddo",
        ".oooooooooooooo.",
        "................",
        "................",
        "................",
        "................",
    ],
    [  # sprung (blood-tipped)
        "...o...o...o....",
        "..oRo.oRo.oRo...",
        "..oSo.oSo.oSo...",
        "..oso.oso.oso...",
        "..oso.oso.oso...",
        ".oSsto.Ssto.Sto.",
        ".oosoooosoooosoo",
        ".oosoooosoooosoo",
        ".oWWWWWWWWWWWWWo",
        ".owwSwwwSwwwSwwo",
        ".odddddddddddddo",
        ".oooooooooooooo.",
        "................",
        "................",
        "................",
        "................",
    ],
]])

# Scarecrow crossbow turret, 16x32, 2 frames (idle / firing)
_turret_base = [
    "......oooo......",
    ".....ojhhjo.....",
    "....ojhHHhjo....",
    "...oooooooooo...",
    "..ojjhhhhhhjjo..",
    "...oocccccoo....",
    "....occlclco....",
    "....occccxco....",
    "....oxcxxcxo....",
    ".....oooooo.....",
    "...orrrrrrrro...",
]
SPRITES["turret"] = strip([sprite(r) for r in [
    _turret_base + [
        "oooorRrrrRrroooo",
        "oWWdorrrrrrodWWo",
        "oddoorrRrrroodDo",
        "...oorrrrrrrro..",
        "....orrrrrrro...",
        "....okkkkkkko...",
        ".....odwwdo.....",
        ".....owwwwo.....",
        "....oossssoo....",
        "...oSssoossSo...",
        "....oooddooo....",
        "......owwo......",
        "......owwo......",
        "......owwo......",
        ".....odwwdo.....",
        "....oddwwddo....",
        "...oDDddddDDo...",
        "...oooooooooo...",
        "................",
        "................",
        "................",
    ],
    _turret_base + [
        "oooorRrrrRrroooo",
        "oSWdorrrrrrodWSo",
        "oddoorrRrrroodDo",
        "...oorrrrrrrro..",
        "....orrrrrrro...",
        "....okkkkkkko...",
        ".....odwwdo.....",
        ".....owwwwo.....",
        "...ooossssooo...",
        "..oSssoooossSo..",
        "....oooddooo....",
        "......owwo......",
        "......owwo......",
        "......owwo......",
        ".....odwwdo.....",
        "....oddwwddo....",
        "...oDDddddDDo...",
        "...oooooooooo...",
        "................",
        "................",
        "................",
    ],
]])

SPRITES["bolt"] = sprite([
    "........",
    "...o....",
    "oooSo...",
    "owwwSso.",
    "oooSo...",
    "...o....",
    "........",
    "........",
])

SPRITES["icon_turret"] = sprite([
    "......oooo......",
    ".....ojhhjo.....",
    "...oooooooooo...",
    "..ojjhhhhhhjjo..",
    "....occlclco....",
    "....oxcxxcxo....",
    "oooorRrrrRrroooo",
    "oWWdorrrrrrodWWo",
    "...oorrRrrrro...",
    "....okkkkkkko...",
    ".....owwwwo.....",
    "...oSssoossSo...",
    "......owwo......",
    ".....odwwdo.....",
    "...oDDddddDDo...",
    "...oooooooooo...",
])

SPRITES["icon_bread"] = sprite([
    "................",
    "................",
    "................",
    ".....oooooo.....",
    "...ooccccccoo...",
    "..occcCcccCcco..",
    ".occCccCccCccCo.",
    ".ocCCcCCcCCcCCo.",
    ".oCCCCCCCCCCCCo.",
    ".oCCCCCCCCCCCxo.",
    ".oxCCCCCCCCCxxo.",
    "..oxxxxxxxxxxo..",
    "...oooooooooo...",
    "................",
    "................",
    "................",
])

SPRITES["icon_tonic"] = sprite([
    "................",
    "......oooo......",
    "......oWwo......",
    "......oddo......",
    ".....oSllSo.....",
    ".....oSllSo.....",
    "....oSlllSso....",
    "...oRRRRRRrro...",
    "..oRRlRRRRRrro..",
    "..oRlRRRRRRrko..",
    "..oRRRRRRRRrko..",
    "..orRRRRRRrrko..",
    "..orrrrrrrrkko..",
    "...okkkkkkkko...",
    "....oooooooo....",
    "................",
])

SPRITES["icon_steel_sword"] = sprite([
    "............ooo.",
    "...........oSlo.",
    "..........oSlso.",
    ".........oSlso..",
    "........oSlso...",
    ".......oSlso....",
    "......oSlso.....",
    "..oo.oSlso......",
    "..oyoSlso.......",
    "...oyyso........",
    "...oyyo.........",
    "..oddoyo........",
    ".oddo.oyo.......",
    "oddo...oo.......",
    "oDo.............",
    "oo..............",
])

SPRITES["icon_lantern"] = sprite([
    "......oooo......",
    ".....oOttOo.....",
    "......oOOo......",
    "....oooooooo....",
    "....otsssstO....",
    "....ooYYYYoo....",
    "....oYyYYyYo....",
    "....oyYllYyo....",
    "....oyYlYYyo....",
    "....ogyYYygo....",
    "....ooggggoo....",
    "....otsssstO....",
    "....oooooooo....",
    "................",
    "................",
    "................",
])

# Interaction key cap (E) 11x11
SPRITES["key_e"] = sprite([
    ".ooooooooo.",
    "ozzzzzzzzzo",
    "ozzoooooozo",
    "ozzozzzzzzo",
    "ozzoooozzzo",
    "ozzozzzzzzo",
    "ozzoooooozo",
    "ozzzzzzzzzo",
    "oZZZZZZZZZo",
    "oZZZZZZZZZo",
    ".ooooooooo.",
])

# Market stall (48x40) for the village square
SPRITES["stall"] = sprite([
    "................................................",
    "..oooooooooooooooooooooooooooooooooooooooooooo..",
    ".orrRRrrRRrrRRrrRRrrRRrrRRrrRRrrRRrrRRrrRRrrRro.",
    "orrRRrrRRrrRRrrRRrrRRrrRRrrRRrrRRrrRRrrRRrrRRrro",
    "orllRRllRRllRRllRRllRRllRRllRRllRRllRRllRRllRRro",
    "orllRRllRRllRRllRRllRRllRRllRRllRRllRRllRRllRRro",
    "orllRRllRRllRRllRRllRRllRRllRRllRRllRRllRRllRRro",
    "okllkkllkkllkkllkkllkkllkkllkkllkkllkkllkkllkkko",
    ".oololoololoololoololoololoololoololoololoololo.",
    "..o.o..o.o..o.o..o.o..o.o..o.o..o.o..o.o..o.o...",
    "..ow......................................wo....",
    "..ow......................................wo....",
    "..ow......................................wo....",
    "..ow......................................wo....",
    "..ow......................................wo....",
    "..ow......................................wo....",
    "..ow......................................wo....",
    "..ow......................................wo....",
    ".ooooooooooooooooooooooooooooooooooooooooooooo..",
    ".oWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWo..",
    ".owwwoooowwwwwoooowwwwwoooowwwwwoooowwwwwwwwwo..",
    ".owwoCxCxowwwoffFfowwwoyyYyowwwoRrRrowwwwwwwwo..",
    ".owwoxCxCowwwoFffeowwwoYygyowwworRrkowwwwwwwwo..",
    ".owwwoooowwwwwoooowwwwwoooowwwwwoooowwwwwwwwwo..",
    ".oddddddddddddddddddddddddddddddddddddddddddddo..",
    ".owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwo..",
    ".owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwo..",
    ".owwdwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwdwwo..",
    ".owwdwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwdwwo..",
    ".oddddddddddddddddddddddddddddddddddddddddddddo..",
    ".oDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDo..",
    ".oooooooooooooooooooooooooooooooooooooooooooooo..",
])

# ---------------------------------------------------------------- graveyard
PAL.update({
    "g": "9babb2", "G": "c7dcd0", "k": "625565", "K": "3e3546",   # (k reused as stone dark in these sprites)
    "m": "4a5a3a", "M": "6a7a4a",  # moss
    "u": "5a3a2a", "U": "7a5a3a",  # grave dirt
    "v": "8fd3ff", "V": "c8f0ff",  # spirit glow
})

SPRITES["tomb_round"] = sprite([
    "................",
    ".....oooooo.....",
    "....oGGGGGgo....",
    "...oGGggggggo...",
    "...oGgkkkkggo...",
    "...oGggggggko...",
    "...oGgkkkkgko...",
    "...oGggggggko...",
    "...oGgkkgggko...",
    "...oGggggggko...",
    "...oggggggkko...",
    "..oMmggggggkmo..",
    "..oKMmmKKmmMKo..",
    "...oooooooooo...",
    "................",
    "................",
])
SPRITES["tomb_cross"] = sprite([
    "......ooo.......",
    "......oGo.......",
    "......oGo.......",
    "...ooooGoooo....",
    "...oGGGGGGgo....",
    "...ooooGgooo....",
    "......oGgo......",
    "......oGgo......",
    "......oGgo......",
    "......oGgo......",
    "......oggo......",
    ".....ooggoo.....",
    "....oMmggkMo....",
    "....oKMmmMKo....",
    ".....oooooo.....",
    "................",
])
SPRITES["tomb_slab"] = sprite([
    "................",
    "................",
    "................",
    "................",
    "..oooooooooooo..",
    "..oGGGGGGGGGgo..",
    "..oGgggggggggo..",
    "..oGgkkgkkgkgo..",
    "..oGgggggggggo..",
    "..oGgkgkkgkkgo..",
    "..oGgggggggggo..",
    "..oggggggggkko..",
    ".oMmggggggggkmo.",
    ".oKMmmKKKmmmMKo.",
    "..oooooooooooo..",
    "................",
])
SPRITES["grave_dirt"] = sprite([
    "................",
    "................",
    "................",
    "....oooooooo....",
    "...oUUUUUUUUo...",
    "..oUuUUuUUuUUo..",
    "..oUUuoooouUUo..",
    "..oUuoKKKKouUo..",
    "..oUuoKKKKouUo..",
    "..oUUuoooouUUo..",
    "..oUuUUuUUuUUo..",
    "...oUUUUUUUUo...",
    "....oooooooo....",
    "................",
    "................",
    "................",
])
SPRITES["iron_fence"] = sprite([
    "................",
    ".o...o...o...o..",
    "oKo.oKo.oKo.oKo.",
    ".K...K...K...K..",
    "oKoooKoooKoooKoo",
    "OKKKKKKKKKKKKKKO",
    "oKoooKoooKoooKoo",
    ".K...K...K...K..",
    ".K...K...K...K..",
    ".K...K...K...K..",
    "oKoooKoooKoooKoo",
    "OKKKKKKKKKKKKKKO",
    "oKoooKoooKoooKoo",
    ".K...K...K...K..",
    ".o...o...o...o..",
    "................",
])
SPRITES["dead_tree"] = sprite([
    "..........o.....o...............",
    "...o.....oDo...oDo..............",
    "..oDo....oDo..oDo....o..........",
    "...oDo...oDo.oDo....oDo.........",
    "....oDo..oDooDo....oDo..........",
    "..o..oDo.oDDDo....oDo...........",
    ".oDo..oDooDDo..ooDDo...o........",
    "..oDDooDDDDooDDDDo....oDo.......",
    "...ooDDDDDDDDDooo...ooDo........",
    ".....ooDDdDDo....ooDDDo.........",
    ".......oDdDDooooDDDoo...........",
    ".......oDdDDDDDDooo.............",
    ".......oDdDDooo.................",
    ".......oDdDDo...................",
    ".......oDdDDo...................",
    ".......oDdDDo...................",
    ".......oDdDDo...................",
    ".......oDdDDo...................",
    "......oDDdDDDo..................",
    ".....oDDddDDDDo.................",
    "....oDDoooooDDDo................",
    "...ooo......oooo................",
])
SPRITES["crypt"] = sprite([
    "...............oo...............",
    "..............oGGo..............",
    ".............oGGggo.............",
    "............oGGggggo............",
    "...........oGGggggggo...........",
    "..........oGGggggggggo..........",
    ".........oGGggggggggggo.........",
    "........oGGggggggggggggo........",
    ".......oooooooooooooooooo.......",
    ".......oGGGGGGGGGGGGGGGgo.......",
    ".......oooooooooooooooooo.......",
    "........oGgo........oGgo........",
    "........oGgo.oooooo.oGgo........",
    "........oGgooKKKKKKooGgo........",
    "........oGgoKKkkkkKKoGgo........",
    "........oGgoKkKKKKkKoGgo........",
    "........oGgoKkKKKKkKoGgo........",
    "........oGgoKkKvVKkKoGgo........",
    "........oGgoKkKKKKkKoGgo........",
    "........oGgoKkKKKKkKoGgo........",
    "........oGgoKkKKKKkKoGgo........",
    "........oGgoKkKKKKkKoGgo........",
    ".......ooGgoKKKKKKKKoGgoo.......",
    "......oMmGgggggggggggggmMo......",
    "......oKMmmKKKKKKKKKKmmMKo......",
    ".......oooooooooooooooooo.......",
])
SPRITES["skull"] = sprite([
    "........",
    "..oooo..",
    ".oGGGgo.",
    "oGoGGogo",
    "oGGGGggo",
    ".oGoGgo.",
    "..oooo..",
    "........",
])


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, im in SPRITES.items():
        im.save(os.path.join(OUT, name + ".png"))
        print("wrote", name, im.size)
