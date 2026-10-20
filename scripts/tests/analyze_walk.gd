extends SceneTree

func _initialize() -> void:
	var img_walk = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Walk.png")
	for f in range(6):
		var min_x = 64
		var max_x = 0
		var feet_x = []
		for y in range(45, 60):
			for x in range(64):
				var c = img_walk.get_pixel(f * 64 + x, y)
				if c.a > 0.5:
					if x < min_x: min_x = x
					if x > max_x: max_x = x
					if y >= 52:
						feet_x.append(x)
		print("Frame ", f, " total x bounds: [", min_x, ", ", max_x, "] feet x: ", feet_x.min(), " to ", feet_x.max())
	quit(0)
