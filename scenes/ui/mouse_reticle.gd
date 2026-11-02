class_name MouseReticle
extends Node2D

## A small ring at the mouse while mouse aiming, in place of the system cursor. The menu
## brings the cursor back. Visual only.

## Radius of the ring, world px.
const RADIUS := 4.0
const COLOR := Color(1, 1, 1, 0.7)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 30
	visible = false


func _process(_delta: float) -> void:
	visible = GameSettings.mouse_aim and not get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if visible else Input.MOUSE_MODE_VISIBLE
	global_position = get_global_mouse_position()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, COLOR, 1.0)
