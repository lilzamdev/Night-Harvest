"""Night Harvest 1.4 rowing boat sprites.
Run: python3 tools_dev/gen_boat.py  (writes Assets/Generated/v131/boat_*.png, icon_boat.png)
boat_h / boat_v are the whole boat; *_front is only the near half, drawn over the
rider so their legs are inside the boat.
"""
import os, math
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "Assets", "Generated", "v131")
K = (43, 26, 16, 255)        # outline
RIM = (214, 158, 96, 255)    # sunlit rim
RIM_D = (170, 112, 62, 255)  # shaded rim
FLOOR = (100, 64, 36, 255)
FLOOR_D = (80, 50, 28, 255)
SEAT = (198, 140, 82, 255)
SEAT_D = (150, 100, 56, 255)
HULL = (146, 92, 52, 255)
HULL_D = (112, 68, 38, 255)
STRIPE = (64, 112, 150, 255)  # painted band on the hull


def deck_half(t):
    """Half-width of the deck at t in 0..1 (0 = stern, 1 = bow)."""
    s = 1.0
    if t < 0.1:
        s = math.sqrt(max(0.0, t / 0.1)) * 0.35 + 0.65
    if t > 0.58:
        s *= max(0.0, 1.0 - ((t - 0.58) / 0.42) ** 1.7)
    return s


def boat(length, half, side, horizontal):
    """Draws a boat lying along x (horizontal) - rotated for the vertical one."""
    W, H = length, int(half * 2 + side + 4)
    cy = half + 1.5
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    def hh(x):
        return half * deck_half((x + 0.5) / W)

    def in_deck(x, y):
        return 0 <= x < W and abs(y + 0.5 - cy) <= hh(x)

    for x in range(W):
        h = hh(x)
        if h < 0.6:
            continue
        # hull side below the deck (the near wall)
        bottom = int(cy + h)
        depth = int(round(side * min(1.0, h / (half * 0.55))))
        for y in range(bottom, min(H, bottom + depth + 1)):
            col = HULL if (y - bottom) % 3 != 2 else HULL_D
            if y - bottom == 1:
                col = STRIPE
            px[x, y] = col
        if bottom + depth + 1 < H:
            px[x, bottom + depth + 1] = K
        for y in range(H):
            if not in_deck(x, y):
                continue
            edge = not (in_deck(x - 1, y) and in_deck(x + 1, y) and in_deck(x, y - 1) and in_deck(x, y + 1))
            inner = abs(y + 0.5 - cy) <= h - 2.0 and in_deck(x - 2, y) and in_deck(x + 2, y)
            if edge:
                px[x, y] = K
            elif not inner:
                px[x, y] = RIM if y + 0.5 < cy else RIM_D
            else:
                px[x, y] = FLOOR if (y % 3) else FLOOR_D
    # two seats across the boat
    for sx in (int(W * 0.3), int(W * 0.62)):
        for x in (sx, sx + 1, sx + 2):
            for y in range(H):
                if px[x, y] in (FLOOR, FLOOR_D):
                    px[x, y] = SEAT if x != sx + 2 else SEAT_D
    # outline the hull bottom corners
    for x in range(W):
        for y in range(H):
            if px[x, y][3] and px[x, y] != K:
                for dx, dy in ((1, 0), (-1, 0), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3] == 0 and (y > cy):
                        px[x, y] = K
    return img, int(cy)


def front_of(img, from_y):
    f = img.copy()
    px = f.load()
    for y in range(min(from_y, f.height)):
        for x in range(f.width):
            px[x, y] = (0, 0, 0, 0)
    return f


h, cy = boat(40, 7.0, 5, True)
h.save(os.path.join(OUT, "boat_h.png"))
front_of(h, cy + 1).save(os.path.join(OUT, "boat_h_front.png"))

# vertical: a slimmer boat drawn along x, turned so the bow points up
v0, vcy = boat(36, 6.0, 0, False)
v = v0.rotate(90, expand=True)
# the near (bottom) end gets a little transom wall
px = v.load()
W, H = v.size
for x in range(W):
    col = [y for y in range(H) if px[x, y][3]]
    if col:
        b = max(col)
        if b + 3 < H and px[x, b] == K and 0 < x < W - 1:
            for y in (b, b + 1, b + 2):
                px[x, y] = HULL if y != b + 1 else STRIPE
            px[x, b + 3] = K
v.save(os.path.join(OUT, "boat_v.png"))
front_of(v, int(H * 0.52)).save(os.path.join(OUT, "boat_v_front.png"))
# v1.4.2: rowing down - the bow points down
vd = v.transpose(Image.FLIP_TOP_BOTTOM)
vd.save(os.path.join(OUT, "boat_vd.png"))
front_of(vd, int(H * 0.52)).save(os.path.join(OUT, "boat_vd_front.png"))

icon = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
small, _ = boat(16, 3.0, 2, True)
icon.alpha_composite(small, (0, max(0, 9 - small.height // 2)))
icon.save(os.path.join(OUT, "icon_boat.png"))
print("boat sizes", h.size, v.size, small.size)

# v1.4.1: pad every boat picture to GPU-friendly sizes (multiples of 16) so the
# D3D12 renderer always accepts them. Content keeps its position from the top.
def pad(name, W, H, ox, oy):
    p = os.path.join(OUT, name)
    src = Image.open(p).convert("RGBA")
    if src.size == (W, H):
        return
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    c.alpha_composite(src, (ox, oy))
    c.save(p)

for n in ("boat_h.png", "boat_h_front.png"):
    pad(n, 48, 32, 4, 0)
for n in ("boat_v.png", "boat_v_front.png", "boat_vd.png", "boat_vd_front.png"):
    pad(n, 16, 48, 0, 0)
print("padded")
