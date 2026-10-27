class_name FireArea
extends Node2D

## A patch of fire on the floor below where it starts. Every `tick` it burns each
## hittable fighter standing in it, the thrower included, without stunning them.

@export var width := 48.0
@export var height := 16.0
@export var lifetime := 4.0
@export var damage_per_tick := 4
@export var tick := 0.5
## How far below its start the fire looks for a floor to settle on.
@export var max_fall := 200.0

## The fighter credited with its hits: whoever threw it.
var attacker: Fighter

var _age := 0.0
var _until_tick := 0.0


func _ready() -> void:
	add_to_group("fire_areas")
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, max_fall), 1)
	var floor_hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not floor_hit.is_empty():
		global_position = floor_hit.position
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_until_tick -= delta
	if _until_tick > 0.0:
		return
	_until_tick = tick
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	var middle := global_position + Vector2(0, -height / 2.0)
	for body in HitQuery.fighters_in(get_world_2d(), shape, Transform2D(0.0, middle), middle):
		# Zero stun: burning fighters can still run out of the fire.
		body.take_hit(damage_per_tick, Vector2.ZERO, 0.0, false, attacker if is_instance_valid(attacker) else null)


func _draw() -> void:
	draw_rect(Rect2(-width / 2.0, -height, width, height), Color(1.0, 0.45, 0.1, 0.6))
