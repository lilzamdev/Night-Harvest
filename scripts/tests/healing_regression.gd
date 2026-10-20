extends SceneTree

var failures := 0
var health_updates := 0
var hunger_updates := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	var stats = load("res://scripts/player_stats.gd").new()
	root.add_child(stats)
	stats.set_process(false)
	stats.health_changed.connect(func(_hp, _max_hp): health_updates += 1)
	stats.hunger_changed.connect(func(_food, _max_food): hunger_updates += 1)
	stats.current_health = 90
	stats._process(1.0)
	check(stats.current_health == 90 and stats.current_hunger == 100, "Waits for healing interval")
	stats._process(1.0)
	check(stats.current_health == 91 and stats.current_hunger == 99, "One HP costs one hunger every two seconds")
	check(health_updates == 1 and hunger_updates == 1, "Both HUD update signals emitted")
	stats._process_regeneration(6.0)
	check(stats.current_health == 94 and stats.current_hunger == 96, "Long frames preserve elapsed healing ticks")
	stats.current_health = 99
	stats._process_regeneration(20.0)
	check(stats.current_health == 100 and stats.current_hunger == 95, "Charges only for missing health")
	stats._process_regeneration(20.0)
	check(stats.current_hunger == 95, "Full health consumes no regeneration hunger")
	stats.current_health = 90
	stats.current_hunger = 1.5
	stats._process_regeneration(20.0)
	check(stats.current_health == 91 and stats.current_hunger == 0.5, "Cannot overspend fractional remaining hunger")
	stats._process_regeneration(20.0)
	check(stats.current_health == 91, "Insufficient hunger stops healing")
	stats.restore_hunger(5.0)
	stats._process_regeneration(1.0)
	check(stats.current_health == 91, "Eating resumes healing without banked ticks")
	stats._process_regeneration(1.0)
	check(stats.current_health == 92 and stats.current_hunger == 4.5, "Eating fuels subsequent healing")
	stats.is_dead = true
	stats.current_health = 0
	stats._process_regeneration(10.0)
	check(stats.current_health == 0 and stats.current_hunger == 4.5, "Healing cannot revive a dead player")
	stats.reset()
	check(stats._regeneration_elapsed == 0, "Reset clears regeneration timer")
	stats._process(10.0)
	check(stats.current_hunger == 99, "Normal hunger drain still works at full health")
	stats.current_hunger = 0
	stats._process(5.0)
	check(stats.current_health == 99, "Starvation still damages player without regenerating")
	stats.free()
	print("Healing regression failures: ", failures)
	quit(1 if failures else 0)
