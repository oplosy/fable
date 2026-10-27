# Run: godot --headless --path . -s res://tests/test_key_bindings.gd
extends "res://tests/test_case.gd"


func run() -> void:
	# Never touch the player's real bindings file.
	KeyBindings.save_path = "user://test_keybindings.cfg"
	KeyBindings.reset_to_defaults()

	check(KeyBindings.key_of("p1_jump").physical_keycode == KEY_SPACE, "player 1 jumps with Space by default")
	check(KeyBindings.key_of("p2_left").physical_keycode == KEY_LEFT, "player 2 moves with the arrows by default")
	check(KeyBindings.key_text("p1_run") == "Left Shift" and KeyBindings.key_text("p2_run") == "Right Shift", "the two Shift keys are told apart")
	check(not _triggers("p1_run", _key(KEY_SHIFT, KEY_LOCATION_RIGHT)), "player 2's Shift does not run player 1")
	var all_keys := {}
	for action in KeyBindings.all_actions():
		var key := KeyBindings.key_of(action)
		all_keys[[key.physical_keycode, key.location]] = true
	check(all_keys.size() == KeyBindings.all_actions().size(), "every default action has its own key")

	KeyBindings.rebind("p1_jump", _key(KEY_L))
	check(_triggers("p1_jump", _key(KEY_L)) and not _triggers("p1_jump", _key(KEY_SPACE)), "rebinding replaces the key")
	KeyBindings.rebind("p1_jump", _key(KEY_J))
	check(_triggers("p1_jump", _key(KEY_J)) and _triggers("p1_attack", _key(KEY_L)), "taking a used key swaps the two bindings")

	# Saved bindings survive a restart.
	InputMap.load_from_project_settings()
	check(_triggers("p1_jump", _key(KEY_SPACE)), "defaults are back before loading")
	KeyBindings.load_saved()
	check(_triggers("p1_jump", _key(KEY_J)) and _triggers("p1_attack", _key(KEY_L)), "saved bindings load")

	KeyBindings.reset_to_defaults()
	check(_triggers("p1_jump", _key(KEY_SPACE)) and not FileAccess.file_exists(KeyBindings.save_path), "reset restores defaults and forgets the file")

	await _test_menu()
	KeyBindings.reset_to_defaults()


func _test_menu() -> void:
	var menu := SettingsMenu.new()
	root.add_child(menu)
	await process_frame
	check(not menu.is_open() and not paused, "the menu starts closed")
	Input.parse_input_event(_key(KEY_ESCAPE, KEY_LOCATION_UNSPECIFIED, true))
	await process_frame
	check(menu.is_open() and paused, "Esc opens the menu and pauses the game")

	menu.start_rebind("p2_attack")
	Input.parse_input_event(_key(KEY_ESCAPE, KEY_LOCATION_UNSPECIFIED, true))
	await process_frame
	check(menu.is_open() and not menu.is_waiting() and _triggers("p2_attack", _key(KEY_PERIOD)), "Esc cancels a rebind and keeps the menu open")

	menu.start_rebind("p2_attack")
	Input.parse_input_event(_key(KEY_ENTER, KEY_LOCATION_UNSPECIFIED, true))
	await process_frame
	check(_triggers("p2_attack", _key(KEY_ENTER)) and not menu.is_waiting(), "pressing a key while waiting binds it")

	Input.parse_input_event(_key(KEY_ESCAPE, KEY_LOCATION_UNSPECIFIED, true))
	await process_frame
	check(not menu.is_open() and not paused, "Esc closes the menu and resumes the game")
	menu.queue_free()


func _triggers(action: String, key: InputEventKey) -> bool:
	return InputMap.action_has_event(action, key) or InputMap.event_is_action(key, action, true)


func _key(code: Key, location := KEY_LOCATION_UNSPECIFIED, pressed := false) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.location = location
	key.pressed = pressed
	return key
