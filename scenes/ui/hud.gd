class_name Hud
extends CanvasLayer

## Each player's health and kills, the kill goal and the winner. Only shows what the mode
## and the fighters report; it never changes the match.

## Laid out for a 640x360 screen and drawn 3x on the 1920x1080 render, like SettingsMenu.
const UI_SCALE := 3.0
const MARGIN := 6.0
const PANEL_WIDTH := 96.0
const BAR_HEIGHT := 6.0
const PLAYER_COLOURS: Array[Color] = [Color(0.3, 0.65, 1.0), Color(1.0, 0.4, 0.35)]
const OUTLINE := Color(0.05, 0.05, 0.1)

var _bars: Array[ProgressBar] = []
var _kills: Array[Label] = []
var _goal: Label
var _result: PanelContainer
var _winner: Label
var _names: Array[String] = []


## Builds the screen for `mode`'s players, one name each. Call it once, before following
## any fighter.
func setup(mode: Deathmatch, names: Array[String]) -> void:
	_names = names
	layer = 5
	scale = Vector2.ONE * UI_SCALE
	var screen := Control.new()
	screen.size = get_viewport().get_visible_rect().size / UI_SCALE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	var row := HBoxContainer.new()
	row.position = Vector2.ONE * MARGIN
	row.size.x = screen.size.x - MARGIN * 2.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(row)
	var players := mode.kills.size()
	for player in players:
		row.add_child(_player_panel(player))
		if player < players - 1:
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
	_goal = _label("First to %d" % mode.kill_limit)
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal.position = Vector2(0.0, MARGIN)
	_goal.size.x = screen.size.x
	screen.add_child(_goal)
	screen.add_child(_result_panel(screen.size))
	mode.score_changed.connect(_show_kills)
	mode.match_ended.connect(_show_winner)


## Points `player`'s health bar at `fighter`, e.g. after a respawn.
func follow(player: int, fighter: Fighter) -> void:
	var bar := _bars[player]
	bar.max_value = fighter.health.max_health
	bar.value = fighter.health.current
	fighter.health.damaged.connect(func(_amount: int) -> void: bar.value = fighter.health.current)


func health_shown(player: int) -> float:
	return _bars[player].value


func kills_shown(player: int) -> String:
	return _kills[player].text


func winner_shown() -> String:
	return _winner.text if _result.visible else ""


func _player_panel(player: int) -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_constant_override("separation", 1)
	var head := HBoxContainer.new()
	panel.add_child(head)
	var name_label := _label(_names[player])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", PLAYER_COLOURS[player])
	head.add_child(name_label)
	var kills := _label("0")
	head.add_child(kills)
	_kills.append(kills)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = BAR_HEIGHT
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _box(OUTLINE))
	bar.add_theme_stylebox_override("fill", _box(PLAYER_COLOURS[player]))
	panel.add_child(bar)
	_bars.append(bar)
	return panel


func _result_panel(screen_size: Vector2) -> Control:
	_result = PanelContainer.new()
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_theme_stylebox_override("panel", _box(Color(OUTLINE, 0.85), 10))
	_result.visible = false
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_result.add_child(box)
	_winner = _label("")
	_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_winner)
	var again := _label("Attack for a rematch")
	again.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(again)
	_result.custom_minimum_size = Vector2(150.0, 50.0)
	_result.position = (screen_size - _result.custom_minimum_size) / 2.0
	return _result


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	return label


func _box(colour: Color, margin := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_content_margin_all(margin)
	return box


func _show_kills(player: int, kills: int) -> void:
	_kills[player].text = str(kills)


func _show_winner(winner: int) -> void:
	_winner.text = "%s wins!" % _names[winner]
	_winner.add_theme_color_override("font_color", PLAYER_COLOURS[winner])
	_result.visible = true
