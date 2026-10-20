extends Node

## GameExtras — boots the v1.1 systems inside Scenes/game.tscn.
##
## Created by game.gd after the core systems (stats, clock, farming, spawner).
## Everything here builds its own nodes at runtime, so game.tscn stays untouched:
##   - applies the chosen character (sprite sheet, HUD portrait, perk)
##   - World: house interiors, doors, villagers, market stall
##   - Economy: shop + selling, coins dropped by zombies
##   - Defenses: placeable barricades / spike traps / scarecrow turrets
##   - NightDirector: harder nights, zombie variants, blood moons, dawn report
##   - Tutorial for new farmers (skippable)
##   - Interaction prompts and dialogue

const Characters = preload("res://scripts/systems/characters.gd")
const WorldScript = preload("res://scripts/systems/world.gd")
const DefenseManagerScript = preload("res://scripts/systems/defense_manager.gd")
const NightDirectorScript = preload("res://scripts/systems/night_director.gd")
const DialogueUIScript = preload("res://scripts/systems/dialogue_ui.gd")
const ShopUIScript = preload("res://scripts/systems/shop_ui.gd")
const PromptUIScript = preload("res://scripts/systems/prompt_ui.gd")
const TutorialScript = preload("res://scripts/systems/tutorial.gd")
const LivingWorldScript = preload("res://scripts/systems/living_world.gd")
const WeatherScript = preload("res://scripts/systems/weather.gd")
const JuiceScript = preload("res://scripts/systems/juice.gd")
const MinesScript = preload("res://scripts/systems/mines.gd")
const CraftingScript = preload("res://scripts/systems/crafting.gd")
const MissionsScript = preload("res://scripts/systems/missions.gd")
const FarmLayoutScript = preload("res://scripts/systems/farm_layout.gd")
const GameModeScript = preload("res://scripts/systems/game_mode.gd")
const WorldGenScript = preload("res://scripts/systems/worldgen.gd")
const BuildManagerScript = preload("res://scripts/systems/build_manager.gd")
const BossDirectorScript = preload("res://scripts/systems/boss_director.gd")
const VillageLightsScript = preload("res://scripts/systems/village_lights.gd")
const FishingScript = preload("res://scripts/systems/fishing.gd")
const SeasonsScript = preload("res://scripts/systems/seasons.gd")

var game: Node2D
var player: CharacterBody2D
var character_id: String = "ken"


func _ready() -> void:
	add_to_group("game_extras")
	game = get_parent() as Node2D
	player = game.get_node_or_null("CharacterBody2D3") as CharacterBody2D
	if has_node("/root/SaveManager"):
		character_id = SaveManager.character_id()
	_apply_character_look()

	var ui: CanvasLayer = game.get_node_or_null("UI")
	if ui:
		ui.layer = 10  # above the v1.2 glow (2) and weather (3) layers

	var juice: Node2D = JuiceScript.new()
	juice.name = "Juice"
	game.add_child(juice)

	var living: Node2D = LivingWorldScript.new()
	living.name = "LivingWorld"
	game.add_child(living)

	# v1.3: Survival / Creative, the endless world, building and surface bosses
	var mode: Node = GameModeScript.new()
	mode.name = "GameMode"
	game.add_child(mode)

	var worldgen: Node2D = WorldGenScript.new()
	worldgen.name = "WorldGen"
	game.add_child(worldgen)

	var builds: Node2D = BuildManagerScript.new()
	builds.name = "BuildManager"
	game.add_child(builds)

	var bosses: Node2D = BossDirectorScript.new()
	bosses.name = "BossDirector"
	game.add_child(bosses)

	var fishing: Node2D = FishingScript.new()
	fishing.name = "Fishing"
	game.add_child(fishing)

	var vlights: Node2D = VillageLightsScript.new()
	vlights.name = "VillageLights"
	game.add_child(vlights)

	var seasons: Node = SeasonsScript.new()
	seasons.name = "Seasons"
	game.add_child(seasons)

	var weather: Node = WeatherScript.new()
	weather.name = "Weather"
	game.add_child(weather)

	var layout: Node = FarmLayoutScript.new()
	layout.name = "FarmLayout"
	game.add_child(layout)

	var mines: Node2D = MinesScript.new()
	mines.name = "Mines"
	game.add_child(mines)

	var world: Node2D = WorldScript.new()
	world.name = "World"
	game.add_child(world)

	var defenses: Node2D = DefenseManagerScript.new()
	defenses.name = "DefenseManager"
	game.add_child(defenses)

	var director: Node = NightDirectorScript.new()
	director.name = "NightDirector"
	game.add_child(director)

	var dialogue: CanvasLayer = DialogueUIScript.new()
	dialogue.name = "DialogueUI"
	game.add_child(dialogue)

	var crafting: CanvasLayer = CraftingScript.new()
	crafting.name = "CraftingUI"
	game.add_child(crafting)

	var missions: CanvasLayer = MissionsScript.new()
	missions.name = "Missions"
	game.add_child(missions)

	var shop: CanvasLayer = ShopUIScript.new()
	shop.name = "ShopUI"
	game.add_child(shop)

	var prompt: CanvasLayer = PromptUIScript.new()
	prompt.name = "PromptUI"
	game.add_child(prompt)

	var tutorial: CanvasLayer = TutorialScript.new()
	tutorial.name = "Tutorial"
	game.add_child(tutorial)

	if has_node("/root/SaveManager"):
		SaveManager.session_started.connect(_on_session_started)
	_add_nights_label(director)
	if has_node("/root/Music"):
		get_node("/root/Music").play_game_music()
	_apply_perks_early()


## "NIGHTS SURVIVED n" under the day/time on the HUD calendar.
func _add_nights_label(director: Node) -> void:
	var box := game.get_node_or_null("UI/HUD/TopCenter/Calendar/Margin/VBox") as VBoxContainer
	if not box:
		return
	var l := Label.new()
	l.text = "NIGHTS SURVIVED 0"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(0.92, 0.55, 0.5))
	box.add_child(l)
	director.nights_changed.connect(func(n: int) -> void: l.text = "NIGHTS SURVIVED %d" % n)


func _apply_character_look() -> void:
	var c := Characters.get_character(character_id)
	var sheet: Texture2D = load(c["sheet"])
	if player:
		var spr: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
		if spr and spr.sprite_frames and c["id"] != "ken":
			var anim := spr.animation
			spr.sprite_frames = Characters.retarget_frames(spr.sprite_frames, sheet)
			spr.play(anim)
	var portrait := game.find_child("PortraitTexture", true, false) as TextureRect
	if portrait:
		portrait.texture = Characters.portrait(character_id)


func _apply_perks_early() -> void:
	match Characters.perk_of(character_id):
		"brawler":
			if player:
				player.set("damage_multiplier", 1.2)
		"growth":
			var fm := game.get_node_or_null("FarmingManager")
			if fm:
				fm.set("growth_multiplier", 1.25)


func _on_session_started(root: Node, _is_new: bool) -> void:
	if root != game:
		return
	if _is_new:
		var st := game.get_node_or_null("PlayerStats")
		if st:
			st.add_gold(30)  # Mayor Pedro's welcome gift
	if Characters.perk_of(character_id) == "brawler":
		var stats := game.get_node_or_null("PlayerStats")
		if stats and int(stats.max_health) < 125:
			var was_full: bool = stats.current_health >= stats.max_health
			stats.max_health = 125
			if was_full or _is_new:
				stats.current_health = 125
			stats.health_changed.emit(stats.current_health, stats.max_health)


## Discount multiplier for defense items in the shop (Ken's perk).
func defense_price_mult() -> float:
	return 0.85 if Characters.perk_of(character_id) == "handyman" else 1.0


func hud() -> Control:
	return game.get_node_or_null("UI/HUD") as Control


func toast(text: String, duration: float = 2.4) -> void:
	var h := hud()
	if h and h.has_method("show_hud_message"):
		h.show_hud_message(text, duration)
