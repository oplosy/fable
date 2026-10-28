class_name CameraShot
extends Marker2D

## A framed view of the map, composed by the map maker: the screen centred here at one of
## FollowCamera.ZOOMS. The arena's camera cuts to the closest shot that holds every
## living fighter, so each shot should read as a finished picture at its zoom.

@export var zoom := 3.0


## The world area the shot shows on a screen of `view` pixels.
func area(view: Vector2) -> Rect2:
	var size := view / zoom
	return Rect2(global_position - size / 2.0, size)
