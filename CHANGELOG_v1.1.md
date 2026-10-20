# Night Harvest 1.1 — "The Hollow Wakes"

Built against the project proposal (farming + survival horror, shop, farm defense,
progression) to make a session last well past an hour.

## New Game
- **Choose your farmer** (New Game step 1): KEN (defenses 15% cheaper), MIRA (crops
  grow 25% faster) or RICO (+25 max HP, +20% weapon damage). Animated previews.
  The chosen farmer appears in game, on the HUD portrait, on save slots and on the title screen.
- New farms start with 30 gold.

## Settings › Updates
- Check, download and install updates in-game, then restart. Saves and settings are kept.
  Auto-check on launch, update notes, rollback ("Remove installed update"). See UPDATES.md.

## Tutorial
- Offered on every new farm (START TUTORIAL / SKIP), skippable at any time.
  9 steps that complete when you actually do them: move, till, plant, water, chop,
  meet the village, trade, build a defense, survive the night. +50 gold at the end.

## A lived-in world
- **Enterable houses** with furnished interiors and fade transitions: your farmhouse
  (your bed is now inside), the barn (storage chest), Rosa's Goods, Ben's Forge,
  Mayor Pedro's house, Lina's house, the guest house and Old Tomas' abandoned house
  (with a loot chest). Some doors are locked.
- **Villagers** with day/night schedules and dialogue: Rosa (seeds & food), Ben
  (defenses & weapons), Mayor Pedro (lore, Blood Moon countdown), Lina (tips) and
  Limuel, the developer, in the guest house. They go home at night — knock to shop.
- **Rosa's market stall** in the village by day.
- **Old Hollow Cemetery**: a fenced graveyard in the north-west field. At night the dead
  climb out of its open graves, so zombies now come from two directions.
- Floating "[E] ..." prompts for everything you can use. Warm lights indoors.

## Economy & defense (PDF: Shop System, Farm Defense System)
- Buy and sell. Slow crops are worth more (corn and watermelon now take longer to grow).
- Placeable defenses (hold in hotbar, aim, LEFT CLICK; green/red preview):
  **Wooden Barricade** (zombies must chew through), **Spike Trap** (hurts + slows),
  **Scarecrow Crossbow** (auto-shoots zombies). Zombies attack turrets and barricades.
- New items: Fresh Bread, Herbal Tonic (+40 HP), Steel Sword, **Steel Axe** (fells trees in 2 swings).
- Ben also sells the basic tools (hoe, axe, pickaxe, watering can), so a lost tool can be replaced.
- Zombies drop gold coins.

## Progression (PDF: "the game becomes more difficult as the days progress")
- Every night is harder: bigger, faster waves and tougher zombies.
- **Runners** from night 3 (fast), **Brutes** from night 5 (huge HP, smash defenses).
- **Blood Moon** every 7th night: red sky, bigger waves, double rewards.
- Night banner at dusk and a **dawn report** (kills, gold, crops/defenses lost, survival bonus).
- "NIGHTS SURVIVED" on the HUD calendar.

## Audio
- Background music: title lullaby, day theme, night theme, Blood Moon theme (crossfades).
- Sound effects for sword swings, hits, chopping, planting, harvesting, eating, coins,
  building, crossbows, zombie groans and deaths, footsteps.

## Fixes
- Shop rows no longer overlap long descriptions with prices.
- Removed a "Lambda capture was freed" error that appeared at nightfall (HUD zombie banner).

## Under the hood
- New systems live in `scripts/systems/` and build their nodes at runtime, so
  `Scenes/game.tscn` is unchanged. Save files gained an `ext` section for the new
  systems; old saves still load (the tutorial is skipped for them).
- Asset generators in `tools_dev/` (characters, props, audio) — rerun to tweak art/sound.
