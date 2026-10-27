class_name FighterController
extends Node

## Drives a Fighter. The base class is idle; subclasses fill the intent in poll()
## (local keyboard, bot, remote player).

var move := 0.0 ## -1 left .. 1 right
var run := false ## Move at run speed instead of walking.
var aim := 0.0 ## -1 up .. 1 down
var down := false ## Down pressed this physics frame (rolls while running).
var jump := false ## Pressed this physics frame.
var attack := false ## Pressed this physics frame.
var attack_held := false
var select_slot := -1 ## Fighter.Slot chosen this physics frame, -1 for none.


## Called by the Fighter at the start of each physics frame.
func poll() -> void:
	pass
