extends CharacterBody2D

## Monsters of The Hollow Mines (v1.2): slime, bat, skeleton, ghoul.
## Simple, readable AI: wander until the player is close, then chase and bite.
## Takes damage from any tool or weapon through take_damage(), like zombies.

const WorldItemScene = preload("res://Scenes/world_item.tscn")
const ItemDB = preload("res://scripts/item_database.gd")
const CoinScript = preload("res://scripts/systems/coin.gd")

## kind -> stats (scaled by floor in setup())
const KINDS := {
	"slime": {"hp": 26, "dmg": 6, "speed": 46.0, "sight": 140.0, "drop": ["slime_gel", 0.8], "gold": 2, "xp": 4},
	"bat": {"hp": 18, "dmg": 5, "speed": 74.0, "sight": 170.0, "drop": ["", 0.0], "gold": 3, "xp": 5},
	"skeleton": {"hp": 60, "dmg": 10, "speed": 40.0, "sight": 160.0, "drop": ["bone", 0.85], "gold": 5, "xp": 9},
	"ghoul": {"hp": 120, "dmg": 14, "speed": 44.0, "sight": 180.0, "drop": ["bone", 0.5], "gold": 9, "xp": 14},
}

var kind: String = "slime"
var floor_level: int = 1
var max_health: int = 20
var current_health: int = 20
var damage: int = 5
var speed: float = 40.0
var sight: float = 140.0
var is_dead := false

var _sprite: AnimatedSprite2D
var _bar: ProgressBar
var _attack_cd := 0.0
var _hop_t := 0.0
var _wander_target := Vector2.ZERO
var _wander_t := 0.0
var _hurt_t := 0.0
var _t := 0.0
var _home := Vector2.ZERO


func setup(k: String, depth: int) -> void:
	kind = k
	floor_level = depth
	var s: Dictionary = KINDS.get(k, KINDS["slime"])
	var scale_hp := 1.0 + 0.12 * float(depth - 1)
	max_health = int(round(float(s["hp"]) * scale_hp))
	damage = int(round(float(s["dmg"]) * (1.0 + 0.06 * float(depth - 1))))
	speed = float(s["speed"])
	sight = float(s["sight"])
	current_health = max_health


func _ready() -> void:
	add_to_group("cave_enemies")
	collision_layer = 2
	collision_mask = 0 if kind == "bat" else 1
	_home = global_position
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.0
	cs.shape = c
	add_child(cs)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _frames()
	add_child(_sprite)
	_sprite.play("move")
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.size = Vector2(16, 3)
	_bar.position = Vector2(-8, -24 if kind in ["skeleton", "ghoul"] else -16)
	_bar.max_value = max_health
	_bar.value = current_health
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.05, 0.05, 0.85)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.3, 0.3)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.visible = false
	add_child(_bar)
	_bar.size = Vector2(16, 3)   # v1.3.1: re-size once in the tree (theme clamps it otherwise)
	_bar.set_deferred("size", Vector2(16, 3))
	_t = randf() * 10.0


func _frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	match kind:
		"slime":
			var tex: Texture2D = load("res://Assets/Enemies/Slime_Green.png")
			_add(sf, "idle", tex, 0, 4, 64, 64, 6.0, true)
			_add(sf, "move", tex, 1, 8, 64, 64, 10.0, true)
			_add(sf, "dead", tex, 2, 8, 64, 64, 14.0, false)
			_sprite_offset = Vector2(0, -14)
			_sprite_scale = 0.75
			if floor_level >= 10:
				_tint = Color(0.75, 0.6, 1.0)
			elif floor_level >= 5:
				_tint = Color(0.6, 0.8, 1.0)
		"bat":
			var tex: Texture2D = load("res://Assets/Generated/v12/bat.png")
			_add(sf, "idle", tex, 0, 2, 12, 8, 10.0, true)
			_add(sf, "move", tex, 0, 2, 12, 8, 12.0, true)
			_add(sf, "dead", tex, 0, 1, 12, 8, 1.0, false)
			_sprite_offset = Vector2(0, -14)
			_sprite_scale = 1.0
		"skeleton":
			var tex: Texture2D = load("res://Assets/Enemies/Skeleton.png")
			_add(sf, "idle", tex, 0, 6, 32, 32, 6.0, true)
			_add(sf, "move", tex, 4, 6, 32, 32, 9.0, true)
			_add(sf, "dead", tex, 6, 4, 32, 32, 8.0, false)
			_sprite_offset = Vector2(0, -12)
			_sprite_scale = 1.0
		_:
			var walk: Texture2D = load("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Walk.png")
			var dead: Texture2D = load("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Dead.png")
			_add(sf, "idle", walk, 0, 6, 64, 64, 5.0, true)
			_add(sf, "move", walk, 0, 6, 64, 64, 8.0, true)
			_add(sf, "dead", dead, 0, 6, 64, 64, 10.0, false)
			_sprite_offset = Vector2(0, -20)
			_sprite_scale = 0.62
			_tint = Color(0.7, 0.62, 1.0)
	return sf


var _sprite_offset := Vector2.ZERO
var _sprite_scale := 1.0
var _tint := Color.WHITE


func _add(sf: SpriteFrames, anim: String, tex: Texture2D, row: int, count: int, w: int, h: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for i in count:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * w, row * h, w, h)
		sf.add_frame(anim, a)


func _physics_process(delta: float) -> void:
	if _sprite and _sprite.offset != _sprite_offset:
		_sprite.offset = _sprite_offset / _sprite_scale
		_sprite.scale = Vector2(_sprite_scale, _sprite_scale)
		_sprite.self_modulate = _tint
	if is_dead:
		return
	_t += delta
	_attack_cd -= delta
	if _hurt_t > 0.0:
		_hurt_t -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var to_p := (p.global_position - global_position) if p else Vector2.ZERO
	var dist := to_p.length()
	var chasing := p != null and dist < sight and not bool(p.get("_is_dead"))
	match kind:
		"slime":
			_hop_t -= delta
			if _hop_t <= 0.0:
				_hop_t = randf_range(0.7, 1.1)
				var dir := to_p.normalized() if chasing else _wander_dir()
				velocity = dir * speed * 2.2
				_sprite.play("move")
				if chasing and randf() < 0.3:
					_sfx("slime", -16.0)
			velocity = velocity.move_toward(Vector2.ZERO, speed * 3.0 * delta)
		"bat":
			var dir := to_p.normalized() if chasing else _wander_dir()
			var swoop := Vector2(-dir.y, dir.x) * sin(_t * 5.0) * 0.8
			velocity = velocity.lerp((dir + swoop).normalized() * speed, delta * 3.0)
		_:
			var dir := to_p.normalized() if chasing else _wander_dir()
			var spd := speed if chasing else speed * 0.4
			velocity = velocity.lerp(dir * spd, delta * 6.0)
			_sprite.play("move" if velocity.length() > 4.0 else "idle")
	if absf(velocity.x) > 2.0:
		_sprite.flip_h = velocity.x < 0.0 if kind != "skeleton" else velocity.x < 0.0
	move_and_slide()
	# Bite
	if chasing and dist < 15.0 and _attack_cd <= 0.0 and p.has_method("take_damage"):
		_attack_cd = 1.1
		p.take_damage(damage, to_p.normalized(), 90.0)
		if kind == "skeleton":
			_sfx("bones", -10.0)


func _wander_dir() -> Vector2:
	_wander_t -= get_physics_process_delta_time()
	if _wander_t <= 0.0 or global_position.distance_to(_wander_target) < 6.0:
		_wander_t = randf_range(1.5, 3.5)
		_wander_target = _home + Vector2(randf_range(-48, 48), randf_range(-36, 36))
	return (_wander_target - global_position).normalized() * 0.6


func take_damage(amount: int, direction: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> void:
	if is_dead:
		return
	current_health = maxi(0, current_health - amount)
	_bar.visible = true
	_bar.value = current_health
	_hurt_t = 0.18
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * maxf(knockback, 40.0) * (1.6 if kind in ["slime", "bat"] else 1.0)
	_sprite.modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.damage_number(global_position + Vector2(0, 6), amount, amount >= 30)
		juice.burst(global_position + Vector2(0, -8), _blood(), 5, 50.0)
		juice.hitstop(0.025)
	_sfx("sword_hit", -8.0)
	if current_health <= 0:
		_die(direction)


func _blood() -> Color:
	match kind:
		"slime":
			return Color(0.45, 0.85, 0.35)
		"skeleton":
			return Color(0.95, 0.93, 0.85)
		"bat":
			return Color(0.55, 0.2, 0.3)
	return Color(0.5, 0.4, 0.7)


func _die(direction: Vector2) -> void:
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	_bar.visible = false
	_sprite.play("dead")
	_sfx("slime" if kind == "slime" else ("bones" if kind == "skeleton" else "zombie_death"), -8.0)
	var juice := get_tree().get_first_node_in_group("juice")
	if juice:
		juice.burst(global_position + Vector2(0, -8), _blood(), 12, 80.0)
		juice.shake(1.6, 0.15)
	var s: Dictionary = KINDS.get(kind, KINDS["slime"])
	var drop: Array = s["drop"]
	var parent := get_parent()
	if str(drop[0]) != "" and randf() < float(drop[1]):
		var it = ItemDB.get_item(str(drop[0]))
		if it:
			var w := WorldItemScene.instantiate()
			parent.add_child(w)
			w.global_position = global_position
			w.call("set_item", it, 1)
	var gold := int(s["gold"]) + floor_level / 2
	var c: Node2D = CoinScript.new()
	c.value = gold
	parent.add_child(c)
	c.global_position = global_position
	c.launch(Vector2(randf_range(-1, 1), -0.5).normalized() * 30.0)
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats:
		stats.add_xp(int(s["xp"]) + floor_level)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("cave_enemy_killed", {"kind": kind, "floor": floor_level})
			break
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + direction.normalized() * 10.0, 0.2)
	tw.tween_interval(0.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _sfx(n: String, db: float) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play(n, db)
