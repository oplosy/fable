# Run: tests/run_all.sh test_ronin_gameplay
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
	check(rig != null, "CharacterRig node exists under Visuals")
	check(not fighter.get_node("Visuals/Placeholder").visible, "Placeholder is hidden")
	check(rig.joints.size() == 18, "Rig has all 18 joints (%d)" % rig.joints.size())
	
	# Equip pistol
	var pistol: WeaponData = load("res://data/weapons/pistol.tres")
	fighter.inventory.equip_firearm(pistol)
	await physics_frames(2)
	check(fighter.is_firearm_drawn(), "Firearm is drawn while standing still")
	
	var input: FighterController = fighter.controller
	
	# 1. Aim Up with keys
	input.aim = -1.0
	await physics_frames(65)
	check(is_equal_approx(fighter.aim_angle, -PI / 2.0), "Aim reaches straight up (-PI/2: %.2f)" % fighter.aim_angle)
	check(rig.joints.head.rotation < -0.5, "Head tilts up (%.2f rad)" % rig.joints.head.rotation)
	check(rig.joints.torso.rotation < -0.2, "Torso arches back (%.2f rad)" % rig.joints.torso.rotation)
	check(rig.joints.arm_front_upper.rotation < -0.8, "Arm points up (%.2f rad)" % rig.joints.arm_front_upper.rotation)
	
	# Fire upward
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(2)
	var bullet_up := arena.get_node_or_null("Bullet")
	check(bullet_up != null, "Bullet spawned towards sky")
	
	# 2. Aim Down with keys
	input.aim = 1.0
	await physics_frames(130)
	check(is_equal_approx(fighter.aim_angle, PI / 2.0), "Aim reaches straight down (+PI/2: %.2f)" % fighter.aim_angle)
	check(rig.joints.head.rotation > 0.5, "Head tilts down (%.2f rad)" % rig.joints.head.rotation)
	check(rig.joints.torso.rotation > 0.2, "Torso leans down (%.2f rad)" % rig.joints.torso.rotation)
	check(rig.joints.arm_front_upper.rotation > 0.8, "Arm points down (%.2f rad)" % rig.joints.arm_front_upper.rotation)
	
	# 3. Dynamic Mouse Aiming (Instant crosshair tracking)
	input.aim = 0.0
	input.aim_at_point = true
	# Aim at point directly above head
	input.aim_point = fighter.global_position + Vector2(0, -100)
	await physics_frames(2)
	check(fighter.aim_angle < -1.4, "Mouse aim points up (%.2f rad)" % fighter.aim_angle)
	check(rig.joints.head.rotation < -0.5, "Head follows mouse up (%.2f rad)" % rig.joints.head.rotation)
	
	# Aim at point forward-level
	var hand_pos: Vector2 = fighter.get_node("Visuals/Hand").global_position
	input.aim_point = hand_pos + Vector2(100, 0)
	await physics_frames(2)
	check(is_zero_approx(fighter.aim_angle), "Mouse aim points forward level (%.2f rad)" % fighter.aim_angle)
	check(is_zero_approx(rig.joints.head.rotation), "Head levels with mouse (%.2f rad)" % rig.joints.head.rotation)
	
	# Aim at point low forward
	input.aim_point = fighter.global_position + Vector2(100, 100)
	await physics_frames(2)
	check(fighter.aim_angle > 0.7, "Mouse aim points diagonal down (%.2f rad)" % fighter.aim_angle)
	check(rig.joints.head.rotation > 0.3, "Head tilts towards mouse (%.2f rad)" % rig.joints.head.rotation)
	
	# 4. Crouch and Aim
	input.aim_point = fighter.global_position + Vector2(100, 0)
	input.crouch = true
	await physics_frames(5)
	check(fighter.is_crouching(), "Fighter is crouching")
	check(fighter.is_firearm_drawn(), "Firearm drawn while crouched")
	
	# 5. Move puts weapon away and plays walk
	input.crouch = false
	input.aim_at_point = false
	input.move = 1.0
	await physics_frames(5)
	check(not fighter.is_firearm_drawn(), "Moving puts firearm away")
	check(fighter.get_node("Animator").assigned_animation == "walk", "Walking animation plays when moving")
	
	arena.queue_free()
