extends Node

## NightDirector — makes every night harder than the last (PDF: "Progression System").
##
##  * Wave size and spawn rate grow with each night survived.
##  * New zombie types join: RUNNERS from night 3 (fast, fragile), BRUTES from night 5
##    (slow, huge HP, smash defenses).
##  * Every 7th night is a BLOOD MOON: red sky, bigger and faster waves, double rewards.
##  * Zombies drop gold coins. Dawn shows a report with a survival bonus.

const UIKit = preload("res://scripts/systems/ui_kit.gd")
const CoinScript = preload("res://scripts/systems/coin.gd")

const BLOOD_MOON_EVERY := 7

signal nights_changed(survived: int)

var save_key := "night_director"
var nights_survived: int = 0
var best_night: int = 0
var tonight: int = 0          ## night number currently running (0 = day)
var blood_moon: bool = false

var _clock: Node
var _spawner: Node
var _base_wave: int = -1
var _base_interval: float = 60.0
var _stats := {}
var _report_layer: CanvasLayer
var _game: Node


func _ready() -> void:
	add_to_group("night_director")
	add_to_group("save_extension")
	_game = get_parent()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_bind")
	if has_node("/root/SaveManager"):
		SaveManager.session_started.connect(_on_session_started)


func _bind() -> void:
	_clock = get_tree().get_first_node_in_group("game_clock")
	_spawner = get_tree().get_first_node_in_group("spawn_manager")
	if _clock:
		_clock.night_started.connect(_on_night_started)
		_clock.night_ended.connect(_on_night_ended)
		_clock.time_updated.connect(_on_time)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.connect(_on_event)
			break
	_prepare_wave(night_number())


## Sets the spawner's wave size / rate for night n (called before the night begins,
## because the spawner releases its first wave the moment night falls).
func _prepare_wave(n: int) -> void:
	if not _spawner:
		return
	if _base_wave < 0:
		_base_wave = int(_spawner.zombies_per_wave)
		_base_interval = float(_spawner.spawn_interval)
	var bm := is_blood_moon_night(n)
	var scale := 1.0 + 0.12 * float(n - 1)
	if bm:
		scale *= 1.4
	_spawner.zombies_per_wave = clampi(roundi(_base_wave * minf(scale, 2.2)), 1, 24)
	_spawner.spawn_interval = maxf(35.0, _base_interval - 3.0 * float(n - 1) - (10.0 if bm else 0.0))
	var t: Timer = _spawner.get("zombie_spawn_timer")
	if t:
		t.wait_time = _spawner.spawn_interval


func _on_session_started(root: Node, _is_new: bool) -> void:
	if root != _game:
		return
	if nights_survived == 0 and has_node("/root/SaveManager"):
		nights_survived = int(SaveManager.active_info.get("nights_survived", 0))
	_prepare_wave(night_number())
	nights_changed.emit(nights_survived)
	if _clock and _clock.is_night() and tonight == 0:
		_on_night_started()


func night_number() -> int:
	return nights_survived + 1


func is_blood_moon_night(n: int) -> bool:
	return n > 0 and n % BLOOD_MOON_EVERY == 0


func nights_until_blood_moon() -> int:
	var n := night_number()
	return (BLOOD_MOON_EVERY - (n % BLOOD_MOON_EVERY)) % BLOOD_MOON_EVERY


# --------------------------------------------------------------------------
# Night flow
# --------------------------------------------------------------------------

func _on_time(h: int, m: int) -> void:
	# Dusk warning one hour before nightfall
	if _clock and h == _clock.night_hour - 1 and m == 0:
		var n := night_number()
		_prepare_wave(n)
		var hud := get_tree().get_first_node_in_group("hud_ui")
		if hud:
			if is_blood_moon_night(n):
				hud.show_hud_message("The moon is turning red... BLOOD MOON TONIGHT!", 5.0)
			else:
				hud.show_hud_message("Night %d is coming in one hour. Get ready!" % n, 4.0)


func _on_night_started() -> void:
	tonight = night_number()
	blood_moon = is_blood_moon_night(tonight)
	_stats = {"kills": 0, "gold": 0, "crops_lost": 0, "defenses_lost": 0}
	_prepare_wave(tonight)
	for env in get_tree().get_nodes_in_group("environment_manager"):
		env.set("night_tint", Color(1.35, 0.55, 0.55) if blood_moon else Color.WHITE)
	_show_night_banner()
	if has_node("/root/Music"):
		get_node("/root/Music").set_night(true, blood_moon)


func _on_night_ended() -> void:
	if tonight == 0:
		return
	var n := tonight
	nights_survived = maxi(nights_survived, n)
	best_night = maxi(best_night, n)
	var bonus := 20 + 10 * n
	if blood_moon:
		bonus *= 2
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats and not stats.is_dead:
		stats.add_gold(bonus)
		stats.add_xp(15 + 5 * n)
	_stats["bonus"] = bonus
	_show_dawn_report(n, _stats.duplicate())
	nights_changed.emit(nights_survived)
	tonight = 0
	blood_moon = false
	_prepare_wave(night_number())
	for env in get_tree().get_nodes_in_group("environment_manager"):
		env.set("night_tint", Color.WHITE)
	if has_node("/root/Music"):
		get_node("/root/Music").set_night(false, false)


# --------------------------------------------------------------------------
# Zombie variants
# --------------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if not (node.get_script() and str(node.get_script().resource_path).ends_with("/zombie.gd")):
		return
	if node.has_meta("nh_variant"):
		return
	node.set_meta("nh_variant", true)
	# Wait until SaveManager has applied difficulty in the same frame.
	_make_variant.call_deferred(node)


func _make_variant(z: Node) -> void:
	if not is_instance_valid(z):
		return
	var n := tonight if tonight > 0 else night_number()
	var bm := is_blood_moon_night(n)
	var hp_scale := 1.0 + 0.06 * float(minf(n - 1, 20))
	var roll := randf()
	var brute_chance := 0.0 if n < 5 else minf(0.08 + 0.02 * float(n - 5), 0.25)
	var runner_chance := 0.0 if n < 3 else minf(0.15 + 0.03 * float(n - 3), 0.35)
	if bm:
		brute_chance += 0.1
		runner_chance += 0.1
	var spr: AnimatedSprite2D = z.get_node_or_null("AnimatedSprite2D")
	if roll < brute_chance:
		z.variant = "brute"
		z.max_health = roundi(z.max_health * 2.2 * hp_scale)
		z.attack_damage = roundi(z.attack_damage * 2.0)
		z.chase_speed *= 0.72
		z.wander_speed *= 0.8
		z.structure_damage = 34
		z.crop_attack_damage *= 2
		z.scale = Vector2(1.28, 1.28)
		if spr:
			spr.self_modulate = Color(1.0, 0.72, 0.68)
	elif roll < brute_chance + runner_chance:
		z.variant = "runner"
		z.max_health = roundi(z.max_health * 0.6 * hp_scale)
		z.chase_speed *= 1.65
		z.wander_speed *= 1.4
		z.detection_range *= 1.25
		z.scale = Vector2(0.9, 0.9)
		if spr:
			spr.self_modulate = Color(0.72, 1.0, 0.7)
	else:
		z.max_health = roundi(z.max_health * hp_scale)
		if bm and spr:
			spr.self_modulate = Color(1.0, 0.82, 0.82)
	z.current_health = z.max_health
	var bar: ProgressBar = z.get_node_or_null("HealthBar")
	if bar:
		bar.max_value = z.max_health
		bar.value = z.current_health


# --------------------------------------------------------------------------
# Events: coins, report counters
# --------------------------------------------------------------------------

func _on_event(type: String, data: Dictionary) -> void:
	match type:
		"zombie_died":
			if not data.get("by_player", false):
				return
			_stats["kills"] = int(_stats.get("kills", 0)) + 1
			var v := str(data.get("variant", "walker"))
			var amount := 3 + randi() % 3
			if v == "runner":
				amount += 2
			elif v == "brute":
				amount += 12
			if blood_moon:
				amount *= 2
			_drop_coins(data.get("pos", Vector2.ZERO), amount)
		"crop_destroyed":
			_stats["crops_lost"] = int(_stats.get("crops_lost", 0)) + 1
		"defense_destroyed":
			_stats["defenses_lost"] = int(_stats.get("defenses_lost", 0)) + 1
		"coin_collected":
			_stats["gold"] = int(_stats.get("gold", 0)) + int(data.get("amount", 0))


func _drop_coins(pos: Vector2, amount: int) -> void:
	var pieces := clampi(amount / 3, 1, 5)
	var each := maxi(1, amount / pieces)
	for i in pieces:
		var c: Node2D = CoinScript.new()
		c.value = each if i < pieces - 1 else amount - each * (pieces - 1)
		_game.add_child(c)
		c.global_position = pos
		c.launch(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.2)).normalized() * randf_range(20.0, 46.0))


# --------------------------------------------------------------------------
# Banners
# --------------------------------------------------------------------------

func _show_night_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 88
	_game.add_child(layer)
	var st := UIKit.stage(layer)
	var title := "BLOOD MOON · NIGHT %d" % tonight if blood_moon else "NIGHT %d" % tonight
	var col := Color("FF5A4E") if blood_moon else Color("C9B8FF")
	var sub := "THE DEAD ARE RESTLESS. DOUBLE REWARDS." if blood_moon else _night_hint(tonight)
	var lt := UIKit.label(st, title, 54, col, Vector2(0, 150))
	lt.size = Vector2(1152, 60)
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := UIKit.label(st, sub, UIKit.F_SMALL, UIKit.C_TEXT_SOFT, Vector2(0, 222))
	ls.size = Vector2(1152, 30)
	ls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.modulate.a = 0.0
	var tw := st.create_tween()
	tw.tween_property(st, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.8)
	tw.tween_property(st, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)


func _night_hint(n: int) -> String:
	if n == 3:
		return "RUNNERS HAVE JOINED THE HORDE. THEY ARE FAST."
	if n == 5:
		return "BRUTES ARE COMING. THEY SMASH BARRICADES."
	if n == 1:
		return "PROTECT YOUR CROPS UNTIL 6:00 AM."
	return "SURVIVE UNTIL DAWN."


func _show_dawn_report(n: int, s: Dictionary) -> void:
	if _report_layer and is_instance_valid(_report_layer):
		_report_layer.queue_free()
	_report_layer = CanvasLayer.new()
	_report_layer.layer = 86
	_game.add_child(_report_layer)
	var st := UIKit.stage(_report_layer)
	var p := UIKit.panel(st, Vector2(376, 120), Vector2(400, 300))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var head := UIKit.label(p, "NIGHT %d SURVIVED" % n, UIKit.F_BIG, UIKit.C_GOLD_LIGHT, Vector2(0, 22))
	head.size = Vector2(400, 30)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.color_rect(p, UIKit.C_LINE, Vector2(24, 64), Vector2(352, 3))
	var rows := [
		["ZOMBIES SLAIN", str(s.get("kills", 0))],
		["GOLD PICKED UP", str(s.get("gold", 0))],
		["CROPS LOST", str(s.get("crops_lost", 0))],
		["DEFENSES LOST", str(s.get("defenses_lost", 0))],
		["DAWN BONUS", "+%d GOLD" % int(s.get("bonus", 0))],
	]
	for i in rows.size():
		UIKit.label(p, rows[i][0], UIKit.F_SMALL, UIKit.C_TEXT_SOFT, Vector2(36, 84 + i * 30))
		var v: String = rows[i][1]
		UIKit.label(p, v, UIKit.F_SMALL, UIKit.C_GOLD if i == rows.size() - 1 else UIKit.C_TEXT, Vector2(364 - UIKit.text_w(v), 84 + i * 30))
	var nxt := night_number()
	var foot := "NEXT: BLOOD MOON!" if is_blood_moon_night(nxt) else "NEXT NIGHT WILL BE HARDER."
	var fl := UIKit.label(p, foot, UIKit.F_SMALL, UIKit.C_RED if is_blood_moon_night(nxt) else UIKit.C_TEXT_DIM, Vector2(0, 248))
	fl.size = Vector2(400, 24)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.modulate.a = 0.0
	var layer := _report_layer
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.4)
	tw.tween_interval(6.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)
	p.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and is_instance_valid(layer):
			layer.queue_free())
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("quest_complete")


func get_save_data() -> Dictionary:
	return {"nights": nights_survived, "best": best_night}


func load_save_data(d: Dictionary) -> void:
	nights_survived = int(d.get("nights", 0))
	best_night = int(d.get("best", nights_survived))
	nights_changed.emit(nights_survived)
