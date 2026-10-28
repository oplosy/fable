class_name WeaponData
extends ItemData

## A firearm.

## Pixel of the texture where projectiles appear.
@export var muzzle := Vector2.ZERO
## Fires while the button is held instead of once per press.
@export var automatic := false
@export var fire_interval := 0.3
@export var damage := 10
## Speed (px/s) added to the hit fighter along the projectile's direction.
@export var knockback := 100.0
## Seconds each hit stuns the target. Keep it below fire_interval for automatic
## weapons, or the target can never act while under fire.
@export var hit_stun := 0.25
@export var projectile_scene: PackedScene
@export var projectile_speed := 600.0
## Shots before the weapon is empty; there are no ammo pickups.
@export var ammo := 12
## Projectiles per shot, each with its own random deviation (shotgun pellets).
@export var pellets := 1
## Distance in px a projectile flies before it disappears; the crosshair stops there too.
## Rule (user, session 4): the pistol, shotgun and SMG reach 220 (set from the user's
## sketch), a rifle is 1/0.55 of that (400) and the sniper 1/0.6 of a rifle (667).
@export var projectile_range := 1200.0
## Extra fighters a projectile passes through after the first one it hits.
@export var pierce := 0
## Hits closer than this to the muzzle knock the target down (0 never does).
@export var knockdown_range := 0.0

@export_group("Spread")
## Each shot deviates randomly by up to this many degrees either side of the aim.
@export var spread_degrees := 2.0
## Degrees added to the spread by each shot (bloom); 0 for weapons that never widen.
@export var spread_per_shot := 0.0
## Upper limit of the bloom, on top of spread_degrees.
@export var max_bloom_degrees := 0.0
## Degrees per second the bloom shrinks back.
@export var bloom_recovery := 20.0
