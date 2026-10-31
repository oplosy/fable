class_name WalkMap
extends RefCounted

## Where a fighter can stand in an arena and how to get from one place to another, scanned
## from its collision and ladders so every map works for bots without any setup. A surface
## is a level stretch of floor; links join surfaces by a jump, a drop off an edge or a ladder.
## The scan is a snapshot: a barrel blown up later stays on it, which costs a bot one hop.

enum Move { JUMP, DROP, LADDER_UP, LADDER_DOWN }

## One level stretch of floor, in world px.
class Surface:
	var y: float
	var left: float
	var right: float
	var links: Array[Link] = []

	func _init(top: float, from: float, to: float) -> void:
		y = top
		left = from
		right = to

	func holds(x: float) -> bool:
		return x >= left and x <= right

	## `x` moved onto the surface, at least `inset` from its ends where it is wide enough.
	func inside(x: float, inset: float) -> float:
		return (left + right) / 2.0 if right - left < inset * 2.0 else clampf(x, left + inset, right - inset)


## A way off a surface: stand at `leave_x`, do `move`, arrive at `land_x` on surface `to`.
class Link:
	var move: Move
	var to: int
	var leave_x: float
	var land_x: float
	## How far the landing is above the take-off (negative below), and the gap across.
	var rise := 0.0
	var gap := 0.0

	func _init(how: Move, target: int, leave: float, land: float) -> void:
		move = how
		to = target
		leave_x = leave
		land_x = land


## Column spacing of the scan (px).
const STEP := 4.0
## Height a fighter needs free above a floor (px), the default body.
const HEADROOM := 28.0
## How far inside an edge a jump takes off and lands (px).
const TAKE_OFF_INSET := 3.0
const LANDING_INSET := 8.0
## How far past an edge a drop looks for a floor (px).
const OVER_EDGE := 8.0
## How far above the higher floor a jump's way is checked (px).
const JUMP_CLEARANCE := 6.0
## Spare jump height and reach a link must leave (px).
const JUMP_MARGIN := 4.0
## A surface this far above the feet still counts as under them (px).
const FEET_SLACK := 3.0
## Extra walking distance a link counts for in a route (px).
const LINK_COST := 16.0

var surfaces: Array[Surface] = []

var _space: PhysicsDirectSpaceState2D


## The map of `arena`, scanned the first time it is asked for. Needs physics to have run once.
static func of(arena: Arena) -> WalkMap:
	if not arena.has_meta(&"walk_map"):
		arena.set_meta(&"walk_map", WalkMap.new(arena))
	return arena.get_meta(&"walk_map")


func _init(arena: Arena) -> void:
	_space = arena.get_world_2d().direct_space_state
	var view := Rect2(arena.global_position + arena.camera_limits.position, arena.camera_limits.size)
	_find_surfaces(view)
	_link_jumps_and_drops()
	for ladder: Ladder in arena.get_tree().get_nodes_in_group(Ladder.GROUP):
		if arena.is_ancestor_of(ladder):
			_link_ladder(ladder)


## Index of the surface under `feet`, -1 over nothing (a pit).
func surface_under(feet: Vector2) -> int:
	var best := -1
	for i in surfaces.size():
		var surface := surfaces[i]
		if surface.holds(feet.x) and surface.y >= feet.y - FEET_SLACK and (best < 0 or surface.y < surfaces[best].y):
			best = i
	return best


## The x of the nearest floor at or below `feet`, for steering out of a fall.
func nearest_floor_x(feet: Vector2) -> float:
	var best := feet.x
	var distance := INF
	for surface in surfaces:
		var x := surface.inside(feet.x, LANDING_INSET)
		if surface.y >= feet.y - FEET_SLACK and absf(x - feet.x) < distance:
			distance = absf(x - feet.x)
			best = x
	return best


## The first link of the shortest route from surface `from` to `to` for a fighter of
## `fighter_class` starting at `x`; null when it cannot get there.
func next_link(from: int, to: int, x: float, fighter_class: FighterClass) -> Link:
	var cost: Array[float] = []
	cost.resize(surfaces.size())
	cost.fill(INF)
	cost[from] = 0.0
	var at: Array[float] = []
	at.resize(surfaces.size())
	at[from] = x
	var first: Array[Link] = []
	first.resize(surfaces.size())
	var open: Array[int] = [from]
	while not open.is_empty():
		var nearest := 0
		for i in open.size():
			if cost[open[i]] < cost[open[nearest]]:
				nearest = i
		var here: int = open.pop_at(nearest)
		if here == to:
			return first[to]
		for link in surfaces[here].links:
			if not _can_take(link, fighter_class):
				continue
			var total := cost[here] + absf(at[here] - link.leave_x) + LINK_COST + absf(link.rise)
			if total < cost[link.to]:
				cost[link.to] = total
				at[link.to] = link.land_x
				first[link.to] = first[here] if first[here] else link
				if link.to not in open:
					open.append(link.to)
	return null


func _can_take(link: Link, fighter_class: FighterClass) -> bool:
	if link.move != Move.JUMP:
		return true
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var height := fighter_class.jump_velocity ** 2 / (2.0 * gravity * fighter_class.gravity_scale)
	# A landing up high is reached late in the jump, so it gets less of the reach.
	var reach := fighter_class.jump_reach() * (1.0 - 0.5 * maxf(link.rise, 0.0) / height)
	return link.rise <= height - JUMP_MARGIN and link.gap <= reach - JUMP_MARGIN


func _find_surfaces(view: Rect2) -> void:
	# Floor height -> the surface still being extended at that height.
	var open := {}
	# Off the whole pixel, so no column runs exactly along a body's side.
	var x := view.position.x + STEP / 2.0 + 0.5
	while x < view.end.x:
		for top in _floors_in_column(x, view):
			var running: Surface = open.get(top)
			if running and running.right >= x - STEP * 1.5:
				running.right = x + STEP / 2.0
			else:
				open[top] = Surface.new(top, x - STEP / 2.0, x + STEP / 2.0)
				surfaces.append(open[top])
		x += STEP


## Heights in this column where a floor has room to stand on it, top down.
func _floors_in_column(x: float, view: Rect2) -> Array[float]:
	var floors: Array[float] = []
	var y := view.position.y
	while y < view.end.y:
		var ray := PhysicsRayQueryParameters2D.create(Vector2(x, y), Vector2(x, view.end.y), HitQuery.WORLD_LAYER)
		var hit := _space.intersect_ray(ray)
		if hit.is_empty():
			break
		var top := roundf(hit.position.y)
		if not _solid_at(Vector2(x, top - 2.0)) and not _solid_at(Vector2(x, top - HEADROOM / 2.0)) and not _solid_at(Vector2(x, top - HEADROOM + 2.0)):
			floors.append(top)
		# A ray also stops inside a one-way plate, so go on from below what it hit.
		y = top + 1.0
		while y < view.end.y and not _bodies_at(Vector2(x, y)).is_empty():
			y += 1.0
		y += 1.0
	return floors


func _bodies_at(point: Vector2) -> Array[Dictionary]:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = HitQuery.WORLD_LAYER
	return _space.intersect_point(query)


## Whether `point` is inside something a fighter cannot pass; one-way platforms do not count.
func _solid_at(point: Vector2) -> bool:
	for hit in _bodies_at(point):
		var body := hit.collider as CollisionObject2D
		if body == null or not body.is_shape_owner_one_way_collision_enabled(body.shape_find_owner(hit.shape)):
			return true
	return false


func _link_jumps_and_drops() -> void:
	for a in surfaces.size():
		for b in surfaces.size():
			if a != b:
				_link_jump(a, b)
		_link_drop(a, surfaces[a].left - OVER_EDGE, surfaces[a].left + 1.0)
		_link_drop(a, surfaces[a].right + OVER_EDGE, surfaces[a].right - 1.0)


## A jump from `a` up to `b`, or across a gap to any height.
func _link_jump(a: int, b: int) -> void:
	var from := surfaces[a]
	var to := surfaces[b]
	var rise := from.y - to.y
	var gap := maxf(maxf(to.left - from.right, from.left - to.right), 0.0)
	if rise <= 0.0 and gap == 0.0:
		return
	# Up a step the wall keeps the body back from the edge; over a gap every pixel counts.
	var inset := LANDING_INSET if rise > 0.0 else TAKE_OFF_INSET
	var leave: float
	if to.left >= from.right:
		leave = from.right - inset
	elif to.right <= from.left:
		leave = from.left + inset
	else:
		leave = from.inside((to.left + to.right) / 2.0, TAKE_OFF_INSET)
	var land := to.inside(leave, LANDING_INSET)
	# The jump goes up first, so only what stands above the higher floor is in its way.
	var height := minf(from.y, to.y) - JUMP_CLEARANCE
	if _path_blocked(Vector2(leave, height), Vector2(land, height)):
		return
	var link := Link.new(Move.JUMP, b, leave, land)
	link.rise = rise
	link.gap = gap
	from.links.append(link)


## Whether something solid stands on the straight line between two points.
func _path_blocked(start: Vector2, end: Vector2) -> bool:
	var steps := ceili(start.distance_to(end) / STEP)
	for i in range(1, steps):
		if _solid_at(start.lerp(end, float(i) / steps)):
			return true
	return false


## Walking off surface `a` over `over`: lands on the first floor below, if there is one.
func _link_drop(a: int, over: float, leave: float) -> void:
	var from := surfaces[a]
	var below := -1
	for i in surfaces.size():
		var surface := surfaces[i]
		if surface.holds(over) and surface.y > from.y and (below < 0 or surface.y < surfaces[below].y):
			below = i
	if below >= 0:
		var link := Link.new(Move.DROP, below, leave, over)
		link.rise = from.y - surfaces[below].y
		from.links.append(link)


func _link_ladder(ladder: Ladder) -> void:
	var x := ladder.global_position.x
	var bottom := _surface_at(x, ladder.bottom())
	var top := _surface_at(x, ladder.top())
	if bottom >= 0 and top >= 0:
		surfaces[bottom].links.append(Link.new(Move.LADDER_UP, top, x, x))
		surfaces[top].links.append(Link.new(Move.LADDER_DOWN, bottom, x, x))


func _surface_at(x: float, y: float) -> int:
	for i in surfaces.size():
		if absf(surfaces[i].y - y) <= FEET_SLACK and surfaces[i].holds(x):
			return i
	return -1
