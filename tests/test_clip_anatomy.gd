# Run: tests/run_all.sh test_clip_anatomy
extends "res://tests/test_case.gd"

## Locomotion clips move the body like a person: knees only bend forward, soles never go
## through the floor, one foot is always on it, the hips stay over the feet, and a planted
## foot moves back at exactly the clip's reference speed, so it does not slide.

const CLIPS := ["walk", "crouch_walk"]
const SAMPLES := 48
## Art px a sole may be off (rounding, cubic easing between keys).
const SLACK := 1.0
## Art px a planted sole may slip between samples; touching down catches it mid-move.
const SLIP := 1.5


func run() -> void:
	var fighter: Fighter = load("res://scenes/fighter/fighter.tscn").instantiate()
	fighter.character = load("res://data/characters/street_brawler.tres")
	root.add_child(fighter)
	fighter.set_physics_process(false)
	await physics_frames(1)
	var animator: RigAnimator = fighter.get_node("Animator")
	animator.set_physics_process(false)
	var rig: CharacterRig = fighter.get_node("Visuals/Rig")
	var soles := {}
	for side in ["front", "back"]:
		soles[side] = _sole(rig.joints["foot_%s" % side].get_child(0))
	for clip: String in CLIPS:
		animator.play(clip)
		var length := animator.current_animation_length
		var speed: float = animator._reference_speeds[clip] * fighter.get_node("Visuals").scale.y * 3.0
		var bad := {}
		var last := {}
		for i in SAMPLES:
			animator.seek(length * i / SAMPLES, true)
			var on_floor := false
			var ankles := []
			for side in ["front", "back"]:
				var hip := _at(rig, "leg_%s_upper" % side, Vector2.ZERO)
				var knee := _at(rig, "leg_%s_lower" % side, Vector2.ZERO)
				var sole := []
				for point: Vector2 in soles[side]:
					sole.append(_at(rig, "foot_%s" % side, point))
				var ankle := _at(rig, "foot_%s" % side, Vector2.ZERO)
				var lowest: float = sole.reduce(func(low: float, p: Vector2) -> float: return maxf(low, p.y), -INF)
				var thigh := ankle - hip
				# Facing right, the knee sits on the forward side of the hip-ankle line.
				if thigh.x * (knee - hip).y - thigh.y * (knee - hip).x > SLACK * thigh.length():
					bad["a %s knee bends backwards" % side] = true
				if lowest > SLACK:
					bad["the %s sole goes through the floor" % side] = true
				var grounded := lowest > -SLACK
				on_floor = on_floor or grounded
				# The sole point touching the floor must not slip; a rolling foot touches with
				# another point next time, so the same point is followed.
				if grounded and last.get(side) != null:
					var moved: float = sole[last[side][0]].x - last[side][1]
					if absf(moved + speed * length / SAMPLES) > SLIP:
						bad["the planted %s foot slides" % side] = true
				var touching := 0
				for k in sole.size():
					if sole[k].y > sole[touching].y:
						touching = k
				last[side] = [touching, sole[touching].x] if grounded else null
				ankles.append(ankle.x)
			if not on_floor:
				bad["both feet leave the floor"] = true
			var hips := (_at(rig, "leg_front_upper", Vector2.ZERO).x + _at(rig, "leg_back_upper", Vector2.ZERO).x) / 2.0
			if hips < ankles.min() - 6.0 or hips > ankles.max() + 6.0:
				bad["the hips are not over the feet"] = true
		check(bad.is_empty(), "%s moves like a person%s" % [clip, (": " + ", ".join(bad.keys())) if bad else ""])


## Rig-space position (art px, feet at the origin) of `point` on a part's canvas, or of
## its pivot for Vector2.ZERO.
func _at(rig: CharacterRig, part: String, point: Vector2) -> Vector2:
	var joint: Node2D = rig.joints[part]
	if point == Vector2.ZERO:
		return rig.to_local(joint.global_position)
	var sprite: Sprite2D = joint.get_child(0)
	return rig.to_local(sprite.to_global(point + sprite.offset))


## Canvas points along the bottom of a foot's sole: its lowest three opaque rows.
func _sole(sprite: Sprite2D) -> Array:
	var image := sprite.texture.get_image()
	var bottom := image.get_used_rect().end.y
	var points := []
	for y in range(bottom - 3, bottom):
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				points.append(Vector2(x + 0.5, y + 1.0))
	return points

