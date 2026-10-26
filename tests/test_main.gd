# Run: godot --headless --path . -s res://tests/test_main.gd
extends "res://tests/test_case.gd"


func run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frames(30)
	var dummy: Fighter = main.dummy

	check(dummy != null and dummy.character.display_name == "Dummy", "main spawns the target dummy")
	check(dummy.global_position.x == main.arena.get_node("SpawnPoints/P2").global_position.x, "dummy stands at the second spawn point")
	check(dummy.controller.get_script() == FighterController, "dummy has the idle controller")

	Input.action_press("p1_attack")
	await physics_frames(2)
	Input.action_release("p1_attack")
	await physics_frames(30)
	check(dummy.health.current == dummy.health.max_health - main.starting_weapon.damage, "player's shot damages the dummy")

	dummy.take_hit(1000)
	await physics_frames(int(main.dummy_respawn_time * 60) + 10)
	check(not is_instance_valid(dummy), "dead dummy is removed")
	check(main.dummy != null and not main.dummy.is_dead(), "a fresh dummy respawns")
