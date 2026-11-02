class_name CharacterData
extends Resource

## A character's look and body; how it fights comes from its class.

const DEFAULT_BODY_SIZE := Vector2(12, 28)

@export var display_name := ""
@export var placeholder_color := Color.WHITE
@export var fighter_class: FighterClass
## Width and height of the standing hit body in world pixels.
@export var body_size := DEFAULT_BODY_SIZE
