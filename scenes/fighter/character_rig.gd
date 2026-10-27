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
	["pelvis", ""],
	["leg_front_upper", "pelvis"],
	["leg_front_lower", "leg_front_upper"],
	["torso", "pelvis"],
	["coat_tail", "pelvis"],
	["head", "torso"],
	["arm_front_upper", "torso"],
	["arm_front_lower", "arm_front_upper"],
]
## Parts a character may leave out of its rig.json.
const OPTIONAL := ["coat_back", "coat_tail"]

## Part name -> the node it rotates around its joint.
var joints := {}
## rig.json "points" (hand_front, hand_back, head_top) in art pixels on the canvas.
var points := {}


## Reads `rig_path` and builds the parts, drawn at 1/`pixels_per_unit` scale with the
## rig's feet pixel on this node's origin. Returns false (and builds nothing) when the
## rig file is broken or a part is missing.
func build(rig_path: String, pixels_per_unit: float) -> bool:
	# Some editors save JSON with a byte order mark, which the parser rejects.
	var rig: Variant = JSON.parse_string(FileAccess.get_file_as_string(rig_path).trim_prefix(char(0xFEFF)))
	if not rig is Dictionary or not rig.get("pivots") is Dictionary or not rig.get("feet") is Array:
		push_error("%s: not a valid rig file" % rig_path)
		return false
	var pivots: Dictionary = rig.pivots
	var dir := rig_path.get_base_dir()
	var textures := {}
	for entry in PARTS:
		var part: String = entry[0]
		if not pivots.has(part):
			if part in OPTIONAL:
				continue
			push_error("%s: no pivot for %s" % [rig_path, part])
			return false
		var texture := load("%s/%s.png" % [dir, part]) as Texture2D
		if texture == null:
			push_error("%s: missing part %s.png" % [rig_path, part])
			return false
		textures[part] = texture
	var feet := _vec(rig.feet)
	scale = Vector2.ONE / pixels_per_unit
	# Parents first; the draw order comes from each part's place in PARTS instead.
	while joints.size() < textures.size():
		for z in PARTS.size():
			var part: String = PARTS[z][0]
			var parent_name: String = PARTS[z][1]
			if not textures.has(part) or joints.has(part) or (parent_name != "" and not joints.has(parent_name)):
				continue
			var pivot := _vec(pivots[part])
			var joint := Node2D.new()
			joint.name = part
			joint.position = pivot - (feet if parent_name == "" else _vec(pivots[parent_name]))
			(self if parent_name == "" else joints[parent_name]).add_child(joint)
			var sprite := Sprite2D.new()
			sprite.texture = textures[part]
			sprite.centered = false
			sprite.offset = -pivot
			# Below zero, so held items and effects on the fighter draw over the body.
			sprite.z_index = z - PARTS.size()
			joint.add_child(sprite)
			joints[part] = joint
	for key: String in rig.get("points", {}):
		points[key] = _vec(rig.points[key])
	return true


static func _vec(value: Array) -> Vector2:
	return Vector2(value[0], value[1])
