class_name LocalController
extends FighterController

## Input action prefix; "p1_" reads p1_left, p1_right, p1_up, p1_down, p1_jump, p1_attack.
@export var prefix := "p1_"


func poll() -> void:
	move = Input.get_axis(prefix + "left", prefix + "right")
	aim = Input.get_axis(prefix + "up", prefix + "down")
	jump = Input.is_action_just_pressed(prefix + "jump")
	attack = Input.is_action_just_pressed(prefix + "attack")
	attack_held = Input.is_action_pressed(prefix + "attack")
