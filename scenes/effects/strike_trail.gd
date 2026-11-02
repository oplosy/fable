class_name StrikeTrail
extends Node2D

## White wind behind a striking limb: fills everything the limb sweeps, from its root to its
## tip, and blows away in `life` seconds, oldest part first. Visual only.

const COLOR := Color(1, 1, 1)
const OPACITY := 0.85
## Pieces drawn between two samples of the limb.
const CURVE_STEPS := 4

@export var life := 0.3

var _tips: Array[Vector2] = []
var _roots: Array[Vector2] = []
var _ages: Array[float] = []


func _init() -> void:
	# Stays where the strike passed while the fighter moves on.
	top_level = true


## Extends the trail to where the limb is now, `root` and `tip` global.
func add(tip: Vector2, root: Vector2) -> void:
	_tips.append(tip)
	_roots.append(root)
	_ages.append(0.0)


func _process(delta: float) -> void:
	for i in _ages.size():
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] >= life:
		_ages.pop_front()
		_tips.pop_front()
		_roots.pop_front()
	queue_redraw()


func _draw() -> void:
	for i in range(1, _tips.size()):
		for step in CURVE_STEPS:
			var from := float(step) / CURVE_STEPS
			var to := float(step + 1) / CURVE_STEPS
			var older := _color(i, from)
			var newer := _color(i, to)
			# Four points draw a plain quad, which stays valid when the limb crosses itself.
			draw_primitive(
				PackedVector2Array([_on_curve(_tips, i, from), _on_curve(_tips, i, to), _on_curve(_roots, i, to), _on_curve(_roots, i, from)]),
				PackedColorArray([older, newer, newer, older]),
				PackedVector2Array()
			)


func _color(i: int, weight: float) -> Color:
	return Color(COLOR, OPACITY * (1.0 - lerpf(_ages[i - 1], _ages[i], weight) / life))


## A point `weight` of the way from sample `i - 1` to sample `i`, rounding the corners between them.
func _on_curve(points: Array[Vector2], i: int, weight: float) -> Vector2:
	var before := points[maxi(i - 2, 0)]
	var after := points[mini(i + 1, points.size() - 1)]
	return points[i - 1].cubic_interpolate(points[i], before, after, weight)
