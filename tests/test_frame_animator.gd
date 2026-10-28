# Run: tests/run_all.sh test_frame_animator
extends "res://tests/test_case.gd"

## The stick figure plays its frame-by-frame clips from the fighter's state: standing,
## walking, aiming by angle, diving into a landing roll, rolling, and its held items
## follow the drawn fist.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const STICKMAN := preload("res://data/characters/stickman.tres")
const PISTOL := preload("res://data/weapons/pistol.tres")
const KNIFE := preload("res://data/weapons/knife.tres")

var arena: Node2D


func run() -> void:
	arena = load("res://scenes/arenas/test_arena.tscn").instantiate()
	arena.get_node("ItemSpawns/W1").interval = 9999.0
	root.add_child(arena)
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = STICKMAN
	arena.add_child(fighter)
	fighter.global_position = Vector2(200, 328)
	await physics_frames(10)
	var frames := fighter.get_node_or_null("Visuals/Frames") as FrameAnimator
	check(frames != null and not fighter.get_node("Visuals/Placeholder").visible, "the stick figure is drawn instead of the placeholder")
	if frames == null:
		return
	for clip in ["idle", "walk", "run", "dive", "dive_roll", "roll", "climb", "stand_aim_0", "crouch_aim_8", "fast_jab_1", "knockdown_back"]:
		check(frames.sprite_frames.has_animation(clip), "has the %s frames" % clip)
	check(frames.animation == &"idle", "standing still plays idle")

	fighter.controller.move = 1.0
	await physics_frames(10)
	check(frames.animation == &"walk" and frames.speed_scale > 0.0, "walking plays walk at the walking speed")
	fighter.controller.run = true
	await physics_frames(10)
	fighter.controller.jump = true
	await physics_frames(1)
	fighter.controller.jump = false
	await physics_frames(2)
	check(frames.animation == &"dive", "a running jump plays the dive")
	for i in 60:
		if fighter.is_on_floor():
			break
		await physics_frames(1)
	await physics_frames(2)
	check(frames.animation == &"dive_roll", "landing from a dive rolls")
	fighter.controller.move = 0.0
	fighter.controller.run = false
	await physics_frames(40)
	check(frames.animation == &"idle", "the landing roll ends standing")

	fighter.controller.move = 1.0
	fighter.controller.run = true
	await physics_frames(10)
	fighter.controller.down = true
	await physics_frames(1)
	fighter.controller.down = false
	await physics_frames(2)
	check(frames.animation == &"roll", "rolling plays the roll")
	fighter.controller.move = 0.0
	fighter.controller.run = false
	await physics_frames(40)

	fighter.inventory.equip_firearm(PISTOL)
	fighter.aim_angle = -PI / 2.0
	await physics_frames(3)
	check(frames.animation == &"stand_aim_0", "aiming straight up holds the first aim pose")
	fighter.aim_angle = 0.0
	await physics_frames(2)
	check(frames.animation == &"stand_aim_4", "aiming level holds the middle aim pose")
	fighter.inventory.drop_firearm()
	await physics_frames(2)

	fighter.inventory.equip_melee_item(KNIFE)
	await physics_frames(2)
	var knife := fighter.inventory._melee_sprite
	check(knife.get_parent() == frames.hand_anchor, "a held melee item is drawn on the stick figure's fist")
	var before := frames.hand_anchor.position
	fighter.controller.attack = true
	await physics_frames(1)
	fighter.controller.attack = false
	await physics_frames(4)
	check(frames.hand_anchor.position.distance_to(before) > 1.0, "the fist (and the item) moves with the attack frames")
