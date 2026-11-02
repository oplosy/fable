class_name StrikeTrail
extends Node2D

## White wind behind a striking fist or foot: three thin streaks along its path that taper
## towards the tail and blow away in `life` seconds. Visual only.

const COLOR := Color(1, 1, 1)
const WIDTH := 1.1
## How far apart the streaks spread at the tail, world px.
const SPREAD := 2.2

@export var life := 0.26

var _points: Array[Vector2] = []
var _ages: Array[float] = []


func _init() -> void:
	# Stays where the strike passed while the fighter moves on.
	top_level = true
	z_index = 20


## Extends the trail to `point` (global).
func add(point: Vector2) -> void:
	_points.append(point)
	_ages.append(0.0)


func _process(delta: float) -> void:
	for i in _ages.size():
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] >= life:
		_ages.pop_front()
		_points.pop_front()
	queue_redraw()


func _draw() -> void:
	for streak: float in [-1.0, 0.0, 1.0]:
		for i in range(1, _points.size()):
			var fade := 1.0 - _ages[i] / life
			var along := _points[i] - _points[i - 1]
			if along.is_zero_approx():
				continue
			var side := along.orthogonal().normalized() * streak * SPREAD * (1.0 - fade)
			var width := WIDTH * fade * (1.0 - absf(streak) * 0.5)
			draw_line(_points[i - 1] + side, _points[i] + side, Color(COLOR, 0.6 * fade), maxf(width, 0.3))
