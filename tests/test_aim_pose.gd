# Run: tests/run_all.sh test_aim_pose
extends "res://tests/test_case.gd"

## A rig fighter with a gun out keeps its legs animating, holds the gun on its fist and
## points it at the mouse all the way around, standing and crouched. A jump puts it away.

class MouseController extends FighterController:
	func _init() -> void:
		aim_at_point = true


func run() -> void:
	await physics_frames(2)
	var arena: Node = preload("res://scenes/arenas/test_arena.tscn").instantiate()
	root.add_child(arena)
	var fighter: Fighter = preload("res://scenes/fighter/fighter.tscn").instantiate()
	fighter.character = load("res://data/characters/ronin.tres")
	var input := MouseController.new()
	fighter.controller = input
	arena.add_child(fighter)
	fighter.global_position = arena.get_node("SpawnPoints").get_child(0).global_position
	fighter.inventory.equip_firearm(load("res://data/weapons/pistol.tres"))
	await physics_frames(30)
	var animator: AnimationPlayer = fighter.get_node("Animator")
	check(fighter.state() == Fighter.State.AIM, "the fighter aims")
	check(animator.is_playing() and animator.assigned_animation == "idle", "the legs idle under the aim (%s)" % animator.assigned_animation)

	await _circle(fighter, input, "standing")

	input.crouch = true
	await physics_frames(10)
	check(fighter.is_crouching(), "the fighter crouches with the gun out")
	check(animator.assigned_animation == "crouch_idle", "crouching shows with the gun out (%s)" % animator.assigned_animation)
	await _circle(fighter, input, "crouched")
	input.crouch = false
	await physics_frames(10)

	input.jump = true
	await physics_frames(1)
	input.jump = false
	await physics_frames(4)
	check(animator.assigned_animation == "jump_rise", "the jump shows, the gun put away (%s)" % animator.assigned_animation)
	check(not fighter.inventory.firearm.visible, "the gun is put away in the air")
	arena.free()


## Points the mouse around the fighter and checks the gun on the fist and on the line.
func _circle(fighter: Fighter, input: FighterController, where: String) -> void:
	var rig: CharacterRig = fighter.get_node("Visuals/Rig")
	var gun: Weapon = fighter.inventory.firearm
	var worst_fist := 0.0
	var worst_line := 0.0
	var worst_reach := 0.0
	var worst_bend := 0.0
	for degrees in range(0, 360, 45):
		var center := fighter.global_position + Vector2(0, -14)
		input.aim_point = center + Vector2.from_angle(deg_to_rad(degrees)) * 60.0
		await physics_frames(2)
		var fist := rig.hand_anchor.global_position
		worst_fist = maxf(worst_fist, fist.distance_to(gun.get_node("Sprite2D").global_position))
		worst_reach = maxf(worst_reach, fist.distance_to(fighter.get_node("Visuals/Hand").global_position))
		worst_bend = maxf(worst_bend, rad_to_deg(absf(rig.joints.arm_front_lower.rotation)))
		var to_mouse := (input.aim_point - gun.global_position).normalized()
		worst_line = maxf(worst_line, rad_to_deg(absf(to_mouse.angle_to(fighter.aim_direction()))))
	check(worst_fist < 1.0, "%s: the gun is on the fist (off by %.1f px)" % [where, worst_fist])
	check(worst_line < 2.0, "%s: the gun points at the mouse (off by %.1f deg)" % [where, worst_line])
	check(worst_bend < 45.0, "%s: the arm stretches out (elbow bent %.0f deg)" % [where, worst_bend])
	check(worst_reach < 1.5, "%s: the fist reaches the aim's hand (off by %.1f px)" % [where, worst_reach])
