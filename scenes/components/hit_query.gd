class_name HitQuery
extends RefCounted

## Shared hit detection for melee, blasts and fire: the fighters inside a shape that
## the hit can reach, so no hit ever lands through a wall or floor.

const WORLD_LAYER := 1


## Hittable fighters overlapping `shape` at `transform`, minus `exclude`, that have
## no world geometry between `from` and their body centre.
static func fighters_in(world: World2D, shape: Shape2D, transform: Transform2D, from: Vector2, exclude: Array[RID] = []) -> Array[Node2D]:
	var space := world.direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = transform
	query.collision_mask = Fighter.FIGHTERS_LAYER
	query.exclude = exclude
	var found: Array[Node2D] = []
	for result in space.intersect_shape(query):
		var body := result.collider as Node2D
		if body == null or not body.has_method("take_hit"):
			continue
		var target: Vector2 = body.center() if body.has_method("center") else body.global_position
		# The target's own shape may be world geometry too (an explosive barrel).
		if world_hit(space, from, target, [result.rid]).is_empty():
			found.append(body)
	return found


## The first world collision on the segment `from` -> `to`, or an empty dictionary.
## A start point inside geometry does not count, so a blast resting on the floor still reaches up.
static func world_hit(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, exclude: Array[RID] = []) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, WORLD_LAYER, exclude))
