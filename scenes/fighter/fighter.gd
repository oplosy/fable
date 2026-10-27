class_name Fighter
extends CharacterBody2D

const WEAPON_SCENE := preload("res://scenes/weapons/weapon.tscn")
const DROPPED_WEAPON_SCENE := preload("res://scenes/weapons/dropped_weapon.tscn")
## Physics layer bit of hittable fighters; dead or invulnerable fighters leave it.
const FIGHTERS_LAYER := 2
const PICKUPS_LAYER := 8

enum Slot { MELEE, FIREARM, THROWABLE, POWERUP }

@export var character: CharacterData
## Without one the fighter stands idle (e.g. a target dummy).
@export var controller: FighterController
@export var acceleration := 900.0
@export var friction := 1100.0
@export var aim_speed_degrees := 90.0
## Seconds a hit fighter ignores its controller.
@export var hit_stun_time := 0.25

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var facing := 1
var active_slot := Slot.MELEE
var firearm: Weapon
## Radians within the half-circle the fighter faces: 0 level, -PI/2 straight up, PI/2 straight down.
## Kept when turning around.
var aim_angle := 0.0
## From the character; a bare default class when there is none.
var fighter_class: FighterClass

var _hit_stun := 0.0
var _down_time := 0.0
var _getup_invulnerable := 0.0
var _roll_time := 0.0
var _diving := false
## The fighter whose melee hit caused the current stun; the combo breaker pushes it back.
var _stunned_by: Fighter
var _breaker_cooldown := 0.0
var _flash_tween: Tween

@onready var _visuals: Node2D = $Visuals
@onready var _placeholder: ColorRect = $Visuals/Placeholder
@onready var _hand: Marker2D = $Visuals/Hand
@onready var _attack_placeholder: ColorRect = $Visuals/AttackPlaceholder
@onready var health: Health = $Health
@onready var melee: Melee = $Melee


func _ready() -> void:
	if character:
		_placeholder.color = character.placeholder_color
	fighter_class = character.fighter_class if character and character.fighter_class else FighterClass.new()
	# Health's own _ready already ran with its default, so start it at the class's maximum.
	health.max_health = fighter_class.max_health
	health.current = health.max_health
	melee.fighter = self
	melee.fighter_class = fighter_class
	if controller == null:
		controller = FighterController.new()
	if controller.get_parent() == null:
		add_child(controller)
	health.died.connect(_on_died)


func equip_firearm(data: WeaponData) -> void:
	if firearm:
		firearm.queue_free()
	firearm = WEAPON_SCENE.instantiate()
	firearm.data = data
	_hand.add_child(firearm)
	active_slot = Slot.FIREARM


## Empty slots cannot be selected; melee (bare hands) is always available.
func select_slot(slot: Slot) -> bool:
	match slot:
		Slot.MELEE:
			pass
		Slot.FIREARM:
			if firearm == null:
				return false
		_:
			# Throwables and power-ups do not exist yet, so these slots are always empty.
			return false
	active_slot = slot
	return true


## The firearm is in hand only while standing on the floor; moving puts it away.
func is_firearm_drawn() -> bool:
	return active_slot == Slot.FIREARM and firearm != null and is_on_floor() and controller.move == 0.0 and can_act() and not is_rolling()


func is_stunned() -> bool:
	return _hit_stun > 0.0


func is_dead() -> bool:
	return health.is_dead()


func is_knocked_down() -> bool:
	return _down_time > 0.0


func is_invulnerable() -> bool:
	return (is_knocked_down() and fighter_class.downed_invulnerable) or _getup_invulnerable > 0.0 or is_rolling()


func is_rolling() -> bool:
	return _roll_time > 0.0


func is_diving() -> bool:
	return _diving


## Only a melee stun can be broken, and only once per cooldown.
func can_break_combo() -> bool:
	return is_stunned() and is_instance_valid(_stunned_by) and _breaker_cooldown <= 0.0 and not is_dead()


func is_breaker_cooling_down() -> bool:
	return _breaker_cooldown > 0.0


func can_act() -> bool:
	return not is_stunned() and not is_dead() and not is_knocked_down()


## Running is moving on the floor with the controller's run intent.
func is_running() -> bool:
	return is_on_floor() and controller.run and controller.move != 0.0


func aim_direction() -> Vector2:
	return Vector2(facing * cos(aim_angle), sin(aim_angle))


## A negative `stun` uses the fighter's default hit_stun_time.
## `knocks_down` puts the fighter on the ground instead of stunning it.
## `attacker` is the fighter behind a melee hit; its stun can be broken with the combo breaker.
func take_hit(damage: int, knockback := Vector2.ZERO, stun := -1.0, knocks_down := false, attacker: Fighter = null) -> void:
	if is_dead() or is_invulnerable():
		return
	health.take_damage(damage)
	# Knockback replaces the speed on each axis it pushes along, so repeated hits
	# (e.g. bullets on an airborne fighter, which has no air friction) never stack.
	if knockback.x != 0.0:
		velocity.x = knockback.x
	if knockback.y != 0.0:
		velocity.y = knockback.y
	melee.cancel()
	_diving = false
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visuals, "modulate", Color.WHITE, 0.15).from(Color(3, 3, 3))
	if is_dead():
		return
	# Already-downed fighters (only hittable if the class allows it) are never knocked down again.
	if knocks_down and not is_knocked_down():
		_knock_down()
	elif not is_knocked_down():
		_hit_stun = stun if stun >= 0.0 else hit_stun_time
		_stunned_by = attacker


## Ends the stun and pushes the attacker back; its combo is cancelled by the hit.
func _break_combo() -> void:
	_hit_stun = 0.0
	_breaker_cooldown = fighter_class.combo_breaker_cooldown
	_stunned_by.take_hit(0, Vector2(-_stunned_by.facing * fighter_class.combo_breaker_push, 0.0), fighter_class.combo_breaker_stun)
	_stunned_by = null


func _knock_down() -> void:
	_down_time = fighter_class.knockdown_time
	_hit_stun = 0.0
	_drop_firearm()
	_update_pose()
	_update_hittable()


## The firearm falls into the arena and the fighter is left with bare hands.
func _drop_firearm() -> void:
	if firearm == null:
		return
	var dropped: DroppedWeapon = DROPPED_WEAPON_SCENE.instantiate()
	dropped.data = firearm.data
	dropped.position = get_parent().to_local(_hand.global_position)
	dropped.linear_velocity = Vector2(-facing * 40.0, -120.0)
	# Hits arrive from physics callbacks, where bodies cannot be added directly.
	get_parent().add_child.call_deferred(dropped)
	firearm.queue_free()
	firearm = null
	if active_slot == Slot.FIREARM:
		active_slot = Slot.MELEE


## Only spawned weapons can be taken: with an empty firearm slot by walking over one,
## with a full slot by standing on one and pressing down (the old firearm drops).
func _update_pickup() -> void:
	var swapping := firearm != null and controller.down and is_on_floor() and not is_running()
	if firearm != null and not swapping:
		return
	var item := _pickup_under()
	if item == null:
		return
	_drop_firearm()
	equip_firearm(item.data)
	item.take()


func _pickup_under() -> DroppedWeapon:
	var body_shape: CollisionShape2D = $CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_shape.shape
	query.transform = body_shape.global_transform
	query.collision_mask = PICKUPS_LAYER
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		var item := result.collider as DroppedWeapon
		if item and item.pickable and not item.is_queued_for_deletion():
			return item
	return null


func _get_up() -> void:
	_down_time = 0.0
	_getup_invulnerable = fighter_class.getup_invulnerability
	_update_pose()
	_update_hittable()


## Out of the fighters layer, projectiles and melee pass over the fighter; it still collides with the world.
func _update_hittable() -> void:
	collision_layer = 0 if is_dead() or is_invulnerable() else FIGHTERS_LAYER


## Placeholder poses until animations exist: lying backwards when down or dead,
## head-first while diving, squashed while rolling.
func _update_pose() -> void:
	var lying := is_dead() or is_knocked_down()
	_visuals.rotation = -facing * PI / 2.0 if lying else (facing * PI / 2.0 if _diving else 0.0)
	_visuals.position.y = -6.0 if lying or _diving else 0.0
	_visuals.scale.y = 0.5 if is_rolling() else 1.0


func _on_died() -> void:
	_drop_firearm()
	_update_pose()
	_update_hittable()
	melee.cancel()


func _physics_process(delta: float) -> void:
	controller.poll()
	_hit_stun = maxf(_hit_stun - delta, 0.0)
	if is_knocked_down() and not is_dead():
		_down_time -= delta
		if _down_time <= 0.0:
			_get_up()
	elif _getup_invulnerable > 0.0:
		_getup_invulnerable = maxf(_getup_invulnerable - delta, 0.0)
		_update_hittable()
	if is_rolling():
		_roll_time = maxf(_roll_time - delta, 0.0)
		if not is_rolling():
			_update_hittable()
	if _diving and is_on_floor():
		_diving = false
	_breaker_cooldown = maxf(_breaker_cooldown - delta, 0.0)
	# The breaker's attack and jump presses are used up by the break.
	var broke := controller.combo_break and can_break_combo()
	if broke:
		_break_combo()
	# Dives and rolls commit the fighter until they end.
	var acting := can_act() and not is_rolling() and not _diving and not broke
	# A melee attack commits the fighter: no moving, turning, jumping or slot changes until it ends.
	var unlocked := acting and not melee.is_attacking()

	if unlocked and controller.select_slot >= 0:
		select_slot(controller.select_slot)
	if unlocked:
		_update_pickup()

	if not is_on_floor():
		velocity.y += gravity * delta

	# No steering in the air: jumps, dives and jump kicks keep their takeoff momentum.
	var direction := controller.move if unlocked and is_on_floor() else 0.0
	if direction:
		var speed := fighter_class.run_speed if controller.run else fighter_class.walk_speed
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		facing = 1 if direction > 0 else -1
		_visuals.scale.x = facing
	elif is_on_floor() and not is_rolling():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if unlocked and controller.jump and is_on_floor():
		if is_running():
			_diving = true
			velocity = Vector2(facing * fighter_class.dive_velocity.x, fighter_class.dive_velocity.y)
		else:
			# A walking jump goes straight up.
			velocity = Vector2(0.0, fighter_class.jump_velocity)
	elif unlocked and controller.down and is_running():
		_roll_time = fighter_class.roll_time
		velocity.x = facing * fighter_class.roll_speed
		_update_hittable()

	if firearm:
		var drawn := is_firearm_drawn()
		firearm.visible = drawn
		if drawn:
			aim_angle = clampf(aim_angle + controller.aim * deg_to_rad(aim_speed_degrees) * delta, -PI / 2.0, PI / 2.0)
			# Visuals are mirrored by facing, so the same local angle points into the facing half.
			_hand.rotation = aim_angle
		var wants_fire := controller.attack_held if firearm.data.automatic else controller.attack
		if drawn and wants_fire:
			# Projectiles belong to the arena, not the fighter, so they outlive it.
			firearm.try_fire(aim_direction(), get_parent(), self)

	if acting and active_slot == Slot.MELEE and controller.attack:
		melee.request_attack(not is_on_floor())
	melee.physics_update(delta)
	_update_attack_placeholder()
	_update_pose()

	move_and_slide()


## Shows the hit area while an attack can land. Replaced by attack animations later.
func _update_attack_placeholder() -> void:
	_attack_placeholder.visible = melee.is_hitting()
	var attack := melee.current_attack()
	if attack:
		# Visuals are mirrored by facing, so the facing-right offset is used as is.
		_attack_placeholder.position = attack.hitbox_offset - attack.hitbox_size / 2.0
		_attack_placeholder.size = attack.hitbox_size
