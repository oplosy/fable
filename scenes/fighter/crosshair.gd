class_name Crosshair
extends Node2D

## A small hollow square on the first fighter, wall or floor a drawn firearm points at:
## along the exact aim, never moved by spread or recoil. Visual only.

## Side of the square, world px.
const SIZE := 3.0
const COLOR := Color(1, 1, 1, 0.85)


func _init() -> void:
	# Placed in world space, so the fighter's facing mirror never flips it.
	top_level = true
	z_index = 10
	visible = false


## Shows the square where the aim from `hand` along `direction` first meets what a bullet
## would hit (but `shooter`), or hides it.
func point(shown: bool, hand: Vector2, direction: Vector2, shooter: RID) -> void:
	visible = shown
	if shown:
		global_position = aimed_at(get_world_2d().direct_space_state, hand, direction, shooter)


## The first point a bullet could hit on the aim, or the end of the longest map's diagonal.
static func aimed_at(space: PhysicsDirectSpaceState2D, hand: Vector2, direction: Vector2, shooter: RID) -> Vector2:
	var end := hand + direction * FollowCamera.MAX_MAP_SIZE.length()
	var query := PhysicsRayQueryParameters2D.create(hand, end, Projectile.HIT_MASK, [shooter])
	return space.intersect_ray(query).get("position", end)


func _draw() -> void:
	draw_rect(Rect2(-SIZE / 2.0, -SIZE / 2.0, SIZE, SIZE), COLOR, false, 0.5)
