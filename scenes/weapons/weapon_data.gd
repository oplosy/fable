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
@export var projectile_scene: PackedScene
@export var projectile_speed := 600.0
