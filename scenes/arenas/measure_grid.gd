extends Node2D

## Measuring lines for tuning movement: a vertical line every `step` px along the floor
## and a horizontal one every `step` px above it, labelled in world px from this node
## (the floor's left end). Visual only.

@export var width := 608.0
@export var height := 160.0
@export var step := 8.0
## Every this many lines is drawn brighter and labelled.
@export var major_every := 4
@export var minor_color := Color(1, 1, 1, 0.08)
@export var major_color := Color(1, 1, 1, 0.25)
@export var label_color := Color(1, 1, 1, 0.6)
@export var font_size := 6


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var lines := int(width / step)
	for i in lines + 1:
		var x := i * step
		var major := i % major_every == 0
		draw_line(Vector2(x, 0), Vector2(x, -height), major_color if major else minor_color)
		if major:
			draw_string(font, Vector2(x + 1, 7), str(int(x)), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
	for i in range(1, int(height / step) + 1):
		var y := -i * step
		var major := i % major_every == 0
		draw_line(Vector2(0, y), Vector2(width, y), major_color if major else minor_color)
		if major:
			draw_string(font, Vector2(1, y - 1), str(int(-y)), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
