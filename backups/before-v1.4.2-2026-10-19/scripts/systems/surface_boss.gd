extends CharacterBody2D

## Surface bosses (v1.3), called with a crafted idol at night (or by a Blood Moon):
##
##   giant   THE ROTTING GIANT - slams the ground, charges, calls zombies at 66% / 33%.
##           Drops the Bone Cleaver and a Giant's Heart (+20 max HP when eaten).
##   plague  THE PLAGUE MOTHER - spits volleys of poison, dashes, calls zombies.
##           Drops the Plague Scythe, gems and gold.

signal defeated(kind: String)

const WorldItemScene = preload("res://Scenes/world_item.tscn")
const ItemDB = preload("res://scripts/item_database.gd")
const CoinScript = preload("res://scripts/systems/coin.gd")
const Z := "res://Assets/Enemies/zombie/1_Default/Zombie_Default_"
const V13 := "res://Assets/Generated/v13/"

const KINDS := {
	"giant": {"name": "THE ROTTING GIANT", "hp": 1800, "scale": 2.3, "tint": Color(0.62, 0.9, 0.5), "speed": 30.0, "bar": Color("7FC24A"), "touch": 18},
	"plague": {"name": "THE PLAGUE MOTHER", "hp": 3000, "scale": 1.9, "tint": Color(0.82, 0.6, 1.0), "speed": 40.0, "bar": Color("A86CFF"), "touch": 16},
}

var kind := "giant"
var max_health := 1800
var current_health := 1800
var is_dead := false
var first_kill := true

var _sprite: AnimatedSprite2D
var _state := "intro"
var _state_t := 2.2
var _slam_cd := 3.0
var _charge_cd := 6.0
var _spit_cd := 2.5
var _charge_dir := Vector2.ZERO
var _summoned := {}
var _touch_cd := 0.0
var _bar_layer: CanvasLayer
var _bar_fill: ColorRect
var _hp_label: Label
var _slow := 1.0


func _ready() -> void:
	add_to_group("boss")
	add_to_group("surface_boss")
	collision_layer = 2
	collision_mask = 1
	var info: Dictionary = KINDS[kind]
	var night_bonus := 1.0
	var nd := get_tree().get_first_node_in_group("night_director")
	if nd:
		night_bonus += minf(1.5, float(nd.get("nights_survived")) * 0.04)
	max_health = int(float(info["hp"]) * night_bonus)
	current_health = max_health
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12.0
	cs.shape = c
	add_child(cs)
	_sprite = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in [["idle", "Idle", 6.0, true], ["walk", "Walk", 7.0, true], ["slam", "Attack1", 10.0, false], ["dead", "Dead", 7.0, false]]:
		sf.add_animation(a[0])
		sf.set_animation_speed(a[0], a[2])
		sf.set_animation_loop(a[0], a[3])
		var tex: Texture2D = load(Z + a[1] + ".png")
		for i in 6:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 64, 0, 64, 64)
			sf.add_frame(a[0], at)
	_sprite.sprite_frames = sf
	var s: float = info["scale"]
	_sprite.scale = Vector2(s, s)
	_sprite.offset = Vector2(0, -18)
	_sprite.self_modulate = info["tint"]
	add_child(_sprite)
	_sprite.play("idle")
	var l := PointLight2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	l.texture = gt
	l.texture_scale = 3.0
	l.color = Color(0.5, 0.95, 0.4) if kind == "giant" else Color(0.75, 0.4, 1.0)
	l.energy = 0.55
	l.position = Vector2(0, -26)
	add_child(l)
	_build_bar()
	_sfx("boss_roar", -1.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.shake(5.0, 0.9)
		juice.popup_text(global_position + Vector2(0, -70), str(info["name"]) + " AWAKENS!", Color("FFB0A0"), true)


func _build_bar() -> void:
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 12
	add_child(_bar_layer)
	var font: Font = load("res://Assets/Fonts/nh_pixel_font.png")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.position = Vector2(-260, 150)
	_bar_layer.add_child(root)
	var name := Label.new()
	name.text = str(KINDS[kind]["name"])
	name.add_theme_font_override("font", font)
	name.add_theme_font_size_override("font_size", 27)
	name.add_theme_color_override("font_color", Color("F0E0C8"))
	name.add_theme_color_override("font_outline_color", Color("1E1209"))
	name.add_theme_constant_override("outline_size", 8)
	name.size = Vector2(520, 30)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.position = Vector2(0, -36)
	root.add_child(name)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.04, 0.1, 0.9)
	bg.size = Vector2(520, 16)
	root.add_child(bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = KINDS[kind]["bar"]
	_bar_fill.position = Vector2(3, 3)
	_bar_fill.size = Vector2(514, 10)
	root.add_child(_bar_fill)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var p := _player()
	if p == null:
		return
	var to_p := p.global_position - global_position
	_state_t -= delta
	_touch_cd -= delta
	var info: Dictionary = KINDS[kind]
	var enraged := current_health < max_health / 2
	match _state:
		"intro":
			velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_state = "chase"
		"chase":
			_sprite.play("walk")
			var spd: float = float(info["speed"]) * (1.35 if enraged else 1.0) * _slow
			velocity = velocity.lerp(to_p.normalized() * spd, delta * 3.0)
			_sprite.flip_h = to_p.x < 0.0
			_slam_cd -= delta
			_charge_cd -= delta
			_spit_cd -= delta
			if kind == "giant":
				if _slam_cd <= 0.0 and to_p.length() < 70.0:
					_begin_slam(54.0)
				elif enraged and _charge_cd <= 0.0 and to_p.length() > 70.0:
					_windup(to_p)
			else:
				if _spit_cd <= 0.0 and to_p.length() < 240.0:
					_spit(to_p, 3 if not enraged else 5)
					_spit_cd = 2.6 if not enraged else 1.8
				elif _slam_cd <= 0.0 and to_p.length() < 56.0:
					_begin_slam(44.0)
				elif _charge_cd <= 0.0 and to_p.length() > 90.0:
					_windup(to_p)
		"slam_windup":
			velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_do_slam()
		"recover":
			velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_state = "chase"
		"windup":
			velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_state = "charge"
				_state_t = 0.9 if kind == "giant" else 0.5
				_sprite.modulate = Color.WHITE
				_sfx("heavy_swing", -4.0)
		"charge":
			_sprite.play("walk")
			velocity = _charge_dir * (240.0 if kind == "giant" else 320.0)
			var juice := get_tree().get_first_node_in_group("juice")
			if juice and randf() < 0.4:
				juice.dust(global_position, 2)
			if _state_t <= 0.0 or get_slide_collision_count() > 0:
				if get_slide_collision_count() > 0:
					# Smash through whatever it ran into
					for i in get_slide_collision_count():
						var col = get_slide_collision(i).get_collider()
						if col and col.has_method("take_zombie_damage"):
							col.take_zombie_damage(120)
					if juice:
						juice.shake(4.0, 0.3)
				_state = "recover"
				_state_t = 1.0
				_charge_cd = randf_range(5.0, 8.0)
	move_and_slide()
	# Walls and doors in the way get chewed
	for i in get_slide_collision_count():
		var col2 = get_slide_collision(i).get_collider()
		if col2 and col2.has_method("take_zombie_damage") and _touch_cd <= 0.0:
			col2.take_zombie_damage(30)
			_touch_cd = 0.6
	if to_p.length() < 22.0 and _touch_cd <= 0.0 and p.has_method("take_damage"):
		_touch_cd = 0.9
		p.take_damage(int(info["touch"]) if _state != "charge" else 32, to_p.normalized(), 170.0)


func _windup(to_p: Vector2) -> void:
	_state = "windup"
	_state_t = 0.7
	_charge_dir = to_p.normalized()
	_sprite.play("idle")
	_sprite.modulate = Color(1.6, 0.7, 0.7)


func _begin_slam(radius: float) -> void:
	_state = "slam_windup"
	_state_t = 0.9
	_sprite.play("slam")
	var ring := Node2D.new()
	ring.set_script(load("res://scripts/systems/warning_ring.gd"))
	ring.set("radius", radius)
	ring.set("duration", 0.9)
	ring.set_meta("radius", radius)
	get_parent().add_child(ring)
	ring.global_position = global_position
	set_meta("slam_radius", radius)


func _do_slam() -> void:
	_state = "recover"
	_state_t = 0.8
	_slam_cd = randf_range(3.0, 4.5)
	var radius: float = get_meta("slam_radius", 50.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.shake(5.0, 0.35)
		juice.burst(global_position, Color(0.5, 0.6, 0.4), 22, 130.0)
		juice.dust(global_position, 10)
	_sfx("rock_break", -2.0)
	var p := _player()
	if p and p.global_position.distance_to(global_position) < radius and p.has_method("take_damage"):
		p.take_damage(26, (p.global_position - global_position).normalized(), 230.0)
	for d in get_tree().get_nodes_in_group("defenses"):
		if (d as Node2D).global_position.distance_to(global_position) < radius and d.has_method("take_zombie_damage"):
			d.take_zombie_damage(70)


## The Plague Mother spits a fan of poison blobs.
func _spit(to_p: Vector2, n: int) -> void:
	_sprite.play("slam")
	_sfx("slime", -4.0)
	var base := to_p.angle()
	for i in n:
		var a := base + (float(i) - float(n - 1) * 0.5) * 0.22
		var b := PoisonBlob.new()
		b.dir = Vector2.from_angle(a)
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(0, -16)


func take_damage(amount: int, _direction: Vector2 = Vector2.ZERO, _knockback: float = 0.0) -> void:
	if is_dead or _state == "intro":
		return
	current_health = maxi(0, current_health - amount)
	_bar_fill.size.x = 514.0 * float(current_health) / float(max_health)
	_sprite.modulate = Color(2.0, 1.8, 1.8)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.damage_number(global_position + Vector2(0, -26), amount, amount >= 40)
		juice.burst(global_position + Vector2(0, -24), Color(0.5, 0.75, 0.35), 6, 60.0)
		juice.hitstop(0.035)
	_sfx("sword_hit", -4.0)
	for threshold in [0.66, 0.33]:
		if float(current_health) / float(max_health) < threshold and not _summoned.has(threshold):
			_summoned[threshold] = true
			_summon()
	if current_health <= 0:
		_die()


func apply_slow(mult: float, _duration: float) -> void:
	_slow = clampf(mult + 0.3, 0.6, 1.0)


func _summon() -> void:
	_sfx("boss_roar", -3.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.shake(3.0, 0.5)
		juice.popup_text(global_position + Vector2(0, -70), "RISE!" if kind == "giant" else "MY CHILDREN, FEED!", Color("C8F070"), true)
	var sm := get_tree().get_first_node_in_group("spawn_manager")
	if sm == null or not sm.has_method("spawn_zombie_at"):
		return
	for i in (4 if kind == "giant" else 5):
		var pos := global_position + Vector2.from_angle(TAU * float(i) / 4.0 + 0.4) * 48.0
		sm.spawn_zombie_at(pos)


func _die() -> void:
	is_dead = true
	collision_layer = 0
	velocity = Vector2.ZERO
	_sprite.play("dead")
	_bar_layer.queue_free()
	_sfx("boss_roar", -2.0)
	_sfx("mission", -4.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.shake(6.0, 1.0)
		juice.burst(global_position + Vector2(0, -24), Color(0.6, 0.9, 0.4), 30, 140.0)
		juice.popup_text(global_position + Vector2(0, -70), str(KINDS[kind]["name"]) + " FALLS!", Color("FFDB80"), true)
	var parent := get_parent()
	var drops: Array
	if kind == "giant":
		drops = [["giant_heart", 1], ["bone", 6], ["rotten_flesh", 8], ["iron_bar", 4]]
		if first_kill or randf() < 0.35:
			drops.append(["bone_cleaver", 1])
	else:
		drops = [["gem", 3], ["gold_bar", 3], ["crystal_shard", 3], ["slime_gel", 4]]
		if first_kill or randf() < 0.35:
			drops.append(["plague_scythe", 1])
	for pair in drops:
		var it = ItemDB.get_item(pair[0])
		if it:
			var w := WorldItemScene.instantiate()
			parent.add_child(w)
			w.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-4, 8))
			w.call("set_item", it, int(pair[1]))
	for i in 8:
		var c: Node2D = CoinScript.new()
		c.value = 40 if kind == "giant" else 60
		parent.add_child(c)
		c.global_position = global_position
		c.launch(Vector2.from_angle(randf() * TAU) * randf_range(30.0, 70.0))
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats:
		stats.add_xp(350 if kind == "giant" else 600)
	defeated.emit(kind)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)


func _sfx(n: String, db: float) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play(n, db)


## A slow poison projectile. Hurts the player; walls stop it.
class PoisonBlob extends Node2D:
	var dir := Vector2.RIGHT
	var speed := 120.0
	var life := 2.6
	var _spr: Sprite2D

	func _ready() -> void:
		_spr = Sprite2D.new()
		_spr.texture = load("res://Assets/Generated/v13/poison_blob.png")
		add_child(_spr)
		z_index = 5

	func _physics_process(delta: float) -> void:
		life -= delta
		var step := dir * speed * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var col = hit.get("collider")
			if col and col.has_method("take_zombie_damage"):
				col.take_zombie_damage(15)
			_pop()
			return
		global_position += step
		_spr.rotation += delta * 6.0
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p and p.global_position.distance_to(global_position + Vector2(0, 10)) < 12.0:
			if p.has_method("take_damage"):
				p.take_damage(12, dir, 90.0)
			_pop()
			return
		if life <= 0.0:
			_pop()

	func _pop() -> void:
		var juice := get_tree().get_first_node_in_group("juice")
		if juice:
			juice.burst(global_position, Color(0.55, 0.85, 0.3), 6, 50.0)
		queue_free()
