"""Night Harvest 1.4.1 fence gate (closed / open + icon), drawn from the fence block.
Run: python3 tools_dev/gen_gate.py  (writes Assets/Generated/v131/gate_wood*.png)"""
import os
from PIL import Image
ROOT = os.path.join(os.path.dirname(__file__), "..", "Assets", "Generated")
fence = Image.open(os.path.join(ROOT, "v13", "fence_wood.png")).convert("RGBA")
px = fence.load()
# sample the fence palette: outline (darkest), wood light, wood dark
cols = sorted({px[x, y][:3] for x in range(16) for y in range(16) if px[x, y][3]}, key=lambda c: sum(c))
OUT_C, DARK, LIGHT = cols[0], cols[len(cols) // 3], cols[-1]
IRON = (70, 72, 82)

closed = fence.copy()
c = closed.load()
# diagonal brace across the inner gap (x 5..10, from bottom rail up to the top rail)
for i, x in enumerate(range(5, 11)):
    y = 12 - i
    for yy in (y, y + 1):
        if 4 <= yy <= 13:
            c[x, yy] = LIGHT + (255,)
    if 4 <= y - 1 <= 13 and c[x, y - 1][3]:
        c[x, y - 1] = DARK + (255,)
# a latch on the right post
for y in (7, 8):
    c[11, y] = IRON + (255,)
closed.save(os.path.join(ROOT, "v131", "gate_wood.png"))

opened = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
o = opened.load()
for y in range(16):
    for x in list(range(0, 5)) + list(range(11, 16)):
        o[x, y] = px[x, y]
# the gate swung open: seen edge-on next to the left post
for y in range(3, 15):
    o[5, y] = OUT_C + (255,)
    o[6, y] = (LIGHT if y % 4 else DARK) + (255,)
    o[7, y] = OUT_C + (255,)
opened.save(os.path.join(ROOT, "v131", "gate_wood_open.png"))
closed.save(os.path.join(ROOT, "v131", "icon_gate_wood.png"))
print("gate ok")
