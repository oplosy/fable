class_name ItemData
extends Resource

## What every item that spawns in the arena and sits in a fighter's hand shares.

@export var display_name := ""
@export var texture: Texture2D
## Git-ignored pack art of the same size as `texture` (from tools/import_items.gd); shown
## instead of it when present.
@export_file("*.png") var art := ""
## Pixel of the texture held by the hand.
@export var grip := Vector2.ZERO
## Texture pixels per world pixel. Item art is drawn at the characters' 3x detail.
@export var pixels_per_unit := 3.0
## Relative chance of being picked by a spawn point that lists this item.
@export var spawn_weight := 1.0


## The item's size in world pixels (for its physics body).
func world_size() -> Vector2:
	return texture.get_size() / pixels_per_unit


## What the item looks like: its art when imported, else the placeholder.
func look() -> Texture2D:
	return load(art) if ResourceLoader.exists(art) else texture


## Shows `item` in `sprite` at world scale; `held` puts its grip on the sprite's origin.
## A null item clears the sprite.
static func show_on(sprite: Sprite2D, item: ItemData, held := true) -> void:
	sprite.texture = item.look() if item else null
	sprite.scale = Vector2.ONE / item.pixels_per_unit if item else Vector2.ONE
	sprite.offset = -item.grip if item and held else Vector2.ZERO
