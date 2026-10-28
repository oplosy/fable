extends SceneTree

## Writes the keyframe clips in assets/animations/ (format: docs/CHARACTER_ANIMATION_SPEC.md,
## section 3.1) from the street brawler's rig, the reference every character is drawn to. Poses name where the feet go; the legs
## are solved to reach them (two-bone IK) and grounded so the lowest sole pixel sits on
## the floor. Planted feet move back at exactly the clip's reference speed, so they never
## slide. Run: <godot> --headless --path . -s res://tools/make_animations.gd

const RIG_DIR := "res://assets/characters/street_brawler"
const OUT_DIR := "res://assets/animations"
## Floor line in art px: the bottom edge of sole row 92.
const FLOOR := 93.0
## Keys per movement cycle; the game blends cubically between them.
const CYCLE_KEYS := 12
## Lying down, the hips drop until the turned body rests on the floor; the pelvis pivot
## is off the body's middle, so face up and face down differ.
const LYING_DROP := {"back": 25.0, "front": 20.0}
const PLANTED := {"front": "planted", "back": "planted"}
## Degrees a coat may turn against the hips to keep hanging straight down.
const COAT_HANG_LIMIT := 30.0
## The deep squat the crouch copies: CMU subject 69 squatting to pick something up.
const SQUAT_CAPTURE := "res://art/mocap/69_70.bvh"
const SQUAT_FRAME := 360
## Least forward lean (degrees) of the crouch.
const CROUCH_HUNCH := 45.0
## Furthest a knee bends (degrees from straight); deeper squats lift the hips.
const KNEE_LIMIT := 150.0
## Extra art px a swinging foot is lifted at twice the body's speed (and faster).
const SWING_LIFT := 3.0
const Mocap = preload("res://tools/mocap.gd")
## Mocap side -> rig side. Facing right, the body's right side is the near one.
const MOCAP_SIDES := {"front": "Right", "back": "Left"}

var _pivots := {}
var _points := {}
var _head_top := Vector2.ZERO
## "front"/"back" -> {hip, knee, ankle, sole, l1, l2, a1, a2, foot}
var _legs := {}


func _initialize() -> void:
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RIG_DIR + "/rig.json").trim_prefix(char(0xFEFF)))
	for part: String in rig.pivots:
		_pivots[part] = Vector2(rig.pivots[part][0], rig.pivots[part][1])
	for point: String in rig.points:
		_points[point] = Vector2(rig.points[point][0], rig.points[point][1])
	_head_top = _points.head_top
	for side in ["front", "back"]:
		_legs[side] = _measure_leg(side)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_write("idle", _idle())
	_write("walk", _mocap_cycle("res://art/mocap/02_01.bvh", "walk"))
	_write("run", _run())
	_write("jump_rise", _jump_rise())
	_write("fall", _fall())
	_write("land", _land())
	_write("crouch_idle", _crouch_idle())
	_write("crouch_walk", _crouch_walk())
	_write_attacks()
	_write_reactions()
	_write_knockdowns()
	_write("dive", _dive())
	_write("dive_roll", _dive_roll())
	_write("roll", _roll())
	_write("climb", _climb())
	_write_aims()
	quit()


# --- Clips -------------------------------------------------------------------------

## Fighting stance turned three quarters to the viewer (user, session 4: standing shows
## both legs and both arms): feet apart, knees soft, both fists up. Breathing sinks the
## body a pixel, drops the guard a little and rocks the weight.
func _idle() -> Dictionary:
	var keys := []
	for i in 4:
		var breath := 0.5 - 0.5 * cos(PI * i / 2.0)
		var rock := sin(PI * i / 2.0)
		keys.append(_key(i * 0.35, {
			"root": Vector2(rock * 0.5, 3 + breath),
			"torso": 4 + breath, "head": -4 - breath,
			"arm_front_upper": 15, "arm_front_lower": -135 - 4 * breath,
			"arm_back_upper": -45, "arm_back_lower": -90 - 4 * breath,
			"feet": {"front": _foot("front", -7, 0), "back": _foot("back", 8, 0)},
		}))
	return {"name": "idle", "loop": true, "length": 1.4, "turn": 1.0, "keys": keys}


func _stance(breath: float) -> Dictionary:
	return {
		"root": Vector2(0, 2 + breath),
		"torso": 2 + breath, "head": -2 - breath,
		"arm_front_upper": -25, "arm_front_lower": -70 - 3 * breath,
		"arm_back_upper": -20, "arm_back_lower": -60 - 3 * breath,
		"feet": {"front": "flat", "back": "flat"},
	}


## One step cycle copied from a motion capture: from the front foot's heel strike to the
## next, the body's height and lean, the arms and where each ankle is relative to its hip.
## The feet are grounded on the floor and planted feet move back at the capture's own
## speed, which becomes the clip's reference_speed.
## With a `body` pose, the hips, lean and arms are that pose's, plus the capture's bob.
func _mocap_cycle(path: String, name: String, body := {}) -> Dictionary:
	var bvh := Mocap.read(path)
	var count: int = bvh.frames.size()
	var walked: Vector3 = Mocap.positions(bvh, count - 1).Hips - Mocap.positions(bvh, 0).Hips
	var forward := Vector3(walked.x, 0.0, walked.z).normalized()
	var frames := []
	for f in count:
		frames.append(Mocap.side_view(Mocap.positions(bvh, f), forward))
	# Heel strikes: the front ankle furthest ahead of its hip. The cycle nearest the middle.
	var reach := func(f: int) -> float: return frames[f].RightFoot.x - frames[f].RightUpLeg.x
	var strikes := []
	for f in range(10, count - 10):
		if range(f - 10, f + 11).all(func(g: int) -> bool: return reach.call(g) <= reach.call(f)):
			strikes.append(f)
	var start: int = strikes[strikes.size() / 2 - 1]
	var end: int = strikes[strikes.size() / 2]
	# The capture floor tilts slightly; the drift over the cycle is spread back out so it loops.
	var drift: float = frames[end].Hips.y - frames[start].Hips.y
	var floors := {}
	for side: String in MOCAP_SIDES.values():
		for joint in [side + "Foot", side + "ToeBase"]:
			floors[joint] = INF
			for f in range(start, end):
				floors[joint] = minf(floors[joint], -frames[f][joint].y + drift * float(f - start) / (end - start))
	var scale: float = (_legs.front.l1 + _legs.front.l2) / _mocap_leg(bvh)
	# A foot lies flat where it is lowest; its pitch is measured from there.
	var flat := {}
	for side: String in MOCAP_SIDES.values():
		var lowest := start
		for f in range(start, end):
			if -frames[f][side + "Foot"].y - frames[f][side + "ToeBase"].y < -frames[lowest][side + "Foot"].y - frames[lowest][side + "ToeBase"].y:
				lowest = f
		flat[side] = frames[lowest]
	var length: float = (end - start) * bvh.frame_time
	var speed: float = (frames[end].Hips.x - frames[start].Hips.x) * scale / 3.0 / length
	var poses := []
	for i in CYCLE_KEYS:
		var p := float(i) / CYCLE_KEYS
		var at: Dictionary = frames[start + roundi(p * (end - start))]
		var height := func(joint: String) -> float: return -at[joint].y + drift * p
		var pose := {"arms": {}, "feet": {}, "pitch": {}}
		for side: String in MOCAP_SIDES:
			var m: String = MOCAP_SIDES[side]
			var lift := minf(height.call(m + "Foot") - floors[m + "Foot"], height.call(m + "ToeBase") - floors[m + "ToeBase"])
			# A real toe clears the floor by a pixel, which reads as shuffling at this size:
			# a swinging foot lifts more the faster it goes.
			var f := start + roundi(p * (end - start))
			var foot_speed: float = (frames[mini(f + 1, count - 1)][m + "Foot"].x - frames[maxi(f - 1, 0)][m + "Foot"].x) / (2.0 * bvh.frame_time)
			lift += SWING_LIFT / scale * clampf(foot_speed / (2.0 * speed * 3.0 / scale), 0.0, 1.0)
			# Seen from the side, the ankles swing about points right under the hips.
			pose.feet[side] = Vector2((at[m + "Foot"].x - at[m + "UpLeg"].x) * scale, -maxf(0.0, lift) * scale)
			pose.pitch[side] = _mocap_pitch(flat[m], at, m)
			pose.arms[side] = _mocap_arm(side, at[m + "Arm"], at[m + "ForeArm"], at[m + "Hand"])
		# Hip joints' height over the floor, against the rig's standing hip height.
		var hip_height: float = (height.call("RightUpLeg") + height.call("LeftUpLeg")) / 2.0 - floors.RightFoot
		_mocap_body(pose, at, hip_height * scale)
		poses.append(pose)
	if body:
		var mean_root: float = poses.reduce(func(sum: float, pose: Dictionary) -> float: return sum + pose.root.y, 0.0) / poses.size()
		for pose: Dictionary in poses:
			pose.root.y = _fit_hips(pose, pose.root.y + body.root.y - mean_root)
			pose.torso = body.torso
			pose.head = body.head
			pose.erase("arms")
			for part: String in body:
				if part.begins_with("arm_"):
					pose[part] = body[part]
	var keys := []
	for i in poses.size():
		keys.append(_key(length * i / poses.size(), poses[i]))
	return {"name": name, "loop": true, "length": snappedf(length, 0.001), "reference_speed": snappedf(speed, 0.1),
		"events": [{"t": 0.0, "name": "step"}, {"t": snappedf(length / 2.0, 0.001), "name": "step"}], "keys": keys}


## A held pose copied from one frame of a capture, seen from the side the body faces:
## the hips' height and lean and where the feet stand, both on the floor.
func _mocap_still(path: String, frame: int) -> Dictionary:
	var bvh := Mocap.read(path)
	var body := Mocap.positions(bvh, frame)
	var right: Vector3 = body.RightUpLeg - body.LeftUpLeg
	var at := Mocap.side_view(body, Vector3.UP.cross(Vector3(right.x, 0.0, right.z)).normalized())
	var scale: float = (_legs.front.l1 + _legs.front.l2) / _mocap_leg(bvh)
	# Standing (the first frame), the ankle is this high over the toes on the floor.
	var standing := Mocap.positions(bvh, 0)
	var ankle_height: float = standing.RightFoot.y - standing.RightToeBase.y
	var floor_y := -INF
	for side: String in MOCAP_SIDES.values():
		floor_y = maxf(floor_y, maxf(at[side + "Foot"].y, at[side + "ToeBase"].y))
	var standing_at := Mocap.side_view(standing, Vector3.UP.cross(Vector3(right.x, 0.0, right.z)).normalized())
	var pose := {"arms": {}, "feet": {}, "pitch": {}}
	for side: String in MOCAP_SIDES:
		var m: String = MOCAP_SIDES[side]
		pose.feet[side] = Vector2((at[m + "Foot"].x - at[m + "UpLeg"].x) * scale, 0.0)
		pose.pitch[side] = _mocap_pitch(standing_at, at, m)
		pose.arms[side] = _mocap_arm(side, at[m + "Arm"], at[m + "ForeArm"], at[m + "Hand"])
	_mocap_body(pose, at, (floor_y - (at.RightUpLeg.y + at.LeftUpLeg.y) / 2.0 - ankle_height) * scale)
	return pose


## Sets a captured pose's hips (from their height over the ankles, in art px), lean and head.
func _mocap_body(pose: Dictionary, at: Dictionary, hip_height: float) -> void:
	pose.root = Vector2(0.0, _fit_hips(pose, _legs.front.ankle.y - _legs.front.hip.y - hip_height))
	var spine: Vector2 = at.Neck - at.Hips
	pose.torso = rad_to_deg(atan2(spine.x, -spine.y))
	# The head stays level, looking ahead.
	pose.head = -pose.torso


## Degrees a captured foot (ankle to toes) has turned from lying flat in `flat`;
## positive tips the toes down and lifts the heel.
func _mocap_pitch(flat: Dictionary, at: Dictionary, side: String) -> float:
	var rest: Vector2 = flat[side + "ToeBase"] - flat[side + "Foot"]
	var now: Vector2 = at[side + "ToeBase"] - at[side + "Foot"]
	return rad_to_deg(angle_difference(rest.angle(), now.angle()))


## The hips' drop `root_y` moved as little as needed for the rig's legs to reach the
## pose's feet without folding past KNEE_LIMIT.
func _fit_hips(pose: Dictionary, root_y: float) -> float:
	# The rig's legs are not the capture's: where a leg cannot reach its ankle, the
	# hips come down until it does, straight-kneed like a real stance leg.
	for side: String in MOCAP_SIDES:
		var leg: Dictionary = _legs[side]
		var to: Vector2 = Vector2(pose.feet[side].x, _ankle_y(leg, pose.feet[side].y, pose.pitch[side]) - leg.hip.y)
		var longest: float = leg.l1 + leg.l2 - 0.5
		if absf(to.x) < longest:
			root_y = maxf(root_y, to.y - sqrt(longest * longest - to.x * to.x))
	# Nor can they fold as far: the hips stop where a knee would bend past KNEE_LIMIT.
	for side: String in MOCAP_SIDES:
		var leg: Dictionary = _legs[side]
		var to: Vector2 = Vector2(pose.feet[side].x, _ankle_y(leg, pose.feet[side].y, pose.pitch[side]) - leg.hip.y)
		var shortest: float = sqrt(leg.l1 * leg.l1 + leg.l2 * leg.l2 + 2.0 * leg.l1 * leg.l2 * cos(deg_to_rad(KNEE_LIMIT)))
		if absf(to.x) < shortest:
			root_y = minf(root_y, to.y - sqrt(shortest * shortest - to.x * to.x))
	return root_y


## Canvas y of a grounded ankle whose lowest sole pixel is `height` (<= 0) off the floor,
## its foot turned `pitch` degrees; without a foot, at its standing height.
func _ankle_y(leg: Dictionary, height: float, pitch: float) -> float:
	if not leg.foot:
		return leg.ankle.y + height
	var low := -INF
	for point: Vector2 in leg.sole:
		low = maxf(low, (point - leg.ankle).rotated(deg_to_rad(pitch)).y)
	return FLOOR - low + height


## Hip-to-ankle length of the capture's leg, in BVH units.
func _mocap_leg(bvh: Dictionary) -> float:
	var length := 0.0
	for joint: Dictionary in bvh.joints:
		if joint.name in ["RightLeg", "RightFoot"]:
			length += joint.offset.length()
	return length


## World turns (degrees) that point the rig's arm along the captured upper arm and forearm.
func _mocap_arm(side: String, shoulder: Vector2, elbow: Vector2, hand: Vector2) -> Vector2:
	var elbow_rest: Vector2 = _pivots["arm_%s_lower" % side]
	var upper_rest: Vector2 = elbow_rest - _pivots["arm_%s_upper" % side]
	var lower_rest: Vector2 = _points["hand_" + side] - elbow_rest
	return Vector2(rad_to_deg(angle_difference(upper_rest.angle(), (elbow - shoulder).angle())),
		rad_to_deg(angle_difference(lower_rest.angle(), (hand - elbow).angle())))


## Leaning forward, longer strides with both feet off the floor between steps, arms pumping.
## A cartoon sprint, two steps per cycle (user, session 4: legs kick back, arms swing,
## the body bobs): each foot strikes ahead of the hip, pushes back, kicks up behind and
## drives the knee forward again. The body drops on each strike and floats between steps,
## leaning forward and rocking with the strides; bent arms pump opposite the legs.
## Played at the fighter's own run speed; the feet slide a little for a readable cadence.
func _run() -> Dictionary:
	var speed := 123.0
	var length := 0.48
	# Ankle path relative to the hip, through one stride (phase 0 = foot strike).
	var path := [Vector2(9, 0), Vector2(2, 0), Vector2(-6, 0), Vector2(-13, -9), Vector2(-9, -19),
		Vector2(1, -15), Vector2(9, -7)]
	var keys := []
	for i in CYCLE_KEYS:
		var p := float(i) / CYCLE_KEYS
		var step := 0.5 + 0.5 * cos(TAU * 2.0 * p)
		var feet := {}
		for side in ["front", "back"]:
			var q := fposmod(p + (0.0 if side == "front" else 0.5), 1.0)
			var leg: Dictionary = _legs[side]
			var at := _loop_curve(path, q)
			feet[side] = {"at": Vector2(leg.hip.x + 2 + at.x, leg.ankle.y + 2 + 3.0 * step + at.y)}
		var swing := cos(TAU * p)
		keys.append(_key(p * length, {
			"root": Vector2(2, 2 + 3.0 * step), "torso": 16 + 3.0 * (1.0 - step), "head": -12,
			"arm_front_upper": -60 * swing, "arm_front_lower": -80 - 25 * maxf(swing, 0.0),
			"arm_back_upper": 60 * swing, "arm_back_lower": -80 - 25 * maxf(-swing, 0.0),
			"feet": feet,
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


## Ducked: a captured deep squat, up on the balls of the feet (the rig's foot turns with
## its shin), guard up; breathing sinks the hips a pixel.
func _crouch_idle() -> Dictionary:
	var keys := []
	for i in 2:
		var pose := _squat()
		pose.root.y += i
		keys.append(_key(i * 0.6, pose))
	return {"name": "crouch_idle", "loop": true, "length": 1.2, "turn": 1.0, "keys": keys}


func _squat() -> Dictionary:
	var pose := _mocap_still(SQUAT_CAPTURE, SQUAT_FRAME)
	pose.erase("arms")
	# A big head on short legs stays high in a squat; hunching over the knees brings it
	# down to the crouch hitbox, the head tipped halfway back to look ahead.
	pose.torso = maxf(pose.torso, CROUCH_HUNCH)
	pose.head = -pose.torso / 2.0
	pose.arm_front_upper = -45
	pose.arm_front_lower = -70
	pose.arm_back_upper = -40
	pose.arm_back_lower = -75
	return pose


## Steps on the balls of the feet from a captured crouched walk, at the squat's height.
func _crouch_walk() -> Dictionary:
	return _mocap_cycle("res://art/mocap/136_13.bvh", "crouch_walk", _squat())


# --- Attacks -----------------------------------------------------------------------

## Every melee attack in the class and item data, timed from its data file: wind-up,
## the hit pose at `windup` (event "hit"), held through `active`, then back to the stance.
## Each reports whether its fist, foot or blade tip is inside the hit area while it hits.
func _write_attacks() -> void:
	var fast: FighterClass = load("res://data/classes/fast.tres")
	var heavy: FighterClass = load("res://data/classes/heavy.tres")
	var knife: MeleeItemData = load("res://data/weapons/knife.tres")
	var bat: MeleeItemData = load("res://data/weapons/bat.tres")
	var front_jab := {"root": Vector2(6, 3), "torso": 15, "head": -12,
		"arms": {"front": {"at": Vector2(56, 38)}, "back": Vector2(-20, -110)}, "feet": PLANTED}
	var back_jab := {"root": Vector2(4, 3), "torso": 10, "head": -8,
		"arms": {"front": Vector2(-15, -120), "back": {"at": Vector2(64, 36)}}, "feet": PLANTED}
	var cock_front := {"root": Vector2(-1, 3), "torso": 0, "head": -2,
		"arms": {"front": Vector2(-10, -125), "back": Vector2(-20, -105)}, "feet": PLANTED}
	var cock_back := {"root": Vector2(-1, 3), "torso": 2, "head": -2,
		"arms": {"front": Vector2(-30, -110), "back": Vector2(10, -120)}, "feet": PLANTED}
	_write_attack("fast_jab_1", fast.melee_combo[0], cock_front, front_jab, front_jab, "hand_front")
	_write_attack("fast_jab_2", fast.melee_combo[1], cock_back, back_jab, back_jab, "hand_back")
	_write_attack("fast_jab_3", fast.melee_combo[2], cock_front, front_jab, front_jab, "hand_front")
	_write_attack("fast_hook", fast.melee_combo[3],
		{"root": Vector2(-3, 4), "torso": -12, "head": 4, "arms": {"front": Vector2(35, -40), "back": Vector2(-30, -110)}, "feet": PLANTED},
		{"root": Vector2(7, 4), "torso": 20, "head": -15, "arms": {"front": {"at": Vector2(54, 34)}, "back": Vector2(10, -60)}, "feet": PLANTED},
		{"root": Vector2(8, 4), "torso": 24, "head": -18, "arms": {"front": {"at": Vector2(58, 38)}, "back": Vector2(15, -50)}, "feet": PLANTED},
		"hand_front")
	var heavy_front := {"root": Vector2(8, 4), "torso": 18, "head": -14,
		"arms": {"front": {"at": Vector2(58, 38)}, "back": Vector2(5, -100)}, "feet": PLANTED}
	var heavy_back := {"root": Vector2(6, 4), "torso": 14, "head": -10,
		"arms": {"front": Vector2(-10, -110), "back": {"at": Vector2(66, 36)}}, "feet": PLANTED}
	_write_attack("heavy_punch_1", heavy.melee_combo[0],
		{"root": Vector2(-4, 4), "torso": -8, "head": 4, "arms": {"front": Vector2(30, -110), "back": Vector2(-25, -110)}, "feet": PLANTED},
		heavy_front, heavy_front, "hand_front")
	_write_attack("heavy_punch_2", heavy.melee_combo[1],
		{"root": Vector2(-4, 4), "torso": -6, "head": 4, "arms": {"front": Vector2(-30, -110), "back": Vector2(35, -100)}, "feet": PLANTED},
		heavy_back, heavy_back, "hand_back")
	# The leading (back) leg kicks out straight; the body leans away to balance it.
	var kick := {"root": Vector2(-2, 2), "torso": -18, "head": 10,
		"arms": {"front": Vector2(30, -60), "back": Vector2(-40, -90)},
		"feet": {"front": "planted", "back": {"at": Vector2(66, 66)}}}
	_write_attack("heavy_kick", heavy.melee_combo[2],
		{"root": Vector2(-3, 3), "torso": -8, "head": 4, "arms": {"front": Vector2(15, -90), "back": Vector2(-30, -110)},
			"feet": {"front": "planted", "back": {"at": Vector2(46, 70)}}},
		kick, kick, "ankle_back")
	for entry in [["fast_jump_kick", fast.air_attack], ["heavy_jump_kick", heavy.air_attack]]:
		var flying := {"root": Vector2(4, 4), "torso": -10, "head": 6,
			"arms": {"front": Vector2(40, -40), "back": Vector2(-60, -80)},
			"feet": {"front": {"at": Vector2(34, 74)}, "back": {"at": Vector2(64, 84)}}}
		_write_attack(entry[0], entry[1],
			{"root": Vector2(2, 2), "torso": 0, "head": 0, "arms": {"front": Vector2(-30, -60), "back": Vector2(-30, -60)},
				"feet": {"front": {"at": Vector2(30, 76)}, "back": {"at": Vector2(46, 78)}}},
			flying, flying, "ankle_back", true)
	var stab := {"root": Vector2(7, 3), "torso": 15, "head": -12,
		"arms": {"front": {"at": Vector2(48, 40), "dir": 0}, "back": Vector2(-10, -100)}, "feet": PLANTED}
	var draw_back := {"root": Vector2(-2, 3), "torso": -2, "head": 0,
		"arms": {"front": Vector2(20, -80), "back": Vector2(-20, -105)}, "feet": PLANTED}
	_write_attack("knife_stab_1", knife.combo[0], draw_back, stab, stab, "tip", false, knife)
	_write_attack("knife_stab_2", knife.combo[1], draw_back, stab, stab, "tip", false, knife)
	_write_attack("knife_slash", knife.combo[2],
		{"root": Vector2(0, 3), "torso": -5, "head": 2, "arms": {"front": Vector2(-150, -175), "back": Vector2(-20, -100)}, "feet": PLANTED},
		{"root": Vector2(6, 3), "torso": 14, "head": -10, "arms": {"front": {"at": Vector2(50, 34), "dir": -20}, "back": Vector2(0, -90)}, "feet": PLANTED},
		{"root": Vector2(7, 4), "torso": 18, "head": -12, "arms": {"front": {"at": Vector2(50, 44), "dir": 30}, "back": Vector2(10, -80)}, "feet": PLANTED},
		"tip", false, knife)
	# Bat: both hands on the handle (the back fist just behind the front one); the bat
	# comes round from behind the shoulder.
	var swing := {"root": Vector2(5, 3), "torso": 14, "head": -10,
		"arms": {"front": {"at": Vector2(46, 40), "dir": 0}, "back": {"at": Vector2(42, 41)}}, "feet": PLANTED}
	var through := {"root": Vector2(6, 3), "torso": 18, "head": -12,
		"arms": {"front": {"at": Vector2(48, 41), "dir": -20}, "back": {"at": Vector2(44, 43)}}, "feet": PLANTED}
	var shoulder := {"root": Vector2(-3, 3), "torso": -10, "head": 6,
		"arms": {"front": Vector2(30, 120), "back": Vector2(40, 110)}, "feet": PLANTED}
	_write_attack("bat_swing_1", bat.combo[0], shoulder, swing, through, "tip", false, bat)
	_write_attack("bat_swing_2", bat.combo[1], shoulder, swing, through, "tip", false, bat)
	var big_shoulder := {"root": Vector2(-6, 4), "torso": -20, "head": 12,
		"arms": {"front": Vector2(50, 150), "back": Vector2(60, 140)}, "feet": PLANTED}
	var full := {"root": Vector2(8, 4), "torso": 25, "head": -18,
		"arms": {"front": {"at": Vector2(48, 36), "dir": -20}, "back": {"at": Vector2(44, 38)}}, "feet": PLANTED}
	_write_attack("bat_home_run", bat.combo[2], big_shoulder, swing, full, "tip", false, bat)


## One attack clip: stance, wind-up, hit pose at `windup`, `follow` at the end of the
## active time, then back to the stance. `reach` names the point that must land in the
## hit area: hand_front, hand_back, ankle_back or tip (of the held `item`).
func _write_attack(name: String, attack: MeleeAttack, windup: Dictionary, hit: Dictionary, follow: Dictionary, reach: String, airborne := false, item: ItemData = null) -> void:
	var length := attack.duration()
	var start := _stance(0.0) if not airborne else windup
	var keys := [_key(0.0, start), _key(attack.windup * 0.6, windup), _key(attack.windup, hit),
		_key(attack.windup + attack.active, follow), _key(length, start)]
	var area := Rect2(Vector2(32, FLOOR) + attack.hitbox_offset * 3.0 - attack.hitbox_size * 1.5, attack.hitbox_size * 3.0)
	for key: Dictionary in [keys[2], keys[3]]:
		var at := _reach_point(key, reach, item)
		if not area.has_point(at):
			printerr("%s t %.3f: %s at %s misses %s" % [name, key.t, reach, at, area])
	_write(name, {"name": name, "loop": false, "length": snappedf(length, 0.001),
		"events": [{"t": snappedf(attack.windup, 0.001), "name": "hit"}], "keys": keys})


# --- Hits, knockdowns and deaths ---------------------------------------------------

## Flinches: light ones snap and recover, heavy ones stagger a step. They end near the
## stance, so a longer stun simply holds the last pose.
func _write_reactions() -> void:
	for side in ["front", "back"]:
		# Hit in front: thrown back (negative lean). Hit from behind: lurch forward.
		var sign := -1.0 if side == "front" else 1.0
		var light := {"root": Vector2(sign * 2, 3), "torso": sign * 12, "head": sign * 14,
			"arms": {"front": Vector2(-60 - sign * 20, -120), "back": Vector2(-40 - sign * 20, -110)}, "feet": PLANTED}
		_write("hit_%s_light" % side, {"name": "hit_%s_light" % side, "loop": false, "length": 0.2,
			"keys": [_key(0.0, _stance(0.0)), _key(0.05, light), _key(0.2, _ease_to_stance(light, 0.3))]})
		var heavy := {"root": Vector2(sign * 6, 6), "torso": sign * 22, "head": sign * 18,
			"arms": {"front": Vector2(-90 - sign * 40, -150), "back": Vector2(-60 - sign * 40, -130)}, "feet": PLANTED}
		_write("hit_%s_heavy" % side, {"name": "hit_%s_heavy" % side, "loop": false, "length": 0.35,
			"keys": [_key(0.0, _stance(0.0)), _key(0.07, heavy), _key(0.35, _ease_to_stance(heavy, 0.35))]})
	var flung := {"root": Vector2.ZERO, "torso": -15, "head": 12,
		"arms": {"front": Vector2(-150, -170), "back": Vector2(-130, -150)},
		"feet": {"front": {"at": Vector2(22, 84)}, "back": {"at": Vector2(52, 80)}}}
	_write("hit_air", {"name": "hit_air", "loop": false, "length": 0.25, "keys": [_key(0.0, flung), _key(0.25, flung)]})


## Knocked down onto the back (hit in front) or the face (hit from behind), lying, getting
## up in exactly 0.4 s, and dying the same two ways.
func _write_knockdowns() -> void:
	for side in ["back", "front"]:
		var sign := -1.0 if side == "back" else 1.0
		var lying := _lying(side, 0.0)
		var flying := {"root": Vector2(sign * 6, 12), "pelvis": sign * 45, "torso": sign * 10, "head": sign * 15,
			"arms": {"front": Vector2(sign * 30 - 150, -160), "back": Vector2(sign * 30 - 120, -140)},
			"feet": {"front": "rest", "back": "rest"}}
		_write("knockdown_" + side, {"name": "knockdown_" + side, "loop": false, "length": 0.35,
			"keys": [_key(0.0, _ease_to_stance(flying, 0.4)), _key(0.15, flying), _key(0.35, lying)]})
		_write("lying_" + side, {"name": "lying_" + side, "loop": true, "length": 0.8,
			"keys": [_key(0.0, lying), _key(0.4, _lying(side, 1.0))]})
		# Up through a crouch: readable as standing from about 0.2 s, as the game may cut it there.
		var push := {"root": Vector2(-sign * 2, 26), "pelvis": sign * 50, "torso": -sign * 20, "head": -sign * 25,
			"arms": {"front": Vector2(sign * 60, sign * 60), "back": Vector2(sign * 70, sign * 70)},
			"feet": {"front": "rest", "back": "rest"}}
		_write("getup_" + side, {"name": "getup_" + side, "loop": false, "length": 0.4,
			"keys": [_key(0.0, lying), _key(0.1, push), _key(0.22, _squat()), _key(0.4, _stance(0.0))]})
		var slump := {"root": Vector2(sign * 4, 14), "pelvis": sign * 30, "torso": sign * 15, "head": sign * 30,
			"arms": {"front": Vector2(sign * 40, sign * 20), "back": Vector2(sign * 50, sign * 30)},
			"feet": {"front": "planted", "back": "planted"}}
		var dead := _lying(side, 0.0)
		dead.head = sign * 20
		dead.arms = {"front": Vector2(sign * 90 + 40, sign * 90 + 70), "back": Vector2(sign * 90 - 20, sign * 90 - 40)}
		_write("death_" + side, {"name": "death_" + side, "loop": false, "length": 0.5,
			"keys": [_key(0.0, _stance(0.0)), _key(0.2, slump), _key(0.5, dead)]})


## Flat on the back (`side` "back", face up) or the face; `breath` lifts the chest a little.
func _lying(side: String, breath: float) -> Dictionary:
	var sign := -1.0 if side == "back" else 1.0
	# Face up, the near arm would sink into the floor; it rests across the belly instead.
	var front_arm := Vector2(-130, -63) if side == "back" else Vector2(105, 120)
	return {"root": Vector2(0, LYING_DROP[side]), "pelvis": sign * 90, "torso": -sign * breath, "head": 20.0 if side == "back" else 5.0,
		"arms": {"front": front_arm, "back": Vector2(sign * 90 - 15, sign * 90 - 5)},
		"feet": {"front": "rest", "back": "rest"}}


## A pose `amount` (0..1) of the way from the stance to `pose`, for root and lean.
func _ease_to_stance(pose: Dictionary, amount: float) -> Dictionary:
	var eased := pose.duplicate(true)
	var stance := _stance(0.0)
	eased.root = stance.root.lerp(pose.root, amount)
	for part in ["pelvis", "torso", "head"]:
		eased[part] = lerpf(stance.get(part, 0.0), pose.get(part, 0.0), amount)
	return eased


# --- Dive, roll, climb, aim (the stick figure's frames, docs/GAME_DESIGN.md) -------

## Tucked into a ball: knees to the chest, arms round the shins, chin down. Rolling, the
## whole ball turns with the hips (`spin`, degrees forward).
func _tuck(spin: float, root: Vector2) -> Dictionary:
	return {"root": root, "pelvis": spin, "torso": 35, "head": 25,
		"arm_front_upper": -50, "arm_front_lower": -100, "arm_back_upper": -35, "arm_back_lower": -110,
		"feet": {"front": "rest", "back": "rest"}, "legs": {"front": Vector2(-120, 140), "back": Vector2(-105, 135)}}


## Head first: arms reach past the head, legs trail; from the takeoff lean into a flat
## flight that holds until landing.
func _dive() -> Dictionary:
	var takeoff := {"root": Vector2(-4, -2), "pelvis": 50, "torso": 5, "head": -30,
		"arms": {"front": Vector2(-140, -125), "back": Vector2(-150, -135)},
		"feet": {"front": "rest", "back": "rest"}, "legs": {"front": Vector2(20, 25), "back": Vector2(-15, 35)}}
	var flight := {"root": Vector2(-10, -8), "pelvis": 82, "torso": 3, "head": -40,
		"arms": {"front": Vector2(-97, -95), "back": Vector2(-102, -98)},
		"feet": {"front": "rest", "back": "rest"}, "legs": {"front": Vector2(5, 15), "back": Vector2(-8, 25)}}
	var glide := flight.duplicate(true)
	glide.root = Vector2(-10, -7)
	glide.legs = {"front": Vector2(0, 22), "back": Vector2(-12, 30)}
	return {"name": "dive", "loop": false, "length": 0.4, "keys": [
		_key(0.0, takeoff), _key(0.12, flight), _key(0.4, glide)]}


## A dive lands into a forward roll: hands to the floor, tuck, over the shoulders and up.
func _dive_roll() -> Dictionary:
	var touch := {"root": Vector2(-6, 6), "pelvis": 100, "torso": 10, "head": -30,
		"arms": {"front": Vector2(-60, -40), "back": Vector2(-70, -50)},
		"feet": {"front": "rest", "back": "rest"}, "legs": {"front": Vector2(-10, 30), "back": Vector2(-25, 40)}}
	return {"name": "dive_roll", "loop": false, "length": 0.45, "keys": [
		_key(0.0, touch), _key(0.08, _tuck(160, Vector2(-3, 12))), _key(0.18, _tuck(250, Vector2(0, 13))),
		_key(0.28, _tuck(330, Vector2(2, 12))), _spun(_key(0.36, _squat()), 360), _spun(_key(0.45, _stance(0.0)), 360)]}


## S while running: down into a forward roll and back up, as long as the roll lasts.
func _roll() -> Dictionary:
	var dip := _squat()
	dip.torso = 55
	return {"name": "roll", "loop": false, "length": 0.4, "keys": [
		_key(0.0, dip), _key(0.08, _tuck(90, Vector2(0, 12))), _key(0.17, _tuck(190, Vector2(0, 13))),
		_key(0.26, _tuck(290, Vector2(0, 12))), _spun(_key(0.33, _squat()), 360), _spun(_key(0.4, _stance(0.0)), 360)]}


## A smooth closed curve through `points`, at `q` (0..1) of the way round (Catmull-Rom).
func _loop_curve(points: Array, q: float) -> Vector2:
	var n := points.size()
	var x := fposmod(q, 1.0) * n
	var i := int(x)
	var t := x - i
	var p0: Vector2 = points[(i - 1 + n) % n]
	var p1: Vector2 = points[i % n]
	var p2: Vector2 = points[(i + 1) % n]
	var p3: Vector2 = points[(i + 2) % n]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


## A key turned a whole `spin` (degrees) further at the hips: the same pose, after a roll,
## so the hips keep turning forward instead of unwinding.
func _spun(key: Dictionary, spin: float) -> Dictionary:
	key.angles.pelvis = key.angles.get("pelvis", 0.0) + spin
	return key


## Up a ladder in front of the body: hand over hand and foot over foot, opposite pairs.
## Played at the climbing speed; it stands still on the ladder.
func _climb() -> Dictionary:
	var keys := []
	for i in 3:
		var up := "front" if i % 2 == 0 else "back"
		var down := "back" if up == "front" else "front"
		var pose := {"root": Vector2(2, -2 - (i % 2)), "torso": -4, "head": -10,
			"arms": {up: {"at": Vector2(40, 14)}, down: {"at": Vector2(40, 36)}},
			"feet": {up: {"at": Vector2(37, 74)}, down: {"at": Vector2(36, 87)}}}
		keys.append(_key(i * 0.3, pose))
	return {"name": "climb", "loop": true, "length": 0.6, "reference_speed": 1.0, "keys": keys}


## Holding a firearm or a throwable: still poses, one per AIM_STEPS step from straight up
## to straight down, standing and crouched. The front hand holds the grip at the
## fighter's hand marker; the back hand steadies it further along the aim.
const AIM_STEPS := 9
const AIM_HAND := {"stand": Vector2(44, 51), "crouch": Vector2(44, 72)}

func _write_aims() -> void:
	for stance in ["stand", "crouch"]:
		for i in AIM_STEPS:
			var aim := lerpf(-90.0, 90.0, float(i) / (AIM_STEPS - 1))
			var pose := _stance(0.0) if stance == "stand" else _squat()
			var hand: Vector2 = AIM_HAND[stance]
			if stance == "stand":
				pose.feet = {"front": _foot("front", -7, 0), "back": _foot("back", 8, 0)}
			pose.torso += aim * 0.12
			pose.head = pose.get("head", 0.0) - aim * 0.12 + aim * 0.35
			pose.arms = {"front": {"at": hand, "dir": aim}, "back": {"at": hand + Vector2.from_angle(deg_to_rad(aim)) * 5.0, "dir": aim}}
			var name := "%s_aim_%d" % [stance, i]
			_write(name, {"name": name, "loop": false, "length": 0.0, "turn": 1.0, "keys": [_key(0.0, pose)]})


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


# --- Solving -----------------------------------------------------------------------

## Turns a pose (root, part angles in degrees, foot targets) into a key with leg angles.
func _key(t: float, pose: Dictionary) -> Dictionary:
	var root: Vector2 = pose.root
	var pelvis := deg_to_rad(pose.get("pelvis", 0.0))
	var angles := {}
	for part: String in pose:
		if part not in ["root", "feet", "arms", "pitch", "legs"]:
			angles[part] = snappedf(pose[part], 0.1)
	# Arms are posed in world turns (from hanging down), whatever the torso does.
	var torso_turn: float = pose.get("pelvis", 0.0) + pose.get("torso", 0.0)
	for side: String in pose.get("arms", {}):
		var arm: Variant = pose.arms[side]
		if arm is Dictionary:
			arm = _arm_turns(side, _shoulder(side, root, pelvis, deg_to_rad(torso_turn)), arm)
		angles["arm_%s_upper" % side] = snappedf(arm.x - torso_turn, 0.1)
		angles["arm_%s_lower" % side] = snappedf(arm.y - arm.x, 0.1)
	for side: String in ["front", "back"]:
		var leg: Dictionary = _legs[side]
		var hip: Vector2 = _pivots.pelvis + root + (leg.hip - _pivots.pelvis).rotated(pelvis)
		var target: Variant = pose.feet[side]
		var pitch := deg_to_rad(pose.get("pitch", {}).get(side, 0.0))
		var solved: Vector2
		if target is Vector2:
			solved = _solve_leg(leg, hip, target.x, target.y, pelvis, pitch)
		elif target is Dictionary:
			# A free foot: the ankle goes to this canvas point.
			var turns := _ik(leg, hip, target.at)
			solved = Vector2(rad_to_deg(turns.x - pelvis), rad_to_deg(turns.y - turns.x))
		elif target == "planted":
			# Stays where it stands while the body moves over it.
			solved = _solve_leg(leg, hip, leg.ankle.x - hip.x, 0.0, pelvis, pitch)
		elif target == "rest":
			solved = Vector2.ZERO
		else:
			solved = _flat_leg(leg, hip, pelvis)
		angles["leg_%s_upper" % side] = snappedf(solved.x, 0.1)
		angles["leg_%s_lower" % side] = snappedf(solved.y, 0.1)
		# A foot on the floor lies at its pitch whatever the leg does; in the air it
		# turns with the shin. Rigs without feet ignore the angle.
		var grounded: bool = target is Vector2 and target.y > -500.0 or target is String and target != "rest"
		var shin := pelvis + deg_to_rad(solved.x + solved.y)
		angles["foot_" + side] = snappedf(rad_to_deg(wrapf(pitch - shin, -PI, PI)), 0.1) if grounded else 0.0
		# Raw leg turns (thigh against the hips, shin against the thigh) for tucks and dives.
		if pose.has("legs") and pose.legs.has(side):
			angles["leg_%s_upper" % side] = snappedf(pose.legs[side].x, 0.1)
			angles["leg_%s_lower" % side] = snappedf(pose.legs[side].y, 0.1)
	# Coats hang straight down whatever the hips do, as far as the body lets them. The game
	# bends them over the legs, sways them after the body and keeps them off the floor.
	var hang := snappedf(clampf(-rad_to_deg(pelvis), -COAT_HANG_LIMIT, COAT_HANG_LIMIT), 0.1)
	angles["coat_tail"] = hang
	angles["coat_back"] = hang
	_report_head(t, pose, root, pelvis)
	return {"t": snappedf(t, 0.001), "root": [snappedf(root.x, 0.1), snappedf(root.y, 0.1)], "angles": angles}


## Leg joint rotations (degrees, upper relative to the pelvis) that put the ankle `dx`
## from the hip. `height` <= 0 is how far the lowest sole pixel is lifted off the floor;
## below -1000 the ankle is placed `height + 1000` above its standing height instead.
## `pitch` (radians) is the foot's turn from lying flat, for rigs with feet.
func _solve_leg(leg: Dictionary, hip: Vector2, dx: float, height: float, pelvis: float, pitch := 0.0) -> Vector2:
	var free := height < -500.0
	var ankle := Vector2(hip.x + dx, leg.ankle.y + (height + 1000.0 if free else height))
	var turns := Vector2.ZERO
	for i in 6:
		turns = _ik(leg, hip, ankle)
		if free:
			break
		# Ground the foot: the lowest sole pixel, turned with the foot (or the shin, which
		# carries the sole on rigs without feet), touches the floor.
		var tilt: float = pitch if leg.foot else turns.y
		var low := -INF
		for point: Vector2 in leg.sole:
			low = maxf(low, (point - leg.ankle).rotated(tilt).y)
		ankle.y = FLOOR - low + height
	# Turns between -180 and 180, so keys never spin the long way round.
	return Vector2(rad_to_deg(wrapf(turns.x - pelvis, -PI, PI)), rad_to_deg(wrapf(turns.y - turns.x, -PI, PI)))


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


## Where a key puts a point (hand_front, hand_back, ankle_front, ankle_back, or the tip
## of `item` held in the front hand), in canvas art px.
func _reach_point(key: Dictionary, what: String, item: ItemData) -> Vector2:
	var angles: Dictionary = key.angles
	var pelvis_at: Vector2 = _pivots.pelvis + Vector2(key.root[0], key.root[1])
	var pelvis := deg_to_rad(angles.get("pelvis", 0.0))
	if what.begins_with("ankle"):
		var side := what.trim_prefix("ankle_")
		var leg: Dictionary = _legs[side]
		var thigh := pelvis + deg_to_rad(angles["leg_%s_upper" % side])
		var shin := thigh + deg_to_rad(angles["leg_%s_lower" % side])
		var knee: Vector2 = pelvis_at + (leg.hip - _pivots.pelvis).rotated(pelvis) + (leg.knee - leg.hip).rotated(thigh)
		return knee + (leg.ankle - leg.knee).rotated(shin)
	var arm := "back" if what == "hand_back" else "front"
	var torso := pelvis + deg_to_rad(angles.get("torso", 0.0))
	var upper := torso + deg_to_rad(angles["arm_%s_upper" % arm])
	var lower := upper + deg_to_rad(angles["arm_%s_lower" % arm])
	var shoulder: Vector2 = pelvis_at + (_pivots.torso - _pivots.pelvis).rotated(pelvis) + (_pivots["arm_%s_upper" % arm] - _pivots.torso).rotated(torso)
	var elbow: Vector2 = shoulder + (_pivots["arm_%s_lower" % arm] - _pivots["arm_%s_upper" % arm]).rotated(upper)
	var hand: Vector2 = elbow + (_points["hand_" + arm] - _pivots["arm_%s_lower" % arm]).rotated(lower)
	if what != "tip":
		return hand
	# Held items lie along the forearm, grip in the fist.
	var forearm: Vector2 = (_points.hand_front - _pivots.arm_front_lower).normalized().rotated(lower)
	return hand + forearm * (item.texture.get_width() - item.grip.x)


## Canvas point of a shoulder for this body position (torso turn in radians).
func _shoulder(side: String, root: Vector2, pelvis: float, torso: float) -> Vector2:
	return _pivots.pelvis + root + (_pivots.torso - _pivots.pelvis).rotated(pelvis) + (_pivots["arm_%s_upper" % side] - _pivots.torso).rotated(torso)


## World turns (degrees) of an arm whose hand reaches `aim.at` from `shoulder`. With
## `aim.dir` (degrees, 0 = forward) the forearm points that way, as a held item lies
## along it, and the upper arm aims at the elbow; without it the elbow bends downwards.
func _arm_turns(side: String, shoulder: Vector2, aim: Dictionary) -> Vector2:
	var elbow_rest: Vector2 = _pivots["arm_%s_lower" % side]
	var upper_rest: Vector2 = elbow_rest - _pivots["arm_%s_upper" % side]
	var lower_rest: Vector2 = _points["hand_" + side] - elbow_rest
	var l1 := upper_rest.length()
	var l2 := lower_rest.length()
	var upper: float
	var lower: float
	if aim.has("dir"):
		lower = deg_to_rad(aim.dir)
		upper = (aim.at - Vector2.from_angle(lower) * l2 - shoulder).angle()
	else:
		var to: Vector2 = aim.at - shoulder
		var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.001)
		var bend := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
		# Of the two elbow positions, the lower one.
		upper = to.angle() + bend if Vector2.from_angle(to.angle() + bend).y > Vector2.from_angle(to.angle() - bend).y else to.angle() - bend
		lower = (aim.at - (shoulder + Vector2.from_angle(upper) * l1)).angle()
	return Vector2(rad_to_deg(angle_difference(upper_rest.angle(), upper)), rad_to_deg(angle_difference(lower_rest.angle(), lower)))


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
	# A separate foot carries the sole; without one, the lower leg does.
	var foot := _pivots.has("foot_" + side)
	var image := Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [RIG_DIR, ("foot_%s" if foot else "leg_%s_lower") % side]))
	var sole := []
	var sum := 0.0
	for y in range(int(FLOOR) - 3, int(FLOOR)):
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				sole.append(Vector2(x, y + 1))
				sum += x + 0.5
	# Without a foot, the ankle sits above the middle of the sole, 6 px over the floor.
	var ankle: Vector2 = _pivots["foot_" + side] if foot else Vector2(sum / sole.size(), FLOOR - 6.0)
	return {"hip": hip, "knee": knee, "ankle": ankle, "sole": sole, "foot": foot,
		"l1": hip.distance_to(knee), "l2": knee.distance_to(ankle),
		"a1": (knee - hip).angle(), "a2": (ankle - knee).angle()}


func _write(name: String, clip: Dictionary) -> void:
	var file := FileAccess.open("%s/%s.json" % [OUT_DIR, name], FileAccess.WRITE)
	file.store_string(JSON.stringify(clip, "\t", false))
	print("%s: %d keys" % [name, clip.keys.size()])
