class_name CharacterRig
extends Node2D

## A character's cutout rig: one node per body part, parented joint to joint,
## so rotating a part carries everything attached to it.
## Built from a rig.json and the part PNGs next to it. Shapes and hits never use it.

## Every part in draw order (back to front) with its parent; "" is the rig root at the feet.
const PARTS := [
	["arm_back_upper", "torso"],
	["arm_back_lower", "arm_back_upper"],
	["hand_back", "arm_back_lower"],
	["coat_back", "pelvis"],
	["leg_back_upper", "pelvis"],
	["leg_back_lower", "leg_back_upper"],
	["foot_back", "leg_back_lower"],
	["pelvis", ""],
	["scabbard", "pelvis"],
	["leg_front_upper", "pelvis"],
	["leg_front_lower", "leg_front_upper"],
	["foot_front", "leg_front_lower"],
	["torso", "pelvis"],
	["coat_tail", "pelvis"],
	["head", "torso"],
	["arm_front_upper", "torso"],
	["arm_front_lower", "arm_front_upper"],
	["hand_front", "arm_front_lower"],
]

## Parts a character may leave out of its rig.json.
const OPTIONAL := ["coat_back", "coat_tail", "foot_back", "foot_front", "hand_back", "hand_front", "scabbard"]

## How much of the aim's angle the torso and the head turn with.
const AIM_TORSO_SHARE := 0.18
const AIM_HEAD_SHARE := 0.42
## Radians the torso bows forward while crouching and aiming.
const CROUCH_LEAN := 0.28
## How far ahead of the fist the back hand holds an aimed item, art px.
const BACK_HAND_LEAD := 6.0

## Part name -> the node it rotates around its joint.
var joints := {}
## rig.json "points" (hand_front, hand_back, head_top) in art pixels on the canvas.
var points := {}
## rig.json "pivots" and "feet", in art pixels on the canvas.
var pivots := {}
var feet := Vector2.ZERO
## On the front fist, turned along the forearm and at world scale, so a held item's art
## follows the hand. Visual only: hits and projectiles never use it.
var hand_anchor: Node2D


## Reads `rig_path` and builds the parts, drawn at 1/`pixels_per_unit` scale with the
## rig's feet pixel on this node's origin. Returns false (and builds nothing) when the
## rig file is broken or a part is missing.
func build(rig_path: String, pixels_per_unit: float) -> bool:
	var rig: Variant = JSON.parse_string(FileAccess.get_file_as_string(rig_path).trim_prefix(char(0xFEFF)))
	if not rig is Dictionary or not rig.get("pivots") is Dictionary or not rig.get("feet") is Array:
		push_error("%s: not a valid rig file" % rig_path)
		return false
	var rig_pivots: Dictionary = rig.pivots
	var dir := rig_path.get_base_dir()
	var textures := {}
	for entry in PARTS:
		var part: String = entry[0]
		if not rig_pivots.has(part):
			if part in OPTIONAL:
				continue
			push_error("%s: no pivot for %s" % [rig_path, part])
			return false
		var texture := load("%s/%s.png" % [dir, part]) as Texture2D
		if texture == null:
			push_error("%s: missing part %s.png" % [rig_path, part])
			return false
		textures[part] = texture
	feet = _vec(rig.feet)
	scale = Vector2.ONE / pixels_per_unit
	
	# Parents first; the draw order comes from each part's place in PARTS instead.
	while joints.size() < textures.size():
		for z in PARTS.size():
			var part: String = PARTS[z][0]
			var parent_name: String = PARTS[z][1]
			if not textures.has(part) or joints.has(part) or (parent_name != "" and not joints.has(parent_name)):
				continue
			var pivot := _vec(rig_pivots[part])
			var joint := Node2D.new()
			joint.name = part
			joint.position = pivot - (feet if parent_name == "" else _vec(rig_pivots[parent_name]))
			(self if parent_name == "" else joints[parent_name]).add_child(joint)
			var art := Sprite2D.new()
			art.texture = textures[part]
			art.centered = false
			art.offset = -pivot
			# Below zero, so held items and effects on the fighter draw over the body.
			art.z_index = z - PARTS.size()
			joint.add_child(art)
			joints[part] = joint

	for key: String in rig.get("points", {}):
		points[key] = _vec(rig.points[key])
	for part: String in textures:
		pivots[part] = _vec(rig_pivots[part])

	# Setup hand anchor on the front hand/fist
	if points.has("hand_front"):
		hand_anchor = Node2D.new()
		hand_anchor.name = "HandFront"
		if joints.has("hand_front"):
			hand_anchor.position = points.hand_front - pivots.hand_front
			hand_anchor.scale = Vector2.ONE * pixels_per_unit
			joints.hand_front.add_child(hand_anchor)
		elif joints.has("arm_front_lower"):
			hand_anchor.position = points.hand_front - pivots.arm_front_lower
			hand_anchor.rotation = hand_anchor.position.angle()
			hand_anchor.scale = Vector2.ONE * pixels_per_unit
			joints.arm_front_lower.add_child(hand_anchor)

	return true


## Lays the aim over the current clip: both arms reach for the gun, the front fist on
## `fist` (rig space, art px) and the back hand `back_hand_lead` art px from it along the item.
## The legs keep playing the clip.
func apply_aim(aim_angle: float, fist: Vector2, is_crouching := false, back_hand_lead := Vector2(BACK_HAND_LEAD, 0.0)) -> void:
	var lean := CROUCH_LEAN if is_crouching else 0.0
	joints.torso.rotation = aim_angle * AIM_TORSO_SHARE + lean
	joints.head.rotation = aim_angle * AIM_HEAD_SHARE - lean
	_reach("front", fist)
	_reach("back", fist + back_hand_lead.rotated(aim_angle))


## Bends one arm so its hand point lands on `target` (rig space, art px), or as near as the
## arm reaches. The elbow bends towards the floor when aiming ahead.
func _reach(side: String, target: Vector2) -> void:
	var upper_name := "arm_%s_upper" % side
	var lower_name := "arm_%s_lower" % side
	var hand_name := "hand_%s" % side
	var upper: Node2D = joints[upper_name]
	var lower: Node2D = joints[lower_name]
	if joints.has(hand_name):
		joints[hand_name].rotation = 0.0
	var elbow_rest: Vector2 = pivots[lower_name] - pivots[upper_name]
	var hand_rest: Vector2 = points[hand_name] - pivots[lower_name]
	var upper_length := elbow_rest.length()
	var lower_length := hand_rest.length()
	var to_target: Vector2 = (upper.get_parent() as Node2D).to_local(to_global(target)) - upper.position
	var distance := clampf(to_target.length(), absf(upper_length - lower_length) + 0.01, upper_length + lower_length - 0.01)
	var bend := acos(clampf((upper_length * upper_length + distance * distance - lower_length * lower_length) / (2.0 * upper_length * distance), -1.0, 1.0))
	var upper_angle := to_target.angle() + bend
	var elbow := Vector2.from_angle(upper_angle) * upper_length
	var hand := Vector2.from_angle(to_target.angle()) * distance
	upper.rotation = wrapf(upper_angle - elbow_rest.angle(), -PI, PI)
	lower.rotation = wrapf((hand - elbow).angle() - hand_rest.angle() - upper.rotation, -PI, PI)


## Resets all joints to their standing rest pose angles.
func reset_pose() -> void:
	for joint: Node2D in joints.values():
		joint.rotation = 0.0


## Hip to floor in art pixels: animations scale their body offsets by it, so the same
## clip fits a short and a tall character.
func leg_length() -> float:
	return feet.y - pivots.leg_front_upper.y


static func _vec(value: Array) -> Vector2:
	return Vector2(value[0], value[1])
