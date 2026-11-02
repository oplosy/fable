class_name MouseCursor
extends Node

## Hides the system cursor while mouse aiming; the crosshair square shows the aim. The menu
## brings the cursor back.


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var hidden := GameSettings.mouse_aim and not get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hidden else Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
