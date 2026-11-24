extends Node2D

## Renders a character in a row of poses at a camera zoom and saves the picture, for
## reviewing rig art without playing. Run with a window (not headless):
##   <godot> --path . --windowed --resolution 1920x1080 res://tools/preview_rig.tscn --
##       --character=res://data/characters/bruno.tres --out=C:/path/preview.png
##       [--poses=idle:0,run:0.1,jab_1:0.12,aim:-0.5] [--zoom=5]
## A pose is clip:seconds, or aim:radians. A 12x28 hitbox outline sits on every pose.

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const SPACING := 44.0
const HITBOX := Vector2(12, 28)


func _ready() -> void:
	var args := {"poses": "idle:0,run:0.1,jab_1:0.12,jump_kick:0.1,aim:0", "zoom": "5"}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			args[pair[0]] = pair[1]
	if not args.has("character") or not args.has("out"):
		push_error("preview_rig: pass --character=<res path> and --out=<png path>")
		get_tree().quit(1)
		return
	var character: CharacterData = load(args.character)
	var poses: PackedStringArray = args.poses.split(",")
	for i in poses.size():
		var at := Vector2((i - (poses.size() - 1) / 2.0) * SPACING, 0.0)
		await _pose(character, poses[i], at)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * float(args.zoom)
	camera.position = Vector2(0, -16)
	add_child(camera)
	camera.make_current()
	for i in 3:
		await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(args.out)
	print("preview_rig: saved %s (%s)" % [args.out, error_string(error)])
	get_tree().quit(0 if error == OK else 1)


func _pose(character: CharacterData, pose: String, at: Vector2) -> void:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	fighter.character = character
	add_child(fighter)
	fighter.position = at
	fighter.set_physics_process(false)
	await get_tree().process_frame
	var animator := fighter.get_node_or_null("Animator") as RigAnimator
	var rig := fighter.get_node_or_null("Visuals/Rig") as CharacterRig
	if animator == null or rig == null:
		push_error("preview_rig: %s has no rig" % character.resource_path)
		return
	animator.set_physics_process(false)
	var parts := pose.split(":")
	var value := float(parts[1]) if parts.size() > 1 else 0.0
	if parts[0] == "aim":
		animator.play("aim_idle")
		animator.seek(0.0, true)
		# The aim holds the arm nearly straight, as the game does with the character's aim_reach.
		var reach: float = character.aim_reach * character.pixels_per_unit
		if reach <= 0.0:
			reach = 0.9 * ((rig.pivots.arm_front_lower - rig.pivots.arm_front_upper).length() + (rig.points.hand_front - rig.pivots.arm_front_lower).length())
		var shoulder := Vector2(rig.pivots.torso.x, rig.pivots.arm_front_upper.y) - rig.feet
		rig.apply_aim(value, shoulder + Vector2.from_angle(value) * reach)
	else:
		animator.play(parts[0])
		animator.seek(value, true)
	var outline := Line2D.new()
	outline.points = [Vector2(-HITBOX.x / 2, 0), Vector2(-HITBOX.x / 2, -HITBOX.y), Vector2(HITBOX.x / 2, -HITBOX.y), Vector2(HITBOX.x / 2, 0)]
	outline.closed = true
	outline.width = 0.2
	outline.default_color = Color(0, 0.7, 1, 0.8)
	outline.position = at
	outline.z_index = 100
	add_child(outline)
