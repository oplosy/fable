# Run: tests/run_all.sh test_mouse_aim
extends "res://tests/test_case.gd"

## Mouse aiming: a fighter aims straight at a point and turns to its side, only while ready
## to aim. The setting picks it for player 1, is saved, and leaves keyboard aiming as it was.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const FAST := preload("res://data/characters/placeholder.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)
	await _test_aim_at_point()
	await _test_keyboard_unchanged()
	await _test_local_controller()
	_test_settings()
	await _test_menu()


func _test_aim_at_point() -> void:
	var shooter := _spawn(Vector2(200, 328))
	await physics_frames(5)
	shooter.inventory.equip_firearm(PISTOL)
	shooter.controller.aim_at_point = true
	await physics_frames(2)
	var body: Vector2 = shooter.global_position
	var hand_y: float = shooter.get_node("Visuals/Hand").global_position.y

	await _aim(shooter, Vector2(body.x + 34, hand_y - 30))
	check(shooter.facing == 1 and is_equal_approx(shooter.aim_angle, -PI / 4.0), "the aim points straight at the mouse")
	await _aim(shooter, Vector2(body.x - 44, hand_y))
	check(shooter.facing == -1 and shooter.get_node("Visuals").scale.x == -1, "a point behind turns the fighter around")
	check(shooter.aim_direction().is_equal_approx(Vector2.LEFT), "the shot goes to the point after the turn")
	await _aim(shooter, Vector2(body.x - 4, hand_y - 50))
	check(shooter.facing == -1 and is_equal_approx(shooter.aim_angle, -PI / 2.0), "straight up keeps the facing")
	await _aim(shooter, Vector2(body.x - 4, hand_y))
	check(is_equal_approx(shooter.aim_angle, -PI / 2.0), "a point on the hand keeps the aim")

	# Between the body and the hand: the turn moves the hand past the point.
	shooter.controller.aim_point = Vector2(body.x + 2, hand_y - 20)
	var steady := true
	for i in 6:
		await physics_frame
		steady = steady and shooter.facing == 1
	check(steady, "a point over the body does not flip the fighter back and forth")

	shooter.controller.move = 1.0
	await _aim(shooter, Vector2(body.x - 80, hand_y - 40))
	check(shooter.facing == 1, "walking sets the facing, not the mouse")
	shooter.inventory.select_slot(Inventory.Slot.MELEE)
	shooter.controller.move = 0.0
	await physics_frames(5)
	check(shooter.facing == 1, "fists do not follow the mouse")
	shooter.free()
	await physics_frames(2)


func _test_keyboard_unchanged() -> void:
	var shooter := _spawn(Vector2(200, 328))
	await physics_frames(5)
	shooter.inventory.equip_firearm(PISTOL)
	await physics_frames(2)
	shooter.controller.aim = -1.0
	await physics_frames(5)
	check(shooter.aim_angle < 0.0 and shooter.aim_angle > -PI / 2.0, "without a point the aim keys still turn it gradually")
	shooter.free()
	await physics_frames(2)


func _test_local_controller() -> void:
	var first := LocalController.new()
	first.uses_mouse = true
	var second := LocalController.new()
	second.prefix = "p2_"
	var player := _spawn(Vector2(200, 328))
	player.controller.free()
	player.controller = first
	player.add_child(first)
	var other := _spawn(Vector2(400, 328))
	other.controller.free()
	other.controller = second
	other.add_child(second)

	first.poll()
	check(not first.aim_at_point, "keyboard aim is the default")
	Input.action_press("p1_mouse_attack")
	first.poll()
	check(not first.attack_held, "a click does not attack in keyboard mode")
	Input.action_release("p1_mouse_attack")

	GameSettings.mouse_aim = true
	first.poll()
	second.poll()
	check(first.aim_at_point and not second.aim_at_point, "mouse aim is player 1's only")
	Input.action_press("p1_mouse_attack")
	first.poll()
	check(first.attack_held, "a click attacks in mouse mode")
	Input.action_release("p1_mouse_attack")
	Input.action_press("p1_attack")
	first.poll()
	check(first.attack_held, "the attack key still works in mouse mode")
	Input.action_release("p1_attack")
	Input.action_press("p1_up")
	first.poll()
	check(first.aim == -1.0, "W stays on the aim intent, which ladders read")
	Input.action_release("p1_up")
	GameSettings.mouse_aim = false
	player.free()
	other.free()
	await physics_frames(2)


func _test_settings() -> void:
	GameSettings.set_mouse_aim(true)
	GameSettings.mouse_aim = false
	GameSettings.load_saved()
	check(GameSettings.mouse_aim, "the choice survives a restart")
	var broken := ConfigFile.new()
	broken.set_value("aim", "mouse", "yes")
	broken.save(GameSettings.save_path)
	GameSettings.load_saved()
	check(not GameSettings.mouse_aim, "a malformed entry keeps keyboard aim")
	GameSettings.reset_to_defaults()
	check(not FileAccess.file_exists(GameSettings.save_path), "reset forgets the file")


func _test_menu() -> void:
	var menu := SettingsMenu.new()
	root.add_child(menu)
	await process_frame
	menu.open()
	menu.toggle_mouse_aim()
	check(GameSettings.mouse_aim, "the menu turns mouse aim on")
	menu.toggle_mouse_aim()
	check(not GameSettings.mouse_aim, "and off again")
	menu.close()
	menu.queue_free()
	await process_frame


func _aim(fighter: Fighter, point: Vector2) -> void:
	fighter.controller.aim_point = point
	await physics_frames(2)


func _spawn(at: Vector2) -> Fighter:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = FAST
	arena.add_child(fighter)
	fighter.global_position = at
	return fighter
