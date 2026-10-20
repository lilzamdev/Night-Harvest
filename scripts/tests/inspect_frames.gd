extends SceneTree

func _initialize() -> void:
	var img_walk = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Walk.png")
	var img_atk = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Attack1.png")
	var img_idle = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Idle.png")

	print("Walk size: ", img_walk.get_size())
	print("Attack size: ", img_atk.get_size())

	# Let's save scaled up versions (x4) of frame 0 and frame 3 of each to see them clearly
	var walk_f0 = img_walk.get_region(Rect2i(0, 0, 64, 64))
	walk_f0.resize(256, 256, Image.INTERPOLATE_NEAREST)
	walk_f0.save_png("res://walk_f0_preview.png")

	var atk_f2 = img_atk.get_region(Rect2i(128, 0, 64, 64))
	atk_f2.resize(256, 256, Image.INTERPOLATE_NEAREST)
	atk_f2.save_png("res://atk_f2_preview.png")

	var atk_f3 = img_atk.get_region(Rect2i(192, 0, 64, 64))
	atk_f3.resize(256, 256, Image.INTERPOLATE_NEAREST)
	atk_f3.save_png("res://atk_f3_preview.png")

	quit(0)
