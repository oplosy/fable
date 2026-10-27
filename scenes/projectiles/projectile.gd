class_name Projectile
extends Node2D

## Moves straight and finds hits with a ray along each frame's path, so fast
## projectiles never skip through thin walls or fighters.

## Physics layers the projectile stops at or hits: world and fighters.
const HIT_MASK := 1 | Fighter.FIGHTERS_LAYER

var velocity := Vector2.ZERO
var damage := 0
var knockback := 0.0
## The fighter that fired it; never hit by its own projectile.
var shooter: Node2D
## Distance in px before it disappears.
var max_range := 1200.0
## Extra fighters it passes through after the first one it hits.
var pierce := 0
## Hits within this distance from the muzzle knock the target down.
var knockdown_range := 0.0

var _traveled := 0.0
var _hits := 0
var _exclude: Array[RID] = []


func _ready() -> void:
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		_exclude.append(shooter.get_rid())


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	var remaining := minf(step.length(), max_range - _traveled)
	var to := global_position + velocity.normalized() * remaining
	var space := get_world_2d().direct_space_state
	var from := global_position
	while true:
		var query := PhysicsRayQueryParameters2D.create(from, to, HIT_MASK, _exclude)
		# Point-blank shots start inside the target's body.
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var body: Object = hit.collider
		if not body.has_method("take_hit"):
			queue_free()
			return
		var at_range := _traveled + global_position.distance_to(hit.position)
		var knocks_down := knockdown_range > 0.0 and at_range <= knockdown_range
		body.take_hit(damage, velocity.normalized() * knockback, -1.0, knocks_down)
		_hits += 1
		if _hits > pierce:
			queue_free()
			return
		_exclude.append(hit.rid)
		from = hit.position
	global_position = to
	_traveled += remaining
	if _traveled >= max_range:
		queue_free()
