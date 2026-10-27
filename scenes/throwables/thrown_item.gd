class_name ThrownItem
extends RigidBody2D

## A grenade or molotov in flight. Goes off when its fuse ends or, if it breaks on
## impact, when it first touches the world or a fighter.

var data: ThrowableData
## Seconds left on the fuse; the pin may have been pulled before the throw.
var fuse_left := 0.0
## Never hit by its own throw (it can still be caught by the blast or fire).
var thrower: Node2D

var _gone := false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_sprite.texture = data.texture
	add_to_group(Arena.BOUNDED)
	var shape := RectangleShape2D.new()
	shape.size = data.texture.get_size()
	_shape.shape = shape
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = data.bounce
	if data.breaks_on_impact:
		collision_mask = 1 | Fighter.FIGHTERS_LAYER
		contact_monitor = true
		max_contacts_reported = 1
		body_entered.connect(func(_body: Node) -> void: go_off())
	if is_instance_valid(thrower) and thrower is PhysicsBody2D:
		add_collision_exception_with(thrower)


func _physics_process(delta: float) -> void:
	if data.fuse_time <= 0.0:
		return
	fuse_left -= delta
	if fuse_left <= 0.0:
		go_off()


func go_off() -> void:
	if _gone:
		return
	_gone = true
	spawn_effect(data, get_parent(), global_position, thrower as Fighter if is_instance_valid(thrower) else null)
	queue_free()


## Spawns `data`'s effect at `at`, crediting its hits to `attacker`; deferred because
## it can be called from physics callbacks.
static func spawn_effect(data: ThrowableData, world: Node, at: Vector2, attacker: Fighter = null) -> void:
	var effect: Node2D = data.effect_scene.instantiate()
	if "attacker" in effect:
		effect.attacker = attacker
	effect.position = world.to_local(at)
	world.add_child.call_deferred(effect)
