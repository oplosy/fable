# Run: godot --headless --path . -s res://tests/test_fighter.gd
extends "res://tests/test_case.gd"


func run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frames(30)
	var fighter: Fighter = main.players[0]

	check(fighter.is_on_floor(), "fighter rests on the floor")
	check(fighter.get_node("Visuals/Placeholder").color == fighter.character.placeholder_color, "character data sets the look")
	var floor_y := fighter.position.y

	var start_x := fighter.position.x
	Input.action_press("p1_right")
	await physics_frames(30)
	Input.action_release("p1_right")
	check(fighter.position.x > start_x + 10.0, "p1_right moves the fighter right")
	check(fighter.facing == 1, "fighter faces right")

	start_x = fighter.position.x
	Input.action_press("p1_left")
	await physics_frames(30)
	Input.action_release("p1_left")
	check(fighter.position.x < start_x - 10.0, "p1_left moves the fighter left")
	check(fighter.facing == -1 and fighter.get_node("Visuals").scale.x == -1, "fighter faces and flips left")

	Input.action_press("p1_jump")
	await physics_frames(10)
	Input.action_release("p1_jump")
	check(fighter.position.y < floor_y - 20.0, "jump lifts the fighter")
	check(not fighter.inventory.firearm.visible, "firearm is put away in the air")

	await physics_frames(90)
	# Collision safe margin leaves a sub-pixel gap, so compare within half a pixel.
	check(fighter.is_on_floor() and absf(fighter.position.y - floor_y) < 0.5, "fighter lands back on the floor")

	Input.action_press("p1_right")
	await physics_frames(300)
	Input.action_release("p1_right")
	check(fighter.position.x < 632.0, "right wall stops the fighter")

	check(fighter.inventory.firearm != null and fighter.inventory.firearm.data.display_name == "Pistol", "fighter spawns with the pistol")
	check(fighter.inventory.active_slot == Inventory.Slot.FIREARM, "firearm slot is active")
	await physics_frames(2)
	check(fighter.inventory.firearm.visible, "standing fighter holds the firearm")

	Input.action_press("p1_left")
	await physics_frames(10)
	check(not fighter.inventory.firearm.visible, "moving puts the firearm away")
	Input.action_press("p1_attack")
	await physics_frames(2)
	Input.action_release("p1_attack")
	check(get_nodes_in_group("projectiles").is_empty(), "no firing while moving")
	await physics_frames(10)
	Input.action_release("p1_left")
	await physics_frames(2)
	check(fighter.inventory.firearm.visible, "stopping draws the firearm again")
	await physics_frames(20)

	# Fighter reads the press on the next physics frame, so wait two.
	Input.action_press("p1_attack")
	await physics_frames(2)
	Input.action_release("p1_attack")
	var bullets := get_nodes_in_group("projectiles")
	check(bullets.size() == 1, "fire spawns one bullet")
	if bullets.size() == 1:
		var bullet: Projectile = bullets[0]
		check(bullet.velocity.x < 0.0 and bullet.global_position.x < fighter.global_position.x, "bullet leaves the muzzle facing left")
		check(bullet.get_parent() == main.arena, "bullet lives in the arena")

	Input.action_press("p1_attack")
	await physics_frames(2)
	Input.action_release("p1_attack")
	check(get_nodes_in_group("projectiles").size() == 1, "cooldown blocks a second shot")

	await physics_frames(120)
	check(get_nodes_in_group("projectiles").is_empty(), "bullet is removed after hitting the wall")

	# Count spawns rather than live bullets: a shot may already have hit player 2.
	var shots := [0]
	var count_shot := func(node: Node) -> void:
		if node is Projectile:
			shots[0] += 1
	main.arena.child_entered_tree.connect(count_shot)
	Input.action_press("p1_attack")
	await physics_frames(30)
	Input.action_release("p1_attack")
	main.arena.child_entered_tree.disconnect(count_shot)
	check(shots[0] == 1, "semi-auto pistol fires once while held")

	Input.action_press("p1_up")
	await physics_frames(30)
	check(fighter.aim_angle < -0.3 and fighter.aim_angle > -PI / 2.0, "W raises the aim gradually")
	await physics_frames(90)
	Input.action_release("p1_up")
	check(is_equal_approx(fighter.aim_angle, -PI / 2.0), "aim stops at straight up")
	check(fighter.aim_direction().y < -0.99, "aim points up")

	Input.action_press("p1_down")
	await physics_frames(150)
	Input.action_release("p1_down")
	check(is_equal_approx(fighter.aim_angle, PI / 2.0), "S lowers the aim to straight down")

	var held_angle := fighter.aim_angle
	Input.action_press("p1_right")
	Input.action_press("p1_up")
	await physics_frames(10)
	Input.action_release("p1_up")
	Input.action_release("p1_right")
	await physics_frames(30)
	check(fighter.aim_angle == held_angle, "aim does not change while moving")
	check(fighter.facing == 1 and fighter.aim_direction().x >= 0.0, "aim is kept and mirrored after turning")

	Input.action_press("p1_up")
	await physics_frames(60)
	Input.action_release("p1_up")
	await physics_frames(30)
	var aim := fighter.aim_direction()
	Input.action_press("p1_attack")
	await physics_frames(2)
	Input.action_release("p1_attack")
	bullets = get_nodes_in_group("projectiles")
	check(bullets.size() == 1, "aimed shot spawns one bullet")
	if bullets.size() == 1:
		var bullet: Projectile = bullets[0]
		var spread := deg_to_rad(fighter.inventory.firearm.spread()) + 0.001
		check(absf(bullet.velocity.angle_to(aim)) <= spread, "bullet travels along the aim within the spread")
		check(is_equal_approx(bullet.rotation, bullet.velocity.angle()), "bullet is rotated to its flight direction")
		var muzzle := fighter.inventory.firearm.to_global(fighter.inventory.firearm.data.muzzle - fighter.inventory.firearm.data.grip)
		check(bullet.global_position.distance_to(muzzle) < bullet.velocity.length() / 30.0, "bullet starts at the rotated muzzle")

	await _press("p1_slot_1")
	check(fighter.inventory.active_slot == Inventory.Slot.MELEE and not fighter.inventory.firearm.visible, "key 1 selects melee and puts the firearm away")
	await _press("p1_slot_4")
	check(fighter.inventory.active_slot == Inventory.Slot.MELEE, "empty power-up slot cannot be selected")
	await _press("p1_slot_3")
	check(fighter.inventory.active_slot == Inventory.Slot.THROWABLE, "key 3 selects the starting grenades")
	await _press("p1_slot_2")
	check(fighter.inventory.active_slot == Inventory.Slot.FIREARM and fighter.inventory.firearm.visible, "key 2 selects and draws the firearm")

	var big_data := CharacterData.new()
	big_data.body_size = Vector2(20, 40)
	var big: Fighter = load("res://scenes/fighter/fighter.tscn").instantiate()
	big.character = big_data
	main.arena.add_child(big)
	big.global_position = Vector2(200, 300)
	await physics_frames(30)
	var shape: RectangleShape2D = big.body_shape().shape
	check(shape.size == Vector2(20, 40) and big.is_on_floor(), "the character sets the body size and it stands on the floor")
	check(fighter.body_shape().shape.size == CharacterData.DEFAULT_BODY_SIZE, "other fighters keep their own body size")
	big.controller.crouch = true
	await physics_frames(2)
	check(big.body_shape().shape.size == Vector2(20, 20), "crouching halves the character's height")

	var art_data := CharacterData.new()
	art_data.texture = ImageTexture.create_from_image(Image.create(64, 96, false, Image.FORMAT_RGBA8))
	var drawn: Fighter = load("res://scenes/fighter/fighter.tscn").instantiate()
	drawn.character = art_data
	main.arena.add_child(drawn)
	var art: Sprite2D = drawn.get_node("Visuals/Art")
	var feet_at := art.get_global_transform() * (art.offset + art_data.feet)
	check(art.scale == Vector2.ONE / 3.0 and not drawn.get_node("Visuals/Placeholder").visible, "character art is drawn at 1/3 scale in place of the placeholder")
	check(feet_at.is_equal_approx(drawn.global_position), "the art's feet pixel stands on the fighter's origin")

	var agent: Fighter = load("res://scenes/fighter/fighter.tscn").instantiate()
	agent.character = load("res://data/characters/trenchcoat_agent.tres")
	main.arena.add_child(agent)
	agent.global_position = Vector2(400, 300)
	var rig: CharacterRig = agent.get_node_or_null("Visuals/Rig")
	check(rig != null and rig.joints.size() == 12 and not agent.get_node("Visuals/Placeholder").visible, "a rigged character builds its 12 parts in place of the placeholder")
	if rig:
		var neck := agent.global_position + (Vector2(33, 22) - Vector2(32, 93)) / 3.0
		check(rig.joints.head.global_position.is_equal_approx(neck), "each part's joint sits on its rig.json pivot (head at %s, want %s)" % [rig.joints.head.global_position, neck])
		var head_before: Vector2 = rig.joints.head.global_position
		rig.joints.torso.rotation = PI / 2.0
		check(not rig.joints.head.global_position.is_equal_approx(head_before), "turning the torso carries the head with it")
		check(rig.points.hand_front == Vector2(24, 49), "the rig keeps its hand and head points")


func _press(action: String) -> void:
	Input.action_press(action)
	await physics_frames(2)
	Input.action_release(action)
	await physics_frames(1)
