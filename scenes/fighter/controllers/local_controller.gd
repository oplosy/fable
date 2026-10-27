class_name LocalController
extends FighterController

## Input action prefix; "p1_" reads p1_left, p1_right, p1_up, p1_down, p1_run, p1_jump, p1_attack, p1_slot_1..4.
@export var prefix := "p1_"
## Max seconds between two taps of the same direction that start a run.
@export var double_tap_time := 0.25

var _held_dir := 0
var _last_tap_dir := 0
var _since_tap := INF
var _tap_run := false


func poll() -> void:
	move = Input.get_axis(prefix + "left", prefix + "right")
	_since_tap += get_physics_process_delta_time()
	var dir := int(signf(move))
	if dir != _held_dir:
		# A double tap runs until the direction is released or changed.
		_tap_run = dir != 0 and dir == _last_tap_dir and _since_tap <= double_tap_time
		if dir != 0:
			_last_tap_dir = dir
			_since_tap = 0.0
		_held_dir = dir
	run = _tap_run or Input.is_action_pressed(prefix + "run")
	aim = Input.get_axis(prefix + "up", prefix + "down")
	down = Input.is_action_just_pressed(prefix + "down")
	jump = Input.is_action_just_pressed(prefix + "jump")
	attack = Input.is_action_just_pressed(prefix + "attack")
	attack_held = Input.is_action_pressed(prefix + "attack")
	select_slot = -1
	for i in 4:
		if Input.is_action_just_pressed(prefix + "slot_%d" % (i + 1)):
			select_slot = i
