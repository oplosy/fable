class_name Weapon
extends Node2D

var data: WeaponData
var _cooldown := 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_sprite.texture = data.texture
	_sprite.offset = -data.grip


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


## Spawns a projectile into `world` travelling in `direction` (1 right, -1 left).
func try_fire(direction: int, world: Node) -> bool:
	if _cooldown > 0.0:
		return false
	_cooldown = data.fire_interval

	var projectile: Projectile = data.projectile_scene.instantiate()
	projectile.velocity = Vector2(direction * data.projectile_speed, 0.0)
	projectile.damage = data.damage
	world.add_child(projectile)
	projectile.global_position = to_global(data.muzzle - data.grip)
	return true
