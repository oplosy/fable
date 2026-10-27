# Run: godot --headless --path . -s res://tests/test_main.gd
extends "res://tests/test_case.gd"


func run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frames(30)
	var p1: Fighter = main.players[0]
	var p2: Fighter = main.players[1]

	for i in 2:
		var player: Fighter = main.players[i]
		var spawn: Marker2D = main.arena.get_node("SpawnPoints").get_child(i)
		check(player.global_position.x == spawn.global_position.x, "player %d stands at spawn point %d" % [i + 1, i + 1])
		check(player.controller is LocalController and player.controller.prefix == "p%d_" % (i + 1), "player %d reads the p%d_ actions" % [i + 1, i + 1])
		check(player.firearm != null and player.firearm.data == main.starting_weapon, "player %d starts with the pistol" % (i + 1))
		check(player.thrower.item == main.starting_throwable and player.thrower.count == 3, "player %d starts with 3 grenades" % (i + 1))

	var p1_x := p1.position.x
	var p2_x := p2.position.x
	Input.action_press("p2_left")
	await physics_frames(20)
	Input.action_release("p2_left")
	check(p2.position.x < p2_x - 10.0 and p2.facing == -1, "p2_left moves player 2")
	check(p1.position.x == p1_x, "player 2's keys do not move player 1")
	await physics_frames(20)

	Input.action_press("p1_attack")
	await physics_frames(2)
	Input.action_release("p1_attack")
	await physics_frames(30)
	check(p2.health.current == p2.health.max_health - main.starting_weapon.damage, "player 1's shot damages player 2")

	Input.action_press("p2_attack")
	await physics_frames(2)
	Input.action_release("p2_attack")
	await physics_frames(30)
	check(p1.health.current == p1.health.max_health - main.starting_weapon.damage, "player 2's shot damages player 1")

	p2.take_hit(1000)
	p1.take_hit(1000)
	paused = true
	await physics_frames(int(main.respawn_time * 60) + 10)
	check(main.players[0] == p1 and main.players[1] == p2, "no respawn while the game is paused")
	paused = false
	await physics_frames(int(main.respawn_time * 60) + 10)
	check(not is_instance_valid(p1) and not is_instance_valid(p2), "dead players are removed")
	for i in 2:
		var fresh: Fighter = main.players[i]
		check(fresh != null and not fresh.is_dead() and fresh.firearm != null, "player %d respawns armed" % (i + 1))
