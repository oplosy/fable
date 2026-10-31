extends SceneTree

## Turns the Mucho Pixels character pack into FrameAnimator clips (a strip and a .json per
## clip) under assets/characters/. The pack's licence forbids redistribution, so its zip stays
## outside the repo and the output is git-ignored: run this once per checkout.
##
## <godot> --headless --path . -s res://tools/import_mucho.gd -- <path to the pack's .zip>
##
## Clips the pack lacks are built from its frames: kicks, the dive and the roll. Timings come
## from the stick figure's clip of the same name, which also lists every clip the game needs.
## Aiming bodies have no far arm: aim_arm.png, turned by the fighter, stands in for it.

const ROOT := "mp_character_animation_asset_pack_v1.0/Exported PNGs/"
## Look -> [pack folder, skin colours from light to dark].
const LOOKS := {
	"mucho_male1": ["Male/Character 1/Clothes 1/", ["e69c69", "bf6f4a", "8a4836"]],
	"mucho_female2": ["Female/Character 2/Clothes 2/", ["bf6f4a", "8a4836", "5d2c28"]],
}
const REFERENCE := "res://assets/characters/stickman/"
const ANIMS := ["idle", "walk", "run", "jump", "fall", "land", "damage", "death", "punch", "climb", "pickup_ground"]
## The pack's six punch frames, cut differently per attack (it has no other strikes). Frames 1
## and 2 are the full reach: an attack's cut shows one when its hit lands (test_combat_sync).
const PUNCHES := {
	"fast_jab_1": [1, 2, 3, 5],
	"fast_jab_2": [3, 2, 4, 5],
	"fast_jab_3": [0, 1, 2, 2, 5],
	"fast_hook": [0, 1, 2, 4, 5],
	"heavy_punch_1": [0, 1, 2, 3, 4, 5],
	"heavy_punch_2": [0, 0, 1, 2, 2, 3, 4, 5],
	"knife_stab_1": [1, 2, 3, 5],
	"knife_stab_2": [3, 2, 4, 5],
	"knife_slash": [0, 1, 2, 3, 4, 5],
	"bat_swing_1": [0, 1, 2, 3, 4, 5],
	"bat_swing_2": [5, 4, 2, 1, 3, 5],
	"bat_home_run": [0, 0, 1, 2, 2, 3, 4, 5],
}
## Art is drawn at the game's 3x so pack pixels stay sharp at the camera's art zoom.
const SCALE := 3
const OUTLINE := Color8(14, 7, 27)
## Length of a kicking leg, its shoe and its slope (one pixel up per this many along).
const LEG := 15
const SHOE := 3
const LEG_SLOPE := 5
## The aiming arm's length, and how much of it is sleeve.
const ARM := 11
const SLEEVE := 2


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var zip := ZIPReader.new()
	if args.size() != 1 or zip.open(args[0]) != OK:
		push_error("usage: -s res://tools/import_mucho.gd -- <pack zip>")
		quit(1)
		return
	var ok := true
	for look: String in LOOKS:
		ok = _build(zip, ROOT + LOOKS[look][0], LOOKS[look][1], "res://assets/characters/" + look) and ok
	zip.close()
	quit(0 if ok else 1)


func _build(zip: ZIPReader, prefix: String, skin: Array, out: String) -> bool:
	var src := {}
	for anim: String in ANIMS:
		src[anim] = _frames(zip, prefix, anim)
		if src[anim].is_empty():
			push_error("%s: no %s frames" % [prefix, anim])
			return false
	var box: Rect2i = src.idle[0].get_used_rect()
	for frame: Image in src.idle:
		box = box.merge(frame.get_used_rect())
	var feet := Vector2(box.position.x + box.size.x / 2.0, box.end.y)
	var clips := _clips(src, feet, skin)
	DirAccess.make_dir_recursive_absolute(out)
	_aim_arm(src.idle[0], feet, skin).save_png(out.path_join("aim_arm.png"))
	for file in DirAccess.get_files_at(REFERENCE):
		if file.get_extension() != "json":
			continue
		var clip := file.get_basename()
		if not clips.has(clip):
			push_error("%s: no frames for %s" % [out, clip])
			return false
		var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE + file))
		_save(clips[clip], reference, feet, out.path_join(clip))
	print("%s: feet %s" % [out, feet])
	return true


## The pack's frames of one animation, in order.
func _frames(zip: ZIPReader, prefix: String, anim: String) -> Array:
	var number := RegEx.create_from_string("_%s_(\\d+)\\.png$" % anim)
	var found := {}
	for path in zip.get_files():
		var hit := number.search(path)
		if path.begins_with(prefix) and hit:
			found[int(hit.get_string(1))] = path
	var keys := found.keys()
	keys.sort()
	var frames := []
	for key: int in keys:
		var image := Image.new()
		if image.load_png_from_buffer(zip.read_file(found[key])) != OK:
			return []
		image.convert(Image.FORMAT_RGBA8)
		frames.append(image)
	return frames


func _clips(src: Dictionary, feet: Vector2, skin: Array) -> Dictionary:
	var crouch: Image = src.pickup_ground[src.pickup_ground.size() / 2]
	var dead: Array = src.death
	var tuck := _on_ground(src.jump[0], feet)
	var kick := _kick(tuck, src.idle[0], feet)
	var tumble := [crouch]
	for quarter in range(1, 4):
		tumble.append(_on_ground(_turned(crouch, quarter), feet, true))
	var clips := {
		"idle": src.idle, "walk": src.walk, "run": src.run, "land": src.land, "climb": src.climb,
		"jump_rise": src.jump, "fall": src.fall,
		"dive": [_on_ground(_turned(src.fall[0], 1), feet, true)],
		"roll": tumble, "dive_roll": tumble,
		"crouch_idle": [crouch], "crouch_walk": [crouch],
		"heavy_kick": [tuck, kick, kick, tuck],
		"fast_jump_kick": [kick], "heavy_jump_kick": [tuck, kick, kick],
		"death_back": dead, "death_front": dead, "knockdown_back": dead, "knockdown_front": dead,
		"lying_back": [dead[-1]], "lying_front": [dead[-1]],
		"getup_back": dead.duplicate(), "getup_front": dead.duplicate(),
	}
	clips.getup_back.reverse()
	clips.getup_front.reverse()
	for clip in ["hit_front_light", "hit_front_heavy", "hit_back_light", "hit_back_heavy", "hit_air"]:
		clips[clip] = src.damage
	for clip: String in PUNCHES:
		clips[clip] = PUNCHES[clip].map(func(index: int) -> Image: return src.punch[index])
	var stand_aim := _armless(src.idle[0], feet, skin, -20, -8)
	var crouch_aim := _armless(crouch, feet, skin, -10, -5)
	for step in FrameAnimator.AIM_STEPS:
		clips["stand_aim_%d" % step] = [stand_aim]
		clips["crouch_aim_%d" % step] = [crouch_aim]
	return clips


## A copy turned `quarters` times clockwise.
func _turned(image: Image, quarters: int) -> Image:
	var turned := image.duplicate() as Image
	for i in quarters:
		turned.rotate_90(CLOCKWISE)
	return turned


## A copy moved down onto the feet line and, if asked, centred on the feet.
func _on_ground(image: Image, feet: Vector2, centre := false) -> Image:
	var used := image.get_used_rect()
	var at := Vector2i(used.position.x, int(feet.y) - used.size.y)
	if centre:
		at.x = int(feet.x) - used.size.x / 2
	var moved := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	moved.blit_rect(image, used, at)
	return moved


## `tuck` with its raised leg replaced by a straight one, in the colours of `stance`'s leg.
func _kick(tuck: Image, stance: Image, feet: Vector2) -> Image:
	var kick := tuck.duplicate() as Image
	var hip := Vector2i(feet) + Vector2i(2, -13)
	kick.fill_rect(Rect2i(hip, kick.get_size() - hip), Color.TRANSPARENT)
	var pants := stance.get_pixelv(Vector2i(feet) + Vector2i(-4, -6))
	var shoe := stance.get_pixelv(Vector2i(feet) + Vector2i(-4, -2))
	for along in LEG:
		var x := hip.x - 1 + along
		var top := hip.y - along / LEG_SLOPE
		kick.set_pixel(x, top, OUTLINE)
		kick.fill_rect(Rect2i(x, top + 1, 1, 4), shoe if along >= LEG - SHOE else pants)
		kick.set_pixel(x, top + 5, OUTLINE)
	var toe := hip.y - (LEG - 1) / LEG_SLOPE
	kick.fill_rect(Rect2i(hip.x - 1 + LEG, toe + 1, 1, 4), OUTLINE)
	return kick


## A copy without the far arm: skin at the right edge of the rows from `top` to `bottom`
## (above the feet) is peeled off and the outline closed on what is left.
func _armless(frame: Image, feet: Vector2, skin: Array, top: int, bottom: int) -> Image:
	var body := frame.duplicate() as Image
	var peeled := skin + [OUTLINE.to_html(false)]
	for y in range(int(feet.y) + top, int(feet.y) + bottom):
		var x := body.get_width() - 1
		while x >= 0 and body.get_pixel(x, y).a == 0.0:
			x -= 1
		var edge := x
		while x >= 0 and body.get_pixel(x, y).to_html(false) in peeled:
			body.set_pixel(x, y, Color.TRANSPARENT)
			x -= 1
		if x >= 0 and x < edge:
			body.set_pixel(x + 1, y, OUTLINE)
	return body


## A straight arm pointing right from the shoulder at its left edge's middle, at 3x.
func _aim_arm(stance: Image, feet: Vector2, skin: Array) -> Image:
	var arm := Image.create_empty(ARM, 5, false, Image.FORMAT_RGBA8)
	var sleeve := stance.get_pixelv(Vector2i(feet) + Vector2i(0, -18))
	var light := Color.html(skin[0])
	var shade := Color.html(skin[1])
	for x in ARM - 1:
		arm.set_pixel(x, 0, OUTLINE)
		arm.fill_rect(Rect2i(x, 1, 1, 2), sleeve if x < SLEEVE else light)
		arm.set_pixel(x, 3, sleeve.darkened(0.2) if x < SLEEVE else shade)
		arm.set_pixel(x, 4, OUTLINE)
	arm.fill_rect(Rect2i(ARM - 1, 1, 1, 3), OUTLINE)
	arm.resize(ARM * SCALE, 5 * SCALE, Image.INTERPOLATE_NEAREST)
	return arm


func _save(frames: Array, reference: Dictionary, feet: Vector2, path: String) -> void:
	var size: Vector2i = frames[0].get_size()
	var strip := Image.create_empty(size.x * frames.size(), size.y, false, Image.FORMAT_RGBA8)
	var hands := []
	for i in frames.size():
		strip.blit_rect(frames[i], Rect2i(Vector2i.ZERO, size), Vector2i(size.x * i, 0))
		var turn: Array = reference.hand_front[i * reference.hand_front.size() / frames.size()]
		hands.append(_hand(frames[i], feet, turn[2]))
	strip.resize(strip.get_width() * SCALE, strip.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	strip.save_png(path + ".png")
	var info := {
		"feet": [feet.x * SCALE, feet.y * SCALE],
		"fps": frames.size() / (reference.frames / reference.fps),
		"frames": frames.size(),
		"hand_front": hands,
		"loop": reference.loop,
		"reference_speed": reference.get("reference_speed", 0.0),
		"size": [size.x * SCALE, size.y * SCALE],
	}
	var file := FileAccess.open(path + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(info))


## The front fist in 3x art px: the furthest pixel out in the arm's height band.
func _hand(frame: Image, feet: Vector2, degrees: float) -> Array:
	for x in range(frame.get_width() - 1, -1, -1):
		for y in range(int(feet.y) - 24, int(feet.y) - 8):
			if frame.get_pixel(x, y).a > 0.0:
				return [float(x * SCALE), float(y * SCALE), degrees]
	return [(feet.x + 6.0) * SCALE, (feet.y - 12.0) * SCALE, degrees]
