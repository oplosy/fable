class_name CharacterRig
extends Node2D

## A character's cutout rig (docs/CHARACTER_ANIMATION_SPEC.md): one node per body part,
## parented joint to joint, so rotating a part carries everything attached to it.
## Built from a rig.json and the part PNGs next to it. Shapes and hits never use it.

## Every part in draw order (back to front) with its parent; "" is the rig root at the feet.
const PARTS := [
	["arm_back_upper", "torso"],
	["arm_back_lower", "arm_back_upper"],
	["coat_back", "pelvis"],
	["leg_back_upper", "pelvis"],
	["leg_back_lower", "leg_back_upper"],
	["foot_back", "leg_back_lower"],
	["pelvis", ""],
	["leg_front_upper", "pelvis"],
	["leg_front_lower", "leg_front_upper"],
	["foot_front", "leg_front_lower"],
	["torso", "pelvis"],
	["coat_tail", "pelvis"],
	["head", "torso"],
	["arm_front_upper", "torso"],
	["arm_front_lower", "arm_front_upper"],
]
## Parts a character may leave out of its rig.json. Without feet, the lower legs carry them.
const OPTIONAL := ["coat_back", "coat_tail", "foot_back", "foot_front"]
## Parts that bend like cloth instead of turning stiffly.
const COATS := ["coat_back", "coat_tail"]

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
## The coat parts' meshes; RigAnimator bends them after each pose.
var coats: Array[CoatMesh] = []


## Reads `rig_path` and builds the parts, drawn at 1/`pixels_per_unit` scale with the
## rig's feet pixel on this node's origin. Returns false (and builds nothing) when the
## rig file is broken or a part is missing.
func build(rig_path: String, pixels_per_unit: float) -> bool:
	# Some editors save JSON with a byte order mark, which the parser rejects.
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
			# Coats bend like cloth; every other part is stiff.
			var art: Node2D
			if part in COATS:
				art = CoatMesh.new()
				art.texture = textures[part]
			else:
				art = Sprite2D.new()
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
	for part: String in COATS:
		if joints.has(part):
			coats.append(joints[part].get_child(0))
			coats.back().setup(self, part)
	if points.has("hand_front"):
		hand_anchor = Node2D.new()
		hand_anchor.name = "HandFront"
		hand_anchor.position = points.hand_front - pivots.arm_front_lower
		hand_anchor.rotation = hand_anchor.position.angle()
		hand_anchor.scale = Vector2.ONE * pixels_per_unit
		joints.arm_front_lower.add_child(hand_anchor)
	return true


## Hip to floor in art pixels: animations scale their body offsets by it, so the same
## clip fits a short and a tall character.
func leg_length() -> float:
	return feet.y - pivots.leg_front_upper.y


static func _vec(value: Array) -> Vector2:
	return Vector2(value[0], value[1])
