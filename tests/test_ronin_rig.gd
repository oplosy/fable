# Run: tests/run_all.sh test_ronin_rig
extends "res://tests/test_case.gd"

func run() -> void:
	var data: CharacterData = load("res://data/characters/ronin.tres")
	check(data != null, "ronin.tres loads")
	check(data.rig_file != "", "ronin has rig_file")
	
	var rig: CharacterRig = CharacterRig.new()
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
	# 1. Aim Straight Up (-PI/2)
	rig.apply_aim(-PI / 2.0)
	check(rig.joints.head.rotation < -0.4, "head tilts up when aiming up (%.2f)" % rig.joints.head.rotation)
	check(rig.joints.torso.rotation < -0.2, "torso leans back when aiming up (%.2f)" % rig.joints.torso.rotation)
	check(rig.joints.arm_front_upper.rotation < -0.8, "arm points up (%.2f)" % rig.joints.arm_front_upper.rotation)
	
	# 2. Aim Straight Down (+PI/2)
	rig.apply_aim(PI / 2.0)
	check(rig.joints.head.rotation > 0.4, "head tilts down when aiming down (%.2f)" % rig.joints.head.rotation)
	check(rig.joints.torso.rotation > 0.2, "torso leans forward when aiming down (%.2f)" % rig.joints.torso.rotation)
	check(rig.joints.arm_front_upper.rotation > 0.8, "arm points down (%.2f)" % rig.joints.arm_front_upper.rotation)
	
	# 3. Reset Pose
	rig.reset_pose()
	check(is_zero_approx(rig.joints.head.rotation), "head resets to 0")
	check(is_zero_approx(rig.joints.torso.rotation), "torso resets to 0")
	
	rig.free()
