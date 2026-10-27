# Run: tests/run_all.sh test_animation
extends "res://tests/test_case.gd"

## A rigged fighter plays the clip that matches what it does: idle, walk and run (at the
## speed its legs match), crouching (feet flat, coat off the floor), jumping, falling
## and landing.

const CLIPS := ["idle", "walk", "run", "jump_rise", "fall", "land", "crouch_idle", "crouch_walk"]


func run() -> void:
	var arena: Node2D = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)
	var fighter: Fighter = load("res://scenes/fighter/fighter.tscn").instantiate()
	fighter.character = load("res://data/characters/trenchcoat_agent.tres")
	arena.add_child(fighter)
	fighter.global_position = Vector2(200, 328)
	await physics_frames(1)
	var animator: RigAnimator = fighter.get_node("Animator")
	var rig: CharacterRig = fighter.get_node("Visuals/Rig")
	var input := fighter.controller
	check(CLIPS.all(func(clip: String) -> bool: return animator.has_animation(clip)), "every clip loads")
	await physics_frames(30)
	check(animator.current_animation == "idle", "standing still plays idle (%s)" % animator.current_animation)

	input.move = 1.0
	await physics_frames(30)
	var walk_scale := fighter.velocity.x / (120.0 * rig.leg_length() / RigAnimator.REFERENCE_LEG_LENGTH)
	check(animator.current_animation == "walk" and is_equal_approx(animator.speed_scale, walk_scale), "walking plays walk at the speed its feet match (%.2f)" % animator.speed_scale)
	input.run = true
	await physics_frames(30)
	check(animator.current_animation == "run", "running plays run")
	input.run = false
	input.move = 0.0

	input.crouch = true
	await physics_frames(30)
	check(animator.current_animation == "crouch_idle", "crouching plays crouch_idle")
	for side in ["front", "back"]:
		check(absf(rig.joints["leg_%s_lower" % side].global_rotation) < 0.01, "a crouched %s shin stands upright, so its foot is flat" % side)
	for part: String in animator._hems:
		var joint: Node2D = rig.joints[part]
		for corner: Vector2 in animator._hems[part]:
			check(rig.to_local(joint.to_global(corner)).y < 0.01, "the %s hem stays off the floor while crouched" % part)
	input.move = 1.0
	await physics_frames(10)
	check(animator.current_animation == "crouch_walk", "moving while crouched plays crouch_walk")
	input.move = 0.0
	input.crouch = false
	await physics_frames(30)

	input.jump = true
	await physics_frames(1)
	input.jump = false
	await physics_frames(5)
	check(animator.current_animation == "jump_rise", "going up plays jump_rise")
	while fighter.velocity.y <= 0.0:
		await physics_frames(1)
	await physics_frames(2)
	check(animator.current_animation == "fall", "coming down plays fall")
	while not fighter.is_on_floor():
		await physics_frames(1)
	await physics_frames(1)
	check(animator.current_animation == "land", "touching down plays land")
	await physics_frames(20)
	check(animator.current_animation == "idle", "land goes back to idle")
