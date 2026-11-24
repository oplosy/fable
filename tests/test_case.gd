# Base for headless tests: extend it, implement run(), then
# godot --headless --fixed-fps 60 --path . -s res://tests/<test>.gd
# or run every suite with tests/run_all.sh.
extends SceneTree


## Collects engine and script errors, which Godot only prints and never turns into an exit code.
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		errors.append("%s (%s:%d %s)" % [rationale if rationale else code, file, line, function])
		_lock.unlock()


## Seconds of game time before the suite fails; set it in _init for a long suite.
var time_limit := 30.0
var _failed := false
var _errors := ErrorCatcher.new()
var _expected_errors: Array[String] = []


func _initialize() -> void:
	OS.add_logger(_errors)
	# Never read or write the player's real settings file.
	GameSettings.save_path = "user://test_settings.cfg"
	GameSettings.reset_to_defaults()
	# Godot does not exit on script errors, so fail instead of hanging.
	create_timer(time_limit).timeout.connect(func() -> void:
		print("FAIL timed out")
		quit(1))
	await run()
	for fragment in _expected_errors:
		var at := _errors.errors.find_custom(func(error: String) -> bool: return fragment in error)
		if at < 0:
			check(false, "expected error: " + fragment)
		else:
			_errors.errors.remove_at(at)
	for error in _errors.errors:
		check(false, "no engine or script error: " + error)
	print("FAILED" if _failed else "ALL PASSED")
	quit(1 if _failed else 0)


func run() -> void:
	pass


## Marks one engine or script error containing `fragment` as expected, so it does not fail
## the suite; the suite fails if no such error happens.
func expect_error(fragment: String) -> void:
	_expected_errors.append(fragment)


func physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_failed = true
