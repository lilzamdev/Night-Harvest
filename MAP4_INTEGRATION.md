# Map4 integration — 2026-09-16

Map4's environment is integrated into the existing `Scenes/game.tscn`. Its original UID remains the project main scene. No gameplay scripts, autoloads, project settings, formulas, or balance values were changed for this integration.

## Imported environment

- Map4's existing TileMap and nested TerrainLayer, ThingsLayer, and ThingsOverlayLayer; all four serialized tile layers match map4 exactly.
- Ground, grass, paths, farmland, rivers, bridges, houses, village, barn, graveyard, fences, trees, rocks, and decorations, with their required embedded TileSets.
- Map-related sprite/tree placements, reusing Night Harvest's existing interactive tree scene and scripts.
- Two required textures, copied into `Assets/Vectoriath Asset/16x16/Tilesets (Compact)/`: `vectoraith_tileset_farmingsims_details.png` and `vectoraith_tileset_farmingsims_buildings.png`. Other referenced map textures already matched the ZIP and were reused.

Map4's player, camera, HUD, gameplay scripts, managers, inventory, project settings, and hidden-animal/HUD overrides were intentionally excluded. An unused autumn atlas and an unused empty texture source were excluded. Machine-specific `.ctex` references were replaced with existing source textures.

## Files changed by this integration

| File | Change |
| --- | --- |
| `Scenes/game.tscn` | Map environment/resources, static collisions, safe player/object placements, camera boundary overrides |
| `Scenes/SpawnManager.tscn` | Three animal spawn marker positions only |
| `Assets/Vectoriath Asset/16x16/Tilesets (Compact)/vectoraith_tileset_farmingsims_details.png` | Required map4 texture added |
| `Assets/Vectoriath Asset/16x16/Tilesets (Compact)/vectoraith_tileset_farmingsims_buildings.png` | Required map4 texture added |
| Both new textures' `.png.import` files | Godot-generated texture import settings |
| `MAP4_INTEGRATION.md` | This report |
| `backups/map4-before-2026-09-16/` | Original scenes and verification logs |

Earlier local HUD, sleeping, and other gameplay edits remain in the working folder; they were not replaced by map4. Development probes and route data are under the ignored `.godot/` folder and are not required to play the game.

## Scene and placement details

- All 37 original non-map root/gameplay/UI nodes were retained. Existing node paths and gameplay resource references remain intact. No second player, HUD, camera, farming system, or manager was added.
- Existing Ken (`CharacterBody2D3`) spawns at local **(-17, 0)**, world **(4, 23)**, on the central farm path.
- Existing camera still belongs to Ken. Its per-instance limits now cover map4: left **-1428**, top **-417**, right **940**, bottom **623**. Automatic bounds detection was disabled on this instance because it ignores the map's parent offsets.
- Existing bed moved to local **(26, -100)**, world **(47, -77)**, beside the farmhouse approach. Wake point is world **(73, -73)** and is clear. The corrected vertical sleep pose and the original sleep/wake marker offsets remain intact.
- Two pigs, one chicken, the stool, and three torches were moved to nearby clear positions. The chest remains at its original position.
- Animal spawn markers 02/04/05 moved to local **(28, -8)**, **(75, 63)**, and **(86, 89)** in `SpawnManager.tscn`. The manager's script, timers, population rules, zombie marker, and runtime creation order are unchanged.

## Collision and farming compatibility

Map4 did not provide TileSet physics polygons. Added one static `TileMap/MapCollisions` body on the existing world layer **1**, mask **0**, with 1,022 merged rectangle shapes sharing 108 shape resources. These block water, solid structures, fences, rocks, stumps, decorative tree trunks, and the outside boundary. Bridge decks remain passable; foliage and flowers do not block movement. Existing harvestable trees keep their own removable trunk collisions.

No global collision layers or masks changed. Ken physically traversed collision-tested routes from the spawn to the farmhouse, barn, village, graveyard, and eastern field. Existing and spawned animals start outside the new map collisions. These checks cover representative routes and obstacle types, not every individual map pixel.

Farming still uses the existing nested TerrainLayer/ThingsLayer/ThingsOverlayLayer with source IDs **9 / 4 / 1**. No fallback soil layer or second farming system is created. The existing hoe → plant → water → grow through GameClock → harvest → inventory/EXP sequence passed on map4 soil.

## Verification results

Ran Godot **4.7.1**, loaded the actual `game.tscn` in a rendered gameplay test at **1280×900**, and separately launched the project's configured main scene headlessly.

| Check | Result |
| --- | --- |
| Map4 visible, resources present, original main scene preserved | Passed; four map layers match source data |
| Single Ken, original camera and bounds | Passed |
| Movement through five map regions, water/solid collision checks | Passed using the actual Ken physics body; wandering animals temporarily excluded from route testing |
| Existing/spawned animal placement | Passed |
| Hoe, plant, water, timed growth, harvest, inventory and EXP | Passed |
| Inventory button, hotbar assignment, eating animation and consumption | Passed |
| Hunger restoration and EXP/level-up behavior | Passed |
| Night transition, original 10-zombie wave, AI target and sword damage | Passed |
| Zombie attack damage to Ken | Passed |
| G sleep confirmation, vertical bed pose, safe wake, next-day 06:00 | Passed |
| Day/night lighting connection and overnight zombie clearing | Passed |
| Active daily quests, HUD and minimap target | Passed |
| HUD regression: feedback and stable layouts at 800×600, 1280×720, 1920×1080 | Passed, 0 failures; resolution checks were headless layout assertions |
| Existing 12-test farming acceptance suite | Passed |
| Static node/resource audit and whitespace check of the two modified scenes | Passed |

The rendered integration test completed with **0 failures**. No missing-resource errors or duplicate gameplay systems were found. Chest and other existing interactable scenes/scripts were preserved; a complete chest transfer cycle was not separately exercised in this map test.

## Warnings and limits

- The existing HUD emits a Control anchor/size warning from `scripts/hud.gd:73`. Layout regression checks pass. This map-only change leaves that HUD code untouched.
- Sandboxed headless runs report inability to read the Windows root certificate store. The rendered run does not report that error. One diagnostic launch without an explicit writable log path also hit a Godot log-file access crash; subsequent launches used an explicit workspace log path and completed.
- The map still contains the source's legacy TileMap node. It was retained to preserve the map data and existing farming paths.
- Repository-wide whitespace checks also report pre-existing gameplay-script whitespace outside this integration. The modified map/spawn scene checks pass.
- These are bounded runtime and regression checks, not an exhaustive long-duration playthrough. No new gameplay features or subsequent phase was implemented.

## Backup and evidence

Original working scenes were preserved before editing:

- `backups/map4-before-2026-09-16/game.tscn.bak`
- `backups/map4-before-2026-09-16/SpawnManager.tscn.bak`

Final gameplay, farming, HUD, and main-scene logs are saved beside those backups. Preview screenshots are saved in the local Codex visualization folder, outside the game's asset tree.
