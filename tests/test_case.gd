# Base for headless tests: extend it, implement run(), then
# godot --headless --path . -s res://tests/<test>.gd
extends SceneTree

var _failed := false


func _initialize() -> void:
	# Godot does not exit on script errors, so fail instead of hanging.
	create_timer(30.0).timeout.connect(func() -> void:
		print("FAIL timed out")
		quit(1))
	await run()
	print("FAILED" if _failed else "ALL PASSED")
	quit(1 if _failed else 0)


func run() -> void:
	pass


func physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_failed = true
