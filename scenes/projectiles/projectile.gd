class_name Projectile
extends Node2D

## Moves straight and finds hits with a ray along each frame's path, so fast
## projectiles never skip through thin walls or fighters.

## Physics layers the projectile stops at or hits: world and fighters.
const HIT_MASK := 1 | Fighter.FIGHTERS_LAYER
## Past every map; a shot that met nothing is gone by then.
const MAX_FLIGHT := 4000.0

var velocity := Vector2.ZERO
var damage := 0
var knockback := 0.0
## Seconds the hit stuns; negative uses the target's default.
var stun := -1.0
## The fighter that fired it; never hit by its own projectile.
var shooter: Node2D
## Fighters within this distance in px are always hit; further away it can fly past them.
var sure_range := 1200.0
## Extra fighters it passes through after the first one it hits.
var pierce := 0
## Hits within this distance from the muzzle knock the target down.
var knockdown_range := 0.0

## Where the first sweep starts, so a target between the hand and the muzzle is hit too.
var breech := Vector2.INF

var _traveled := 0.0
var _hits := 0
var _exclude: Array[RID] = []


func _ready() -> void:
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		_exclude.append(shooter.get_rid())


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	var remaining := minf(step.length(), MAX_FLIGHT - _traveled)
	var to := global_position + velocity.normalized() * remaining
	var space := get_world_2d().direct_space_state
	var from := breech if _traveled == 0.0 and breech != Vector2.INF else global_position
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
		if body is Fighter and Arena.rng_of(self).randf() >= hit_chance(at_range, sure_range):
			_exclude.append(hit.rid)
			from = hit.position
			continue
		var knocks_down := knockdown_range > 0.0 and at_range <= knockdown_range
		var credit: Fighter = shooter as Fighter if is_instance_valid(shooter) else null
		body.take_hit(damage, velocity.normalized() * knockback, stun, knocks_down, credit)
		_hits += 1
		if _hits > pierce:
			queue_free()
			return
		_exclude.append(hit.rid)
		from = hit.position
	global_position = to
	_traveled += remaining
	if _traveled >= MAX_FLIGHT:
		queue_free()


## Certain up to `range_px`, then falling with the distance: half at twice the range.
static func hit_chance(distance: float, range_px: float) -> float:
	return minf(range_px / maxf(distance, 1.0), 1.0)
