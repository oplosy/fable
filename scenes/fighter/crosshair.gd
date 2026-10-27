class_name Crosshair
extends Node2D

## A small hollow square where a drawn firearm points: along the exact aim, never moved by
## spread or recoil. Visual only.

## World px from the hand.
const DISTANCE := 120.0
## Side of the square, world px.
const SIZE := 3.0
const COLOR := Color(1, 1, 1, 0.85)


func _init() -> void:
	# Placed in world space, so the fighter's facing mirror never flips it.
	top_level = true
	z_index = 10
	visible = false


## Shows the square DISTANCE along `direction` from `hand`, or hides it.
func point(shown: bool, hand: Vector2, direction: Vector2) -> void:
	visible = shown
	if shown:
		global_position = hand + direction * DISTANCE


func _draw() -> void:
	draw_rect(Rect2(-SIZE / 2.0, -SIZE / 2.0, SIZE, SIZE), COLOR, false, 0.5)
