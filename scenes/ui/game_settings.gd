class_name GameSettings
extends RefCounted

## Player options other than key bindings; saved to `save_path` and applied on startup.

static var save_path := "user://settings.cfg"
## Player 1 aims and fires with the mouse instead of the aim keys.
static var mouse_aim := false


static func set_mouse_aim(on: bool) -> void:
	mouse_aim = on
	var config := ConfigFile.new()
	config.set_value("aim", "mouse", on)
	var error := config.save(save_path)
	if error != OK:
		push_error("Could not save settings to %s (error %d)" % [save_path, error])


## Applies saved settings; a missing file or malformed entry keeps the default.
static func load_saved() -> void:
	mouse_aim = false
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	var value: Variant = config.get_value("aim", "mouse", false)
	if value is bool:
		mouse_aim = value


static func reset_to_defaults() -> void:
	mouse_aim = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
