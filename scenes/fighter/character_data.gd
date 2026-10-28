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

@export_group("Art")
## Folder of frame-by-frame clips (a strip and a .json each, from tools/make_stickman.gd);
## used instead of `rig_file` and `texture`.
@export_dir var frames_dir := ""
## The cutout rig (rig.json with its part PNGs beside it); used instead of `texture`.
@export_file("*.json") var rig_file := ""
## Standing frame; without a rig or this, a placeholder box in placeholder_color is drawn.
@export var texture: Texture2D
## Texture pixels per world pixel. The game renders at 3x, so 64x96 art uses 3 and is
## drawn pixel for pixel when the camera is at its art zoom.
@export var pixels_per_unit := 3.0
## Texture pixel that stands on the fighter's feet (bottom centre of the stance).
@export var feet := Vector2(32, 93)
