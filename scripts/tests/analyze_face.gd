extends SceneTree

func _initialize() -> void:
	var img = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Walk.png")
	# Let's print colors across the face row y=23 in frame 0
	for x in range(20, 45):
		var c = img.get_pixel(x, 23)
		print("x=", x, " col: ", c)
	quit(0)
