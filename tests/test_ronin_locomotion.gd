# Run: tests/run_all.sh test_ronin_locomotion
extends "res://tests/test_case.gd"

func run() -> void:
	var arena: Node2D = load("res://scenes/arenas/test_arena.tscn").instantiate()
	root.add_child(arena)
	
	var fighter: Fighter = load("res://scenes/fighter/fighter.tscn").instantiate()
	fighter.character = load("res://data/characters/ronin.tres")
	arena.add_child(fighter)
	fighter.global_position = Vector2(200, 328)
	
	await physics_frames(2)
	
	var rig: CharacterRig = fighter.get_node_or_null("Visuals/Rig")
	var animator: RigAnimator = fighter.get_node_or_null("Animator")
	check(rig != null, "CharacterRig exists")
	check(animator != null, "RigAnimator exists")
	check(animator.has_animation("walk"), "Animator loaded walk clip")
	check(animator.has_animation("run"), "Animator loaded run clip")
	
	var input: FighterController = fighter.controller
	
	# 1. Walk Test
	input.move = 1.0
	await physics_frames(10)
	check(fighter.state() == Fighter.State.WALK, "Fighter is in WALK state")
	await physics_frames(5)
	check(animator.assigned_animation == "walk", "Walking plays walk clip (%s)" % animator.assigned_animation)
	check(animator.is_playing(), "Walk animation is currently playing")
	check(animator.speed_scale > 0.6, "Speed scale scales with movement (%.2f)" % animator.speed_scale)
	
	# 2. Run Test
	input.run = true
	await physics_frames(10)
	check(fighter.state() == Fighter.State.RUN, "Fighter is in RUN state")
	await physics_frames(5)
	check(animator.assigned_animation == "run", "Running plays run clip (%s)" % animator.assigned_animation)
	check(animator.is_playing(), "Run animation is currently playing")
	
	# 3. Stop Test
	input.run = false
	input.move = 0.0
	await physics_frames(15)
	check(fighter.state() == Fighter.State.IDLE, "Fighter returns to IDLE state")
	check(animator.assigned_animation == "idle", "Animator transitions to idle (%s)" % animator.assigned_animation)
	check(absf(rig.joints.leg_front_upper.rotation) < 0.35, "Legs return to the standing pose (%.2f)" % rig.joints.leg_front_upper.rotation)
	
	arena.queue_free()
