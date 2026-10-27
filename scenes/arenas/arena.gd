class_name Arena
extends Node2D

## Root of every arena scene. Anything in the BOUNDED group that leaves `bounds` has
## fallen out of the map: fighters die (`fall_out`), items and thrown objects are removed.

const BOUNDED := &"bounded"

## Playable area in the arena's own coordinates; leave room above for jumps.
@export var bounds := Rect2(-64, -360, 768, 784)


func _physics_process(_delta: float) -> void:
	for node: Node2D in get_tree().get_nodes_in_group(BOUNDED):
		if not is_ancestor_of(node) or bounds.has_point(to_local(node.global_position)):
			continue
		if node.has_method("fall_out"):
			node.fall_out()
		else:
			node.queue_free()
