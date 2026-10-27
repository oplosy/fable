class_name Weapon
extends Node2D

var data: WeaponData
var ammo_left: int
## Extra spread in degrees from recent shots; shrinks back over time.
var bloom := 0.0
var _cooldown := 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_sprite.texture = data.texture
	_sprite.offset = -data.grip
	ammo_left = data.ammo


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	bloom = maxf(bloom - data.bloom_recovery * delta, 0.0)


func is_empty() -> bool:
	return ammo_left <= 0


## Current maximum deviation either side of the aim, in degrees.
func spread(scale := 1.0) -> float:
	return (data.spread_degrees + bloom) * scale


## Spawns a projectile into `world` along the unit vector `direction`, deviated
## randomly within the spread. `spread_scale` narrows it (e.g. crouching).
func try_fire(direction: Vector2, world: Node, shooter: Node2D, spread_scale := 1.0) -> bool:
	if _cooldown > 0.0 or is_empty():
		return false
	_cooldown = data.fire_interval
	ammo_left -= 1
	var max_deviation := deg_to_rad(spread(spread_scale))
	var shot := direction.rotated(randf_range(-max_deviation, max_deviation))
	bloom = minf(bloom + data.spread_per_shot, data.max_bloom_degrees)

	var projectile: Projectile = data.projectile_scene.instantiate()
	projectile.velocity = shot * data.projectile_speed
	projectile.rotation = shot.angle()
	projectile.damage = data.damage
	projectile.knockback = data.knockback
	projectile.shooter = shooter
	world.add_child(projectile)
	projectile.global_position = to_global(data.muzzle - data.grip)
	return true
