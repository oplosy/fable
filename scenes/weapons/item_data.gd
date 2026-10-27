class_name ItemData
extends Resource

## What every item that spawns in the arena and sits in a fighter's hand shares.

@export var display_name := ""
@export var texture: Texture2D
## Pixel of the texture held by the hand.
@export var grip := Vector2.ZERO
## Relative chance of being picked by a spawn point that lists this item.
@export var spawn_weight := 1.0
