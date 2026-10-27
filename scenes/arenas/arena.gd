class_name Arena
extends Node2D

## Root of every arena scene. Anything in the BOUNDED group that leaves `bounds` has
## fallen out of the map: fighters die (`fall_out`), items and thrown objects are removed.

const BOUNDED := &"bounded"

## Playable area in the arena's own coordinates; leave room above for jumps.
@export var bounds := Rect2(-64, -360, 768, 784)
## The part of the map the camera may show, in the arena's own coordinates. Everywhere
## a fighter can stand or jump must lie inside it, and it may be at most
## FollowCamera.MAX_MAP_SIZE (2560x1440), or fighters could end up off screen.
@export var camera_limits := Rect2(0, 0, 640, 360)

## The match's single source of randomness (spawn picks, bullet spread), so seeding it
## replays a match exactly, e.g. for tests, replays or keeping online peers in sync.
var rng := RandomNumberGenerator.new()

static var _fallback_rng := RandomNumberGenerator.new()


## The rng of the arena `node` lives in; outside an arena, a shared unseeded one.
static func rng_of(node: Node) -> RandomNumberGenerator:
	while node and not node is Arena:
		node = node.get_parent()
	return node.rng if node else _fallback_rng


func _ready() -> void:
	if not fits_camera():
		push_error("%s: camera_limits %s is bigger than the %s maximum; fighters could end up off screen." % [scene_file_path, camera_limits.size, FollowCamera.MAX_MAP_SIZE])
	# The camera only ever shrinks the 3x art (never past 1:1), so mipmaps keep it from
	# dropping pixels and shimmering while zooming. At the art zoom it draws pixel for pixel.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Whether the whole map fits the furthest camera zoom.
func fits_camera() -> bool:
	return camera_limits.size.x <= FollowCamera.MAX_MAP_SIZE.x and camera_limits.size.y <= FollowCamera.MAX_MAP_SIZE.y


func _physics_process(_delta: float) -> void:
	for node: Node2D in get_tree().get_nodes_in_group(BOUNDED):
		if not is_ancestor_of(node) or bounds.has_point(to_local(node.global_position)):
			continue
		if node.has_method("fall_out"):
			node.fall_out()
		else:
			node.queue_free()
