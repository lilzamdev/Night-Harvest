extends SceneTree

func _initialize() -> void:
	var img_atk = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Attack1.png")
	var img_walk = Image.load_from_file("res://Assets/Enemies/zombie/1_Default/Zombie_Default_Walk.png")

	for i in range(6):
		var r = img_atk.get_region(Rect2i(i * 64, 0, 64, 64))
		r.resize(128, 128, Image.INTERPOLATE_NEAREST)
		r.save_png("res://atk_f%d.png" % i)

		var rw = img_walk.get_region(Rect2i(i * 64, 0, 64, 64))
		rw.resize(128, 128, Image.INTERPOLATE_NEAREST)
		rw.save_png("res://walk_f%d.png" % i)

	quit(0)
