# Run: tests/run_all.sh test_deathmatch
extends "res://tests/test_case.gd"

## A match in the main scene: kills score for the killer only, the HUD follows health and
## score, the first to the limit wins, everyone stops, and attack starts a rematch.

const LIMIT := 2


func run() -> void:
	_check_rules()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.arena_scene = load("res://scenes/arenas/test_arena.tscn")
	root.add_child(main)
	current_scene = main
	await physics_frames(10)
	check(main.mode.kill_limit == 20, "a deathmatch runs to 20 kills")
	main.mode.kill_limit = LIMIT
	var hud: Hud = main.hud
	var p1: Fighter = main.players[0]
	var p2: Fighter = main.players[1]
	check(hud.health_shown(0) == p1.health.max_health and hud.health_shown(1) == p2.health.max_health, "the HUD starts at full health")

	p2.take_hit(10, Vector2.ZERO, 0.0, false, p1)
	check(hud.health_shown(1) == p2.health.max_health - 10, "the HUD follows damage")
	check(hud.health_shown(0) == p1.health.max_health, "only the hit player's bar moves")

	p2.take_hit(1000, Vector2.ZERO, 0.0, false, p1)
	await physics_frames(2)
	check(main.mode.kills == [1, 0] and hud.kills_shown(0) == "1", "a kill scores for the killer")
	check(hud.health_shown(1) == 0.0, "a dead player's bar is empty")
	await physics_frames(int(main.respawn_time * 60) + 5)
	p2 = main.players[1]
	check(not p2.is_dead() and hud.health_shown(1) == p2.health.max_health, "the bar fills again after a respawn")

	p2.take_hit(1000, Vector2.ZERO, 0.0, false, p2)
	await physics_frames(int(main.respawn_time * 60) + 5)
	check(main.mode.kills == [1, 0], "a self-kill scores nothing")
	p2 = main.players[1]
	p2.take_hit(1000)
	await physics_frames(int(main.respawn_time * 60) + 5)
	check(main.mode.kills == [1, 0], "a death with no killer scores nothing")
	p2 = main.players[1]

	p1.take_hit(10, Vector2.ZERO, 0.0, false, p2)
	await physics_frames(2)
	p2.take_hit(1000, Vector2.ZERO, 0.0, false, p1)
	await physics_frames(2)
	check(main.mode.winner == 0 and hud.winner_shown() == "Player 1 wins!", "the first to the limit wins")
	check(p1.controller.get_script() == FighterController, "the fighters stop obeying the keys")
	Input.action_press("p1_attack")
	await physics_frames(2)
	Input.action_release("p1_attack")
	check(get_nodes_in_group(Fighter.GROUP).size() == 2 and current_scene == main, "attack during the result does not skip it")
	await physics_frames(int((main.end_settle_time + main.rematch_delay) * 60) + 5)
	check(main.arena.process_mode == Node.PROCESS_MODE_DISABLED, "the arena freezes after the last death")
	check(main.players[1] == p2 and p2.is_dead(), "nobody respawns after the match")

	Input.action_press("p2_attack")
	await physics_frames(5)
	Input.action_release("p2_attack")
	await physics_frames(5)
	check(current_scene != main and current_scene.mode.kills == [0, 0] and not current_scene.mode.is_over(), "attack starts a rematch from zero")


func _check_rules() -> void:
	var mode := Deathmatch.new(3)
	mode.kill_limit = 2
	var ended: Array[int] = []
	mode.match_ended.connect(func(winner: int) -> void: ended.append(winner))
	mode.record_kill(1, 2)
	mode.record_kill(0, 0)
	mode.record_kill(0, -1)
	check(mode.kills == [0, 0, 1] and not mode.is_over(), "only a kill of someone else scores")
	mode.record_kill(0, 2)
	mode.record_kill(0, 2)
	mode.record_kill(2, 1)
	check(mode.winner == 2 and ended == [2], "the match ends once")
	check(mode.kills == [0, 0, 2], "kills after the end do not count")
