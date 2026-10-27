class_name Crosshair
extends Node2D

## A small hollow square on the first wall or floor a drawn firearm points at: along the
## exact aim, never moved by spread or recoil. Visual only.

## Side of the square, world px.
const SIZE := 3.0
const COLOR := Color(1, 1, 1, 0.85)


func _init() -> void:
	# Placed in world space, so the fighter's facing mirror never flips it.
	top_level = true
	z_index = 10
	visible = false


## Shows the square where the aim from `hand` along `direction` meets the world, or hides it.
func point(shown: bool, hand: Vector2, direction: Vector2) -> void:
	visible = shown
	if shown:
		global_position = aimed_at(get_world_2d().direct_space_state, hand, direction)


## The first world point on the aim, or the end of the longest map's diagonal.
static func aimed_at(space: PhysicsDirectSpaceState2D, hand: Vector2, direction: Vector2) -> Vector2:
	var end := hand + direction * FollowCamera.MAX_MAP_SIZE.length()
	return HitQuery.world_hit(space, hand, end).get("position", end)


func _draw() -> void:
	draw_rect(Rect2(-SIZE / 2.0, -SIZE / 2.0, SIZE, SIZE), COLOR, false, 0.5)
