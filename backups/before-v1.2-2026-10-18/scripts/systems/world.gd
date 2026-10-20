extends Node2D

## World — the lived-in parts of Night Harvest's map (v1.1).
##
##  * House interiors: each enterable house has its own furnished room, built from
##    Assets/HouseInterior/HouseInteriorA.png. Rooms live far away from the map
##    (ROOMS_ORIGIN) and doors teleport the player with a fade.
##  * Ken's bed now sits inside the farmhouse.
##  * Villagers with schedules (out by day, home at night), dialogue and shops.
##  * A market stall for Rosa and a notice board.
##
## Coordinates below are global positions measured on the map in Scenes/game.tscn.

const UIKit = preload("res://scripts/systems/ui_kit.gd")
const DoorScript = preload("res://scripts/systems/door.gd")
const NPCScript = preload("res://scripts/systems/npc.gd")
const StallScript = preload("res://scripts/systems/stall.gd")
const Characters = preload("res://scripts/systems/characters.gd")
const GraveyardScript = preload("res://scripts/systems/graveyard.gd")

const INTERIOR_TEX := "res://Assets/HouseInterior/HouseInteriorA.png"
const ROOMS_ORIGIN := Vector2(6000, 4000)
const TILE := 32

## Furniture atlas regions in HouseInteriorA.png and their solid footprint
## (width, height) measured up from the sprite's bottom edge. [0,0] = walk-through.
const FURNITURE := {
	"bed": [Rect2(135, 37, 19, 44), Vector2(19, 30)],
	"table_long": [Rect2(45, 38, 38, 26), Vector2(36, 12)],
	"table_round": [Rect2(5, 35, 23, 29), Vector2(20, 10)],
	"table_tall": [Rect2(101, 42, 22, 48), Vector2(22, 34)],
	"nightstand": [Rect2(164, 43, 22, 21), Vector2(20, 10)],
	"wardrobe": [Rect2(197, 34, 22, 29), Vector2(22, 12)],
	"kitchen": [Rect2(230, 32, 21, 32), Vector2(21, 12)],
	"shelf": [Rect2(2, 67, 28, 15), Vector2(28, 8)],
	"bench": [Rect2(34, 72, 28, 10), Vector2(28, 6)],
	"chair_back": [Rect2(40, 3, 16, 29), Vector2(0, 0)],
	"chair_left": [Rect2(72, 3, 16, 29), Vector2(0, 0)],
	"chair_right": [Rect2(104, 3, 16, 29), Vector2(0, 0)],
	"throne": [Rect2(136, 1, 16, 31), Vector2(14, 8)],
	"chair_red": [Rect2(167, 3, 16, 29), Vector2(0, 0)],
	"stool": [Rect2(10, 18, 12, 14), Vector2(0, 0)],
	"window": [Rect2(72, 72, 17, 16), Vector2(0, 0)],
	"window_green": [Rect2(72, 102, 17, 18), Vector2(0, 0)],
	"painting": [Rect2(70, 134, 21, 16), Vector2(0, 0)],
	"mirror": [Rect2(103, 129, 16, 31), Vector2(14, 6)],
	"chest": [Rect2(167, 74, 18, 16), Vector2(18, 10)],
	"chest_gold": [Rect2(199, 73, 18, 17), Vector2(18, 10)],
	"barrel": [Rect2(228, 68, 24, 28), Vector2(22, 12)],
	"sack": [Rect2(6, 108, 20, 20), Vector2(16, 8)],
	"sack2": [Rect2(39, 109, 19, 19), Vector2(16, 8)],
	"vase": [Rect2(105, 117, 14, 11), Vector2(0, 0)],
	"pot": [Rect2(10, 181, 9, 9), Vector2(0, 0)],
	"plate": [Rect2(10, 141, 12, 9), Vector2(0, 0)],
	"mug": [Rect2(45, 142, 7, 7), Vector2(0, 0)],
	"bench_small": [Rect2(36, 183, 24, 9), Vector2(24, 6)],
}
const WALLS := {"wood": Rect2(192, 96, 32, 32), "stone": Rect2(224, 96, 32, 32), "plain": Rect2(160, 96, 32, 32), "window": Rect2(128, 96, 32, 32)}
const FLOORS := {"wood": Rect2(192, 128, 32, 32), "stone": Rect2(224, 128, 32, 32)}

## Houses on the map. door: bottom-centre of the door on the map.
## items: [type, x, y] in pixels from the room's top-left floor corner (sprite bottom-centre),
## "wall:" prefix = hung on the wall (y measured from wall top).
const HOUSES := [
	{"id": "farmhouse", "name": "Your Farmhouse", "door": Vector2(-15, -102), "size": Vector2i(9, 6),
		"wall": "wood", "floor": "wood", "light": Color(1.0, 0.78, 0.5), "rug": Color("6E2E2E"),
		"items": [["wall:window", 64, 30], ["wall:window", 224, 30], ["wall:painting", 144, 26],
			["wardrobe", 24, 70], ["kitchen", 96, 70], ["barrel", 124, 70],
			["table_round", 70, 140], ["chair_left", 52, 140], ["chair_right", 88, 140],
			["nightstand", 214, 64], ["shelf", 30, 186], ["sack", 262, 186], ["vase", 214, 52]]},
	{"id": "barn", "name": "Barn", "door": Vector2(-395, -118), "size": Vector2i(10, 6),
		"wall": "wood", "floor": "wood", "light": Color(1.0, 0.85, 0.55), "rug": Color(0, 0, 0, 0),
		"items": [["barrel", 26, 70], ["barrel", 52, 70], ["sack", 90, 66], ["sack2", 112, 66], ["sack", 290, 66],
			["table_long", 160, 150], ["stool", 150, 168], ["barrel", 296, 190], ["sack2", 262, 190]],
		"chest": Vector2(220, 74)},
	{"id": "rosa", "name": "Rosa's Goods", "door": Vector2(-722, 51), "size": Vector2i(10, 6),
		"wall": "plain", "floor": "wood", "light": Color(1.0, 0.8, 0.55), "rug": Color("3E4E7A"),
		"items": [["wall:window_green", 60, 30], ["wall:window_green", 260, 30],
			["shelf", 30, 68], ["shelf", 120, 68], ["shelf", 200, 68], ["barrel", 290, 72],
			["table_long", 140, 118], ["table_long", 180, 118], ["sack", 24, 186], ["sack2", 46, 186], ["chest_gold", 290, 186]],
		"shopkeeper_spot": Vector2(160, 92)},
	{"id": "ben", "name": "Ben's Forge", "door": Vector2(-1134, 458), "size": Vector2i(9, 6),
		"wall": "stone", "floor": "stone", "light": Color(1.0, 0.6, 0.3), "rug": Color(0, 0, 0, 0),
		"items": [["table_tall", 40, 110], ["barrel", 90, 70], ["barrel", 114, 70], ["chest", 250, 70],
			["table_long", 160, 130], ["stool", 200, 150], ["sack", 262, 186], ["mirror", 20, 186]],
		"shopkeeper_spot": Vector2(150, 104)},
	{"id": "pedro", "name": "Mayor Pedro's House", "door": Vector2(-916, 445), "size": Vector2i(11, 7),
		"wall": "window", "floor": "wood", "light": Color(1.0, 0.82, 0.6), "rug": Color("5E2E52"),
		"items": [["wall:painting", 176, 26], ["throne", 176, 70], ["table_long", 176, 132],
			["chair_red", 140, 134], ["chair_red", 212, 134], ["shelf", 36, 70], ["shelf", 316, 70],
			["bed", 320, 200], ["nightstand", 290, 160], ["wardrobe", 30, 220]]},
	{"id": "lina", "name": "Lina's House", "door": Vector2(-709, 248), "size": Vector2i(8, 6),
		"wall": "wood", "floor": "wood", "light": Color(1.0, 0.8, 0.62), "rug": Color("2E5E4E"),
		"items": [["wall:window", 128, 30], ["bed", 30, 112], ["nightstand", 62, 64], ["mirror", 228, 74],
			["table_round", 150, 140], ["stool", 130, 150], ["vase", 150, 128], ["wardrobe", 200, 186]]},
	{"id": "abandoned", "name": "Old Tomas' House", "door": Vector2(-564, 474), "size": Vector2i(8, 6),
		"wall": "stone", "floor": "stone", "light": Color(0.6, 0.65, 1.0), "rug": Color(0, 0, 0, 0),
		"items": [["barrel", 26, 70], ["sack2", 60, 186], ["table_round", 150, 120], ["chair_back", 150, 100],
			["pot", 210, 70], ["plate", 150, 112]],
		"chest": Vector2(220, 74), "dim": true},
	{"id": "limuel", "name": "Guest House", "door": Vector2(-1062, 248), "size": Vector2i(8, 6),
		"wall": "plain", "floor": "wood", "light": Color(0.85, 0.9, 1.0), "rug": Color("4A3A2A"),
		"items": [["wall:window", 64, 30], ["bed", 220, 112], ["table_long", 90, 130], ["chair_back", 90, 112],
			["mug", 80, 122], ["shelf", 30, 186], ["vase", 230, 186]]},
]

## Doors that exist on the map but stay closed.
const LOCKED_DOORS := [
	[Vector2(-560, -120), "The storage cottage is locked."],
	[Vector2(61, -186), "Just old tools in the shed. It's locked."],
	[Vector2(-983, 198), "The side door is bolted shut."],
	[Vector2(-371, 348), "Nobody answers."],
]

var rooms: Dictionary = {}   ## id -> {node, rect (global floor rect), spawn, exit, house}
var player_room: String = ""  ## "" = outdoors
var _tex: Texture2D
var _img: Image
var _tile_cache: Dictionary = {}
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy := false
var _outdoor_limits: Array = []
var _game: Node2D
var save_key := "world"
var _given_loot: Dictionary = {}


func _ready() -> void:
	add_to_group("nh_world")
	add_to_group("save_extension")
	y_sort_enabled = true
	_game = get_parent() as Node2D
	_tex = load(INTERIOR_TEX)
	_img = _tex.get_image()
	_build_fade()
	var i := 0
	for h in HOUSES:
		_build_room(h, ROOMS_ORIGIN + Vector2(i * 900, 0))
		i += 1
	for d in LOCKED_DOORS:
		var door: Node2D = DoorScript.new()
		door.locked = true
		door.locked_text = d[1]
		add_child(door)
		door.global_position = d[0] + Vector2(0, -6)
	_move_bed_inside()
	_spawn_villagers()
	_spawn_stall()
	var gy: Node2D = GraveyardScript.new()
	gy.name = "Graveyard"
	add_child(gy)
	if has_node("/root/SaveManager"):
		SaveManager.session_started.connect(_on_session_started)


# ==========================================================================
# Rooms
# ==========================================================================

func _tile_tex(region: Rect2) -> ImageTexture:
	var key := str(region)
	if not _tile_cache.has(key):
		_tile_cache[key] = ImageTexture.create_from_image(_img.get_region(Rect2i(region)))
	return _tile_cache[key]


func _build_room(h: Dictionary, origin: Vector2) -> void:
	var size_t: Vector2i = h["size"]
	var w := float(size_t.x * TILE)
	var fh := float(size_t.y * TILE)
	var wall_h := 40.0
	var room := Node2D.new()
	room.name = "Room_" + str(h["id"])
	room.y_sort_enabled = true
	add_child(room)
	room.global_position = origin
	# Pure black void around the room
	var void_rect := ColorRect.new()
	void_rect.color = Color("0B0806")
	void_rect.position = Vector2(-400, -400)
	void_rect.size = Vector2(w + 800, fh + wall_h + 800)
	void_rect.z_index = -20
	room.add_child(void_rect)
	# Floor
	var floor_rect := TextureRect.new()
	floor_rect.texture = _tile_tex(FLOORS[h["floor"]])
	floor_rect.stretch_mode = TextureRect.STRETCH_TILE
	floor_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_rect.position = Vector2(0, wall_h)
	floor_rect.size = Vector2(w, fh)
	floor_rect.z_index = -19
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(floor_rect)
	# Soft shadow under the wall
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.28)
	shade.position = Vector2(0, wall_h)
	shade.size = Vector2(w, 6)
	shade.z_index = -18
	room.add_child(shade)
	# Back wall
	var wall := TextureRect.new()
	wall.texture = _tile_tex(WALLS[h["wall"]])
	wall.stretch_mode = TextureRect.STRETCH_TILE
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wall.position = Vector2(0, wall_h - 32)
	wall.size = Vector2(w, 32)
	wall.z_index = -18
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(wall)
	var trim := ColorRect.new()
	trim.color = Color("3A2418")
	trim.position = Vector2(0, 0)
	trim.size = Vector2(w, wall_h - 32)
	trim.z_index = -18
	room.add_child(trim)
	# Outer frame
	for r in [Rect2(-6, -6, w + 12, 6), Rect2(-6, 0, 6, fh + wall_h + 6), Rect2(w, 0, 6, fh + wall_h + 6),
			Rect2(-6, fh + wall_h, w * 0.5 - 14 + 6, 6), Rect2(w * 0.5 + 14, fh + wall_h, w * 0.5 - 14 + 6, 6)]:
		var fr := ColorRect.new()
		fr.color = Color("1E1209")
		fr.position = r.position
		fr.size = r.size
		fr.z_index = -17
		room.add_child(fr)
	# Rug
	var rug_col: Color = h.get("rug", Color(0, 0, 0, 0))
	if rug_col.a > 0.0:
		var rug := ColorRect.new()
		rug.color = rug_col.darkened(0.35)
		rug.position = Vector2(w * 0.5 - 52, wall_h + fh * 0.5 - 30)
		rug.size = Vector2(104, 60)
		rug.z_index = -17
		room.add_child(rug)
		var rug_in := ColorRect.new()
		rug_in.color = rug_col
		rug_in.position = rug.position + Vector2(4, 4)
		rug_in.size = rug.size - Vector2(8, 8)
		rug_in.z_index = -17
		room.add_child(rug_in)
		var rug_line := ColorRect.new()
		rug_line.color = rug_col.lightened(0.25)
		rug_line.position = rug.position + Vector2(10, 10)
		rug_line.size = rug.size - Vector2(20, 20)
		rug_line.z_index = -17
		room.add_child(rug_line)
		var rug_core := ColorRect.new()
		rug_core.color = rug_col
		rug_core.position = rug.position + Vector2(12, 12)
		rug_core.size = rug.size - Vector2(24, 24)
		rug_core.z_index = -17
		room.add_child(rug_core)
	# Door mat at the exit
	var mat := ColorRect.new()
	mat.color = Color("7A5A30")
	mat.position = Vector2(w * 0.5 - 14, wall_h + fh - 10)
	mat.size = Vector2(28, 10)
	mat.z_index = -17
	room.add_child(mat)
	var mat_in := ColorRect.new()
	mat_in.color = Color("A0703E")
	mat_in.position = mat.position + Vector2(2, 2)
	mat_in.size = mat.size - Vector2(4, 4)
	mat_in.z_index = -17
	room.add_child(mat_in)
	var glow := _radial(Color(1.0, 0.9, 0.7, 0.22), Vector2(80, 40))
	glow.position = Vector2(w * 0.5 - 40, wall_h + fh - 20)
	glow.z_index = -16
	room.add_child(glow)
	# Walls (collision)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	room.add_child(body)
	for r in [Rect2(-40, -40, w + 80, wall_h + 40 + 4), Rect2(-40, 0, 40, fh + wall_h + 40), Rect2(w, 0, 40, fh + wall_h + 40),
			Rect2(-40, fh + wall_h, w * 0.5 - 14 + 40, 40), Rect2(w * 0.5 + 14, fh + wall_h, w * 0.5 - 14 + 40, 40),
			Rect2(w * 0.5 - 14, fh + wall_h + 14, 28, 26)]:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		cs.position = r.position + r.size * 0.5
		body.add_child(cs)
	# Furniture
	for it in h["items"]:
		var type: String = it[0]
		var on_wall := type.begins_with("wall:")
		if on_wall:
			type = type.substr(5)
		_place_furniture(room, body, type, Vector2(it[1], (it[2] if on_wall else wall_h + float(it[2]) - 40.0)), on_wall)
	# Warm light (visible at night through the day/night CanvasModulate)
	var light := PointLight2D.new()
	light.texture = _radial_texture()
	light.texture_scale = maxf(w, fh) / 110.0
	light.color = h.get("light", Color(1, 0.8, 0.55))
	light.energy = 0.55 if h.get("dim", false) else 0.9
	light.position = Vector2(w * 0.5, wall_h + fh * 0.45)
	room.add_child(light)
	# Exit
	var exit: Node2D = DoorScript.new()
	exit.is_exit = true
	exit.interact_range = 26.0
	exit.target_position = h["door"] + Vector2(0, 12)
	room.add_child(exit)
	exit.position = Vector2(w * 0.5, wall_h + fh - 6)
	var trigger := Area2D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 0xFFFFFFFF
	var tcs := CollisionShape2D.new()
	var trs := RectangleShape2D.new()
	trs.size = Vector2(26, 6)
	tcs.shape = trs
	trigger.add_child(tcs)
	room.add_child(trigger)
	trigger.position = Vector2(w * 0.5, wall_h + fh + 9)
	trigger.body_entered.connect(func(b: Node) -> void:
		if b.is_in_group("player") and not _busy and player_room == str(h["id"]):
			travel(b, exit))
	# Outside door
	var door: Node2D = DoorScript.new()
	door.door_id = h["id"]
	door.display_name = h["name"]
	door.target_room = room
	door.target_position = origin + Vector2(w * 0.5, wall_h + fh - 22)
	add_child(door)
	door.global_position = h["door"] + Vector2(0, -6)
	var room_rect := Rect2(origin, Vector2(w, fh + wall_h))
	rooms[h["id"]] = {"node": room, "rect": room_rect, "spawn": door.target_position, "exit": exit, "door": door, "house": h}
	# Optional chest (barn storage, abandoned loot)
	if h.has("chest"):
		var chest_scene: PackedScene = load("res://Scenes/Objects/chest.tscn")
		var chest := chest_scene.instantiate()
		chest.name = "Chest_" + str(h["id"])
		room.add_child(chest)
		chest.position = Vector2(h["chest"].x, wall_h + h["chest"].y - 40.0)


func _place_furniture(room: Node2D, body: StaticBody2D, type: String, pos: Vector2, on_wall: bool) -> void:
	if not FURNITURE.has(type):
		return
	var def: Array = FURNITURE[type]
	var region: Rect2 = def[0]
	var foot: Vector2 = def[1]
	var spr := Sprite2D.new()
	spr.texture = UIKit.atlas(_tex, region)
	spr.centered = false
	spr.offset = Vector2(-region.size.x * 0.5, -region.size.y)
	room.add_child(spr)
	spr.position = pos
	if on_wall:
		spr.z_index = -17
		spr.position.y = pos.y + region.size.y * 0.5
		return
	if foot.x > 0.0:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = foot
		cs.shape = rs
		cs.position = pos + Vector2(0, -foot.y * 0.5)
		body.add_child(cs)


func _radial(c: Color, sz: Vector2) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([c, Color(c, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var r := TextureRect.new()
	r.texture = t
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return r


func _radial_texture() -> GradientTexture2D:
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


func room_rect(id: String) -> Rect2:
	return rooms[id]["rect"] if rooms.has(id) else Rect2()


func room_at(pos: Vector2) -> String:
	for id in rooms:
		if (rooms[id]["rect"] as Rect2).grow(48).has_point(pos):
			return id
	return ""


func is_player_indoors() -> bool:
	return player_room != ""


# ==========================================================================
# Bed moves into the farmhouse
# ==========================================================================

func _move_bed_inside() -> void:
	var room: Dictionary = rooms.get("farmhouse", {})
	if room.is_empty():
		return
	var origin: Vector2 = (room["rect"] as Rect2).position
	var bed := _game.get_node_or_null("Bed") as Node2D
	if bed:
		bed.global_position = origin + Vector2(250, 78)
	var stool := _game.get_node_or_null("Stool") as Node2D
	if stool:
		stool.global_position = origin + Vector2(214, 150)


# ==========================================================================
# Travelling through doors
# ==========================================================================

func _build_fade() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 80
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)


func travel(player: Node2D, door: Node2D) -> void:
	if _busy:
		return
	_busy = true
	player.set("input_locked", true)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("ui_click")
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.22)
	tw.tween_callback(func() -> void:
		var going_in: bool = not door.get("is_exit")
		var dest: Vector2 = door.get("target_position")
		player.global_position = dest
		player.velocity = Vector2.ZERO
		if going_in:
			player.set("last_direction", Vector2.UP)
			_enter_room_state(player, str(door.get("door_id")))
		else:
			player.set("last_direction", Vector2.DOWN)
			_exit_room_state(player)
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.reset_smoothing())
	tw.tween_interval(0.12)
	tw.tween_property(_fade, "color:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		player.set("input_locked", false)
		_busy = false)


func _enter_room_state(player: Node2D, id: String) -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if player_room == "" and cam:
		_outdoor_limits = [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
	player_room = id
	var r: Rect2 = rooms[id]["rect"]
	if cam:
		var c := r.get_center()
		var half := get_viewport_rect().size / cam.zoom * 0.5
		cam.limit_left = int(minf(r.position.x - 8, c.x - half.x))
		cam.limit_right = int(maxf(r.end.x + 8, c.x + half.x))
		cam.limit_top = int(minf(r.position.y - 36, c.y - half.y))
		cam.limit_bottom = int(maxf(r.end.y + 44, c.y + half.y))
	_set_indoor_lighting(true)
	_notify("player_entered_house", id)


func _exit_room_state(player: Node2D) -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam and _outdoor_limits.size() == 4:
		cam.limit_left = _outdoor_limits[0]
		cam.limit_top = _outdoor_limits[1]
		cam.limit_right = _outdoor_limits[2]
		cam.limit_bottom = _outdoor_limits[3]
	var was := player_room
	player_room = ""
	_set_indoor_lighting(false)
	_notify("player_left_house", was)


func _set_indoor_lighting(on: bool) -> void:
	for env in get_tree().get_nodes_in_group("environment_manager"):
		if env.has_method("set_indoors"):
			env.set_indoors(on)
	if has_node("/root/Music"):
		get_node("/root/Music").set_indoors(on)


func _notify(event: String, id: String) -> void:
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit(event, {"house": id})
			break


## After loading a save, the player may already be standing inside a house.
func sync_player_location() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	var id := room_at(player.global_position)
	if id != "" and player_room != id:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam and _outdoor_limits.is_empty():
			_outdoor_limits = [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
		_enter_room_state(player, id)
		if cam:
			cam.reset_smoothing()


# ==========================================================================
# Villagers
# ==========================================================================

func _spawn_villagers() -> void:
	var cast := [
		{"id": "rosa", "name": "Rosa", "role": "general", "day": Vector2(-640, 80), "radius": 4.0, "house": "rosa",
			"from": 7, "until": 18, "lines": [
				"Morning, farmer! Fresh seeds and Rosa's bread, right here.",
				"Slow crops like corn and watermelon sell for the most. Worth the wait!",
				"I close the stall at six and go inside. Knock on my door if you need me at night.",
				"Watermelons fetch 22 gold. My late husband swore by them.",
				func() -> String: return _rosa_dynamic_line()]},
		{"id": "ben", "name": "Ben", "role": "smith", "day": Vector2(-1096, 467), "radius": 10.0, "house": "ben",
			"from": 6, "until": 19, "lines": [
				"Barricades buy you time. Spike traps make them pay for it.",
				"Zombies go for crops first. Wall your field and they'll have to chew through.",
				"My scarecrow crossbows shoot whatever moves at night. Mind they don't run out of patience.",
				"A steel sword cuts through those rotters twice as fast. Not cheap, though.",
				func() -> String: return _ben_dynamic_line()]},
		{"id": "pedro", "name": "Mayor Pedro", "role": "", "day": Vector2(-720, 395), "radius": 36.0, "house": "pedro",
			"from": 7, "until": 18, "lines": [
				"Welcome to Harvest Hollow. The town's quieter since the dead started walking.",
				"They rise from the old quarry in the north-east, and from Old Hollow Cemetery to the north-west.",
				"Each night there are more of them. The crypt glows blue when the dead are restless.",
				"Every seventh night the moon turns red. Blood Moon. Lock your doors... or fight.",
				"Old Tomas left his house unlocked when he vanished. Maybe he left something useful.",
				"Survive, farmer, and this town might just have a future.",
				func() -> String: return _pedro_dynamic_line()]},
		{"id": "lina", "name": "Lina", "role": "", "day": Vector2(-560, 170), "radius": 44.0, "house": "lina",
			"from": 8, "until": 18, "lines": [
				"Oh! Hi! Are you the new farmer? Everyone's talking about you.",
				"Water your crops after planting, or they won't grow at all!",
				"Torches keep the dark away. I keep three by my bed. Okay, maybe five.",
				"Hold SHIFT to run. Trust me, you'll need it at night.",
				"If you get hungry, eat something! Carrots, bread, anything.",
			]},
	]
	for c in cast:
		var npc: CharacterBody2D = NPCScript.new()
		npc.npc_id = c["id"]
		npc.display_name = c["name"]
		npc.role = c["role"]
		npc.sheet = load(Characters.VILLAGER_SHEETS[c["id"]])
		npc.day_spot = c["day"]
		npc.day_radius = c["radius"]
		npc.day_from = c["from"]
		npc.day_until = c["until"]
		npc.lines = c["lines"]
		var room: Dictionary = rooms.get(c["house"], {})
		if not room.is_empty():
			var house: Dictionary = room["house"]
			var r: Rect2 = room["rect"]
			npc.night_spot = r.position + (Vector2(house["shopkeeper_spot"]) if house.has("shopkeeper_spot") else Vector2(r.size.x * 0.5, r.size.y * 0.55))
		add_child(npc)
		npc.snap_to_schedule()
	# The developer, hanging out in the guest house (row 0 of limuel(2).png is a front idle loop).
	var dev: CharacterBody2D = NPCScript.new()
	dev.npc_id = "limuel"
	dev.display_name = "Limuel"
	dev.sheet = load("res://Assets/Player/limuel(2).png")
	dev.idle_strip = {"row": 0, "frames": 8}
	dev.walk_speed = 0.0
	var gr: Rect2 = rooms["limuel"]["rect"]
	dev.day_spot = gr.position + Vector2(130, 110)
	dev.night_spot = Vector2.ZERO
	dev.day_radius = 0.0
	dev.lines = [
		"Hey! I'm Limuel, I write the code that keeps this town running.",
		"Shh... between us, the zombies follow 4-way paths. Diagonals confuse them.",
		"Thanks for playing Night Harvest. Tell the team what you think!",
		"If something breaks, check SETTINGS > UPDATES. We fix things fast.",
	]
	add_child(dev)
	dev.snap_to_schedule()


func _spawn_stall() -> void:
	var stall: Node2D = StallScript.new()
	stall.shop_id = "general"
	stall.keeper_id = "rosa"
	add_child(stall)
	stall.global_position = Vector2(-640, 98)


func _nights() -> int:
	var d := get_tree().get_first_node_in_group("night_director")
	return int(d.get("nights_survived")) if d else 0


func _rosa_dynamic_line() -> String:
	var n := _nights()
	if n == 0:
		return "First night coming? Buy a few extra seeds. Crops are gold."
	return "You made it through %d night%s! Treat yourself to some bread." % [n, "" if n == 1 else "s"]


func _ben_dynamic_line() -> String:
	var n := _nights()
	if n < 1:
		return "Survive one night and I'll sell you a scarecrow crossbow."
	if n < 2:
		return "Two nights and I'll trust you with steel. Keep breathing."
	return "Night %d coming. Stock up, the brutes hit barricades hard." % (n + 1)


func _pedro_dynamic_line() -> String:
	var d := get_tree().get_first_node_in_group("night_director")
	if d and d.has_method("nights_until_blood_moon"):
		var k: int = d.nights_until_blood_moon()
		if k == 0:
			return "Tonight the moon bleeds. Stay sharp, farmer."
		return "%d night%s until the next Blood Moon." % [k, "" if k == 1 else "s"]
	return "Stay safe out there."


# ==========================================================================
# Save / load
# ==========================================================================

func _on_session_started(root: Node, is_new: bool) -> void:
	if root != _game:
		return
	sync_player_location()
	if is_new and not _given_loot.get("abandoned", false):
		_given_loot["abandoned"] = true
		var chest := find_child("Chest_abandoned", true, false)
		if chest and chest.has_method("add_item"):
			var db = load("res://scripts/item_database.gd")
			for pair in [["herbal_tonic", 2], ["barricade", 4], ["corn_seed", 4], ["torch", 3]]:
				var it = db.get_item(pair[0])
				if it:
					chest.add_item(it, pair[1])


func get_save_data() -> Dictionary:
	return {"loot": _given_loot}


func load_save_data(d: Dictionary) -> void:
	_given_loot = d.get("loot", {})
