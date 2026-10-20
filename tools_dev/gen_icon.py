"""Night Harvest app icon (PNG + Windows .ico) from the game's lantern art.
Run: python3 tools_dev/gen_icon.py

NOTE (v1.4.3): the official logo badge now lives in Assets/Generated/v131/game_icon.png,
game_logo.png and game_icon.ico. Running this script overwrites it with the old lantern icon."""
import os
from PIL import Image, ImageDraw
ROOT = os.path.join(os.path.dirname(__file__), "..")
S = 256
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
# night sky tile with a rim
d.rounded_rectangle((6, 6, S - 7, S - 7), radius=40, fill=(24, 30, 58, 255), outline=(232, 186, 92, 255), width=8)
for x, y in [(40, 52), (70, 30), (200, 60), (180, 34), (52, 110), (214, 120)]:
    d.rectangle((x, y, x + 5, y + 5), fill=(230, 236, 255, 255))
# moon
d.ellipse((150, 26, 222, 98), fill=(250, 238, 190, 255))
d.ellipse((168, 18, 236, 86), fill=(24, 30, 58, 255))
# field
d.rectangle((14, 190, S - 15, S - 15), fill=(52, 104, 52, 255))
for x in range(22, S - 22, 22):
    d.rectangle((x, 182, x + 6, 192), fill=(76, 146, 66, 255))
# warm glow + the lantern
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for r, a in [(96, 40), (72, 60), (50, 80)]:
    gd.ellipse((128 - r, 140 - r, 128 + r, 140 + r), fill=(255, 190, 90, a))
im = Image.alpha_composite(im, glow)
lan = Image.open(os.path.join(ROOT, "Assets", "Generated", "v131", "lantern.png")).convert("RGBA")
big = lan.resize((lan.width * 10, lan.height * 10), Image.NEAREST)
im.alpha_composite(big, (128 - big.width // 2, 140 - big.height // 2))
out_png = os.path.join(ROOT, "Assets", "Generated", "v131", "game_icon.png")
im.save(out_png)
im.save(os.path.join(ROOT, "game_icon.ico"), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("icon ok")
