class_name LocalController
extends FighterController

## Input action prefix; "p1_" reads p1_left, p1_right, p1_up, p1_down, p1_jump, p1_attack, p1_slot_1..4.
@export var prefix := "p1_"


func poll() -> void:
	move = Input.get_axis(prefix + "left", prefix + "right")
	aim = Input.get_axis(prefix + "up", prefix + "down")
	jump = Input.is_action_just_pressed(prefix + "jump")
	attack = Input.is_action_just_pressed(prefix + "attack")
	attack_held = Input.is_action_pressed(prefix + "attack")
	select_slot = -1
	for i in 4:
		if Input.is_action_just_pressed(prefix + "slot_%d" % (i + 1)):
			select_slot = i
