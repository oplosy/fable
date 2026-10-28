class_name TuningPanel
extends CanvasLayer

## Developer panel (F1, debug builds only) for tuning how fighters move while playing.
## Sliders change player 1's FighterClass live (shared by every fighter of that class);
## Save writes it back to its .tres, Reset reloads the saved values.

## Drawn this many times its size, so it reads on the 1920x1080 render.
const UI_SCALE := 1.5
## [property, min, max, step]; "a:x" is the x of Vector2 property a.
const PARAMS := [
	["walk_speed", 40.0, 300.0, 5.0],
	["run_speed", 80.0, 400.0, 5.0],
	["crouch_speed", 20.0, 150.0, 5.0],
	["acceleration", 200.0, 5000.0, 50.0],
	["friction", 200.0, 5000.0, 50.0],
	["air_acceleration", 0.0, 3000.0, 50.0],
	["jump_velocity", -600.0, -120.0, 5.0],
	["gravity_scale", 0.3, 3.0, 0.05],
	["fall_gravity_scale", 0.3, 4.0, 0.05],
	["jump_cut", 0.0, 1.0, 0.05],
	["coyote_time", 0.0, 0.25, 0.01],
	["jump_buffer", 0.0, 0.25, 0.01],
	["dive_velocity:x", 100.0, 500.0, 5.0],
	["dive_velocity:y", -500.0, -50.0, 5.0],
	["roll_speed", 80.0, 450.0, 5.0],
	["roll_time", 0.1, 1.0, 0.05],
	["climb_speed", 30.0, 250.0, 5.0],
]

## Returns the class being tuned, or null when there is no player yet.
var source: Callable

var _panel: PanelContainer
var _sliders := {} ## property -> HSlider
var _values := {} ## property -> Label
var _summary: Label
var _status: Label
var _tuned: FighterClass


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 9
	_build()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refresh()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _panel.visible and source.is_valid() and source.call() != _tuned:
		_refresh()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.scale = Vector2.ONE * UI_SCALE
	_panel.position = Vector2(16, 16)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Movement tuning (F1)"
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	for param: Array in PARAMS:
		var property: String = param[0]
		var name_label := Label.new()
		name_label.text = property.replace("_", " ").replace(":", " ")
		grid.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = param[1]
		slider.max_value = param[2]
		slider.step = param[3]
		slider.custom_minimum_size.x = 160
		# No keyboard focus: the arrow keys move player 2, not sliders.
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(_on_slider.bind(property))
		grid.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size.x = 48
		grid.add_child(value)
		_sliders[property] = slider
		_values[property] = value
	_summary = Label.new()
	box.add_child(_summary)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for action: Array in [["Save", _save], ["Reset", _reset]]:
		var button := Button.new()
		button.text = action[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(action[1])
		buttons.add_child(button)
	_status = Label.new()
	buttons.add_child(_status)


## Shows the tuned class's current values.
func _refresh() -> void:
	_tuned = source.call() if source.is_valid() else null
	_status.text = "%s (%s)" % [_tuned.display_name, _tuned.resource_path.get_file()] if _tuned else "no player"
	if _tuned == null:
		return
	for property: String in _sliders:
		_sliders[property].set_value_no_signal(_tuned.get_indexed(property))
		_show_value(property)
	_update_summary()


func _on_slider(value: float, property: String) -> void:
	if _tuned == null:
		return
	_tuned.set_indexed(property, value)
	_show_value(property)
	_update_summary()


func _show_value(property: String) -> void:
	_values[property].text = str(snappedf(_tuned.get_indexed(property), 0.01))


## What the values mean on the map: jump height and reach, in px and 16 px tiles.
func _update_summary() -> void:
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var c := _tuned
	var rise := gravity * c.gravity_scale
	var fall := gravity * c.fall_gravity_scale
	var height := c.jump_velocity * c.jump_velocity / (2.0 * rise)
	var air := -c.jump_velocity / rise + sqrt(2.0 * height / fall)
	var dive_height := c.dive_velocity.y * c.dive_velocity.y / (2.0 * rise)
	var dive_air := -c.dive_velocity.y / rise + sqrt(2.0 * dive_height / fall)
	_summary.text = "Jump %.0f px high (%.1f tiles), %.2f s in the air\nWalking jump reaches %.0f px, dive %.0f px (%.1f tiles)\nWalk speed in %.2f s, stop in %.2f s" % [
		height, height / 16.0, air, c.walk_speed * air, c.dive_velocity.x * dive_air, c.dive_velocity.x * dive_air / 16.0,
		c.walk_speed / c.acceleration, c.walk_speed / c.friction]


func _save() -> void:
	if _tuned and _tuned.resource_path != "":
		var error := ResourceSaver.save(_tuned)
		_status.text = "saved %s" % _tuned.resource_path.get_file() if error == OK else "save failed: %s" % error_string(error)


func _reset() -> void:
	if _tuned == null or _tuned.resource_path == "":
		return
	var saved: FighterClass = ResourceLoader.load(_tuned.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	for property: String in _sliders:
		_tuned.set_indexed(property, saved.get_indexed(property))
	_refresh()
