class_name Ladder
extends Node2D

## A climbable ladder. Its origin is the bottom middle, where it stands on the floor, and it
## reaches `height` px up to the surface of the platform it leads to. Fighters climb it with
## no world collision, so a ladder may pass through one-way platforms but never solid ground.

## Fighters find ladders through this group.
const GROUP := &"ladders"
## How far (px) from the ladder's middle a fighter's feet can be to take hold.
const REACH := 6.0

@export var height := 96.0
## One section of rails and a rung, tiled up the ladder.
@export var texture: Texture2D
## Art pixels per world pixel (the map art is 3x).
@export var pixels_per_unit := 3.0


func _ready() -> void:
	add_to_group(GROUP)
	if texture:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, texture.get_width(), height * pixels_per_unit)
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.scale = Vector2.ONE / pixels_per_unit
		sprite.position = Vector2(-texture.get_width() / pixels_per_unit / 2.0, -height)
		add_child(sprite)


## Feet height (global y) of a fighter standing on the platform at the top.
func top() -> float:
	return global_position.y - height


## Feet height (global y) of a fighter standing on the floor at the bottom.
func bottom() -> float:
	return global_position.y


## Whether a fighter with its feet at `feet` can take hold.
func reaches(feet: Vector2) -> bool:
	return absf(feet.x - global_position.x) <= REACH and feet.y >= top() - 1.0 and feet.y <= bottom() + 1.0
