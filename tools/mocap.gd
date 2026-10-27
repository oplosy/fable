extends RefCounted

## Reads BVH motion capture (the CMU Graphics Lab Motion Capture Database,
## mocap.cs.cmu.edu, in Bruce Hahne's BVH conversion; files under art/mocap/) and turns a
## frame into joint positions seen from the side, so clips can copy real human motion.


## Joints (name, parent index, offset, channel names) and frames (channel values) of
## a BVH file, or an empty dictionary when it cannot be read.
static func read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("%s: cannot read" % path)
		return {}
	var words := text.replace("\t", " ").replace("\r", " ").replace("\n", " ").split(" ", false)
	var joints := []
	var stack := []
	var i := 0
	while i < words.size():
		var word := words[i]
		if word == "ROOT" or word == "JOINT":
			joints.append({"name": words[i + 1], "parent": stack.back() if stack else -1, "offset": Vector3.ZERO, "channels": []})
			stack.append(joints.size() - 1)
			i += 2
		elif word == "End":
			# An end site has an offset but no channels; only its braces matter here.
			stack.append(-1)
			i += 2
		elif word == "}":
			stack.pop_back()
			i += 1
		elif word == "OFFSET":
			if stack.back() >= 0:
				joints[stack.back()].offset = Vector3(float(words[i + 1]), float(words[i + 2]), float(words[i + 3]))
			i += 4
		elif word == "CHANNELS":
			var count := int(words[i + 1])
			joints[stack.back()].channels = words.slice(i + 2, i + 2 + count)
			i += 2 + count
		elif word == "MOTION":
			break
		else:
			i += 1
	# MOTION Frames: <n> Frame Time: <seconds> <values...>
	var frame_count := int(words[i + 2])
	var frame_time := float(words[i + 5])
	var values := words.slice(i + 6)
	var width := 0
	for joint: Dictionary in joints:
		width += joint.channels.size()
	if joints.is_empty() or values.size() < frame_count * width:
		push_error("%s: not a valid BVH file" % path)
		return {}
	var frames := []
	for f in frame_count:
		var frame := PackedFloat32Array()
		for v in width:
			frame.append(float(values[f * width + v]))
		frames.append(frame)
	return {"joints": joints, "frames": frames, "frame_time": frame_time}


## World position (BVH units, y up) of every joint in frame `f`, by joint name.
static func positions(bvh: Dictionary, f: int) -> Dictionary:
	var frame: PackedFloat32Array = bvh.frames[f]
	var bases := []
	var origins := []
	var at := {}
	var v := 0
	for joint: Dictionary in bvh.joints:
		var local := Basis.IDENTITY
		var shift := Vector3.ZERO
		# Rotations apply in the order the channels are listed.
		for channel: String in joint.channels:
			var value := frame[v]
			v += 1
			match channel:
				"Xposition": shift.x = value
				"Yposition": shift.y = value
				"Zposition": shift.z = value
				"Xrotation": local = local * Basis(Vector3.RIGHT, deg_to_rad(value))
				"Yrotation": local = local * Basis(Vector3.UP, deg_to_rad(value))
				"Zrotation": local = local * Basis(Vector3.BACK, deg_to_rad(value))
		var origin: Vector3 = joint.offset + shift
		var basis := local
		if joint.parent >= 0:
			origin = bases[joint.parent] * origin + origins[joint.parent]
			basis = bases[joint.parent] * local
		bases.append(basis)
		origins.append(origin)
		at[joint.name] = origin
	return at


## Joint positions seen from the side, walking direction `forward` (horizontal) to the
## right: x forwards, y down, in BVH units.
static func side_view(at: Dictionary, forward: Vector3) -> Dictionary:
	var flat := {}
	for name: String in at:
		var p: Vector3 = at[name]
		flat[name] = Vector2(p.dot(forward), -p.y)
	return flat
