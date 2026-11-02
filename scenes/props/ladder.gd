class_name Ladder
extends Node2D

## A climbable ladder. Its origin is the bottom middle, where it stands on the floor, and it
## reaches `height` px up to the surface of the platform it leads to. Fighters climb it with
## no world collision, so a ladder may pass through one-way platforms but never solid ground.

## Fighters find ladders through this group.
const GROUP := &"ladders"
## How far (px) from the ladder's middle a fighter's feet can be to take hold.
const REACH := 6.0
## Width of the placeholder look (px).
const WIDTH := 10.0

@export var height := 96.0


func _ready() -> void:
	add_to_group(GROUP)
	var visual := ColorRect.new()
	visual.color = Color(0.5, 0.36, 0.22)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.position = Vector2(-WIDTH / 2.0, -height)
	visual.size = Vector2(WIDTH, height)
	add_child(visual)


## Feet height (global y) of a fighter standing on the platform at the top.
func top() -> float:
	return global_position.y - height


## Feet height (global y) of a fighter standing on the floor at the bottom.
func bottom() -> float:
	return global_position.y


## Whether a fighter with its feet at `feet` can take hold.
func reaches(feet: Vector2) -> bool:
	return absf(feet.x - global_position.x) <= REACH and feet.y >= top() - 1.0 and feet.y <= bottom() + 1.0
