extends SceneTree

func _initialize() -> void:
	var img_walk = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Walk.png")
	var img_atk = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Attack1.png")

	# Let's inspect the bounding box of non-transparent pixels in frame 0 of walk and attack
	print("Walk frame 0 bounds: ", _get_non_transparent_bounds(img_walk, 0))
	print("Attack frame 2 bounds: ", _get_non_transparent_bounds(img_atk, 2))
	print("Attack frame 3 bounds: ", _get_non_transparent_bounds(img_atk, 3))

	quit(0)

func _get_non_transparent_bounds(img: Image, frame_idx: int) -> Rect2i:
	var min_x = 64
	var max_x = 0
	var min_y = 64
	var max_y = 0
	var offset_x = frame_idx * 64
	for y in range(64):
		for x in range(64):
			var c = img.get_pixel(offset_x + x, y)
			if c.a > 0.1:
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
