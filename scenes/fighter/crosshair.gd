class_name Crosshair
extends Node2D

## A small cross where a drawn firearm points: along the exact aim, never moved by
## spread or recoil. Visual only.

## World px from the hand.
const DISTANCE := 120.0
const SIZE := 4.0
const GAP := 1.5
const COLOR := Color(1, 1, 1, 0.85)


func _init() -> void:
	# Placed in world space, so the fighter's facing mirror never flips it.
	top_level = true
	z_index = 10
	visible = false


## Shows the cross DISTANCE along `direction` from `hand`, or hides it.
func point(shown: bool, hand: Vector2, direction: Vector2) -> void:
	visible = shown
	if shown:
		global_position = hand + direction * DISTANCE


func _draw() -> void:
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
		draw_line(axis * GAP, axis * SIZE, COLOR, 1.0)
		draw_line(-axis * GAP, -axis * SIZE, COLOR, 1.0)
