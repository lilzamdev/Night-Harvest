extends StaticBody2D

## Things to find out in the wild (v1.3):
##   berry_bush  pick berries (E); they grow back after a few days
##   crate       an abandoned supply crate with random loot (once)
##   cave        a cave mouth: a way down into the Hollow Mines

const ItemDB = preload("res://scripts/item_database.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const V13 := "res://Assets/Generated/v13/"
const V12 := "res://Assets/Generated/v12/"
const REGROW_DAYS := 3

var kind := "berry_bush"
var interact_range := 22.0
## berry_bush
var picked_day := -100
var on_picked: Callable
## sign
var sign_text := ""
var display_name := "Old Signpost"
## crate
var looted := false
var loot_tier := 0
var loot_seed := 0
var on_looted: Callable

var _sprite: Sprite2D

## [item, min, max, chance] per tier (0 near the village, 2 far away)
const LOOT := [
	[["wood_log", 3, 6, 1.0], ["stone_rock", 2, 5, 0.8], ["carrot_seed", 2, 4, 0.5], ["wheat_seed", 2, 4, 0.5],
		["potato_seed", 1, 3, 0.4], ["bread", 1, 2, 0.5], ["torch", 2, 4, 0.6], ["copper_ore", 1, 3, 0.4],
		["berries", 2, 4, 0.5], ["stone_pickaxe", 1, 1, 0.12], ["stone_sword", 1, 1, 0.1]],
	[["wood_log", 3, 6, 0.8], ["iron_ore", 2, 4, 0.6], ["copper_bar", 1, 3, 0.5], ["herbal_tonic", 1, 2, 0.4],
		["bone", 1, 3, 0.5], ["strawberry_seed", 2, 4, 0.4], ["tomato_seed", 2, 3, 0.4], ["bread", 1, 3, 0.5],
		["copper_pickaxe", 1, 1, 0.1], ["copper_sword", 1, 1, 0.1], ["iron_bar", 1, 2, 0.3], ["brick", 2, 6, 0.3]],
	[["gold_bar", 1, 3, 0.5], ["iron_bar", 2, 4, 0.6], ["gem", 1, 2, 0.35], ["crystal_shard", 1, 3, 0.35],
		["pumpkin_seed", 2, 4, 0.4], ["moonflower_seed", 1, 3, 0.3], ["herbal_tonic", 2, 3, 0.5],
		["steel_pickaxe", 1, 1, 0.12], ["steel_sword", 1, 1, 0.12], ["rotten_totem", 1, 1, 0.08]],
]


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("forage")
	collision_mask = 0
	collision_layer = 1
	_sprite = Sprite2D.new()
	add_child(_sprite)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	match kind:
		"berry_bush":
			rs.size = Vector2(12, 6)
			cs.position = Vector2(0, -3)
			_sprite.offset = Vector2(0, -8)
			_refresh_bush()
		"crate":
			rs.size = Vector2(14, 8)
			cs.position = Vector2(0, -4)
			_sprite.texture = load(V12 + "crate.png")
			_sprite.offset = Vector2(0, -8)
			if looted:
				_sprite.modulate = Color(0.62, 0.58, 0.55)
		"sign":
			rs.size = Vector2(4, 4)
			cs.position = Vector2(0, -2)
			_sprite.texture = load(V13 + "signpost.png")
			_sprite.offset = Vector2(0, -8)
		"cave":
			interact_range = 26.0
			_sprite.texture = load(V13 + "cave_mouth.png")
			_sprite.offset = Vector2(0, -12)
			# Solid rock on both sides; the dark mouth in the middle is where you go in.
			rs.size = Vector2(8, 10)
			cs.position = Vector2(-11, -6)
			var cs2 := CollisionShape2D.new()
			var rs2 := RectangleShape2D.new()
			rs2.size = Vector2(8, 10)
			cs2.shape = rs2
			cs2.position = Vector2(11, -6)
			add_child(cs2)
			var top := CollisionShape2D.new()
			var rt := RectangleShape2D.new()
			rt.size = Vector2(24, 6)
			top.shape = rt
			top.position = Vector2(0, -16)
			add_child(top)
			var l := PointLight2D.new()
			var g := Gradient.new()
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.width = 64
			gt.height = 64
			gt.fill = GradientTexture2D.FILL_RADIAL
			gt.fill_from = Vector2(0.5, 0.5)
			gt.fill_to = Vector2(1.0, 0.5)
			l.texture = gt
			l.texture_scale = 0.8
			l.color = Color(0.6, 0.45, 1.0)
			l.energy = 0.45
			l.position = Vector2(0, -8)
			add_child(l)
	cs.shape = rs
	add_child(cs)


func portrait() -> Texture2D:
	return _sprite.texture if _sprite else null


func _day() -> int:
	var clock := get_tree().get_first_node_in_group("game_clock")
	return int(clock.current_day) if clock else 1


func is_ripe() -> bool:
	return _day() - picked_day >= REGROW_DAYS


func _refresh_bush() -> void:
	_sprite.texture = load(V13 + ("berry_bush.png" if is_ripe() else "berry_bush_picked.png"))


func can_interact(_p: Node2D) -> bool:
	match kind:
		"berry_bush":
			return is_ripe()
		"crate":
			return not looted
	return true


func get_prompt() -> String:
	match kind:
		"berry_bush":
			return "PICK BERRIES"
		"crate":
			return "SEARCH CRATE"
		"cave":
			return "ENTER CAVE"
		"sign":
			return "READ SIGN"
	return ""


func interact(p: Node2D) -> void:
	match kind:
		"berry_bush":
			if not is_ripe():
				return
			picked_day = _day()
			_give(ItemDB.get_item("berries"), randi_range(2, 4))
			if randf() < 0.5:
				_give(ItemDB.get_item("fiber"), 1)
			_refresh_bush()
			_sfx("crop_harvest", -6.0)
			if on_picked.is_valid():
				on_picked.call(picked_day)
		"crate":
			if looted:
				return
			looted = true
			_roll_loot()
			_sprite.modulate = Color(0.62, 0.58, 0.55)
			_sfx("craft", -6.0)
			if on_looted.is_valid():
				on_looted.call()
			_event("crate_looted", {})
		"sign":
			var ui := get_tree().get_first_node_in_group("dialogue_ui")
			if ui and ui.has_method("open_dialogue"):
				ui.open_dialogue(self, sign_text, [{"text": "OK", "action": "bye"}], func(_a: String) -> void: ui.close_dialogue())
			else:
				var hud := get_tree().get_first_node_in_group("hud_ui")
				if hud:
					hud.show_hud_message(sign_text.replace("\n", " "), 6.0)
		"cave":
			var mines := get_tree().get_first_node_in_group("mines")
			if mines and mines.has_method("on_entrance_used"):
				mines.set("surface_return", global_position + Vector2(0, 14))
				mines.on_entrance_used(p)


func _roll_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = loot_seed
	var table: Array = LOOT[clampi(loot_tier, 0, 2)]
	var got := 0
	var names: Array = []
	for e in table:
		if rng.randf() > float(e[3]):
			continue
		var it = ItemDB.get_item(str(e[0]))
		if it == null:
			continue
		var n := rng.randi_range(int(e[1]), int(e[2]))
		_give(it, n)
		names.append("%d %s" % [n, str(it.display_name).to_upper()])
		got += 1
		if got >= 4:
			break
	if got == 0:
		var w = ItemDB.get_item("wood_log")
		_give(w, 3)
		names.append("3 WOOD")
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.popup_text(global_position + Vector2(0, -22), "FOUND: " + ", ".join(names.slice(0, 2)), Color("FFDB80"), true)


func _give(item: Resource, n: int) -> void:
	if item == null or n <= 0:
		return
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	var left := n
	if inv:
		left = inv.add_item(item, n)
	if left > 0:
		var w := WorldItemScene.instantiate()
		get_parent().add_child(w)
		w.global_position = global_position + Vector2(randf_range(-8, 8), 10)
		w.call("set_item", item, left)


func _process(_delta: float) -> void:
	if kind == "berry_bush" and Engine.get_process_frames() % 120 == 0:
		_refresh_bush()


func _event(t: String, data: Dictionary) -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit(t, data)
			break


func _sfx(n: String, db: float) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play(n, db)
