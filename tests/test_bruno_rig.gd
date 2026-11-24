# Run: tests/run_all.sh test_bruno_rig
extends "res://tests/test_case.gd"

## Bruno's SVG cutout rig builds with all 15 parts, aims with its arms and resets, and
## every part keeps mipmaps so the zoomed-out shots stay smooth.


func run() -> void:
	var data: CharacterData = load("res://data/characters/bruno.tres")
	check(data != null, "bruno.tres loads")
	if data == null:
		return
	check(data.rig_file != "", "Bruno has a rig_file")

	var rig := CharacterRig.new()
	root.add_child(rig)
	await physics_frames(2)
	check(rig.build(data.rig_file, data.pixels_per_unit), "the rig builds from rig.json")
	check(rig.joints.size() == 15, "the rig has all 15 joints (%d)" % rig.joints.size())
	for part in ["head", "torso", "pelvis", "hand_front", "hand_back", "foot_front", "foot_back"]:
		check(rig.joints.has(part), "the rig has %s" % part)
	check(not rig.joints.has("scabbard"), "Bruno has no scabbard")
	var height: float = rig.feet.y - rig.points.head_top.y
	check(height >= 150.0 and height <= 170.0, "he stands 30 to 34 world px tall (%.0f art px)" % height)
	for joint: Node2D in rig.joints.values():
		var texture := (joint.get_child(0) as Sprite2D).texture
		check(texture.get_image().has_mipmaps(), "%s has mipmaps" % joint.name)

	var shoulder := Vector2(rig.pivots.torso.x, rig.pivots.arm_front_upper.y) - rig.feet
	var fist: Vector2 = shoulder + Vector2.UP * 26.7
	rig.apply_aim(-PI / 2.0, fist)
	check(rig.joints.head.rotation < -0.4, "the head tilts up aiming up (%.2f)" % rig.joints.head.rotation)
	check(rig.joints.torso.rotation < -0.1, "the torso leans back aiming up (%.2f)" % rig.joints.torso.rotation)
	check(rig.hand_anchor.global_position.distance_to(rig.to_global(fist)) < 0.5, "the fist reaches a point above")
	fist = shoulder + Vector2.DOWN * 26.7
	rig.apply_aim(PI / 2.0, fist)
	check(rig.joints.head.rotation > 0.4, "the head tilts down aiming down (%.2f)" % rig.joints.head.rotation)
	check(rig.hand_anchor.global_position.distance_to(rig.to_global(fist)) < 0.5, "the fist reaches a point below")
	fist = shoulder + Vector2.RIGHT * 28.3
	rig.apply_aim(0.0, fist)
	check(rig.hand_anchor.global_position.distance_to(rig.to_global(fist)) < 0.5, "the fist reaches a point ahead (%.1f)" % rig.hand_anchor.global_position.distance_to(rig.to_global(fist)))

	rig.reset_pose()
	check(is_zero_approx(rig.joints.head.rotation), "the head resets")
	check(is_zero_approx(rig.joints.torso.rotation), "the torso resets")
	rig.free()
