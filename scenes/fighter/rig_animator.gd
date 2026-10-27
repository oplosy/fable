class_name RigAnimator
extends AnimationPlayer

## Plays the shared keyframe clips (docs/CHARACTER_ANIMATION_SPEC.md, section 3.1) on a
## fighter's cutout rig and picks the clip from the fighter's state. Cosmetic only: hits,
## shapes and timings never read it.

const CLIPS_DIR := "res://assets/animations"
## Hip-to-floor length (art px) of the rig the clips were made on. A rig's body offsets
## and movement speeds scale by its own leg length against it, so feet stay planted on
## short and tall characters alike.
const REFERENCE_LEG_LENGTH := 40.0
## Seconds two clips cross-fade when the clip changes.
const BLEND := 0.1
## Below this horizontal speed (world px/s) a crouched fighter counts as still.
const STILL_SPEED := 5.0

var fighter: Fighter
var _rig: CharacterRig
var _leg_scale := 1.0
## Clip name -> its reference_speed (world px/s); 0 for clips that do not follow speed.
var _reference_speeds := {}
var _was_airborne := false
## Coat part -> the two bottom corners of its hem relative to its pivot, in art px.
var _hems := {}


## Loads every clip in CLIPS_DIR for this rig. Call once both are in the tree.
func setup(target: Fighter, rig: CharacterRig) -> void:
	fighter = target
	_rig = rig
	_leg_scale = rig.leg_length() / REFERENCE_LEG_LENGTH
	root_node = get_path_to(rig)
	# Played by hand in _physics_process, so the coats can be fixed after each step.
	callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for part: String in CharacterRig.OPTIONAL:
		if rig.joints.has(part):
			var sprite: Sprite2D = rig.joints[part].get_child(0)
			var used := sprite.texture.get_image().get_used_rect()
			_hems[part] = [Vector2(used.position.x, used.end.y) - rig.pivots[part], Vector2(used.end) - rig.pivots[part]]
	var library := AnimationLibrary.new()
	for file in DirAccess.get_files_at(CLIPS_DIR):
		if file.get_extension() == "json":
			var clip := _load_clip(CLIPS_DIR.path_join(file))
			if clip:
				library.add_animation(file.get_basename(), clip)
	add_animation_library("", library)


func _physics_process(delta: float) -> void:
	_choose_clip()
	advance(delta)
	_fit_coats()


func _choose_clip() -> void:
	var clip := _pick()
	var landed := _was_airborne and fighter.is_on_floor()
	_was_airborne = not fighter.is_on_floor()
	if clip == "idle":
		if landed and has_animation("land"):
			clip = "land"
		elif current_animation == "land":
			return
	if not has_animation(clip):
		clip = "idle"
		if not has_animation(clip):
			return
	var reference: float = _reference_speeds.get(clip, 0.0)
	speed_scale = absf(fighter.velocity.x) / (reference * _leg_scale) if reference > 0.0 else 1.0
	if clip != current_animation:
		play(clip, BLEND)


## A stiff coat part whose hem would go through the floor (crouching, landing) is
## squashed until it touches the floor instead, like cloth bunching up.
func _fit_coats() -> void:
	for part: String in _hems:
		var joint: Node2D = _rig.joints[part]
		joint.scale = Vector2.ONE
		# The rig's origin is the feet, so the floor is y = 0 in rig space.
		var waist := _rig.to_local(joint.global_position).y
		var squash := 1.0
		for corner: Vector2 in _hems[part]:
			# A corner's height is waist + across + down * scale.y: solve it for the floor.
			var across := _rig.to_local(joint.to_global(Vector2(corner.x, 0.0))).y - waist
			var down := _rig.to_local(joint.to_global(Vector2(0.0, corner.y))).y - waist
			if waist + across + down > 0.0 and down > 0.0:
				squash = minf(squash, (-waist - across) / down)
		joint.scale.y = clampf(squash, 0.3, 1.0)


## The clip for what the fighter is doing. States without their own clips yet show idle.
func _pick() -> String:
	match fighter.state():
		Fighter.State.WALK:
			return "walk"
		Fighter.State.RUN:
			return "run"
		Fighter.State.AIR:
			return "jump_rise" if fighter.velocity.y < 0.0 else "fall"
	# Crouching also covers aiming and cooking while crouched.
	if fighter.is_crouching():
		return "crouch_walk" if absf(fighter.velocity.x) > STILL_SPEED else "crouch_idle"
	return "idle"


func _load_clip(path: String) -> Animation:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path).trim_prefix(char(0xFEFF)))
	if not data is Dictionary or not data.get("keys") is Array or data.keys.is_empty():
		push_error("%s: not a valid animation file" % path)
		return null
	var clip := Animation.new()
	clip.length = data.get("length", 0.0)
	clip.loop_mode = Animation.LOOP_LINEAR if data.get("loop", false) else Animation.LOOP_NONE
	_reference_speeds[path.get_file().get_basename()] = float(data.get("reference_speed", 0.0))
	# Every part gets a track, so a clip resets what the previous clip turned.
	var root_track := _add_track(clip, "pelvis", "position")
	var angle_tracks := {}
	for part: String in _rig.joints:
		angle_tracks[part] = _add_track(clip, part, "rotation")
	var rest_root: Vector2 = _rig.joints.pelvis.position
	var root := Vector2.ZERO
	var angles := {}
	for key: Dictionary in data.keys:
		var t := float(key.get("t", 0.0))
		if key.has("root"):
			root = CharacterRig._vec(key.root)
		clip.track_insert_key(root_track, t, rest_root + root * _leg_scale)
		for part: String in angle_tracks:
			# A part missing from a key keeps the previous key's angle.
			angles[part] = float(key.get("angles", {}).get(part, angles.get(part, 0.0)))
			clip.track_insert_key(angle_tracks[part], t, deg_to_rad(angles[part]))
	return clip


func _add_track(clip: Animation, part: String, property: String) -> int:
	var track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, "%s:%s" % [_rig.get_path_to(_rig.joints[part]), property])
	clip.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	return track
