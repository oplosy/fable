class_name Arena
extends Node2D

## Root of every arena scene. Anything in the BOUNDED group that leaves `bounds` has
## fallen out of the map: fighters die (`fall_out`), items and thrown objects are removed.

const BOUNDED := &"bounded"

## Playable area in the arena's own coordinates; leave room above for jumps.
@export var bounds := Rect2(-64, -360, 768, 784)

## The match's single source of randomness (spawn picks, bullet spread), so seeding it
## replays a match exactly, e.g. for tests, replays or keeping online peers in sync.
var rng := RandomNumberGenerator.new()

static var _fallback_rng := RandomNumberGenerator.new()


## The rng of the arena `node` lives in; outside an arena, a shared unseeded one.
static func rng_of(node: Node) -> RandomNumberGenerator:
	while node and not node is Arena:
		node = node.get_parent()
	return node.rng if node else _fallback_rng


func _physics_process(_delta: float) -> void:
	for node: Node2D in get_tree().get_nodes_in_group(BOUNDED):
		if not is_ancestor_of(node) or bounds.has_point(to_local(node.global_position)):
			continue
		if node.has_method("fall_out"):
			node.fall_out()
		else:
			node.queue_free()
