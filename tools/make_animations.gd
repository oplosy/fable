extends SceneTree

## Writes the keyframe clips in assets/animations/ (format: docs/CHARACTER_ANIMATION_SPEC.md,
## section 3.1) from the trench coat agent's rig. Poses name where the feet go; the legs
## are solved to reach them (two-bone IK) and grounded so the lowest sole pixel sits on
## the floor. Planted feet move back at exactly the clip's reference speed, so they never
## slide. Run: <godot> --headless --path . -s res://tools/make_animations.gd

const RIG_DIR := "res://assets/characters/trenchcoat_agent"
const OUT_DIR := "res://assets/animations"
## Floor line in art px: the bottom edge of sole row 92.
const FLOOR := 93.0
## Keys per movement cycle; the game blends cubically between them.
const CYCLE_KEYS := 12
## Crouched body offset: hips back over the heels and down until the thighs are level.
const CROUCH_ROOT := Vector2(-8, 23)

var _pivots := {}
var _head_top := Vector2.ZERO
## "front"/"back" -> {hip, knee, ankle, sole, l1, l2, a1, a2}
var _legs := {}


func _initialize() -> void:
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RIG_DIR + "/rig.json").trim_prefix(char(0xFEFF)))
	for part: String in rig.pivots:
		_pivots[part] = Vector2(rig.pivots[part][0], rig.pivots[part][1])
	_head_top = Vector2(rig.points.head_top[0], rig.points.head_top[1])
	for side in ["front", "back"]:
		_legs[side] = _measure_leg(side)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_write("idle", _idle())
	_write("walk", _walk_cycle(120.0, 32.0, 0.5, 7.0, 3.0, 1.5, 6.0, 25.0, -35.0))
	_write("run", _run())
	_write("jump_rise", _jump_rise())
	_write("fall", _fall())
	_write("land", _land())
	_write("crouch_idle", _crouch_idle())
	_write("crouch_walk", _crouch_walk())
	quit()


# --- Clips -------------------------------------------------------------------------

## Fighting stance, breathing: the body sinks 1 px and the guard drops a little.
func _idle() -> Dictionary:
	var keys := []
	for i in 2:
		keys.append(_key(i * 0.7, _stance(float(i))))
	return {"name": "idle", "loop": true, "length": 1.4, "keys": keys}


func _stance(breath: float) -> Dictionary:
	return {
		"root": Vector2(0, 2 + breath),
		"torso": 2 + breath, "head": -2 - breath,
		"arm_front_upper": -25, "arm_front_lower": -70 - 3 * breath,
		"arm_back_upper": -20, "arm_back_lower": -60 - 3 * breath,
		"feet": {"front": "flat", "back": "flat"},
	}


## A walking leg cycle: each foot is planted for `stance` of the cycle and slides back
## `stride` art px at exactly `speed` (world px/s), then swings forward `lift` px high.
func _walk_cycle(speed: float, stride: float, stance: float, lift: float, drop: float, bob: float, lean: float, arm_swing: float, elbow: float, name := "walk") -> Dictionary:
	var length := stride / (speed * 3.0 * stance)
	var keys := []
	for i in CYCLE_KEYS:
		var p := float(i) / CYCLE_KEYS
		keys.append(_key(p * length, {
			# Lowest when both feet are down (p 0 and 0.5), highest mid-stride.
			"root": Vector2(0, drop + bob * 0.5 * (1.0 + cos(4.0 * PI * p))),
			"torso": lean, "head": -lean * 0.6,
			# Arms swing against the legs: the front leg leads at p 0, so the front arm trails.
			"arm_front_upper": arm_swing * cos(TAU * p), "arm_front_lower": elbow,
			"arm_back_upper": -arm_swing * cos(TAU * p), "arm_back_lower": elbow,
			"feet": {
				"front": _cycle_foot("front", p, stride, stance, lift),
				"back": _cycle_foot("back", p + 0.5, stride, stance, lift),
			},
		}))
	return {"name": name, "loop": true, "length": snappedf(length, 0.001), "reference_speed": speed,
		"events": [{"t": 0.0, "name": "step"}, {"t": snappedf(length / 2.0, 0.001), "name": "step"}], "keys": keys}


## Leaning forward, longer strides with both feet off the floor between steps, arms pumping.
func _run() -> Dictionary:
	var speed := 200.0
	var stride := 36.0
	var stance := 0.35
	var length := stride / (speed * 3.0 * stance)
	var keys := []
	for i in CYCLE_KEYS:
		var p := float(i) / CYCLE_KEYS
		keys.append(_key(p * length, {
			# Lowest mid-stance (p 0.175 and 0.675), highest in the flight between steps.
			"root": Vector2(2, 5 + 2.0 * cos(TAU * (2.0 * p - stance))),
			"torso": 15, "head": -10,
			"arm_front_upper": 45 * cos(TAU * p), "arm_front_lower": -85,
			"arm_back_upper": -45 * cos(TAU * p), "arm_back_lower": -85,
			"feet": {
				"front": _cycle_foot("front", p, stride, stance, 12.0),
				"back": _cycle_foot("back", p + 0.5, stride, stance, 12.0),
			},
		}))
	return {"name": "run", "loop": true, "length": snappedf(length, 0.001), "reference_speed": speed,
		"events": [{"t": 0.0, "name": "step"}, {"t": snappedf(length / 2.0, 0.001), "name": "step"}], "keys": keys}


## Instant push-off (legs straight, arms thrown up), then the legs tuck on the way up. Holds.
func _jump_rise() -> Dictionary:
	return {"name": "jump_rise", "loop": false, "length": 0.25, "keys": [
		_key(0.0, {"root": Vector2.ZERO, "torso": 2, "head": -4,
			"arm_front_upper": -60, "arm_front_lower": -40, "arm_back_upper": -45, "arm_back_lower": -40,
			"feet": {"front": _foot("front", 0, 0, true), "back": _foot("back", 0, 0, true)}}),
		_key(0.25, {"root": Vector2.ZERO, "torso": 6, "head": -4,
			"arm_front_upper": -35, "arm_front_lower": -70, "arm_back_upper": -25, "arm_back_lower": -60,
			"feet": {"front": _foot("front", 9, 14, true), "back": _foot("back", 2, 9, true)}}),
	]}


## Arms out for balance, legs reaching down for the floor, a slow wave in the arms.
func _fall() -> Dictionary:
	var keys := []
	for i in 2:
		var w := float(i)
		keys.append(_key(i * 0.2, {"root": Vector2.ZERO, "torso": 0, "head": -2,
			"arm_front_upper": -80 - 10 * w, "arm_front_lower": -20 + 10 * w,
			"arm_back_upper": 70 + 10 * w, "arm_back_lower": -25,
			"feet": {"front": _foot("front", 6, 6 - 2 * w, true), "back": _foot("back", -3, 3 + 2 * w, true)}}))
	return {"name": "fall", "loop": true, "length": 0.4, "keys": keys}


## Knees take the landing, then back up into the stance.
func _land() -> Dictionary:
	var deep := _stance(0.0)
	deep.root = Vector2(0, 11)
	deep.torso = 14
	deep.head = -8
	deep.arm_front_upper = -20
	deep.arm_back_upper = -5
	var touch := deep.duplicate()
	touch.root = Vector2(0, 5)
	return {"name": "land", "loop": false, "length": 0.12, "keys": [
		_key(0.0, touch), _key(0.04, deep), _key(0.12, _stance(0.0))]}


## Ducked: deep squat on both feet, body hunched forward over the knees with the guard
## up. The top of the head comes down to about 45 art px, the crouched hit shape's height.
func _crouch_idle() -> Dictionary:
	var keys := []
	for i in 2:
		keys.append(_key(i * 0.6, _crouch(float(i), "flat", "flat")))
	return {"name": "crouch_idle", "loop": true, "length": 1.2, "keys": keys}


func _crouch(breath: float, front: Variant, back: Variant) -> Dictionary:
	return {
		"root": Vector2(CROUCH_ROOT.x, CROUCH_ROOT.y + breath),
		"torso": 45 + breath, "head": -35 - breath,
		"arm_front_upper": -45, "arm_front_lower": -65,
		"arm_back_upper": -40, "arm_back_lower": -75,
		"feet": {"front": front, "back": back},
	}


## Short, quick shuffling steps without rising out of the squat.
func _crouch_walk() -> Dictionary:
	var speed := 50.0
	var stride := 16.0
	var stance := 0.5
	var length := stride / (speed * 3.0 * stance)
	var keys := []
	for i in CYCLE_KEYS:
		var p := float(i) / CYCLE_KEYS
		var front := _cycle_foot("front", p, stride, stance, 4.0, _flat_ankle_dx("front"))
		var back := _cycle_foot("back", p + 0.5, stride, stance, 4.0, _flat_ankle_dx("back"))
		var pose := _crouch(0.5 + 0.5 * cos(4.0 * PI * p), front, back)
		keys.append(_key(p * length, pose))
	return {"name": "crouch_walk", "loop": true, "length": snappedf(length, 0.001), "reference_speed": speed,
		"events": [{"t": 0.0, "name": "step"}, {"t": snappedf(length / 2.0, 0.001), "name": "step"}], "keys": keys}


# --- Feet --------------------------------------------------------------------------

## A foot target: x of the ankle relative to its hip, and how far it is lifted off the
## floor. `free` feet (in the air) keep their ankle height instead of being grounded.
func _foot(side: String, dx: float, lift: float, free := false) -> Vector2:
	var rest := _rest_foot(side)
	return Vector2(rest.x + dx, -lift if not free else -lift - 1000.0)


func _rest_foot(side: String) -> Vector2:
	var leg: Dictionary = _legs[side]
	return Vector2(leg.ankle.x - leg.hip.x, 0.0)


## Where a walking foot is at cycle phase `p`: planted and moving back for `stance`, then
## swinging forward on an arc. Centred under its hip, plus `shift`.
func _cycle_foot(side: String, p: float, stride: float, stance: float, lift: float, shift := 0.0) -> Vector2:
	p = fposmod(p, 1.0)
	var centre := _rest_foot(side).x * 0.4 + shift if shift == 0.0 else shift
	if p < stance:
		return Vector2(centre + stride / 2.0 - stride * p / stance, 0.0)
	var s := (p - stance) / (1.0 - stance)
	return Vector2(centre - stride / 2.0 + stride * (0.5 - 0.5 * cos(PI * s)), -lift * sin(PI * s))


## Where the flat-footed crouch puts this ankle, relative to its hip.
func _flat_ankle_dx(side: String) -> float:
	var leg: Dictionary = _legs[side]
	var hip: Vector2 = leg.hip + CROUCH_ROOT
	var turns := _flat_leg(leg, hip, 0.0)
	var thigh: float = deg_to_rad(turns.x) + leg.a1
	return (Vector2.from_angle(thigh) * leg.l1 + Vector2.from_angle(leg.a2) * leg.l2).x


# --- Solving -----------------------------------------------------------------------

## Turns a pose (root, part angles in degrees, foot targets) into a key with leg angles.
func _key(t: float, pose: Dictionary) -> Dictionary:
	var root: Vector2 = pose.root
	var pelvis := deg_to_rad(pose.get("pelvis", 0.0))
	var angles := {}
	for part: String in pose:
		if part not in ["root", "feet"]:
			angles[part] = snappedf(pose[part], 0.1)
	var thighs := []
	for side: String in ["front", "back"]:
		var leg: Dictionary = _legs[side]
		var hip: Vector2 = _pivots.pelvis + root + (leg.hip - _pivots.pelvis).rotated(pelvis)
		var target: Variant = pose.feet[side]
		var solved := _flat_leg(leg, hip, pelvis) if target is String else _solve_leg(leg, hip, target.x, target.y, pelvis)
		angles["leg_%s_upper" % side] = snappedf(solved.x, 0.1)
		angles["leg_%s_lower" % side] = snappedf(solved.y, 0.1)
		thighs.append(solved.x)
	# The coat's front follows the leading thigh, its lining the trailing one. The game
	# squashes either one whose hem would go through the floor.
	angles["coat_tail"] = snappedf(0.3 * minf(0.0, thighs.min()), 0.1)
	angles["coat_back"] = snappedf(0.5 * maxf(0.0, thighs.max()), 0.1)
	_report_head(t, pose, root, pelvis)
	return {"t": snappedf(t, 0.001), "root": [snappedf(root.x, 0.1), snappedf(root.y, 0.1)], "angles": angles}


## Leg joint rotations (degrees, upper relative to the pelvis) that put the ankle `dx`
## from the hip. `height` <= 0 is how far the lowest sole pixel is lifted off the floor;
## below -1000 the ankle is placed `height + 1000` above its standing height instead.
func _solve_leg(leg: Dictionary, hip: Vector2, dx: float, height: float, pelvis: float) -> Vector2:
	var free := height < -500.0
	var ankle := Vector2(hip.x + dx, leg.ankle.y + (height + 1000.0 if free else height))
	var turns := Vector2.ZERO
	for i in 6:
		turns = _ik(leg, hip, ankle)
		if free:
			break
		# Ground the foot: the lowest sole pixel, turned with the shin, touches the floor.
		var low := -INF
		for point: Vector2 in leg.sole:
			low = maxf(low, (point - leg.ankle).rotated(turns.y).y)
		ankle.y = FLOOR - low + height
	var upper := turns.x - pelvis
	var lower := turns.y - turns.x
	return Vector2(rad_to_deg(upper), rad_to_deg(lower))


## A grounded leg whose shin keeps its standing angle, so the foot stays flat on the
## floor; the thigh turns (knee forward) to bring the hip down to `hip`.
func _flat_leg(leg: Dictionary, hip: Vector2, pelvis: float) -> Vector2:
	var l1: float = leg.l1
	var l2: float = leg.l2
	var reach: float = (leg.ankle.y - l2 * sin(leg.a2) - hip.y) / l1
	if absf(reach) > 1.0:
		printerr("flat leg out of reach (%.2f)" % reach)
	var thigh := asin(clampf(reach, -1.0, 1.0))
	return Vector2(rad_to_deg(thigh - leg.a1 - pelvis), rad_to_deg(leg.a1 - thigh))


## Prints how high the top of the head is above the floor in crouched keys.
func _report_head(t: float, pose: Dictionary, root: Vector2, pelvis: float) -> void:
	if root.y < 15.0:
		return
	var torso := pelvis + deg_to_rad(pose.get("torso", 0.0))
	var head := torso + deg_to_rad(pose.get("head", 0.0))
	var at: Vector2 = _pivots.pelvis + root + (_pivots.torso - _pivots.pelvis).rotated(pelvis)
	at += (_pivots.head - _pivots.torso).rotated(torso)
	at += (_head_top - _pivots.head).rotated(head)
	print("  t %.3f: head top %.1f art px above the floor" % [t, FLOOR - at.y])


## World turns (radians from the standing pose) of the thigh and shin reaching `ankle`
## from `hip`, knee bent forward. Out of reach, the leg points straight at the target.
func _ik(leg: Dictionary, hip: Vector2, ankle: Vector2) -> Vector2:
	var to := ankle - hip
	var l1: float = leg.l1
	var l2: float = leg.l2
	if to.length() > l1 + l2:
		printerr("out of reach by %.1f px" % (to.length() - l1 - l2))
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.001)
	var thigh := to.angle() - acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var knee := hip + Vector2.from_angle(thigh) * l1
	var shin := (ankle - knee).angle()
	return Vector2(thigh - leg.a1, shin - leg.a2)


## Hip, knee and ankle of one leg in the standing pose, and the sole's bottom corners.
func _measure_leg(side: String) -> Dictionary:
	var hip: Vector2 = _pivots["leg_%s_upper" % side]
	var knee: Vector2 = _pivots["leg_%s_lower" % side]
	var image := Image.load_from_file(ProjectSettings.globalize_path("%s/leg_%s_lower.png" % [RIG_DIR, side]))
	var sole := []
	var sum := 0.0
	for y in range(int(FLOOR) - 3, int(FLOOR)):
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				sole.append(Vector2(x, y + 1))
				sum += x + 0.5
	# The ankle sits above the middle of the sole, 6 px over the floor.
	var ankle := Vector2(sum / sole.size(), FLOOR - 6.0)
	return {"hip": hip, "knee": knee, "ankle": ankle, "sole": sole,
		"l1": hip.distance_to(knee), "l2": knee.distance_to(ankle),
		"a1": (knee - hip).angle(), "a2": (ankle - knee).angle()}


func _write(name: String, clip: Dictionary) -> void:
	var file := FileAccess.open("%s/%s.json" % [OUT_DIR, name], FileAccess.WRITE)
	file.store_string(JSON.stringify(clip, "\t", false))
	print("%s: %d keys" % [name, clip.keys.size()])
