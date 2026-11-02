class_name LandingDust
extends Node2D

## Dust thrown out to both sides where a fighter lands, bigger the harder it fell, gone in
## `life` seconds. Visual only.

const PUFFS := 5
const COLOR := Color(0.9, 0.88, 0.82)
## Slower landings raise no dust, world px/s.
const MIN_FALL_SPEED := 150.0
## Landing speed of the biggest dust.
const FULL_FALL_SPEED := 450.0

@export var life := 1.0
## How far the outermost puff travels, world px, at full size.
@export var reach := 16.0
var size := 1.0

var _age := 0.0


## Adds dust to `parent` at `point` (global) for a landing at `fall_speed`.
static func spawn(parent: Node, point: Vector2, fall_speed: float) -> LandingDust:
	var dust := LandingDust.new()
	dust.size = clampf(fall_speed / FULL_FALL_SPEED, 0.5, 1.0)
	parent.add_child(dust)
	dust.global_position = point
	return dust


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / life, 0.0, 1.0)
	var out := 1.0 - (1.0 - t) * (1.0 - t)
	var fade := 1.0 - t
	for side: float in [-1.0, 1.0]:
		for i in PUFFS:
			var share := (i + 1.0) / PUFFS
			var at := Vector2(side * reach * size * share * out, -(1.0 + 2.5 * out) * (1.0 - share * 0.6))
			draw_circle(at, (2.6 - 1.4 * share) * size * fade + 0.3, Color(COLOR, 0.8 * fade))
