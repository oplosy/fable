extends SceneTree

## Draws the stick figure's frame-by-frame animations: every keyframe clip in
## assets/animations/ (from tools/make_animations.gd, posed on the street brawler's
## skeleton) is sampled FPS times a second and each frame is drawn as its own picture.
## Writes art/stickman/strips/<clip>.png (one strip per clip) and, next to the game's
## copy, assets/characters/stickman/<clip>.json with the frame timing and where the front
## hand is on every frame. tools/stickman.lua then turns the strips into .aseprite files
## and exports the PNGs the game loads.
## Run: <godot> --headless --path . -s res://tools/make_stickman.gd

const RIG := "res://assets/characters/street_brawler/rig.json"
const CLIPS_DIR := "res://assets/animations"
const STRIPS_DIR := "res://art/stickman/strips"
const OUT_DIR := "res://assets/characters/stickman"
const FPS := 24.0
## Fewest frames a loop gets, so short cycles played fast (running) still look smooth.
const MIN_LOOP_FRAMES := 12
## Frame size in art px (3 per world px) and where the feet stand in it: wide and tall
## enough for lying down, diving and arms over the head.
const SIZE := Vector2i(192, 128)
const FEET := Vector2(96, 118)

## Stroke radii in art px.
const LIMB := 1.6
const TORSO := 2.2
const HEAD := 8.5
const HAND := 2.4
## White parts take the character's colour in the game (modulate); the far limbs are
## shaded so they read as behind the body. The outline stays dark under any colour.
const NEAR := Color(0.96, 0.96, 0.96)
const FAR := Color(0.62, 0.62, 0.68)
const OUTLINE := Color(0.07, 0.05, 0.11)
## A hand or foot moving faster than this (art px per frame) leaves a smear behind it.
const SMEAR_SPEED := 7.0
const SMEAR := Color(1, 1, 1, 0.35)
## Attack clips get a second, untinted strip (<clip>_fx.png): white wind behind a fast fist
## or foot, a tapering trail along its last WIND_STEPS frames plus two speed lines.
const ATTACK := "^(fast_|heavy_|knife_|bat_)"
const WIND := Color(1, 1, 1)
const WIND_STEPS := 3
## Speed lines sit this far (art px) to each side of the swing.
const WIND_SPREAD := 4.0

## Art px the near shoulder and hip move back, and the far ones forward, in clips turned
## three quarters to the viewer ("turn" 1 in the clip): both arms and legs show apart.
const SHOULDER_SPREAD := 5.0
const HIP_SPREAD := 3.5
## Speed (world px/s) a clip plays at its own pace, where it differs from the clip's
## reference_speed: the captured walk keeps its feet planted at 12 px/s, which at the
## game's walking speed would step frantically.
const SHOWN_SPEED := {"walk": 56.0}
## Where the shoulders hang from, the head's middle and the toe and heel of a foot, in
## the rig's canvas (the rig only has pivots for joints).
const SHOULDER := Vector2(31, 39)
const HEAD_CENTER := Vector2(32, 25)
const TOE := Vector2(37, 92)
const HEEL := Vector2(29, 92)

## Every part with its parent, as in CharacterRig.PARTS (coats left out).
const PARTS := [
	["pelvis", ""], ["torso", "pelvis"], ["head", "torso"],
	["arm_back_upper", "torso"], ["arm_back_lower", "arm_back_upper"],
	["arm_front_upper", "torso"], ["arm_front_lower", "arm_front_upper"],
	["leg_back_upper", "pelvis"], ["leg_back_lower", "leg_back_upper"], ["foot_back", "leg_back_lower"],
	["leg_front_upper", "pelvis"], ["leg_front_lower", "leg_front_upper"], ["foot_front", "leg_front_lower"],
]

var _pivots := {}
var _points := {}
var _feet := Vector2.ZERO


func _initialize() -> void:
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RIG).trim_prefix(char(0xFEFF)))
	for part: String in rig.pivots:
		_pivots[part] = Vector2(rig.pivots[part][0], rig.pivots[part][1])
	for point: String in rig.points:
		_points[point] = Vector2(rig.points[point][0], rig.points[point][1])
	_feet = Vector2(rig.feet[0], rig.feet[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STRIPS_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for file in DirAccess.get_files_at(CLIPS_DIR):
		if file.get_extension() == "json":
			_draw_clip(file.get_basename())
	quit()


func _draw_clip(name: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [CLIPS_DIR, name]).trim_prefix(char(0xFEFF)))
	var clip := _animation(data)
	var loop: bool = data.get("loop", false)
	# A loop's last frame leads back into its first; a one-shot ends on its last pose.
	var count := maxi(MIN_LOOP_FRAMES, roundi(clip.length * FPS)) if loop else int(clip.length * FPS) + 1
	var step := clip.length / count if loop else 1.0 / FPS
	var strip := Image.create_empty(SIZE.x * count, SIZE.y, false, Image.FORMAT_RGBA8)
	var attack := RegEx.create_from_string(ATTACK).search(name) != null
	var fx := Image.create_empty(SIZE.x * count, SIZE.y, false, Image.FORMAT_RGBA8)
	var hands := []
	for i in count:
		var t := minf(i * step, clip.length)
		var turn: float = data.get("turn", 0.0)
		var body := _pose(clip, t, turn)
		var previous := _pose(clip, t - step, turn) if i > 0 or loop else body
		var frame := _draw(body, {} if attack else previous)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * i, 0))
		if attack:
			var path := []
			for back in WIND_STEPS * 4 + 1:
				path.append(_pose(clip, maxf(t - step * WIND_STEPS * (1.0 - back / (WIND_STEPS * 4.0)), 0.0), turn))
			fx.blit_rect(_wind(path), Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * i, 0))
		var forearm: Vector2 = body.hand_front - body.elbow_front
		hands.append([snappedf(body.hand_front.x, 0.1), snappedf(body.hand_front.y, 0.1), snappedf(rad_to_deg(forearm.angle()), 0.1)])
	strip.save_png(ProjectSettings.globalize_path("%s/%s.png" % [STRIPS_DIR, name]))
	if attack:
		fx.save_png(ProjectSettings.globalize_path("%s/%s_fx.png" % [STRIPS_DIR, name]))
	var info := {"fps": 1.0 / step if clip.length > 0.0 else FPS, "frames": count, "loop": loop, "size": [SIZE.x, SIZE.y], "feet": [FEET.x, FEET.y],
		"reference_speed": SHOWN_SPEED.get(name, data.get("reference_speed", 0.0)), "hand_front": hands}
	FileAccess.open("%s/%s.json" % [OUT_DIR, name], FileAccess.WRITE).store_string(JSON.stringify(info))
	print("%s: %d frames" % [name, count])


## The clip as the game would play it on a rig: one cubic track per part angle and one for
## the hips' offset, so the frames match RigAnimator's motion exactly.
func _animation(data: Dictionary) -> Animation:
	var clip := Animation.new()
	clip.length = data.get("length", 0.0)
	clip.loop_mode = Animation.LOOP_LINEAR if data.get("loop", false) else Animation.LOOP_NONE
	var tracks := {}
	for name in ["root"] + PARTS.map(func(p: Array) -> String: return p[0]):
		var track := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track, NodePath(name))
		clip.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		tracks[name] = track
	var angles := {}
	var root := Vector2.ZERO
	for key: Dictionary in data["keys"]:
		var t := float(key.get("t", 0.0))
		if key.has("root"):
			root = Vector2(key.root[0], key.root[1])
		clip.track_insert_key(tracks.root, t, root)
		for part: String in tracks:
			if part != "root":
				angles[part] = float(key.get("angles", {}).get(part, angles.get(part, 0.0)))
				clip.track_insert_key(tracks[part], t, deg_to_rad(angles[part]))
	return clip


## Joint positions (frame art px) at time `t`, by turning each part about its pivot.
func _pose(clip: Animation, t: float, view := 0.0) -> Dictionary:
	if clip.loop_mode == Animation.LOOP_LINEAR and clip.length > 0.0:
		t = fposmod(t, clip.length)
	t = clampf(t, 0.0, clip.length)
	var xforms := {}
	for entry: Array in PARTS:
		var part: String = entry[0]
		var parent: String = entry[1]
		var turn: float = clip.value_track_interpolate(clip.find_track(NodePath(part), Animation.TYPE_VALUE), t)
		var local: Transform2D
		if parent == "":
			var root: Vector2 = clip.value_track_interpolate(clip.find_track(NodePath("root"), Animation.TYPE_VALUE), t)
			local = Transform2D(turn, _pivots[part] - _feet + root + FEET)
			xforms[part] = local
		else:
			xforms[part] = xforms[parent] * Transform2D(turn, _pivots[part] - _pivots[parent])
	var at := func(part: String, point: Vector2) -> Vector2: return xforms[part] * (point - _pivots[part])
	var body := {
		"pelvis": at.call("pelvis", _pivots.pelvis),
		"shoulder": at.call("torso", SHOULDER),
		"neck": at.call("head", _pivots.head),
		"head": at.call("head", HEAD_CENTER),
	}
	for side in ["front", "back"]:
		body["elbow_" + side] = at.call("arm_%s_upper" % side, _pivots["arm_%s_lower" % side])
		body["hand_" + side] = at.call("arm_%s_lower" % side, _points["hand_" + side])
		body["hip_" + side] = at.call("pelvis", _pivots["leg_%s_upper" % side])
		body["knee_" + side] = at.call("leg_%s_upper" % side, _pivots["leg_%s_lower" % side])
		body["ankle_" + side] = at.call("leg_%s_lower" % side, _pivots["foot_" + side])
		body["toe_" + side] = at.call("foot_" + side, TOE)
		body["heel_" + side] = at.call("foot_" + side, HEEL)
	# Turned to the viewer: the near arm and leg move back, the far ones forward, each
	# hanging from its own end of the shoulders and hips.
	for side in ["front", "back"]:
		var away := -1.0 if side == "front" else 1.0
		body["shoulder_" + side] = body.shoulder + Vector2(away * SHOULDER_SPREAD * view, 0)
		for joint in ["elbow_", "hand_"]:
			body[joint + side] += Vector2(away * SHOULDER_SPREAD * view, 0)
		body["hip_" + side] = body.pelvis + Vector2(away * HIP_SPREAD * view, 0)
		for joint in ["knee_", "ankle_", "toe_", "heel_"]:
			body[joint + side] += Vector2(away * HIP_SPREAD * view, 0)
	return body


## One frame: far arm and leg, body and head, near leg and arm, each outlined over what is
## behind it, plus smears behind fast hands and feet.
func _draw(body: Dictionary, previous: Dictionary) -> Image:
	var frame := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	for end in previous:
		if end in ["hand_back", "toe_back", "hand_front", "toe_front"]:
			_smear(frame, previous[end], body[end])
	_layer(frame, FAR, [[body.shoulder_back, body.elbow_back, LIMB], [body.elbow_back, body.hand_back, LIMB], [body.hand_back, body.hand_back, HAND]])
	_layer(frame, FAR, _leg(body, "back"))
	_layer(frame, NEAR, [[body.pelvis, body.shoulder, TORSO], [body.shoulder_front, body.shoulder_back, LIMB],
		[body.hip_front, body.hip_back, LIMB], [body.shoulder, body.neck, LIMB], [body.head, body.head, HEAD]])
	_layer(frame, NEAR, _leg(body, "front"))
	_layer(frame, NEAR, [[body.shoulder_front, body.elbow_front, LIMB], [body.elbow_front, body.hand_front, LIMB], [body.hand_front, body.hand_front, HAND]])
	return frame


func _leg(body: Dictionary, side: String) -> Array:
	return [[body["hip_" + side], body["knee_" + side], LIMB], [body["knee_" + side], body["ankle_" + side], LIMB],
		[body["heel_" + side], body["toe_" + side], LIMB]]


## Draws round-capped strokes ([from, to, radius]) in `color` with a 1 px outline, over
## `frame`.
func _layer(frame: Image, color: Color, strokes: Array) -> void:
	var mask := {}
	for stroke: Array in strokes:
		var from: Vector2 = stroke[0]
		var to: Vector2 = stroke[1]
		var radius: float = stroke[2]
		var steps := maxi(1, ceili(from.distance_to(to) * 2.0))
		for s in steps + 1:
			var centre := from.lerp(to, float(s) / steps)
			for y in range(floori(centre.y - radius), ceili(centre.y + radius) + 1):
				for x in range(floori(centre.x - radius), ceili(centre.x + radius) + 1):
					if Vector2(x + 0.5, y + 0.5).distance_to(centre) <= radius + 0.25:
						mask[Vector2i(x, y)] = true
	var edge := {}
	for pixel: Vector2i in mask:
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not mask.has(pixel + step):
				edge[pixel + step] = true
	for pixel: Vector2i in edge:
		_put(frame, pixel, OUTLINE)
	for pixel: Vector2i in mask:
		_put(frame, pixel, color)


## A faint streak from where a hand or foot was a frame ago, when it moved fast.
func _smear(frame: Image, from: Vector2, to: Vector2) -> void:
	if from.distance_to(to) < SMEAR_SPEED:
		return
	var steps := ceili(from.distance_to(to) * 2.0)
	for s in steps:
		var centre := from.lerp(to, float(s) / steps)
		var radius := lerpf(0.6, LIMB + 0.4, float(s) / steps)
		for y in range(floori(centre.y - radius), ceili(centre.y + radius) + 1):
			for x in range(floori(centre.x - radius), ceili(centre.x + radius) + 1):
				if Vector2(x + 0.5, y + 0.5).distance_to(centre) <= radius:
					var pixel := Vector2i(x, y)
					if Rect2i(Vector2i.ZERO, SIZE).has_point(pixel) and frame.get_pixelv(pixel).a < SMEAR.a:
						frame.set_pixelv(pixel, SMEAR)


## White wind behind every hand or foot striking fast in its last frame: `path` is the
## pose over the last WIND_STEPS frames, oldest first.
func _wind(path: Array) -> Image:
	var frame := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var last: Dictionary = path[-1]
	var before: Dictionary = path[-5]
	for end: String in ["hand_back", "toe_back", "hand_front", "toe_front"]:
		var motion: Vector2 = last[end] - before[end]
		# Only the strike itself: forward (the art faces right) and reaching out from the
		# shoulder or hip, not the wind-up, the pull back or a leg folding.
		var root := end.replace("hand", "shoulder").replace("toe", "hip")
		var reaching: bool = last[end].distance_to(last[root]) > before[end].distance_to(before[root])
		if motion.length() < SMEAR_SPEED or motion.x <= 0.0 or not reaching:
			continue
		# The trail: thin and faint where the limb was, thick and bright at it.
		for k in path.size() - 1:
			var from: Vector2 = path[k][end]
			var to: Vector2 = path[k + 1][end]
			var age := float(k) / (path.size() - 1)
			_line(frame, from, to, lerpf(0.3, 1.8, age), lerpf(0.15, 0.9, age))
		# Speed lines: straight streaks behind the strike, to each side of it.
		var back := -motion.normalized()
		var side := back.orthogonal() * WIND_SPREAD
		var tip: Vector2 = last[end] + back * 3.0
		for offset in [side, -side]:
			_line(frame, tip + offset, tip + offset + back * motion.length() * 1.3, 0.5, 0.85)
	return frame


## A soft-edged line of `radius` in WIND at `alpha`, keeping the brighter of what is there.
func _line(frame: Image, from: Vector2, to: Vector2, radius: float, alpha: float) -> void:
	var steps := maxi(1, ceili(from.distance_to(to) * 2.0))
	for s in steps + 1:
		var centre := from.lerp(to, float(s) / steps)
		for y in range(floori(centre.y - radius - 1), ceili(centre.y + radius + 1) + 1):
			for x in range(floori(centre.x - radius - 1), ceili(centre.x + radius + 1) + 1):
				var pixel := Vector2i(x, y)
				var cover := clampf(radius + 0.5 - Vector2(x + 0.5, y + 0.5).distance_to(centre), 0.0, 1.0) * alpha
				if cover > 0.0 and Rect2i(Vector2i.ZERO, SIZE).has_point(pixel) and frame.get_pixelv(pixel).a < cover:
					frame.set_pixelv(pixel, Color(WIND, cover))


func _put(frame: Image, pixel: Vector2i, color: Color) -> void:
	if Rect2i(Vector2i.ZERO, SIZE).has_point(pixel):
		frame.set_pixelv(pixel, color)
