class_name KeyBindings
extends RefCounted

## Per-player key bindings: one key per pN_ action. Defaults come from the project's
## input map; changes are saved to `save_path` and applied on startup.

const PLAYERS := 2
const ACTIONS: Array[String] = ["left", "right", "up", "down", "crouch", "jump", "attack", "slot_1", "slot_2", "slot_3", "slot_4"]

static var save_path := "user://keybindings.cfg"


static func action_name(player: int, action: String) -> String:
	return "p%d_%s" % [player, action]


static func all_actions() -> Array[String]:
	var names: Array[String] = []
	for player in range(1, PLAYERS + 1):
		for action in ACTIONS:
			names.append(action_name(player, action))
	return names


static func key_of(action: String) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event
	return null


static func key_text(action: String) -> String:
	var key := key_of(action)
	if key == null:
		return "-"
	var side: String = {KEY_LOCATION_LEFT: "Left ", KEY_LOCATION_RIGHT: "Right "}.get(key.location, "")
	return side + key.as_text_physical_keycode()


## Binds `key` to `action`. An action that already used the key gets the
## action's old key instead, so no action is ever left unbound.
static func rebind(action: String, key: InputEventKey) -> void:
	var bound := _plain_key(key)
	var old := key_of(action)
	for other in all_actions():
		if other != action and _same_key(key_of(other), bound):
			_set_key(other, old)
	_set_key(action, bound)
	save()


static func reset_to_defaults() -> void:
	InputMap.load_from_project_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


static func save() -> void:
	var config := ConfigFile.new()
	for action in all_actions():
		var key := key_of(action)
		if key:
			config.set_value("keys", action, [key.physical_keycode, key.location])
	var error := config.save(save_path)
	if error != OK:
		push_error("Could not save key bindings to %s (error %d)" % [save_path, error])


## Applies saved bindings over the defaults; unknown or malformed entries are ignored.
static func load_saved() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	for action in all_actions():
		var value: Variant = config.get_value("keys", action, null)
		if value is Array and value.size() == 2 and value[0] is int and value[1] is int:
			var key := InputEventKey.new()
			key.physical_keycode = value[0]
			key.location = value[1]
			_set_key(action, key)


static func _plain_key(key: InputEventKey) -> InputEventKey:
	var plain := InputEventKey.new()
	plain.physical_keycode = key.physical_keycode
	plain.location = key.location
	return plain


static func _same_key(a: InputEventKey, b: InputEventKey) -> bool:
	return a != null and b != null and a.physical_keycode == b.physical_keycode and a.location == b.location


static func _set_key(action: String, key: InputEventKey) -> void:
	InputMap.action_erase_events(action)
	if key:
		InputMap.action_add_event(action, key)
