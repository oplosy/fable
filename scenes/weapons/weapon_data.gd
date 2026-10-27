class_name WeaponData
extends Resource

@export var display_name := ""
@export var texture: Texture2D
## Pixel of the texture held by the hand.
@export var grip := Vector2.ZERO
## Pixel of the texture where projectiles appear.
@export var muzzle := Vector2.ZERO
## Fires while the button is held instead of once per press.
@export var automatic := false
@export var fire_interval := 0.3
@export var damage := 10
## Speed (px/s) added to the hit fighter along the projectile's direction.
@export var knockback := 100.0
@export var projectile_scene: PackedScene
@export var projectile_speed := 600.0
## Shots before the weapon is empty; there are no ammo pickups.
@export var ammo := 12

@export_group("Spread")
## Each shot deviates randomly by up to this many degrees either side of the aim.
@export var spread_degrees := 2.0
## Degrees added to the spread by each shot (bloom); 0 for weapons that never widen.
@export var spread_per_shot := 0.0
## Upper limit of the bloom, on top of spread_degrees.
@export var max_bloom_degrees := 0.0
## Degrees per second the bloom shrinks back.
@export var bloom_recovery := 20.0
