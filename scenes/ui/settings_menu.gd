class_name SettingsMenu
extends CanvasLayer

## Esc opens and closes the menu and pauses the game while it is open.
## Click a binding, then press the new key; Esc cancels. Escape itself cannot be bound.

const LABELS := {
	"left": "Move left", "right": "Move right", "up": "Aim up", "down": "Aim down / roll / swap",
	"run": "Run", "crouch": "Crouch", "jump": "Jump", "attack": "Attack",
	"slot_1": "Slot 1", "slot_2": "Slot 2", "slot_3": "Slot 3", "slot_4": "Slot 4",
}

var _panel: PanelContainer
var _buttons := {} ## action name -> Button
var _waiting_for := "" ## Action waiting for its new key, "" when none.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	close()


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_panel.visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	_panel.visible = false
	_waiting_for = ""
	get_tree().paused = false


func start_rebind(action: String) -> void:
	_waiting_for = action
	_refresh()


func is_waiting() -> bool:
	return _waiting_for != ""


# _input runs before the GUI, so arrow keys and Space reach the rebind instead of moving focus.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if is_waiting():
		if key.physical_keycode != KEY_ESCAPE:
			KeyBindings.rebind(_waiting_for, key)
		_waiting_for = ""
		_refresh()
	elif key.physical_keycode == KEY_ESCAPE and is_open():
		close()
	elif key.physical_keycode == KEY_ESCAPE:
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func _build() -> void:
	# Compact rows so every action fits the 360 px tall viewport.
	var theme := Theme.new()
	theme.default_font_size = 9
	theme.set_constant("v_separation", "GridContainer", 1)
	var compact := StyleBoxFlat.new()
	compact.bg_color = Color(0.2, 0.22, 0.27)
	compact.set_content_margin_all(2)
	compact.content_margin_left = 6
	compact.content_margin_right = 6
	var compact_hover: StyleBoxFlat = compact.duplicate()
	compact_hover.bg_color = Color(0.3, 0.33, 0.4)
	theme.set_stylebox("normal", "Button", compact)
	theme.set_stylebox("pressed", "Button", compact)
	theme.set_stylebox("hover", "Button", compact_hover)
	_panel = PanelContainer.new()
	_panel.theme = theme
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var box := VBoxContainer.new()
	_panel.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var title := Label.new()
	title.text = "Controls (Esc closes)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var grid := GridContainer.new()
	grid.columns = KeyBindings.PLAYERS + 1
	box.add_child(grid)
	grid.add_child(Label.new())
	for player in range(1, KeyBindings.PLAYERS + 1):
		var header := Label.new()
		header.text = "Player %d" % player
		grid.add_child(header)
	for action in KeyBindings.ACTIONS:
		var label := Label.new()
		label.text = LABELS.get(action, action.capitalize())
		grid.add_child(label)
		for player in range(1, KeyBindings.PLAYERS + 1):
			var action_id := KeyBindings.action_name(player, action)
			var button := Button.new()
			button.custom_minimum_size.x = 80
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(start_rebind.bind(action_id))
			grid.add_child(button)
			_buttons[action_id] = button

	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void:
		KeyBindings.reset_to_defaults()
		_refresh())
	row.add_child(reset)
	var done := Button.new()
	done.text = "Close"
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(close)
	row.add_child(done)


func _refresh() -> void:
	for action_id: String in _buttons:
		_buttons[action_id].text = "press a key..." if action_id == _waiting_for else KeyBindings.key_text(action_id)
