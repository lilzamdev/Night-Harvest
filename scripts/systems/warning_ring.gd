extends Node2D

## A red ground ring that fills up before a boss attack lands (v1.2).

var radius: float = 40.0
var duration: float = 0.9
var _t := 0.0


func _ready() -> void:
	z_index = -1


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duration + 0.15:
		queue_free()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var a := 0.25 + 0.35 * k
	draw_circle(Vector2.ZERO, radius * k, Color(0.9, 0.15, 0.2, a * 0.55))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 0.3, 0.3, a + 0.2), 1.5)
