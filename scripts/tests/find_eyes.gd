extends SceneTree

func _initialize() -> void:
	var img_walk = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Walk.png")
	var img_atk = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Attack1.png")

	_find_yellow_eyes("Walk f0", img_walk, 0)
	_find_yellow_eyes("Atk f2", img_atk, 2)
	quit(0)

func _find_yellow_eyes(name: String, img: Image, frame_idx: int) -> void:
	var offset_x = frame_idx * 64
	var eyes = []
	for y in range(64):
		for x in range(64):
			var c = img.get_pixel(offset_x + x, y)
			# Yellow eyes have high red, high green, low blue
			if c.r > 0.7 and c.g > 0.7 and c.b < 0.3 and c.a > 0.5:
				eyes.append(Vector2i(x, y))
	print(name, " yellow eyes at x: ", eyes)
