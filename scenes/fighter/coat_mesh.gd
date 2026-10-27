class_name CoatMesh
extends Polygon2D

## A coat part drawn as a grid of points instead of one stiff picture, so it bends like
## cloth: each point hangs from the coat's joint and is carried part of the way by the
## thigh it covers, more the lower it is, and no point goes through the floor.
## Cosmetic only.

## Art px between grid points.
const CELL := 3
## Share of a thigh's swing the hem takes; the waist takes none.
const FOLLOW := 0.6
## Art px cloth spreads over the floor per px it would have gone below it.
const POOL := 0.7

var _rig: CharacterRig
var _pivot := Vector2.ZERO
## Per grid point: its place on the part's canvas, how far down the coat it is (0 at the
## pivot, 1 at the hem) and how much it covers the front thigh rather than the back one.
var _rest := PackedVector2Array()
var _depth := PackedFloat32Array()
var _front := PackedFloat32Array()


## Builds the grid over the part's drawn pixels. `rig` must have its leg pivots.
func setup(rig: CharacterRig, part: String) -> void:
	_rig = rig
	_pivot = rig.pivots[part]
	var used := texture.get_image().get_used_rect()
	var xs := _steps(used.position.x, used.end.x)
	var ys := _steps(used.position.y, used.end.y)
	var hips: Vector2 = Vector2(rig.pivots.leg_front_upper.x, rig.pivots.leg_back_upper.x)
	for y in ys:
		for x in xs:
			_rest.append(Vector2(x, y))
			_depth.append(clampf((y - _pivot.y) / (used.end.y - _pivot.y), 0.0, 1.0))
			_front.append(1.0 - smoothstep(hips.x, hips.y, x))
	var cells := []
	for row in ys.size() - 1:
		for column in xs.size() - 1:
			var i := row * xs.size() + column
			cells.append(PackedInt32Array([i, i + 1, i + xs.size() + 1, i + xs.size()]))
	uv = _rest
	polygons = cells
	var shape := PackedVector2Array()
	for point in _rest:
		shape.append(point - _pivot)
	polygon = shape


## Moves the grid for the rig's current pose. Call after the joints are posed.
func deform() -> void:
	# Everything in rig space: art px, feet at the origin, y down.
	var to_rig := _rig.global_transform.affine_inverse()
	var own := to_rig * (get_parent() as Node2D).global_transform
	var legs := [_leg("front", to_rig), _leg("back", to_rig)]
	var waist := own.origin
	var shape := PackedVector2Array()
	shape.resize(_rest.size())
	var to_mesh := (to_rig * global_transform).affine_inverse()
	for i in _rest.size():
		var point := _rest[i]
		var hanging := own * (point - _pivot)
		var carried := Vector2.ZERO
		var follow := 0.0
		for side in 2:
			var weight := _front[i] if side == 0 else 1.0 - _front[i]
			carried += _carry(legs[side], point) * weight
			follow += legs[side].follow * weight
		var depth := _depth[i]
		var at := hanging.lerp(carried, follow * depth * depth)
		# Cloth reaching the floor spreads out over it, away from the body, instead of
		# going through it.
		if at.y > 0.0:
			at.x += signf(at.x - waist.x) * at.y * POOL
			at.y = 0.0
		shape[i] = to_mesh * at
	polygon = shape


## How a thigh carries the coat this frame: its transform into rig space, its rest axis
## and length, and how much of the coat it takes (more as it rises forward, so a crouch's
## coat lies on the thighs).
func _leg(side: String, to_rig: Transform2D) -> Dictionary:
	var hip: Vector2 = _rig.pivots["leg_%s_upper" % side]
	var knee: Vector2 = _rig.pivots["leg_%s_lower" % side]
	var thigh: Transform2D = to_rig * (_rig.joints["leg_%s_upper" % side] as Node2D).global_transform
	var now: Vector2 = thigh.basis_xform(knee - hip)
	var raise := clampf(atan2(now.x, now.y) / (PI / 2.0), 0.0, 1.0)
	return {"thigh": thigh, "hip": hip, "axis": (knee - hip).normalized(), "length": hip.distance_to(knee),
		"follow": FOLLOW + (1.0 - FOLLOW) * raise}


## Where `point` (on the canvas) goes if the leg carries it: along the thigh as far as
## the knee, then hanging straight down from there like cloth over a knee.
func _carry(leg: Dictionary, point: Vector2) -> Vector2:
	var offset: Vector2 = point - leg.hip
	var past: float = offset.dot(leg.axis) - leg.length
	if past <= 0.0:
		return leg.thigh * offset
	return leg.thigh * (offset - leg.axis * past) + Vector2(0.0, past)


## Grid lines from `from` to `to` (both included), CELL apart.
static func _steps(from: int, to: int) -> Array:
	var steps := range(from, to, CELL)
	if steps.back() != to:
		steps.append(to)
	return steps
