# Run: tests/run_all.sh test_ronin_actions
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
	
	# Verify all animations loaded into animator
	var expected_clips := [
		"idle", "walk", "run", "crouch_idle", "crouch_walk",
		"jump_rise", "jump_apex", "fall", "land", "roll", "dive", "aim_idle",
		"jab_1", "jab_2", "jab_3", "hook", "jump_kick",
		"knife_stab", "knife_slash", "hit_front", "hit_back",
		"bat_swing", "bat_homerun", "climb", "cook", "throw",
		"down", "getup"
	]
	for clip in expected_clips:
		check(animator.has_animation(clip), "Loaded clip: %s" % clip)
		
	var input: FighterController = fighter.controller
	
	# 1. Idle -> Crouch Idle
	check(animator.assigned_animation == "idle", "Starts in idle animation")
	input.crouch = true
	await physics_frames(5)
	check(fighter.is_crouching(), "Fighter is crouching")
	check(animator.assigned_animation == "crouch_idle", "Plays crouch_idle when crouched still (%s)" % animator.assigned_animation)
	
	# 2. Crouch Walk
	input.move = 1.0
	await physics_frames(5)
	check(animator.assigned_animation == "crouch_walk", "Plays crouch_walk when moving while crouched (%s)" % animator.assigned_animation)
	
	input.crouch = false
	input.move = 0.0
	await physics_frames(10)
	check(animator.assigned_animation == "idle", "Returns to idle (%s)" % animator.assigned_animation)
	
	# 3. Jump (Airborne states)
	input.jump = true
	await physics_frames(2)
	input.jump = false
	await physics_frames(2)
	check(not fighter.is_on_floor(), "Fighter left floor")
	check(fighter.velocity.y < -50.0, "Ascending with upward velocity")
	check(animator.assigned_animation == "jump_rise", "Plays jump_rise ascending (%s)" % animator.assigned_animation)
	
	# Wait until apex / descending
	await physics_frames(25)
	if fighter.velocity.y > 50.0:
		check(animator.assigned_animation == "fall", "Plays fall descending (%s)" % animator.assigned_animation)
		
	# Wait to land
	await physics_frames(30)
	check(fighter.is_on_floor(), "Landed on floor")
	await physics_frames(int(Fighter.LANDING_TIME * 60) + 15)
	check(animator.assigned_animation == "idle", "Returns to idle after landing")
	
	# 4. Melee Combo: Jab 1 -> Jab 2 -> Jab 3 -> Hook
	input.attack = true
	await physics_frames(1)
	input.attack = false
	check(fighter.melee.is_attacking(), "Melee attack 1 started")
	check(animator.assigned_animation == "jab_1", "Plays jab_1 on attack 1 (%s)" % animator.assigned_animation)
	
	# Queue attack 2
	await physics_frames(5)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(20)
	check(animator.assigned_animation == "jab_2", "Plays jab_2 on combo 2 (%s)" % animator.assigned_animation)
	
	# Queue attack 3
	await physics_frames(5)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(20)
	check(animator.assigned_animation == "jab_3", "Plays jab_3 on combo 3 (%s)" % animator.assigned_animation)
	
	# Queue attack 4 (Hook finisher)
	await physics_frames(5)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(20)
	check(animator.assigned_animation == "hook", "Plays hook on finisher (%s)" % animator.assigned_animation)
	
	# Wait for combo to finish
	await physics_frames(35)
	check(not fighter.melee.is_attacking(), "Melee combo ended")
	check(animator.assigned_animation == "idle", "Returns to idle after combo")
	
	# 5. Jump Kick
	input.jump = true
	await physics_frames(2)
	input.jump = false
	await physics_frames(3)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(2)
	check(fighter.melee.is_air_attacking(), "Air attack active")
	check(animator.assigned_animation == "jump_kick", "Plays jump_kick in air (%s)" % animator.assigned_animation)
	
	await physics_frames(50)
	check(fighter.is_on_floor(), "Landed from air attack")
	
	# 6. Combat Roll
	input.move = 1.0
	input.run = true
	await physics_frames(10)
	input.down = true
	await physics_frames(2)
	input.down = false
	input.run = false
	input.move = 0.0
	check(fighter.is_rolling(), "Fighter is rolling")
	check(animator.assigned_animation == "roll", "Plays roll animation (%s)" % animator.assigned_animation)
	
	await physics_frames(25)
	check(not fighter.is_rolling(), "Roll ended")
	check(animator.assigned_animation == "idle", "Returns to idle after roll")
	
	# 7. Knife Combo (Stab -> Slash)
	var knife: MeleeItemData = load("res://data/weapons/knife.tres")
	fighter.melee.equip(knife)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	check(animator.assigned_animation == "knife_stab", "Plays knife_stab with knife (%s)" % animator.assigned_animation)
	
	# Queue combo 2 (Stab)
	await physics_frames(4)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(6)
	check(animator.assigned_animation == "knife_stab", "Plays knife_stab combo 2 (%s)" % animator.assigned_animation)
	
	# Queue combo 3 (Slash finisher)
	await physics_frames(4)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(8)
	check(animator.assigned_animation == "knife_slash", "Plays knife_slash on knife finisher (%s)" % animator.assigned_animation)
	
	await physics_frames(25)
	check(not fighter.melee.is_attacking(), "Knife combo finished")
	
	# 8. Hit Reaction Front & Back
	fighter.take_hit(5, Vector2(-50, 0), 0.25)
	await physics_frames(2)
	check(fighter.is_stunned(), "Fighter is stunned")
	check(animator.assigned_animation == "hit_front", "Plays hit_front on taking hit from front (%s)" % animator.assigned_animation)
	await physics_frames(20)
	
	# Hit from behind (knockback in facing direction)
	fighter.take_hit(5, Vector2(50, 0), 0.25)
	await physics_frames(2)
	check(fighter.hit_from_behind, "Hit from behind detected")
	check(animator.assigned_animation == "hit_back", "Plays hit_back on hit from behind (%s)" % animator.assigned_animation)
	await physics_frames(20)
	check(animator.assigned_animation == "idle", "Returns to idle after hit")
	
	# 9. Bat Melee Attacks
	var bat: MeleeItemData = load("res://data/weapons/bat.tres")
	fighter.melee.equip(bat)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	check(animator.assigned_animation == "bat_swing", "Plays bat_swing with bat (%s)" % animator.assigned_animation)
	
	# Queue combo 2 (swing is 0.42s = ~25 frames)
	await physics_frames(10)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(18)
	check(animator.assigned_animation == "bat_swing", "Plays bat_swing combo 2 (%s)" % animator.assigned_animation)
	
	# Queue combo 3 (home run finisher)
	await physics_frames(10)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(18)
	check(animator.assigned_animation == "bat_homerun", "Plays bat_homerun finisher (%s)" % animator.assigned_animation)
	await physics_frames(40)
	
	# 10. Grenade Cook & Throw
	var grenade: ThrowableData = load("res://data/throwables/grenade.tres")
	fighter.inventory.equip_throwable(grenade, 3)
	fighter.inventory.select_slot(Inventory.Slot.THROWABLE)
	await physics_frames(2)
	check(fighter.is_throwable_drawn(), "Throwable is drawn")
	
	# Pull pin (cook)
	input.attack = true
	input.attack_held = true
	await physics_frames(5)
	check(fighter.thrower.is_cooking(), "Grenade is cooking")
	check(animator.assigned_animation == "cook", "Plays cook while holding grenade pin (%s)" % animator.assigned_animation)
	
	# Release to throw
	input.attack = false
	input.attack_held = false
	await physics_frames(2)
	check(not fighter.thrower.is_cooking(), "Grenade released")
	check(animator.assigned_animation == "throw", "Plays throw on release (%s)" % animator.assigned_animation)
	
	await physics_frames(20)
	# Switch back to melee bare hands
	fighter.inventory.select_slot(Inventory.Slot.MELEE)
	await physics_frames(2)
	check(animator.assigned_animation == "idle", "Returns to idle after switching back to melee (%s)" % animator.assigned_animation)

	arena.queue_free()
