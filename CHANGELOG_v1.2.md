# Night Harvest 1.2 — "The Hollow Below"

Goal of this update: give every play session a reason to keep going — somewhere
deeper to explore, better gear to make, something to automate and a story to finish.

## A new dimension: The Hollow Mines
- Enter from the **old quarry north-east of the farm** (the dark shaft between the stone slabs).
- **Every floor is randomly generated**: caves, wall torches, crates and minecarts.
- **Break rocks with a pickaxe** for stone and ore. Better veins need better pickaxes:
  stone/copper (any) · iron & gold (Steel+) · crystal & gems (Golden+).
- Depth changes everything: floors 1-4 stone and copper, 5+ iron, 10+ gold, 16+ Hollow crystal and gems.
- **Cave monsters**: slimes, bats, skeletons and purple ghouls, stronger on every floor. They drop slime gel, bones and gold.
- **Ladders** lead down; a **mine lift** on every 5th floor lets you come back to that depth from the entrance.
- **Boss — The Hollow King (floor 15)**: ground slams with a warning ring, a charge attack, summons ghouls.
  Defeating him drops the **Hollow Crown** and makes **every future night 25% calmer**.
- **Old Tomas' journal pages** on floors 3, 7 and 11 tell what happened to him.
- Dark caves lit only by your lantern, glowing crystals and torches; its own music.
- Saving underground is safe: you wake up at the mine entrance.

## Crafting
- **Workbench** beside your farmhouse: barricades, torches, bread, stone walls, sprinklers,
  lantern posts, herbal tonics, scarecrow crossbows, spike traps.
- **Anvil** in Ben's Forge: Copper Sword, Steel Pickaxe/Axe/Sword, Iron Spikes, War Hammer,
  Golden Sword/Pickaxe/Axe, Crystal Sword/Pickaxe and the **Hollow Blade** (boss crown).
- New buildables: **Stone Wall** (tough), **Iron Spikes**, **Lantern Post** (lights the farm, slows zombies),
  **Sprinkler** (waters the 8 tiles around it by itself).

## A living world
- Animated water with ripples and sun glints; wind rustles the trees (stronger in storms).
- **Weather**: sunny, cloudy, rain, thunderstorms, fog. Drifting cloud shadows.
  Rain waters every crop for you. Lightning can strike zombies near you at night.
  Today's weather shows under the clock; Lina knows tomorrow's.
- Butterflies by day, sparrows that fly off when you walk close, fireflies on clear nights,
  fish jumping in the rivers, falling leaves.

## Game feel ("physics")
- Camera shake and a tiny freeze frame on heavy hits, floating damage numbers.
- Items pop out, bounce, and are pulled to you when you walk near (no more pressing E for every log).
- Trees topple over with a thud; rocks crumble; zombies are flung back and splatter.
- Dust when you sprint.

## Missions & story
- **Quest Board** in the village square: three town requests at a time (deliveries, mining depth,
  monster hunts, zombie kills, crafting, building). New ones every morning.
- **Town reputation** unlocks shop stock: Strawberry seeds (1), Sunflower seeds (2), Pumpkin seeds (3),
  War Hammer (4), Moonflower seeds (5).
- **Story — The Hollow Below**: 5 chapters from the quarry to the Hollow Blade, shown on the HUD.

## Farming
- You can now **till any ordinary grass**, not only the old field, and the farm animals moved to
  their own pastures so the field is all yours.
- New crops: **Strawberry** (2-3 per plant), **Sunflower**, **Pumpkin** (sells for 60),
  **Moonflower** (only grows at night, sells for 95).

## Zombies
- New **Bloater** from night 6: slow and swollen, bursts in a toxic cloud that hurts you and your defenses.

## Fixes & under the hood
- Gameplay sound effects now follow the SOUND EFFECTS volume slider (they ignored it before), and more
  sounds can play at once.
- Trees that were parented to other trees no longer vanish when the parent is chopped.
- New systems: `scripts/systems/` (mines, mine_rock, cave_enemy, mine_boss, crafting, missions,
  weather, living_world, juice, farm_layout, items_v12) and `shaders/`.
- Art and sound generators: `tools_dev/gen_v12.py`, `tools_dev/gen_audio_v12.py`.
- Version 1.2.0 (`scripts/update_manager.gd` BASE_VERSION, `project.godot`, `updates/manifest.json`).
