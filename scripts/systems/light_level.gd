extends RefCounted

## LightLevel (v1.4.1): how dark the world looks right now, 0 (bright day) .. 1 (night).
## Read from the day/night tint, so dusk, dawn, thunderstorms, heavy rain and the mines
## all count - not just the clock. Every lamp, lantern and lit window uses level() to
## decide how bright to shine, so lights come on whenever it actually gets dark.

static var _cm: WeakRef = null
static var _glow: GradientTexture2D = null


static func _modulate(tree: SceneTree) -> CanvasModulate:
	var cm: CanvasModulate = _cm.get_ref() if _cm else null
	if cm == null or not is_instance_valid(cm) or not cm.is_inside_tree():
		cm = null
		var scene := tree.current_scene if tree else null
		if scene:
			cm = scene.get_node_or_null("DayNightModulate") as CanvasModulate
		_cm = weakref(cm) if cm else null
	return cm


static func darkness(tree: SceneTree) -> float:
	if tree == null:
		return 0.0
	var mines := tree.get_first_node_in_group("mines")
	if mines and mines.get("active"):
		return 1.0
	var cm := _modulate(tree)
	if cm == null or not cm.visible:
		var clock := tree.get_first_node_in_group("game_clock")
		return 1.0 if (clock and clock.has_method("is_night") and clock.is_night()) else 0.0
	# bright day ~0.75-0.9, dusk ~0.6, a noon thunderstorm ~0.6, night ~0.2
	return clampf((0.72 - cm.color.get_luminance()) / 0.42, 0.0, 1.0)


## 0..1 brightness for lights: off on a bright day, half-on at dusk or in a storm, full at night.
static func level(tree: SceneTree) -> float:
	return smoothstep(0.08, 0.45, darkness(tree))


## A soft but clearly bounded pool of light for lanterns (bright core, gentle edge).
static func lantern_glow() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.72, 0.9, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.82), Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0)])
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.width = 256
		_glow.height = 256
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(0.5, 0.0)
	return _glow
