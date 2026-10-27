class_name Explosion
extends Node2D

## Hurts, pushes away and knocks down every hittable fighter within `radius` once,
## the thrower included. A fading circle stands in for the blast art.

@export var radius := 40.0
@export var damage := 35
## Speed (px/s) pushing fighters away from the centre.
@export var knockback := 220.0
@export var knocks_down := true
@export var show_time := 0.25

var _age := 0.0


func _ready() -> void:
	# Deferred so the blast sees the world as it is after this physics step.
	_blast.call_deferred()


func _blast() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	for body in HitQuery.fighters_in(get_world_2d(), shape, Transform2D(0.0, global_position), global_position):
		# Pushed away from the blast and a little upwards.
		var away := (body.global_position - global_position).normalized()
		var push := Vector2(signf(away.x) if away.x != 0.0 else 0.0, -0.5).normalized() * knockback
		body.take_hit(damage, push, -1.0, knocks_down)


func _process(delta: float) -> void:
	_age += delta
	if _age >= show_time:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _age / show_time
	draw_circle(Vector2.ZERO, radius * (0.6 + 0.4 * _age / show_time), Color(1.0, 0.75, 0.3, 0.7 * fade))
