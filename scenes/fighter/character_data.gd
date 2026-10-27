class_name CharacterData
extends Resource

## A character's look and body; how it fights comes from its class.

const DEFAULT_BODY_SIZE := Vector2(12, 28)

@export var display_name := ""
@export var placeholder_color := Color.WHITE
@export var fighter_class: FighterClass
## Width and height of the standing hit body in world pixels; match it to the art
## (64x96 art drawn at 1/3 scale is about 12x28).
@export var body_size := DEFAULT_BODY_SIZE
