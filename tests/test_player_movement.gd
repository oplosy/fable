# Run: godot --headless --path . -s res://tests/test_player_movement.gd
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
	var player: CharacterBody2D = main.player

	_check(player.is_on_floor(), "player rests on the floor")
	var floor_y := player.position.y

	var start_x := player.position.x
	Input.action_press("move_right")
	await _physics_frames(30)
	Input.action_release("move_right")
	_check(player.position.x > start_x + 10.0, "move_right moves the player right")

	start_x = player.position.x
	Input.action_press("move_left")
	await _physics_frames(30)
	Input.action_release("move_left")
	_check(player.position.x < start_x - 10.0, "move_left moves the player left")

	Input.action_press("jump")
	await _physics_frames(10)
	Input.action_release("jump")
	_check(player.position.y < floor_y - 20.0, "jump lifts the player")

	await _physics_frames(90)
	# Collision safe margin leaves a sub-pixel gap, so compare within half a pixel.
	_check(player.is_on_floor() and absf(player.position.y - floor_y) < 0.5, "player lands back on the floor")

	Input.action_press("move_right")
	await _physics_frames(300)
	Input.action_release("move_right")
	_check(player.position.x < 632.0, "right wall stops the player")

	print("FAILED" if _failed else "ALL PASSED")
	quit(1 if _failed else 0)


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_failed = true
