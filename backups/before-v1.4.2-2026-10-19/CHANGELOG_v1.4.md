# Night Harvest 1.4.1 — fixes

- **Animals and zombies no longer drag you along** when you stand right next to them (the player
  body now moves like a top-down character, not one standing on a moving floor).
- **You are drawn in front of houses, furniture, lamp posts and cave mouths** when you stand in
  front of them (the game now sorts you by your feet, not the middle of your body).
- **E works properly**: one key press now counts once. Doors open (and stay open), boats let you
  get in and out, Q drops one item, beds no longer say "too early" twice.
- **Boat**: no more crash when pressing E to get in; the boat picture no longer shows as a white box.
- **Fence Gate** (workbench, BUILD tab: 3 wood): a fence you can open and close with E.
- **Trash**: drop any stack on the red TRASH bar in the inventory to delete it; click it to undo.
- **Lights come on whenever it gets dark** - at dusk, in thunderstorms and heavy rain, at night and
  in the mines - not only by the clock. Lanterns light a clear pool around them; the iron lamp posts
  around the farm now light up too, and the blue wooden houses' windows glow.
- **Fishing**: rippling, sparkling **fishing spots** appear in the water while you hold a rod; cast onto
  one and fish bite twice as fast, with better odds for rare fish. The line now hangs from the tip of
  the rod with a natural sag, and the splash on the water shows properly.
- **No more little freeze when planting next to zombies** (their path search is now time-limited).
- The sprint dust kicks up at your feet; the tutorial card hides while a menu (Settings, shop,
  crafting, a chat) is open, and there is no tutorial in Creative.
- Long sign and villager texts shrink to fit inside the conversation box; HUD messages wrap
  instead of being cut off.
- Chopping a pink tree no longer knocks down three flowers with it (they were part of its picture).

# Night Harvest 1.4 — "Seasons & Seas"

Goal of this update: make the endless world feel alive and real — seasons and weather you can
feel, oceans with islands to sail to, villages to find, animals to raise, fish to catch — and
fix the rough edges players reported.

## Four seasons
- **Spring → Summer → Fall → Winter**, 5 days each (the calendar shows e.g. `SUMMER 3 · SUNNY`).
  A banner announces each new season and the world slowly changes colour.
- **Spring**: fresh green, pink petals in the wind, crops grow **25% faster**, lots of rain.
- **Summer**: warm golden grass, long sunny days and thunderstorms. The **midday sun makes you
  hungry faster** (HOT).
- **Fall**: trees turn amber, gold and red and **drop their leaves**; foggy mornings. Pines stay green.
- **Winter**: **snow covers the ground**, trees are frosted, lakes and rivers ice over, rain turns into
  **snowfall**. Crops grow at half speed and snow doesn't water them. Away from a fire you are
  **COLD**: hunger drops much faster, and in a snowstorm at night the cold slowly hurts — stand near a
  lantern, a furnace or a street lamp, hold a lantern, or go indoors. You can see your breath.
- **Weather affects you**: rain makes the ground muddy (WET, a little slower), storms slow you more,
  deep snow slows you. Your current condition shows under the calendar.
- Fixed: rain streaks were never actually drawn on screen (only the splashes) — rain is now visible.

## Oceans, islands and boats
- The world now has **oceans** (the nearest one is a few hundred steps from Harvest Village — its
  coordinates are on your starting signpost) with **sandy shores** and **islands** out at sea.
- **Rowing Boat** (workbench: 24 wood + 8 fiber): hold it and click on water to put it in, press **E**
  to get in, row with **WASD** (SHIFT rows faster), press **E** next to the shore to get out.
  Zombies can't follow you onto the water. Hit an empty boat twice with an axe to pick it up.
  Boats are saved — even while you are sitting in one.
- The HUD says `ISLAND · FOREST` when you land on an island.

## Fishing
- **Fishing Rod** (workbench: 3 wood + 4 fiber). Face water and click to cast; when the float dips
  and a **!** appears, click again quickly to reel in. Works from the shore and from a boat.
- 9 catches depend on the water: **rivers & lakes** (minnow, perch, trout, catfish, golden carp),
  **snowfield waters** (salmon), **the sea** (sea bass, tuna, pufferfish, driftwood). Catfish and the
  rare golden carp bite at night, rain makes fish hungry. Also old boots and seaweed...
- Grill perch, trout and sea bass or smoke salmon at the furnace. Fish sell at the shop.

## Villages and ruins
- **Other villages** out in the wild, each with its own name, a square with street lamps that light up
  at night, houses with furniture, villagers who talk, and a **trader** you can buy from and sell to.
- **Abandoned villages** ("RUINS OF ..."): crumbling houses with **rare treasure** (gems, gold bars,
  crystal, steel gear, moonflower seeds, golden carp, paintings, a plague idol...).
- **Village design follows the land**: wood or brick on the plains, pine in forests, sandstone in
  the desert, ice brick in the snowfields, mossy stone in the highlands, driftwood on islands.
- Signs show **coordinates**: each village sign tells you where you are and where Harvest Village is;
  your starting sign lists the village square, the sea and the nearest other village.

## Biome blocks (for building and designing)
- New materials you only find in one kind of land: **Sandstone** (desert rocks), **Ice Chunk**
  (snowfield rocks), **Mossy Cobble** (highland rocks), **Driftwood** (island trees, the sea) and
  **Pine Log** (pine trees).
- Craft them at the workbench (BUILD tab) into **walls and floors**: sandstone, ice, mossy stone,
  driftwood and pine — 10 new blocks. You can also take them from village houses.

## Animals
- Wild animals live in their own lands: **rabbits** and **deer** in plains and forests, **ducks** near
  water, **goats** in the highlands, **snow hares** in the snowfields (plus chickens, cows, pigs, sheep).
- Animals can be **hunted** for meat (and leather, wool, feathers); the herd runs away when one is hit.
  Wild herds come back after a few days.
- **Breeding**: feed two animals of the same kind (E) and they make a baby that grows up by the next day.
- Cook meat at the furnace (6 recipes).

## Farming, trees and flowers
- **Fixed: seeds turning into a green rectangle** when planted (the health bar was drawn huge).
- Tilled **soil has no direction** any more — it joins up evenly however you till it.
- **Plant trees**: chopped trees sometimes drop a **sapling** (or pine sapling); plant it and it grows
  into a full tree in two days. Dig a young one back up with E.
- **Flowers** can be picked (E) — in the wild and in Harvest Village — and placed again as decoration.
- **Trees can be chopped from any side.**

## Building, decoration and the workbench
- The **workbench is reorganised**: a **search bar**, tabs (ALL / TOOLS / BUILD / DECOR / DEFENSE /
  ITEMS), a grid of icons with things you can make right now first, and a detail panel showing what
  you need (have / need) with **CRAFT** and **CRAFT x5**.
- **29 decorations**: chairs, tables, bookshelves, cupboards, barrels, benches, street lamps and crate
  lanterns that glow at night, flower boxes and pots, flowers, rugs, and paintings, mirrors, windows
  and curtains for your walls.

## Light and the lantern
- The torch is now a **Lantern** with a real lantern sprite and a **small, warm light at night only**
  (it used to light the whole screen).
- **Harvest Village lights up at night**: house windows glow and the street lamps shine (6 PM–6 AM).

## Controls, settings and the UI
- **ESC → Settings** is a full panel: **AUDIO**, **DISPLAY** (graphics), **CONTROLS** — click any action
  and press a new key to **rebind it** (RESET KEYS restores the defaults) — and **GAMEPLAY**
  (camera zoom, coordinates on the HUD, screen shake, damage numbers).
- **Coordinates** (`X 12  Y -40`) under the biome name, and "You are at..." on the world map.
- **Item names are shown** under every inventory and hotbar slot, and the hovered item is described.
- **Drag and throw**: drag an item out of the inventory or off the hotbar into the world to drop it.
- The **tutorial card is smaller** and out of the way, but still easy to read.

## Fixes
- **No more flash of the old map** when a new game starts — a "Preparing the world..." screen covers
  it until your world is ready.
- **Restart after death no longer crashes**: WAKE UP revives you at your bed or your start point
  (with zombies pushed back) instead of reloading the whole scene.
- **Watch tower**: pressing E over and over no longer keeps zooming the view out.
- **Normal walking speed** (it was too fast) and a proper **sprint**: quicker steps and dust.
- **Zombies** go for both your crops and you; at night they hunt you down even from further away.
- **Item names and icons fixed** (tomato, potato, watermelon, corn, wheat, seeds and more had wrong
  or mismatched pictures).
- The soil tiles no longer pile up a new copy in memory every time you load a game.

## For players with a 1.3 save
- Your farm, house and everything you explored stay exactly as they were. New oceans, islands and
  villages only appear in land you haven't explored yet.
