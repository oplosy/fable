class_name FighterController
extends Node

## Drives a Fighter. The base class is idle; subclasses fill the intent in poll()
## (local keyboard, bot, remote player).

var move := 0.0 ## -1 left .. 1 right
var aim := 0.0 ## -1 up .. 1 down
var jump := false ## Pressed this physics frame.
var attack := false ## Pressed this physics frame.
var attack_held := false


## Called by the Fighter at the start of each physics frame.
func poll() -> void:
	pass
