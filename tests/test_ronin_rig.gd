# Run: tests/run_all.sh test_ronin_rig
extends "res://tests/test_case.gd"

func run() -> void:
	var data: CharacterData = load("res://data/characters/ronin.tres")
	check(data != null, "ronin.tres loads")
	check(data.rig_file != "", "ronin has rig_file")
	
	var rig: CharacterRig = CharacterRig.new()
	root.add_child(rig)
	await physics_frames(2)
	var built := rig.build(data.rig_file, data.pixels_per_unit)
	check(built, "rig builds successfully from json")
	
	check(rig.joints.size() == 18, "rig has all 18 joints (%d)" % rig.joints.size())
	check(rig.joints.has("foot_front"), "rig has foot_front")
	check(rig.joints.has("foot_back"), "rig has foot_back")
	check(rig.joints.has("hand_front"), "rig has hand_front")
	check(rig.joints.has("hand_back"), "rig has hand_back")
	check(rig.joints.has("scabbard"), "rig has scabbard")
	check(rig.joints.has("head"), "rig has head")
	check(rig.joints.has("torso"), "rig has torso")
	check(rig.joints.has("pelvis"), "rig has pelvis")
	
	# Test Aim Articulation:
	# 1. Aim straight up: the fist lands on the point, above the shoulder
	var shoulder: Vector2 = rig.pivots.arm_front_upper - rig.feet
	var fist: Vector2 = shoulder + Vector2.UP * 16.0
	rig.apply_aim(-PI / 2.0, fist)
	check(rig.joints.head.rotation < -0.4, "head tilts up when aiming up (%.2f)" % rig.joints.head.rotation)
	check(rig.joints.torso.rotation < -0.1, "torso leans back when aiming up (%.2f)" % rig.joints.torso.rotation)
	check(rig.hand_anchor.global_position.distance_to(rig.to_global(fist)) < 0.5, "the fist reaches a point above")

	# 2. Aim straight down and ahead: the same, with no rest of the body in the way
	fist = shoulder + Vector2.DOWN * 16.0
	rig.apply_aim(PI / 2.0, fist)
	check(rig.joints.head.rotation > 0.4, "head tilts down when aiming down (%.2f)" % rig.joints.head.rotation)
	check(rig.joints.torso.rotation > 0.1, "torso leans forward when aiming down (%.2f)" % rig.joints.torso.rotation)
	check(rig.hand_anchor.global_position.distance_to(rig.to_global(fist)) < 0.5, "the fist reaches a point below (%.1f)" % rig.hand_anchor.global_position.distance_to(rig.to_global(fist)))
	fist = shoulder + Vector2.RIGHT * 17.0
	rig.apply_aim(0.0, fist)
	check(rig.hand_anchor.global_position.distance_to(rig.to_global(fist)) < 0.5, "the fist reaches a point ahead (%.1f)" % rig.hand_anchor.global_position.distance_to(rig.to_global(fist)))

	# 3. Reset Pose
	rig.reset_pose()
	check(is_zero_approx(rig.joints.head.rotation), "head resets to 0")
	check(is_zero_approx(rig.joints.torso.rotation), "torso resets to 0")
	
	rig.free()
