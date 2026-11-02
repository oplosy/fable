# Run: tests/run_all.sh test_combat_sync
extends "res://tests/test_case.gd"

func run() -> void:
	var arena: Node2D = load("res://scenes/arenas/test_arena.tscn").instantiate()
	root.add_child(arena)
	
	var fighter: Fighter = load("res://scenes/fighter/fighter.tscn").instantiate()
	fighter.character = load("res://data/characters/ronin.tres")
	arena.add_child(fighter)
	fighter.global_position = Vector2(200, 328)
	
	var dummy: Fighter = load("res://scenes/fighter/fighter.tscn").instantiate()
	dummy.character = load("res://data/characters/dummy.tres")
	arena.add_child(dummy)
	dummy.global_position = Vector2(224, 328) # In front of fighter
	
	await physics_frames(2)
	
	var rig: CharacterRig = fighter.get_node_or_null("Visuals/Rig")
	var animator: RigAnimator = fighter.get_node_or_null("Animator")
	var input: FighterController = fighter.controller
	
	check(rig != null, "CharacterRig exists")
	check(animator != null, "RigAnimator exists")
	
	# 1. Test Single Punch: Jab 1 plays exactly ONCE (No double punch bug)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	
	var play_count := 0
	var last_frame_time := 0.0
	for f in 25:
		await physics_frames(1)
		# Track if animation restarted from beginning while still in attack
		var cur_time: float = animator.current_animation_position
		if animator.assigned_animation == "jab_1" and cur_time < last_frame_time and fighter.melee.is_attacking():
			play_count += 1
		last_frame_time = cur_time
	
	check(play_count == 0, "Jab 1 plays exactly once without restarting mid-attack (%d restarts)" % play_count)
	
	# 2. Test Combat Sync: Fist extension during is_hitting()
	await physics_frames(30) # Wait for cooldown
	
	input.attack = true
	await physics_frames(1)
	input.attack = false
	
	var hit_synced := false
	var fist_extended_during_hit := false
	
	for f in 15:
		await physics_frames(1)
		if fighter.melee.is_hitting():
			hit_synced = true
			var hand_x: float = rig.hand_anchor.global_position.x
			var body_x: float = fighter.global_position.x
			# When facing right, front fist must reach forward past body origin
			if hand_x > body_x:
				fist_extended_during_hit = true
	
	check(hit_synced, "Attack reached active hit window (is_hitting)")
	check(fist_extended_during_hit, "Fist is physically extended forward during active hit window")
	
	# 3. Test Attack Placeholder is Hidden for Rig
	var attack_placeholder: ColorRect = fighter.get_node("Visuals/AttackPlaceholder")
	check(not attack_placeholder.visible, "Orange attack placeholder box is hidden on rigged character")
	
	# 4. Test Weapon Attachment: the picture follows the fist, the aim point never moves
	var hand_node: Node2D = fighter.get_node("Visuals/Hand")
	check(hand_node.position == Vector2(4, -14), "The hand, where shots start, is not moved by the animation (%s)" % hand_node.position)
	var drawn_item: Sprite2D = fighter.inventory.item_sprites()[0]
	check(drawn_item.global_position.distance_to(rig.hand_anchor.global_position) < 1.0, "A held item is drawn on the fist (%.2f px)" % drawn_item.global_position.distance_to(rig.hand_anchor.global_position))
	
	# 5. Test Full 4-Hit Combo Chain: Jab 1 -> Jab 2 -> Jab 3 -> Hook
	await physics_frames(70)
	
	input.attack = true
	await physics_frames(1)
	input.attack = false
	check(animator.assigned_animation == "jab_1", "Combo 1: jab_1")
	
	await physics_frames(5)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(20)
	check(animator.assigned_animation == "jab_2", "Combo 2: jab_2")
	
	await physics_frames(5)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(20)
	check(animator.assigned_animation == "jab_3", "Combo 3: jab_3")
	
	await physics_frames(5)
	input.attack = true
	await physics_frames(1)
	input.attack = false
	await physics_frames(20)
	check(animator.assigned_animation == "hook", "Combo 4: hook")
	
	arena.queue_free()
