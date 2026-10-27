# Run: tests/run_all.sh test_animation
extends "res://tests/test_case.gd"

## A rigged fighter plays the clip that matches what it does: idle, walk and run (at the
## speed its legs match), crouching (a deep squat, coat off the floor), jumping (coat hanging down), falling
## and landing; attacks play their own clip, hits a flinch, and a knockdown falls, lies
## and gets up on the side the hit came from.

const CLIPS := ["idle", "walk", "run", "jump_rise", "fall", "land", "crouch_idle", "crouch_walk"]


func run() -> void:
	var arena: Node2D = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)
	var fighter: Fighter = load("res://scenes/fighter/fighter.tscn").instantiate()
	fighter.character = load("res://data/characters/street_brawler.tres")
	arena.add_child(fighter)
	fighter.global_position = Vector2(200, 328)
	await physics_frames(1)
	var animator: RigAnimator = fighter.get_node("Animator")
	var rig: CharacterRig = fighter.get_node("Visuals/Rig")
	var input := fighter.controller
	check(CLIPS.all(func(clip: String) -> bool: return animator.has_animation(clip)), "every clip loads")
	await physics_frames(30)
	check(animator.current_animation == "idle", "standing still plays idle (%s)" % animator.current_animation)
	var standing := _head_top(rig)

	input.move = 1.0
	await physics_frames(30)
	var walk_scale: float = fighter.velocity.x / (animator._reference_speeds.walk * rig.leg_length() / RigAnimator.REFERENCE_LEG_LENGTH)
	check(animator.current_animation == "walk" and is_equal_approx(animator.speed_scale, walk_scale), "walking plays walk at the speed its feet match (%.2f)" % animator.speed_scale)
	input.run = true
	await physics_frames(30)
	check(animator.current_animation == "run", "running plays run")
	input.run = false
	input.move = 0.0

	input.crouch = true
	await physics_frames(30)
	check(animator.current_animation == "crouch_idle", "crouching plays crouch_idle")
	check(_head_top(rig) < standing * 0.75, "crouching brings the head down to under 75%% of standing (%.0f%%)" % (100.0 * _head_top(rig) / standing))
	for coat in rig.coats:
		check(_coat_points(rig, coat).all(func(p: Vector2) -> bool: return p.y < 0.01), "the %s stays off the floor while crouched" % coat.get_parent().name)
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
	await physics_frames(10)
	for coat in rig.coats:
		var part := String(coat.get_parent().name)
		var waist := rig.to_local(coat.get_parent().global_position).y
		var length: float = Array(coat.uv).map(func(p: Vector2) -> float: return p.y).max() - rig.pivots[part].y
		var hem: float = _coat_points(rig, coat).map(func(p: Vector2) -> float: return p.y).max()
		check(hem - waist > length * 0.5, "the %s hangs down in the air instead of flying up" % part)
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

	input.attack = true
	await physics_frames(2)
	input.attack = false
	check(animator.current_animation == "fast_jab_1", "the first jab of the combo plays fast_jab_1 (%s)" % animator.current_animation)
	await physics_frames(30)

	fighter.take_hit(1, Vector2(-40, 0), 0.2)
	await physics_frames(2)
	check(animator.current_animation == "hit_front_light", "a short stun from in front plays hit_front_light (%s)" % animator.current_animation)
	await physics_frames(30)
	fighter.take_hit(1, Vector2(40, 0), 0.5)
	await physics_frames(2)
	check(animator.current_animation == "hit_back_heavy", "a long stun from behind plays hit_back_heavy (%s)" % animator.current_animation)
	await physics_frames(60)

	fighter.take_hit(1, Vector2(-40, 0), -1.0, true)
	await physics_frames(3)
	check(animator.current_animation == "knockdown_back", "a knockdown from in front falls on the back")
	await physics_frames(40)
	check(animator.current_animation == "lying_back", "the fall ends lying on the back")
	while fighter.is_knocked_down():
		await physics_frames(1)
	await physics_frames(2)
	check(animator.current_animation == "getup_back", "getting up plays getup_back")

	await physics_frames(60)
	fighter.take_hit(9999, Vector2(40, 0))
	await physics_frames(3)
	check(animator.current_animation == "death_front", "a killing hit from behind plays death_front (%s)" % animator.current_animation)


## A coat mesh's points in rig space (art px, feet at the origin).
func _coat_points(rig: CharacterRig, coat: CoatMesh) -> Array:
	var points := []
	for point in coat.polygon:
		points.append(rig.to_local(coat.to_global(point)))
	return points


## Height of the top of the head over the floor, in art px.
func _head_top(rig: CharacterRig) -> float:
	return -rig.to_local(rig.joints.head.to_global(rig.points.head_top - rig.pivots.head)).y
