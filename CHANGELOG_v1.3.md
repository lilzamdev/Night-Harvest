# Night Harvest 1.3 — "The Endless World"

Goal of this update: the world was too small. Now you start somewhere in an endless,
randomly generated world, gather and craft from nothing, build your own house and farm,
and survive the zombies every night — exactly the Night Harvest loop
(farm by day, defend by night), just in a world as big as you can walk.

## Survival & Creative (New Game screen)
- **Survival**: you start with almost nothing. Punch trees for your first wood, craft, build, survive.
  You can only use items you crafted, found, bought or looted.
- **Creative**: press **C** for the catalog of every item. No damage, no hunger, everything breaks
  in one hit, crafting is free. Zombies still come at night but leave you alone.
- Every new world has a **seed** (random or typed in) — the same seed makes the same world.

## The endless world
- Harvest Village (the old map) is now a **village** in the middle of the world; Ben, the shop and
  the quest board are still there. You spawn somewhere around it and can walk in any direction.
- **Biomes**: plains, forests, deserts, snowfields and rocky highlands, with lakes and winding rivers.
- Generated as you walk (16x16-tile chunks), far chunks unload again. Only what you change is saved.
- Trees, rocks with ore, berry bushes, mushrooms, cacti, tall grass (fiber and seeds),
  abandoned cabins and camps with loot, and **cave entrances** into the Hollow Mines.
- The world map (M) shows the land you have explored, the village and the caves you found.

## Crafting from scratch (wood, stone, fiber)
- **C anywhere** — hand crafting: a workbench and torches, enough to get started.
- **Workbench** — tools (wood → stone → copper → iron → gold → crystal), building blocks, furniture,
  fences, torches, traps and defenses, food, boss idols.
- **Furnace** — smelt ore into bars, fire bricks, cook food. **Anvil** — metal tools and weapons.
- Empty hands now **punch**: that is how you get your first wood.

## Build your own house
- Place **wooden, stone and brick walls and floors, doors, fences, chests, beds, workbenches, furnaces,
  anvils and your own watch tower** on a 16 px grid. Aim with the mouse, LEFT CLICK / SPACE; hold the button to build a whole row.
- **Wooden floor on water makes a bridge.** Break your builds with an axe or pickaxe to get them back.
- **Sleep in a bed** to skip the night and set your respawn point.
- Zombies batter your walls, doors and fences at night — stone holds longer than wood.

## Zombies & bosses
- Zombies now come **anywhere in the wild at night**, not only on the farm, and still go for your crops.
  Every night is harder than the last; blood moons are worse.
- Zombies drop **Rotten Flesh** and **Bones**; brutes sometimes drop iron ore.
- **The Rotting Giant** — craft a *Rotten Totem* and use it at night, or it comes for your farm itself
  on blood moons from night 7. Drops the Giant Heart and (first kill) the **Bone Cleaver**.
- **The Plague Mother** — craft a *Plague Idol*. Drops gems, gold and crystal and (first kill) the **Plague Scythe**.
- The Hollow King still waits on mine floor 15.

## Controls (new / changed)
- **C** crafting (catalog in Creative) · **1-8** or mouse wheel: hotbar · **LEFT CLICK / SPACE** use, punch, place blocks
- **RIGHT CLICK** place torch · **E** interact · **F** inventory · **Q** drop · **M** map · **ESC** menu

## Saves
- Old 1.2 saves still load and keep playing in the village. New worlds save their seed, everything you
  built, mined, chopped or looted, chests, bridges and boss kills. Autosave every morning as before.

## Fixes
- Crafting window no longer overlaps or overflows; HUD messages no longer cover the wider hotbar.
- The old map's invisible walls and the cliff line around it are gone (the world continues past them).
- Regression tests updated for the new hotbar, punching and graveyard zombies.
