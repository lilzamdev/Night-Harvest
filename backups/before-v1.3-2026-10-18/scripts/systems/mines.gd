extends Node2D

## The Hollow Mines (v1.2) — a randomly generated underground "dimension".
##
##  * Enter from the old quarry north-east of the farm.
##  * Every floor is a new cave: break rocks and ore veins with a pickaxe, fight
##    slimes, bats, skeletons and ghouls, find the ladder down.
##  * Deeper = richer ores and nastier monsters:
##      floors 1-4 stone, copper · 5-9 +iron · 10-14 +gold · 15 THE HOLLOW KING · 16+ crystal, gems
##  * A mine lift on every 5th floor lets you come back to that depth later.
##  * Old Tomas' journal pages lie on floors 3, 7 and 11.
## The caves live far away from the map (ORIGIN); the player is teleported with a fade.

signal floor_changed(n: int)

const RockScript = preload("res://scripts/systems/mine_rock.gd")
const EnemyScript = preload("res://scripts/systems/cave_enemy.gd")
const BossScript = preload("res://scripts/systems/mine_boss.gd")
const V12 := "res://Assets/Generated/v12/"

const ORIGIN := Vector2(-30000, 0)
const W := 56
const H := 40
const T := 16
const ENTRANCE_POS := Vector2(665, -150)
const BOSS_FLOOR := 15

const JOURNAL := {
	3: "OLD TOMAS' JOURNAL, PAGE 1:\\nThe quarry broke into a cave today. Cold air, and a sound like breathing. The town says leave it. I say there is iron down there.",
	7: "OLD TOMAS' JOURNAL, PAGE 2:\\nThe deeper I dig, the more the dead walk up top. They come from below. Something down here is CALLING them.",
	11: "OLD TOMAS' JOURNAL, PAGE 3:\\nI saw it. A crowned corpse, sitting on a throne of bones. The Hollow King. If he falls, the nights will quiet. Floor fifteen. God help whoever goes.",
}

var active := false
var floor_num := 0
var deepest := 0
var lifts: Array = [1]
var boss_defeated := false
var journals: Dictionary = {}
var save_key := "mines"

var _game: Node2D
var _level: Node2D
var _grid := PackedByteArray()
var _start := Vector2i.ZERO
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy := false
var _cam_limits: Array = []
var _hud_label: Label
var _light: PointLight2D
var _rng := RandomNumberGenerator.new()
var _tiles := {}


func _ready() -> void:
	add_to_group("mines")
	add_to_group("save_extension")
	_game = get_parent() as Node2D
	_rng.randomize()
	y_sort_enabled = true
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 81
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)
	for n in ["cave_floor", "cave_wall_top", "cave_wall_face"]:
		_tiles[n] = (load(V12 + n + ".png") as Texture2D).get_image()
		(_tiles[n] as Image).convert(Image.FORMAT_RGBA8)
	_build_entrance()
	call_deferred("_add_hud_label")
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").session_started.connect(_on_session_started)


# ==========================================================================
# Overworld entrance
# ==========================================================================

class Entrance extends Node2D:
	var mines: Node
	var interact_range := 26.0
	var display_name := "Mine Lift"

	func _ready() -> void:
		add_to_group("interactables")

	func can_interact(_p: Node2D) -> bool:
		return true

	func get_prompt() -> String:
		return "ENTER THE HOLLOW MINES"

	func interact(p: Node2D) -> void:
		mines.on_entrance_used(p)

	func portrait() -> Texture2D:
		return load("res://Assets/Generated/v12/icon_copper_pickaxe.png")

	func end_talk() -> void:
		pass


func _build_entrance() -> void:
	var root := Node2D.new()
	root.name = "MineEntrance"
	root.y_sort_enabled = true
	add_child(root)
	root.global_position = ENTRANCE_POS
	var spr := Sprite2D.new()
	spr.texture = load(V12 + "mine_entrance.png")
	spr.offset = Vector2(0, -12)
	root.add_child(spr)
	var cart := Sprite2D.new()
	cart.texture = load(V12 + "minecart.png")
	cart.position = Vector2(30, 2)
	cart.offset = Vector2(0, -8)
	root.add_child(cart)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for r in [Rect2(-14, -6, 6, 6), Rect2(9, -6, 6, 6), Rect2(-24, -2, 10, 3), Rect2(15, -2, 10, 3), Rect2(24, -6, 12, 6)]:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		cs.position = r.position + r.size * 0.5
		body.add_child(cs)
	var e := Entrance.new()
	e.mines = self
	root.add_child(e)
	e.position = Vector2(1, -2)
	var l := PointLight2D.new()
	l.texture = _glow()
	l.texture_scale = 1.2
	l.color = Color(0.6, 0.45, 1.0)
	l.energy = 0.5
	l.position = Vector2(0, -10)
	root.add_child(l)


func on_entrance_used(p: Node2D) -> void:
	var floors: Array = []
	for f in lifts:
		if int(f) <= maxi(1, deepest) or int(f) == 1:
			floors.append(int(f))
	if floors.size() <= 1:
		enter(1)
		return
	var ui := get_tree().get_first_node_in_group("dialogue_ui")
	if ui == null:
		enter(1)
		return
	var opts: Array = []
	for f in floors:
		opts.append({"text": "FLOOR %d" % f, "action": str(f)})
	opts.append({"text": "NOT NOW", "action": "bye"})
	var ent := get_tree().get_first_node_in_group("interactables")
	for n in get_tree().get_nodes_in_group("interactables"):
		if n is Entrance:
			ent = n
	ui.open_dialogue(ent, "The old lift creaks. Deepest floor reached: %d. Where to?" % deepest, opts, func(action: String) -> void:
		ui.close_dialogue()
		if action != "bye":
			enter(int(action)))


func _add_hud_label() -> void:
	var box := _game.get_node_or_null("UI/HUD/TopCenter/Calendar/Margin/VBox") as VBoxContainer
	if not box:
		return
	_hud_label = Label.new()
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.add_theme_font_size_override("font_size", 10)
	_hud_label.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	_hud_label.visible = false
	box.add_child(_hud_label)


# ==========================================================================
# Travel
# ==========================================================================

func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func enter(n: int) -> void:
	_go(n)


func leave() -> void:
	_go(0)


func _go(n: int) -> void:
	if _busy:
		return
	var p := _player()
	if p == null:
		return
	_busy = true
	p.set("input_locked", true)
	_sfx("ladder" if n > 0 else "door", -6.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func() -> void:
		if n > 0:
			_load_floor(n, p)
		else:
			_exit_to_surface(p))
	tw.tween_interval(0.15)
	tw.tween_property(_fade, "color:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		p.set("input_locked", false)
		_busy = false
		if n > 0:
			_floor_banner(n))


func _load_floor(n: int, p: CharacterBody2D) -> void:
	var cam: Camera2D = p.get_node_or_null("Camera2D")
	if not active:
		if cam:
			_cam_limits = [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
		active = true
		_set_ambience(true)
	floor_num = n
	if n > deepest:
		deepest = n
	if n % 5 == 0 and not lifts.has(n):
		lifts.append(n)
	_build_floor(n)
	p.global_position = _cell_world(_start) + Vector2(0, 10)
	p.velocity = Vector2.ZERO
	if cam:
		cam.limit_left = int(ORIGIN.x)
		cam.limit_top = int(ORIGIN.y)
		cam.limit_right = int(ORIGIN.x + W * T)
		cam.limit_bottom = int(ORIGIN.y + H * T)
		cam.reset_smoothing()
	var env := get_tree().get_first_node_in_group("environment_manager")
	if env and env.has_method("set_area_color"):
		var k := clampf(float(n) / 25.0, 0.0, 1.0)
		env.set_area_color(Color(0.15, 0.13, 0.2).lerp(Color(0.08, 0.06, 0.13), k))
	if _hud_label:
		_hud_label.visible = true
		_hud_label.text = "HOLLOW MINES · FLOOR %d" % n
	floor_changed.emit(n)
	_event("mine_floor_reached", {"floor": n})


func _exit_to_surface(p: CharacterBody2D) -> void:
	_clear_level()
	active = false
	floor_num = 0
	p.global_position = ENTRANCE_POS + Vector2(0, 14)
	p.velocity = Vector2.ZERO
	p.set("last_direction", Vector2.DOWN)
	var cam: Camera2D = p.get_node_or_null("Camera2D")
	if cam and _cam_limits.size() == 4:
		cam.limit_left = _cam_limits[0]
		cam.limit_top = _cam_limits[1]
		cam.limit_right = _cam_limits[2]
		cam.limit_bottom = _cam_limits[3]
		cam.reset_smoothing()
	_set_ambience(false)
	if _hud_label:
		_hud_label.visible = false


func _set_ambience(on: bool) -> void:
	var p := _player()
	if on:
		if p and _light == null:
			_light = PointLight2D.new()
			_light.name = "MinerLight"
			_light.texture = _glow()
			_light.texture_scale = 2.8
			_light.energy = 1.15
			_light.color = Color(1.0, 0.88, 0.7)
			_light.position = Vector2(0, -8)
			p.add_child(_light)
	else:
		if _light and is_instance_valid(_light):
			_light.queue_free()
		_light = null
		var env := get_tree().get_first_node_in_group("environment_manager")
		if env and env.has_method("set_area_color"):
			env.set_area_color(Color(0, 0, 0, 0))
	if has_node("/root/Music"):
		get_node("/root/Music").set_area("mines" if on else "")


func _floor_banner(n: int) -> void:
	var juice := get_tree().get_first_node_in_group("juice")
	var p := _player()
	if juice and p:
		var txt := "FLOOR %d" % n
		if n == BOSS_FLOOR and not boss_defeated:
			txt = "FLOOR 15 · THE THRONE"
		elif n % 5 == 0:
			txt += " · LIFT UNLOCKED"
		juice.popup_text(p.global_position + Vector2(0, -30), txt, Color("D8C8FF"), true)


# ==========================================================================
# Generation
# ==========================================================================

func _idx(x: int, y: int) -> int:
	return y * W + x


func _wall(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H:
		return true
	return _grid[_idx(x, y)] == 1


func _cell_world(c: Vector2i) -> Vector2:
	return ORIGIN + Vector2(c.x * T + T * 0.5, c.y * T + T * 0.5)


func _clear_level() -> void:
	if _level and is_instance_valid(_level):
		_level.queue_free()
	_level = null
	for e in get_tree().get_nodes_in_group("cave_enemies"):
		if is_instance_valid(e):
			e.queue_free()


func _build_floor(n: int) -> void:
	_clear_level()
	_level = Node2D.new()
	_level.name = "MineFloor%d" % n
	_level.y_sort_enabled = true
	add_child(_level)
	# The game root is not at (0, 0); keep floor coordinates global.
	_level.global_position = Vector2.ZERO
	var boss := n == BOSS_FLOOR and not boss_defeated
	if boss:
		_carve_arena()
	else:
		_carve_cave()
	var dist := _distances(_start)
	var far := _start
	var far_d := 0
	var floor_cells: Array[Vector2i] = []
	for y in H:
		for x in W:
			if not _wall(x, y):
				var d: int = dist.get(Vector2i(x, y), -1)
				if d < 0:
					_grid[_idx(x, y)] = 1  # unreachable pocket -> wall
					continue
				floor_cells.append(Vector2i(x, y))
				if d > far_d:
					far_d = d
					far = Vector2i(x, y)
	_render_image()
	_build_collision()
	_place_props(n, far, floor_cells, dist, boss)


func _carve_cave() -> void:
	_grid = PackedByteArray()
	_grid.resize(W * H)
	for y in H:
		for x in W:
			var border := x < 2 or y < 2 or x >= W - 2 or y >= H - 2
			_grid[_idx(x, y)] = 1 if (border or _rng.randf() < 0.44) else 0
	for _i in 5:
		var nxt := _grid.duplicate()
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				var walls := 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if (dx != 0 or dy != 0) and _wall(x + dx, y + dy):
							walls += 1
				nxt[_idx(x, y)] = 1 if walls >= 5 else (0 if walls <= 3 else _grid[_idx(x, y)])
		_grid = nxt
	# Start near the bottom-left: clear a small landing room
	_start = Vector2i(6, H - 7)
	for y in range(_start.y - 2, _start.y + 3):
		for x in range(_start.x - 3, _start.x + 4):
			_grid[_idx(x, y)] = 0
	# Guarantee a winding tunnel towards the far corner, so every floor connects
	var c := _start
	var goal := Vector2i(W - 7, 6)
	while c != goal:
		if _rng.randf() < 0.55:
			c.x += signi(goal.x - c.x)
		else:
			c.y += signi(goal.y - c.y)
		for dy in [0, 1]:
			for dx in [0, 1]:
				var xx := clampi(c.x + dx, 2, W - 3)
				var yy := clampi(c.y + dy, 2, H - 3)
				_grid[_idx(xx, yy)] = 0


func _carve_arena() -> void:
	_grid = PackedByteArray()
	_grid.resize(W * H)
	var cx := W / 2.0
	var cy := H / 2.0
	for y in H:
		for x in W:
			var dx := (x - cx) / (W * 0.42)
			var dy := (y - cy) / (H * 0.4)
			var wob := sin(x * 0.7) * 0.04 + cos(y * 0.9) * 0.04
			_grid[_idx(x, y)] = 0 if dx * dx + dy * dy < 1.0 + wob else 1
	_start = Vector2i(int(cx), H - 6)
	for y in range(_start.y - 1, _start.y + 3):
		for x in range(_start.x - 2, _start.x + 3):
			_grid[_idx(x, clampi(y, 0, H - 2))] = 0


func _distances(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if not _wall(nb.x, nb.y) and not dist.has(nb):
				dist[nb] = int(dist[c]) + 1
				q.append(nb)
	return dist


func _render_image() -> void:
	var img := Image.create(W * T, H * T, false, Image.FORMAT_RGBA8)
	var floor_img: Image = _tiles["cave_floor"]
	var top_img: Image = _tiles["cave_wall_top"]
	var face_img: Image = _tiles["cave_wall_face"]
	for y in H:
		for x in W:
			var dst := Vector2i(x * T, y * T)
			if _wall(x, y):
				if not _wall(x, y + 1):
					img.blit_rect(face_img, Rect2i(0, 0, T, T), dst)
				else:
					var v := (x * 7 + y * 13) % 3
					img.blit_rect(top_img, Rect2i(v * T, 0, T, T), dst)
			else:
				var v2 := (x * 11 + y * 5 + (x * y) % 7) % 4
				img.blit_rect(floor_img, Rect2i(v2 * T, 0, T, T), dst)
	# Soft shading: floor next to walls gets darker edges, wall tops get a rim
	var dark := Color(0, 0, 0, 0.35)
	for y in H:
		for x in W:
			if _wall(x, y):
				continue
			var px := x * T
			var py := y * T
			if _wall(x - 1, y):
				_shade_rect(img, Rect2i(px, py, 2, T), dark)
			if _wall(x + 1, y):
				_shade_rect(img, Rect2i(px + T - 2, py, 2, T), dark)
			if _wall(x, y - 1):
				_shade_rect(img, Rect2i(px, py, T, 3), Color(0, 0, 0, 0.45))
			if _wall(x, y + 1):
				_shade_rect(img, Rect2i(px, py + T - 1, T, 1), Color(0, 0, 0, 0.3))
	var void_rect := ColorRect.new()
	void_rect.color = Color(0.17, 0.14, 0.2)
	void_rect.position = ORIGIN - Vector2(600, 600)
	void_rect.size = Vector2(W * T + 1200, H * T + 1200)
	void_rect.z_index = -11
	void_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level.add_child(void_rect)
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.z_index = -10
	spr.position = ORIGIN
	_level.add_child(spr)


func _shade_rect(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var o := img.get_pixel(x, y)
			img.set_pixel(x, y, o.lerp(Color(c.r, c.g, c.b, 1.0), c.a))


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_level.add_child(body)
	for y in H:
		var x := 0
		while x < W:
			if _wall(x, y):
				var x0 := x
				while x < W and _wall(x, y):
					x += 1
				var cs := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				# Wall faces are only half solid, so you can walk right up to them
				var face := not _wall(x0, y + 1)
				rs.size = Vector2((x - x0) * T, T - (6 if face else 0))
				cs.shape = rs
				cs.position = ORIGIN + Vector2(x0 * T + (x - x0) * T * 0.5, y * T + rs.size.y * 0.5)
				body.add_child(cs)
			else:
				x += 1


func _place_props(n: int, far: Vector2i, cells: Array[Vector2i], dist: Dictionary, boss: bool) -> void:
	# Rope back to the surface
	var rope := _interactable("CLIMB TO THE SURFACE", func(_p: Node2D) -> void: leave())
	rope.position = _cell_world(_start) + Vector2(0, -6)
	_sprite_at(rope, "rope.png", Vector2(0, -8))
	# Lift on every 5th floor
	if n % 5 == 0:
		var lift := _interactable("RIDE THE LIFT UP", func(_p: Node2D) -> void: leave())
		lift.position = _cell_world(_start) + Vector2(32, -4)
		_sprite_at(lift, "minecart.png", Vector2(0, -8))
	# Ladder (on the boss floor it appears when the king falls)
	if not boss:
		_spawn_ladder(_cell_world(far))
	# Light sources on walls
	var torches := 0
	for c in cells:
		if _wall(c.x, c.y - 1) and _rng.randf() < 0.035 and torches < 14:
			torches += 1
			var t := Sprite2D.new()
			t.texture = load(V12 + "wall_torch.png")
			t.position = _cell_world(c) + Vector2(0, -12)
			t.z_index = -5
			_level.add_child(t)
			var l := PointLight2D.new()
			l.texture = _glow()
			l.texture_scale = 1.6
			l.color = Color(1.0, 0.7, 0.4)
			l.energy = 0.9
			l.position = t.position
			_level.add_child(l)
	if boss:
		_spawn_boss()
		return
	# Rocks and ore
	var used := {}
	var density := 0.13 + minf(0.06, n * 0.004)
	for c in cells:
		var d: int = dist.get(c, 0)
		if d < 4 or c == far or _rng.randf() > density:
			continue
		used[c] = true
		var r: StaticBody2D = RockScript.new()
		r.rock_type = _roll_rock(n)
		r.variant = _rng.randi() % 3
		_level.add_child(r)
		r.global_position = _cell_world(c) + Vector2(_rng.randf_range(-2, 2), 5)
		# Crates and decor sometimes
	for c in cells:
		if used.has(c) or int(dist.get(c, 0)) < 3 or _rng.randf() > 0.012:
			continue
		var s := Sprite2D.new()
		s.texture = load(V12 + ("crate.png" if _rng.randf() < 0.6 else "minecart.png"))
		s.offset = Vector2(0, -8)
		s.global_position = _cell_world(c) + Vector2(0, 6)
		_level.add_child(s)
		used[c] = true
	# Monsters
	var count := 4 + n + _rng.randi_range(0, 2)
	count = mini(count, 18)
	var spawned := 0
	var tries := 0
	while spawned < count and tries < 400:
		tries += 1
		var c: Vector2i = cells[_rng.randi() % cells.size()]
		if used.has(c) or int(dist.get(c, 0)) < 10:
			continue
		var e: CharacterBody2D = EnemyScript.new()
		e.setup(_roll_enemy(n), n)
		_level.add_child(e)
		e.global_position = _cell_world(c)
		spawned += 1
	# Story pages
	if JOURNAL.has(n) and not journals.has(str(n)):
		var mid: Vector2i = far
		var best := 1 << 30
		var target := int(dist.get(far, 0)) / 2
		for c in cells:
			var dd := absi(int(dist.get(c, 0)) - target)
			if dd < best and not used.has(c):
				best = dd
				mid = c
		var page := _interactable("READ THE OLD JOURNAL", func(_p: Node2D) -> void: _read_journal(n))
		page.position = _cell_world(mid)
		_sprite_at(page, "icon_journal.png", Vector2(0, -6))
		var gl := PointLight2D.new()
		gl.texture = _glow()
		gl.texture_scale = 0.8
		gl.color = Color(1.0, 0.95, 0.7)
		gl.energy = 0.8
		page.add_child(gl)


func _roll_rock(n: int) -> String:
	var table := [["stone", 60.0], ["copper", 26.0]]
	if n >= 5:
		table.append(["iron", 18.0 + n])
	if n >= 10:
		table.append(["gold", 8.0 + n * 0.6])
	if n >= 16:
		table.append(["crystal", 6.0 + (n - 16) * 1.5])
		table.append(["gem", 1.5])
	elif n >= 8:
		table.append(["gem", 0.6])
	var total := 0.0
	for e in table:
		total += float(e[1])
	var r := _rng.randf() * total
	for e in table:
		r -= float(e[1])
		if r <= 0.0:
			return str(e[0])
	return "stone"


func _roll_enemy(n: int) -> String:
	var table := [["slime", 50.0], ["bat", 20.0 if n >= 2 else 0.0]]
	if n >= 4:
		table.append(["skeleton", 10.0 + n * 2.0])
	if n >= 10:
		table.append(["ghoul", 6.0 + n])
	var total := 0.0
	for e in table:
		total += float(e[1])
	var r := _rng.randf() * total
	for e in table:
		r -= float(e[1])
		if r <= 0.0:
			return str(e[0])
	return "slime"


class MineInteract extends Node2D:
	var prompt := ""
	var action: Callable
	var interact_range := 22.0

	func _ready() -> void:
		add_to_group("interactables")

	func can_interact(_p: Node2D) -> bool:
		return true

	func get_prompt() -> String:
		return prompt

	func interact(p: Node2D) -> void:
		if action.is_valid():
			action.call(p)


func _interactable(prompt: String, action: Callable) -> Node2D:
	var i := MineInteract.new()
	i.prompt = prompt
	i.action = action
	_level.add_child(i)
	return i


func _sprite_at(parent: Node2D, file: String, offset: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(V12 + file)
	s.offset = offset
	parent.add_child(s)
	return s


func _spawn_ladder(pos: Vector2) -> void:
	var ladder := _interactable("CLIMB DOWN", func(_p: Node2D) -> void: _go(floor_num + 1))
	ladder.position = pos
	var s := _sprite_at(ladder, "ladder.png", Vector2(0, 0))
	s.z_index = -6
	var gl := PointLight2D.new()
	gl.texture = _glow()
	gl.texture_scale = 0.9
	gl.color = Color(0.7, 0.6, 1.0)
	gl.energy = 0.7
	ladder.add_child(gl)


func _spawn_boss() -> void:
	var b: CharacterBody2D = BossScript.new()
	b.arena = Rect2(ORIGIN, Vector2(W * T, H * T))
	_level.add_child(b)
	b.global_position = ORIGIN + Vector2(W * T * 0.5, H * T * 0.38)
	b.defeated.connect(_on_boss_defeated.bind(b))


func _on_boss_defeated(b: Node2D) -> void:
	boss_defeated = true
	_spawn_ladder(b.global_position + Vector2(0, 30))
	var nd := get_tree().get_first_node_in_group("night_director")
	if nd:
		nd.set("hollow_quieted", true)
	_event("boss_defeated", {"boss": "hollow_king"})
	var hud := get_tree().get_first_node_in_group("hud_ui")
	if hud:
		hud.show_hud_message("The Hollow quiets. Fewer dead will rise each night.", 5.0)
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").call_deferred("save_game")


func _read_journal(n: int) -> void:
	journals[str(n)] = true
	var ui := get_tree().get_first_node_in_group("dialogue_ui")
	var page: Node2D = null
	for c in _level.get_children():
		if c is MineInteract and (c as MineInteract).prompt == "READ THE OLD JOURNAL":
			page = c
	var speaker := Entrance.new()
	speaker.display_name = "Old Tomas"
	if ui:
		ui.open_dialogue(speaker, JOURNAL[n].replace("\\n", "\n"), [{"text": "KEEP IT", "action": "bye"}], func(_a: String) -> void:
			ui.close_dialogue()
			speaker.free())
	if page:
		page.queue_free()
	_sfx("quest_complete", -6.0)
	_event("journal_found", {"page": n, "total": journals.size()})


func _glow() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _event(t: String, data: Dictionary) -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit(t, data)
			break


func _sfx(n: String, db: float) -> void:
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play(n, db)


# ==========================================================================
# Save / load
# ==========================================================================

func get_save_data() -> Dictionary:
	return {"deepest": deepest, "lifts": lifts, "boss": boss_defeated, "journals": journals}


func load_save_data(d: Dictionary) -> void:
	deepest = int(d.get("deepest", 0))
	lifts = d.get("lifts", [1])
	if not lifts.has(1):
		lifts.append(1)
	boss_defeated = bool(d.get("boss", false))
	journals = d.get("journals", {})
	var nd := get_tree().get_first_node_in_group("night_director")
	if nd and boss_defeated:
		nd.set("hollow_quieted", true)


## A save made underground puts the player back at the mine entrance.
func _on_session_started(root: Node, _is_new: bool) -> void:
	if root != _game:
		return
	var p := _player()
	if p and p.global_position.x < ORIGIN.x + W * T + 2000.0:
		p.global_position = ENTRANCE_POS + Vector2(0, 14)
		var cam: Camera2D = p.get_node_or_null("Camera2D")
		if cam:
			cam.reset_smoothing()
