class_name HitSpark
extends Node2D

## The white burst where a melee hit lands: a flash, rays shooting out (longest along the
## hit) and a widening ring, gone in `life` seconds. Visual only.

const RAYS := 9
const COLOR := Color(1, 1, 1)

@export var life := 0.2
## Ray length (world px) at the start; a heavy hit doubles the whole burst.
@export var reach := 5.0
## 1 or -1: the way the hit travels, which the rays lean towards.
var direction := 1.0
var size := 1.0

var _age := 0.0
var _angles: Array[float] = []
var _lengths: Array[float] = []


## Adds a spark to `parent` at `point` (global).
static func spawn(parent: Node, point: Vector2, hit_direction: float, heavy: bool) -> HitSpark:
	var spark := HitSpark.new()
	spark.direction = hit_direction
	spark.size = 1.6 if heavy else 1.0
	parent.add_child(spark)
	spark.global_position = point
	return spark


func _ready() -> void:
	z_index = 10
	var rng := Arena.rng_of(self)
	for i in RAYS:
		var angle := TAU * i / RAYS + rng.randf_range(-0.2, 0.2)
		_angles.append(angle)
		# Rays along the hit are longest, the ones pointing back are short.
		_lengths.append(reach * size * (1.0 + 0.7 * cos(angle) * direction) * rng.randf_range(0.7, 1.0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / life, 0.0, 1.0)
	var fade := 1.0 - t
	if t < 0.4:
		draw_circle(Vector2.ZERO, 2.0 * size * (1.0 - t / 0.4), COLOR)
	for i in RAYS:
		var along := Vector2.from_angle(_angles[i])
		var start := along * (1.0 + 3.5 * t) * size
		draw_line(start, start + along * _lengths[i] * fade, Color(COLOR, fade), size * fade + 0.4)
	draw_arc(Vector2.ZERO, (1.5 + 5.5 * t) * size, 0.0, TAU, 20, Color(COLOR, 0.6 * fade), 0.6)
