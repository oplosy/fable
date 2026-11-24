# Run: tests/run_all.sh test_svg_rig
extends "res://tests/test_case.gd"

## A cutout rig builds from SVG parts, and a missing part file fails the build cleanly.

const FIXTURE := "res://tests/fixtures/svg_rig/"


func run() -> void:
	var rig := CharacterRig.new()
	root.add_child(rig)
	var built := rig.build(FIXTURE + "rig.json", 1.0)
	check(built, "a rig of SVG parts builds")
	check(rig.joints.size() == 11, "every required part is a joint (%d)" % rig.joints.size())
	if rig.joints.has("pelvis"):
		check((rig.joints.pelvis.get_child(0) as Sprite2D).texture != null, "a part draws its SVG")
	rig.free()

	var broken := CharacterRig.new()
	root.add_child(broken)
	expect_error("hand_front.svg")
	check(not broken.build(FIXTURE + "broken.json", 1.0), "a missing part file fails the build")
	broken.free()
