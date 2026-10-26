# Run: godot --headless --path . -s res://tests/test_fighter.gd
extends SceneTree

var _failed := false


func _initialize() -> void:
	# Godot does not exit on script errors, so fail instead of hanging.
	create_timer(30.0).timeout.connect(func() -> void:
		print("FAIL timed out")
		quit(1))

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _physics_frames(30)
	var fighter: Fighter = main.fighter

	_check(fighter.is_on_floor(), "fighter rests on the floor")
	_check(fighter.get_node("Visuals/Placeholder").color == fighter.character.placeholder_color, "character data sets the look")
	var floor_y := fighter.position.y

	var start_x := fighter.position.x
	Input.action_press("p1_right")
	await _physics_frames(30)
	Input.action_release("p1_right")
	_check(fighter.position.x > start_x + 10.0, "p1_right moves the fighter right")
	_check(fighter.facing == 1, "fighter faces right")

	start_x = fighter.position.x
	Input.action_press("p1_left")
	await _physics_frames(30)
	Input.action_release("p1_left")
	_check(fighter.position.x < start_x - 10.0, "p1_left moves the fighter left")
	_check(fighter.facing == -1 and fighter.get_node("Visuals").scale.x == -1, "fighter faces and flips left")

	Input.action_press("p1_jump")
	await _physics_frames(10)
	Input.action_release("p1_jump")
	_check(fighter.position.y < floor_y - 20.0, "jump lifts the fighter")
	_check(not fighter.firearm.visible, "firearm is put away in the air")

	await _physics_frames(90)
	# Collision safe margin leaves a sub-pixel gap, so compare within half a pixel.
	_check(fighter.is_on_floor() and absf(fighter.position.y - floor_y) < 0.5, "fighter lands back on the floor")

	Input.action_press("p1_right")
	await _physics_frames(300)
	Input.action_release("p1_right")
	_check(fighter.position.x < 632.0, "right wall stops the fighter")

	_check(fighter.firearm != null and fighter.firearm.data.display_name == "Pistol", "fighter spawns with the pistol")
	_check(fighter.active_slot == Fighter.Slot.FIREARM, "firearm slot is active")
	await _physics_frames(2)
	_check(fighter.firearm.visible, "standing fighter holds the firearm")

	Input.action_press("p1_left")
	await _physics_frames(10)
	_check(not fighter.firearm.visible, "moving puts the firearm away")
	Input.action_press("p1_attack")
	await _physics_frames(2)
	Input.action_release("p1_attack")
	_check(get_nodes_in_group("projectiles").is_empty(), "no firing while moving")
	await _physics_frames(10)
	Input.action_release("p1_left")
	await _physics_frames(2)
	_check(fighter.firearm.visible, "stopping draws the firearm again")
	await _physics_frames(20)

	# Fighter reads the press on the next physics frame, so wait two.
	Input.action_press("p1_attack")
	await _physics_frames(2)
	Input.action_release("p1_attack")
	var bullets := get_nodes_in_group("projectiles")
	_check(bullets.size() == 1, "fire spawns one bullet")
	if bullets.size() == 1:
		var bullet: Projectile = bullets[0]
		_check(bullet.velocity.x < 0.0 and bullet.global_position.x < fighter.global_position.x, "bullet leaves the muzzle facing left")
		_check(bullet.get_parent() == main.arena, "bullet lives in the arena")

	Input.action_press("p1_attack")
	await _physics_frames(2)
	Input.action_release("p1_attack")
	_check(get_nodes_in_group("projectiles").size() == 1, "cooldown blocks a second shot")

	await _physics_frames(120)
	_check(get_nodes_in_group("projectiles").is_empty(), "bullet is removed after hitting the wall")

	Input.action_press("p1_attack")
	await _physics_frames(30)
	Input.action_release("p1_attack")
	_check(get_nodes_in_group("projectiles").size() == 1, "semi-auto pistol fires once while held")

	print("FAILED" if _failed else "ALL PASSED")
	quit(1 if _failed else 0)


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_failed = true
