extends Node

## FarmLayout (v1.2) — keeps the farm tidy: animals live in their own pastures
## instead of wandering over the crop field, so the whole field is yours to plant.

## The main crop field next to the farmhouse (global coordinates).
const FIELD := Rect2(-56, -44, 232, 176)
## Where each kind of animal lives now: [centre, roam radius]
const PASTURES := {
	"chicken": [Vector2(128, -122), 30.0],
	"pig": [Vector2(400, 395), 45.0],
	"cow": [Vector2(494, -22), 50.0],
	"sheep": [Vector2(470, -10), 50.0],
}

var _t := 0.0


func _ready() -> void:
	add_to_group("farm_layout")


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 2.0
	for a in get_tree().get_nodes_in_group("animals"):
		if not (a is Node2D) or a.has_meta("nh_rehomed"):
			continue
		if not bool(a.get("_home_initialized")):
			continue
		var home: Vector2 = a.get("_home")
		if not FIELD.grow(24).has_point(home):
			a.set_meta("nh_rehomed", true)
			continue
		var kind := _kind(a)
		var p: Array = PASTURES.get(kind, PASTURES["chicken"])
		var spot: Vector2 = p[0] + Vector2(randf_range(-12, 12), randf_range(-8, 8))
		a.set("_home", spot)
		a.set("roam_radius", float(p[1]))
		a.set_meta("nh_rehomed", true)
		# Walk there on their own if close, otherwise just appear in the pasture
		if (a as Node2D).global_position.distance_to(spot) > 160.0:
			(a as Node2D).global_position = spot


func _kind(a: Node) -> String:
	var path := str(a.scene_file_path).to_lower()
	for k in PASTURES:
		if path.find(k) != -1:
			return k
	return "chicken"
