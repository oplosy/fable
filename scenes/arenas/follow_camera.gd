class_name FollowCamera
extends Camera2D

## The arena's camera. It shows the map through shots: the arena's CameraShot nodes plus
## one shot of the whole map, which every map has. It holds the closest shot (highest
## zoom) that contains every living fighter and glides to another only when the fighters
## leave it or fit a closer one, so the picture is always a composed one.
##
## Shots sit only at ZOOMS, where the 3x art shrinks by a whole factor (1:1, 2:1, 4:1);
## with mipmaps every one of them stays crisp. In between, the zoom only passes through
## while the camera moves from one shot to the next.

## Screen pixels per world pixel a shot may use. At 3, one pixel of the 3x art is one
## screen pixel; each step out halves it.
const ZOOMS: Array[float] = [3.0, 1.5, 0.75]
## Furthest zoom on any map: a 96 px tall character is then 24 px tall on a 1080p screen,
## the smallest it stays readable.
const MIN_ZOOM := 0.75
const VIEW := Vector2(1920, 1080)
## The whole view at MIN_ZOOM: the largest map there is.
const MAX_MAP_SIZE := VIEW / MIN_ZOOM

## Fraction of a shot on each side that fighters must stay out of for the camera to cut
## to it; once there, the camera holds the shot until a fighter leaves it altogether.
@export_range(0.0, 0.4) var margin := 0.12
## How fast the camera glides to a new shot; higher is snappier.
@export var move_speed := 5.0
## Pulling back is quicker, so a fighter running off never leaves the screen.
@export var zoom_out_speed := 7.0
@export var zoom_in_speed := 4.0

## The shot of the whole map, at the closest zoom that shows all of it.
var whole_map := Rect2()
## The shot the camera holds or is moving to.
var current := Rect2()
var _shots: Array[Rect2] = []
var _placed := false


func _ready() -> void:
	var view := get_viewport_rect().size
	var arena := get_parent() as Arena
	var limits := Rect2(Vector2.ZERO, view / ZOOMS[0])
	if arena:
		limits = Rect2(arena.to_global(arena.camera_limits.position), arena.camera_limits.size)
		for shot: CameraShot in arena.find_children("*", "CameraShot", true, false):
			_shots.append(shot.area(view))
	limit_left = int(limits.position.x)
	limit_top = int(limits.position.y)
	limit_right = int(limits.end.x)
	limit_bottom = int(limits.end.y)
	var whole_zoom := ZOOMS[-1]
	for step in ZOOMS:
		if view.x / step >= limits.size.x and view.y / step >= limits.size.y:
			whole_zoom = step
			break
	whole_map = Rect2(limits.get_center() - view / whole_zoom / 2.0, view / whole_zoom)
	_shots.append(whole_map)
	zoom = Vector2.ONE * ZOOMS[0]


func _physics_process(delta: float) -> void:
	var box := _fighters_box()
	if box.position == Vector2.INF:
		return
	current = pick_shot(box)
	var target_zoom := get_viewport_rect().size.x / current.size.x
	var target := current.get_center()
	if not _placed:
		_placed = true
		global_position = target
		zoom = Vector2.ONE * target_zoom
		return
	var speed := zoom_out_speed if target_zoom < zoom.x else zoom_in_speed
	# Zoom is a scale, so it eases in log space: every step changes the view by the
	# same proportion whether the camera is close or far.
	var next := exp(lerpf(log(zoom.x), log(target_zoom), 1.0 - exp(-speed * delta)))
	var position_next := global_position.lerp(target, 1.0 - exp(-move_speed * delta))
	# Land exactly on the shot, so the art is never left at an almost-whole scale.
	var landed := absf(log(next / target_zoom)) < 0.004 and position_next.distance_to(target) < 0.5
	zoom = Vector2.ONE * (target_zoom if landed else next)
	global_position = target if landed else position_next


## The shot for fighters spanning `box`: the current one while it still holds them,
## unless a closer one holds them inside its margins; otherwise the closest shot that
## does, nearest the fighters first; the whole map when none does.
func pick_shot(box: Rect2) -> Rect2:
	var best := Rect2()
	for shot in _shots:
		var inner := shot.grow_individual(-shot.size.x * margin, -shot.size.y * margin, -shot.size.x * margin, -shot.size.y * margin)
		if not inner.encloses(box):
			continue
		if best.size == Vector2.ZERO or shot.size.x < best.size.x or (shot.size.x == best.size.x and shot.get_center().distance_to(box.get_center()) < best.get_center().distance_to(box.get_center())):
			best = shot
	if best.size == Vector2.ZERO:
		best = whole_map
	if current.size != Vector2.ZERO and current.encloses(box) and best.size.x >= current.size.x:
		return current
	return best


## Bounding box of the living fighters in this camera's arena; position INF when there are none.
func _fighters_box() -> Rect2:
	var box := Rect2(Vector2.INF, Vector2.ZERO)
	for fighter: Fighter in get_tree().get_nodes_in_group(Fighter.GROUP):
		if fighter.is_dead() or not get_parent().is_ancestor_of(fighter):
			continue
		if box.position == Vector2.INF:
			box = Rect2(fighter.center(), Vector2.ZERO)
		else:
			box = box.expand(fighter.center())
	return box
