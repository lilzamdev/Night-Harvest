extends StaticBody2D

## Decor (v1.3.1): furniture, lamps, flower boxes, rugs and flowers you craft (or pick)
## and place to make your house and farm your own. Placed like blocks (16 px grid);
## take one back with any tool or your hands. Wall pieces (windows, paintings, the
## mirror) hang on a wall block you built.

const ItemDB = preload("res://scripts/item_database.gd")
const WorldItemScene = preload("res://Scenes/world_item.tscn")
const ORIGIN := Vector2(28, 47)

const HI := "res://Assets/HouseInterior/HouseInteriorA.png"
const OD := "res://Assets/Pixel Lands Village Demo/objects_demo.png"
const ODF := "res://Assets/Outdoor decoration/Outdoor_Decor_Free.png"
const VD := "res://Assets/Vectoriath Asset/16x16/Tilesets (Compact)/vectoraith_tileset_farmingsims_details.png"
const GEN := "res://Assets/Generated/v131/"

## id -> sheet, region, w (cells), solid, light, wall, flat (lies on the floor), name, desc
const KINDS := {
	# --- furniture
	"wooden_chair": {"tex": HI, "r": Rect2(40, 3, 16, 29), "name": "Wooden Chair", "desc": "A simple chair for your table."},
	"armchair": {"tex": HI, "r": Rect2(136, 1, 16, 31), "name": "Red Armchair", "desc": "A cushioned chair. Very comfy."},
	"stool": {"tex": HI, "r": Rect2(10, 18, 12, 14), "name": "Stool", "desc": "A little wooden stool."},
	"round_table": {"tex": HI, "r": Rect2(5, 35, 23, 29), "name": "Round Table", "desc": "A round wooden table."},
	"long_table": {"tex": HI, "r": Rect2(45, 38, 38, 26), "w": 2, "name": "Long Table", "desc": "A long dining table."},
	"bookshelf": {"tex": HI, "r": Rect2(2, 67, 28, 15), "w": 2, "name": "Book Shelf", "desc": "A low shelf full of books."},
	"cupboard": {"tex": HI, "r": Rect2(197, 34, 22, 29), "name": "Cupboard", "desc": "A tall wooden cupboard."},
	"pantry_shelf": {"tex": HI, "r": Rect2(230, 32, 21, 32), "name": "Pantry Shelf", "desc": "Shelves with jars and pumpkins."},
	"nightstand": {"tex": HI, "r": Rect2(164, 43, 22, 21), "name": "Nightstand", "desc": "Goes next to your bed."},
	"barrel": {"tex": HI, "r": Rect2(225, 68, 31, 30), "w": 2, "name": "Barrel", "desc": "A big oak barrel."},
	"grain_sack": {"tex": HI, "r": Rect2(6, 108, 20, 20), "name": "Grain Sack", "desc": "A sack of grain for the farmhouse."},
	"bench": {"tex": OD, "r": Rect2(82, 33, 28, 24), "w": 2, "name": "Wooden Bench", "desc": "Sit down and watch the sunset."},
	"firewood": {"tex": OD, "r": Rect2(1, 64, 14, 15), "name": "Firewood Stack", "desc": "Neatly stacked logs."},
	"water_bucket": {"tex": OD, "r": Rect2(51, 65, 10, 15), "name": "Water Bucket", "desc": "A bucket of fresh water."},
	"wooden_sign": {"tex": OD, "r": Rect2(101, 6, 21, 16), "name": "Wooden Sign", "desc": "A sign with an arrow."},
	# --- lights
	"street_lamp": {"tex": OD, "r": Rect2(33, 32, 13, 48), "light": 1.1, "name": "Street Lamp", "desc": "Lights up the night around it."},
	"crate_lantern": {"tex": OD, "r": Rect2(49, 32, 15, 32), "light": 0.8, "name": "Crate Lantern", "desc": "A lantern on a crate. Warm light at night."},
	# --- flower boxes and pots
	"flower_box_red": {"tex": OD, "r": Rect2(128, 67, 16, 17), "name": "Red Flower Box", "desc": "A planter of red flowers."},
	"flower_box_pink": {"tex": OD, "r": Rect2(144, 67, 16, 17), "name": "Pink Flower Box", "desc": "A planter of pink flowers."},
	"flower_box_white": {"tex": OD, "r": Rect2(128, 36, 16, 16), "name": "White Flower Box", "desc": "A planter of daisies."},
	"flower_box_yellow": {"tex": OD, "r": Rect2(144, 36, 16, 16), "name": "Yellow Flower Box", "desc": "A planter of yellow flowers."},
	"pot_red": {"tex": ODF, "r": Rect2(32, 128, 16, 16), "name": "Potted Red Flower", "desc": "A red flower in a clay pot."},
	"pot_yellow": {"tex": ODF, "r": Rect2(48, 128, 16, 16), "name": "Potted Yellow Flower", "desc": "A yellow flower in a clay pot."},
	# --- flowers you pick in the wild and plant again (you can walk over them)
	"red_flower": {"tex": ODF, "r": Rect2(0, 128, 16, 16), "solid": false, "name": "Red Tulip", "desc": "Picked in the wild. Plant it anywhere, or use it as dye."},
	"yellow_flower": {"tex": ODF, "r": Rect2(16, 128, 16, 16), "solid": false, "name": "Yellow Tulip", "desc": "Picked in the wild. Plant it anywhere, or use it as dye."},
	"daisy": {"tex": ODF, "r": Rect2(16, 16, 16, 16), "solid": false, "name": "Daisy", "desc": "A little white wildflower."},
	"buttercup": {"tex": ODF, "r": Rect2(0, 16, 16, 16), "solid": false, "name": "Buttercup", "desc": "A yellow meadow flower."},
	"blue_flower": {"tex": VD, "r": Rect2(130, 114, 12, 12), "solid": false, "name": "Bluebell", "desc": "A blue forest flower. Good blue dye."},
	"pink_flower": {"tex": VD, "r": Rect2(66, 97, 11, 14), "solid": false, "name": "Pink Blossom", "desc": "A pink wildflower."},
	# --- rugs (lie flat on the floor)
	"rug_red": {"tex": GEN + "rug_red.png", "r": Rect2(0, 0, 32, 32), "w": 2, "h": 2, "flat": true, "solid": false, "name": "Red Rug", "desc": "A woven rug, dyed with red tulips."},
	"rug_blue": {"tex": GEN + "rug_blue.png", "r": Rect2(0, 0, 32, 32), "w": 2, "h": 2, "flat": true, "solid": false, "name": "Blue Rug", "desc": "A woven rug, dyed with bluebells."},
	# --- hung on a wall block
	"painting": {"tex": HI, "r": Rect2(70, 134, 21, 16), "wall": true, "name": "Painting", "desc": "Hang it on a wall you built."},
	"mirror": {"tex": HI, "r": Rect2(103, 129, 16, 31), "wall": true, "name": "Mirror", "desc": "Hang it on a wall you built."},
	"window": {"tex": HI, "r": Rect2(72, 72, 17, 16), "wall": true, "name": "Window", "desc": "Put it in a wall you built. Lights up at night."},
	"curtain_window": {"tex": HI, "r": Rect2(72, 102, 17, 18), "wall": true, "name": "Curtained Window", "desc": "A window with green curtains."},
}

static var _icon_cache := {}

var kind := "stool"
var anchor := Vector2i.ZERO
var is_dead := false
var _spr: Sprite2D
var _light: PointLight2D
var _work := 0.0


static func info(k: String) -> Dictionary:
	return KINDS.get(k, {})


static func size_of(k: String) -> Vector2i:
	var i: Dictionary = KINDS.get(k, {})
	return Vector2i(int(i.get("w", 1)), int(i.get("h", 1)))


static func is_wall_kind(k: String) -> bool:
	return bool(KINDS.get(k, {}).get("wall", false))


static func is_flat_kind(k: String) -> bool:
	return bool(KINDS.get(k, {}).get("flat", false)) or not bool(KINDS.get(k, {}).get("solid", true))


static func texture_of(k: String) -> Texture2D:
	if _icon_cache.has(k):
		return _icon_cache[k]
	var i: Dictionary = KINDS.get(k, {})
	if i.is_empty() or not ResourceLoader.exists(str(i["tex"])):
		return null
	var a := AtlasTexture.new()
	a.atlas = load(str(i["tex"]))
	a.region = i["r"]
	_icon_cache[k] = a
	return a


## World position the decor stands on: bottom-centre of its footprint.
static func base_for(k: String, c: Vector2i) -> Vector2:
	var sz := size_of(k)
	return ORIGIN + Vector2(c.x * 16 + sz.x * 8, c.y * 16 + 16)


func _ready() -> void:
	add_to_group("decor")
	var i := info(kind)
	collision_mask = 0
	var solid: bool = bool(i.get("solid", true)) and not is_wall_kind(kind)
	collision_layer = 1 if solid else 0
	_spr = Sprite2D.new()
	_spr.texture = texture_of(kind)
	_spr.centered = false
	var sz := size_of(kind)
	var t: Texture2D = _spr.texture
	var tw := float(t.get_width()) if t else 16.0
	var th := float(t.get_height()) if t else 16.0
	if is_flat_kind(kind) and bool(i.get("flat", false)):
		z_index = -1   # rugs lie under everything
		_spr.offset = Vector2(-tw * 0.5, -th)
	elif is_wall_kind(kind):
		# hangs on the wall face (walls are 16 x 24 px, standing on their cell)
		_spr.offset = Vector2(-tw * 0.5, -21.0 - th * 0.5)
		z_index = 1
	else:
		_spr.offset = Vector2(-tw * 0.5, -th + 1.0)
	add_child(_spr)
	if not solid:
		add_to_group("interactables")
	if solid:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(maxf(sz.x * 16.0 - 4.0, 8.0), 8.0)
		cs.shape = rs
		cs.position = Vector2(0, -4)
		add_child(cs)
	if i.has("light"):
		_add_light(float(i["light"]), th)
	elif kind in ["window", "curtain_window"]:
		_add_light(0.45, 34.0)


func _add_light(energy: float, h: float) -> void:
	_light = PointLight2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 128
	gt.height = 128
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	_light.texture = gt
	_light.texture_scale = 0.9 if energy > 0.6 else 0.45
	_light.color = Color(1.0, 0.76, 0.45)
	_light.position = Vector2(0, -h + 6.0)
	_light.set_meta("full", energy)
	add_child(_light)
	_update_light()
	var clock := get_tree().get_first_node_in_group("game_clock")
	if clock and clock.has_signal("time_updated"):
		clock.time_updated.connect(func(_h: int, _m: int) -> void: _update_light())


func _update_light() -> void:
	if _light == null:
		return
	var clock := get_tree().get_first_node_in_group("game_clock")
	var h := int(clock.get("current_hour")) if clock else 20
	var on := h >= 18 or h < 6
	_light.enabled = on
	_light.energy = float(_light.get_meta("full")) if on else 0.0


func cell() -> Vector2i:
	return anchor


# Flowers, rugs and wall pieces have no body to hit: pick them up with E instead.
var interact_range := 20.0

func can_interact(_p: Node2D) -> bool:
	return not is_dead and (collision_layer == 0)


func get_prompt() -> String:
	return "PICK UP " + str(info(kind).get("name", "")).to_upper()


func interact(_p: Node2D) -> void:
	pick_up(not _creative())


## Any tool or bare hands take decor back (it is light work).
func take_hit(_tool_power: int = 1, _hit_dir: Vector2 = Vector2.ZERO) -> bool:
	if is_dead:
		return false
	_work += 1.0
	var tw := create_tween()
	tw.tween_property(_spr, "position", Vector2(1.5, 0), 0.04)
	tw.tween_property(_spr, "position", Vector2.ZERO, 0.05)
	if has_node("/root/GameAudio"):
		get_node("/root/GameAudio").play("ui_click", -10.0)
	if _work >= 2.0 or _creative():
		pick_up(not _creative())
	return true


func pick_up(drop: bool = true) -> void:
	if is_dead:
		return
	is_dead = true
	if drop:
		var it = ItemDB.get_item(kind)
		if it:
			var w := WorldItemScene.instantiate()
			get_parent().add_child(w)
			w.global_position = global_position + Vector2(0, -4)
			w.call("set_item", it, 1)
	for bus in get_tree().get_nodes_in_group("event_bus"):
		if bus.has_signal("gameplay_event"):
			bus.gameplay_event.emit("block_removed", {"kind": kind, "by_player": true})
			break
	queue_free()


func _creative() -> bool:
	var gm := get_tree().get_first_node_in_group("game_mode")
	return gm != null and gm.get("creative") == true


func get_save_data() -> Dictionary:
	return {"k": kind, "x": anchor.x, "y": anchor.y}
