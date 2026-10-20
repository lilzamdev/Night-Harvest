extends Node2D

## Fishing (v1.4). Hold a Fishing Rod, face water (a river, lake, the village pond or
## the sea) and LEFT CLICK / SPACE to cast. Wait for the bite - the float dips and a
## "!" pops up - then click again quickly to reel the fish in. Click too early and you
## just pull the line back. Works from a boat too.
##
## What bites depends on the water: fresh (rivers, lakes), cold (snow biome) or the sea,
## and on the hour: catfish and the rare golden carp like the night. Rain makes fish hungry.

const ItemDB = preload("res://scripts/item_database.gd")

const LOOT := {
	"fresh": [["minnow", 30], ["perch", 28], ["trout", 18], ["catfish", 6], ["golden_carp", 2], ["old_boot", 6], ["seaweed", 4]],
	"cold": [["salmon", 30], ["trout", 25], ["minnow", 14], ["golden_carp", 2], ["old_boot", 5]],
	"sea": [["sea_bass", 30], ["tuna", 16], ["pufferfish", 8], ["seaweed", 14], ["driftwood", 8], ["old_boot", 5], ["golden_carp", 1]],
}
const BITE_WINDOW := 1.15

var state := "idle"   # idle, cast, wait, bite
var _player: Node2D
var _bobber: Node2D
var _line: Line2D
var _spot := Vector2.ZERO
var _cast_from := Vector2.ZERO
var _t := 0.0
var _water := "fresh"
var _last_use_ms := 0


func _ready() -> void:
	add_to_group("fishing")
	global_position = Vector2.ZERO
	z_index = 4


func is_fishing() -> bool:
	return state != "idle"


## Called by the player when using the rod.
func use_rod(p: Node2D) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_use_ms < 300:
		return
	_last_use_ms = now
	_player = p
	match state:
		"idle":
			_try_cast(p)
		"wait":
			_msg("Too soon! Wait for the float to dip.")
			_stop()
		"bite":
			_catch()


# --- Where is the water? ----------------------------------------------------

func water_kind_at(pos: Vector2) -> String:
	var wg := get_tree().get_first_node_in_group("worldgen")
	var bm := get_tree().get_first_node_in_group("build_manager")
	if bm == null:
		return ""
	var c: Vector2i = bm.BlockScript.cell_of(pos)
	if bm.has_method("_village_water") and bm._village_water(c):
		return "fresh"
	if wg and wg.has_method("ground_is_water") and wg.ground_is_water(c) and not (bm.floor_at(c) != null):
		if wg.has_method("is_ocean") and wg.is_ocean(c):
			return "sea"
		if wg.has_method("biome_at") and int(wg.biome_at(c)) == 3:   # snowfields
			return "cold"
		return "fresh"
	return ""


func _find_spot(p: Node2D) -> Vector2:
	var m: Vector2 = p.get_global_mouse_position()
	if m.distance_to(p.global_position) <= 80.0 and water_kind_at(m) != "":
		return m
	var dir: Vector2 = p.get("last_direction") if p.get("last_direction") != null else Vector2.DOWN
	for d in [28.0, 40.0, 52.0, 64.0, 20.0]:
		var pt: Vector2 = p.global_position + dir * d + Vector2(0, -2)
		if water_kind_at(pt) != "":
			return pt
	return Vector2.INF


func _rod_tip(p: Node2D) -> Vector2:
	var dir: Vector2 = p.get("last_direction") if p.get("last_direction") != null else Vector2.DOWN
	return p.global_position + dir * 10.0 + Vector2(0, -16)


# --- Casting ----------------------------------------------------------------

func _try_cast(p: Node2D) -> void:
	var spot := _find_spot(p)
	if spot == Vector2.INF:
		_msg("Face a river, a lake or the sea to cast your line.")
		return
	_spot = spot
	_water = water_kind_at(spot)
	_cast_from = p.global_position
	state = "cast"
	_make_bobber()
	var from := _rod_tip(p)
	_bobber.global_position = from
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(_bobber):
			var pt := from.lerp(_spot, k)
			pt.y -= sin(k * PI) * 18.0
			_bobber.global_position = pt, 0.0, 1.0, 0.45)
	tw.tween_callback(_landed)
	_sfx("sword_swing", -10.0)


func _landed() -> void:
	if state != "cast":
		return
	state = "wait"
	_t = randf_range(2.5, 7.5)
	var weather := get_tree().get_first_node_in_group("weather")
	if weather and (str(weather.get("kind")).contains("rain") or str(weather.get("kind")).contains("storm")):
		_t *= 0.7
	_splash()


func _make_bobber() -> void:
	_bobber = Node2D.new()
	add_child(_bobber)
	var r := Polygon2D.new()
	r.polygon = PackedVector2Array([Vector2(-2, -3), Vector2(2, -3), Vector2(2, 0), Vector2(-2, 0)])
	r.color = Color("E83B3B")
	_bobber.add_child(r)
	var w := Polygon2D.new()
	w.polygon = PackedVector2Array([Vector2(-2, 0), Vector2(2, 0), Vector2(2, 2), Vector2(-2, 2)])
	w.color = Color("F3F0E6")
	_bobber.add_child(w)
	_line = Line2D.new()
	_line.width = 1.0
	_line.default_color = Color(0.92, 0.92, 0.9, 0.8)
	add_child(_line)


func _process(delta: float) -> void:
	if state == "idle":
		return
	var p := _player
	if p == null or not is_instance_valid(p) or not is_instance_valid(_bobber):
		_stop()
		return
	var item: Resource = p.get("current_held_item")
	var moved: bool = p.global_position.distance_to(_cast_from) > 10.0
	if moved or item == null or str(item.get("item_id")) != "fishing_rod" or (p.has_method("is_ui_blocking") and p.is_ui_blocking()):
		_stop()
		return
	_line.points = PackedVector2Array([_rod_tip(p), _bobber.global_position + Vector2(0, -2)])
	match state:
		"wait":
			_t -= delta
			_bobber.global_position = _spot + Vector2(0, sin(Time.get_ticks_msec() * 0.004) * 0.8)
			if _t <= 0.0:
				state = "bite"
				_t = BITE_WINDOW
				_bobber.global_position = _spot + Vector2(0, 3)
				_splash()
				var juice := get_tree().get_first_node_in_group("juice")
				if juice:
					juice.popup_text(_spot + Vector2(0, -14), "!", Color("FFDB80"), true)
				_sfx("splash", -4.0)
		"bite":
			_t -= delta
			_bobber.global_position = _spot + Vector2(0, 2.0 + sin(Time.get_ticks_msec() * 0.03) * 1.5)
			if _t <= 0.0:
				_msg("It got away...")
				state = "wait"
				_t = randf_range(2.0, 6.0)


func _catch() -> void:
	var id := roll(_water)
	var it = ItemDB.get_item(id)
	_stop()
	if it == null:
		return
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	var left: int = inv.add_item(it, 1) if inv else 1
	if left > 0 and _player and _player.has_method("throw_stack"):
		_player.throw_stack(it, left)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice and _player:
		juice.popup_text(_player.global_position + Vector2(0, -28), "+1 " + str(it.display_name).to_upper(), Color("FFDB80"))
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats and stats.has_method("add_xp") and not id in ["old_boot", "seaweed"]:
		stats.add_xp(6 if id != "golden_carp" else 40)
	_sfx("crop_harvest", -6.0)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("fish_caught", {"id": id})
			break


## Picks what bites in this kind of water right now.
func roll(water: String) -> String:
	var table: Array = (LOOT.get(water, LOOT["fresh"]) as Array).duplicate(true)
	var clock := get_tree().get_first_node_in_group("game_clock")
	var night: bool = clock != null and clock.has_method("is_night") and clock.is_night()
	var total := 0
	for e in table:
		if night and e[0] in ["catfish", "golden_carp"]:
			e[1] = int(e[1]) * 3
		total += int(e[1])
	var r := randi() % maxi(total, 1)
	for e in table:
		r -= int(e[1])
		if r < 0:
			return str(e[0])
	return "minnow"


func _stop() -> void:
	state = "idle"
	if is_instance_valid(_bobber):
		_bobber.queue_free()
	if is_instance_valid(_line):
		_line.queue_free()
	_bobber = null
	_line = null


func _splash() -> void:
	var lw := get_tree().get_first_node_in_group("living_world")
	if lw and lw.has_method("play_fx"):
		lw.play_fx(_spot, "splash", 6, 6, 3, 12.0)
	else:
		var juice := get_tree().get_first_node_in_group("juice")
		if juice:
			juice.burst(_spot, Color(0.7, 0.85, 1.0, 0.8), 5, 30.0)


func _msg(t: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message(t, 2.0)


func _sfx(n: String, db: float) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play(n, db)
