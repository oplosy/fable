class_name CharacterData
extends Resource

## A character's look and body; how it fights comes from its class.

const DEFAULT_BODY_SIZE := Vector2(12, 28)

@export var display_name := ""
@export var placeholder_color := Color.WHITE
@export var fighter_class: FighterClass
## Width and height of the standing hit body in world pixels.
@export var body_size := DEFAULT_BODY_SIZE

@export_group("Art")
## Folder of frame-by-frame clips (a strip and a .json each); used instead of `rig_file`.
@export_dir var frames_dir := ""
## The cutout rig (rig.json with its part PNGs beside it); used instead of frames or texture.
@export_file("*.json") var rig_file := ""
## Standing frame; without frames or rig, a placeholder box in placeholder_color is drawn.
@export var texture: Texture2D
## Texture pixels per world pixel. The game renders at 3x, so 64x96 art uses 3.
@export var pixels_per_unit := 3.0
