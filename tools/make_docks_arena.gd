extends SceneTree

## Builds scenes/arenas/docks.tscn, the Docks arena (a harbour at sunset), from the
## LAYOUT below, and its TileSet. Change the layout here and rerun rather than editing the
## scene by hand. Art comes from tools/draw_docks.lua.
##   <godot> --headless --path . -s res://tools/make_docks_arena.gd
##
## Layout, one character per 16 px tile:
##   #  concrete quay           W  warehouse wall        X  crate
##   R B G  shipping containers (red, blue, green)
##   =  steel catwalk: one-way, jump up through it
##   H  ladder; a run of H always has a = right above it, where the ladder ends
##   o  barrel   !  explosive barrel   L  lamp post   b  bollard (standing in the tile)
##   1 2  player spawn points   w  item spawner   s  sniper spawner
## Gaps in the quay drop into the sea, which is out of the arena's bounds.

const LAYOUT: Array[String] = [
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"                                                                                ",
	"WW                                                                            WW",
	"WW                                                                            WW",
	"WW                                                                            WW",
	"WW                                                                            WW",
	"WW                                    s                                       WW",
	"WW                               ===========                                  WW",
	"WW                                    H                                       WW",
	"WW                                    H                                       WW",
	"WW                                    H                                       WW",
	"WW                                    H                                       WW",
	"WW                  w   o             H                     !o w              WW",
	"WW      =====================         H         ===================           WW",
	"WW            H                       H             H                         WW",
	"WW            H                       H             H                         WW",
	"WW            H                       H             H                         WW",
	"WW            H                       H             H                         WW",
	"WW      X  w  H                       H !           H                         WW",
	"WW =============                 ==============     H               ========= WW",
	"WW  H                              H         H   =GGGGGG                  H   WW",
	"WW  H                              H         H   HGGGGGG                  H   WW",
	"WW  H                     w        H         H   HGGGGGG        o         H   WW",
	"WW  H                   RRRRRR     H         H   HGGGGGG       BBBBB      H X WW",
	"WW  H  1   L    b     b RRRRRRX  o!H        LH w HGGGGGG!     bBBBBBXL 2  HXX WW",
	"WW################   ################    #################   #################WW",
	"WW################   ################    #################   #################WW",
	"WW################   ################    #################   #################WW",
	"WW################   ################    #################   #################WW",
	"WW################   ################    #################   #################WW",
	"WW################   ################    #################   #################WW",
	"WW################   ################    #################   #################WW",
	"WW################   ################    #################   #################WW",
	"WW################   ################    #################   #################WW",
]

const TILE := 16
## The map art is 3x: an art tile is 48 px.
const ART_SCALE := 3
const ART := "res://assets/arenas/docks/"
const SCENE_PATH := "res://scenes/arenas/docks.tscn"
const TILESET_PATH := "res://assets/arenas/docks/tiles.tres"
## World y of the sea surface; fighters that fall in sink behind it.
const SEA_Y := 656.0

## Atlas rows of the materials laid out as 3x2 blocks: top-left, top, top-right, left, middle, right.
const BLOCKS := {"#": 0, "R": 2, "B": 3, "G": 4}
const SOLID := "#WXRBG"
## Close camera shots at zoom 3 (640x360 each): the centre of each, by name. The whole
## map (1280x720 at zoom 1.5) is a shot of its own. Ground shots frame the quay with the
## first catwalks above it; upper shots frame the catwalks, the gantries and the perch.
const SHOTS := {
	"GroundWest": Vector2(320, 540),
	"GroundMiddle": Vector2(640, 540),
	"GroundEast": Vector2(960, 540),
	"UpperWest": Vector2(320, 360),
	"UpperMiddle": Vector2(640, 330),
	"UpperEast": Vector2(960, 360),
}
const WEAPONS := ["pistol", "shotgun", "smg", "knife", "bat"]
const THROWABLES := ["grenade", "molotov"]

var _root: Arena


func _initialize() -> void:
	for row in LAYOUT:
		assert(row.length() == LAYOUT[0].length(), "every layout row has the same width")
	var size := Vector2(LAYOUT[0].length(), LAYOUT.size()) * TILE
	_root = Arena.new()
	_root.name = "Docks"
	_root.camera_limits = Rect2(Vector2.ZERO, size)
	# Room above for jumps; the bottom edge is just under the sea, so a fall kills soon.
	_root.bounds = Rect2(-64, -256, size.x + 128, size.y + 256 + 32)
	_add_background(size)
	_add(_tiles(), "Tiles")
	var props := _add(Node2D.new(), "Props")
	var spawns := _add(Node2D.new(), "SpawnPoints")
	var items := _add(Node2D.new(), "ItemSpawns")
	var sea := _repeated(load(ART + "water.png"), Rect2(0, SEA_Y, size.x, size.y - SEA_Y))
	# In front of the fighters, so they sink out of view.
	sea.z_index = 10
	_add(sea, "Sea")
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			_add_prop(LAYOUT[y][x], x, y, props, spawns, items)
	var shots := _add(Node2D.new(), "Shots")
	for shot_name: String in SHOTS:
		var shot := CameraShot.new()
		shot.position = SHOTS[shot_name]
		_add(shot, shot_name, shots)
	var camera := FollowCamera.new()
	camera.position = size / 2.0
	_add(camera, "Camera2D")
	var scene := PackedScene.new()
	scene.pack(_root)
	var error := ResourceSaver.save(scene, SCENE_PATH)
	print("saved %s: %s" % [SCENE_PATH, error_string(error)])
	_root.free()
	quit(1 if error != OK else 0)


func _add(node: Node, node_name: String, parent: Node = _root) -> Node:
	node.name = node_name
	parent.add_child(node, true)
	node.owner = _root
	return node


## A texture tiled over `area` (world px) at the 3x art scale.
func _repeated(texture: Texture2D, area: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, area.size * ART_SCALE)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.scale = Vector2.ONE / ART_SCALE
	sprite.position = area.position
	return sprite


func _art(file: String, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(ART + file)
	sprite.scale = Vector2.ONE / ART_SCALE
	sprite.position = at
	return sprite


## Sky fixed to the map; sun, city and cranes slide slower than the map as the camera
## moves, nearest fastest, for depth.
func _add_background(size: Vector2) -> void:
	var back := _add(Node2D.new(), "Background")
	back.z_index = -100
	_add(_repeated(load(ART + "sky.png"), Rect2(Vector2.ZERO, size)), "Sky", back)
	_add(_art("sun.png", Vector2(860, 380)), "Sun", _parallax(back, "SunLayer", 0.1))
	# Wide enough for any camera position, since the layers lag behind it.
	for layer: Array in [["City", "city.png", 0.35], ["Cranes", "cranes.png", 0.6]]:
		var strip := _repeated(load(ART + layer[1]), Rect2(-size.x, 330, size.x * 3.0, 326))
		_add(strip, layer[0], _parallax(back, layer[0] + "Layer", layer[2]))


func _parallax(parent: Node, node_name: String, scroll: float) -> Parallax2D:
	var parallax := Parallax2D.new()
	parallax.scroll_scale = Vector2(scroll, 1.0)
	return _add(parallax, node_name, parent)


func _tiles() -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = _tile_set()
	layer.scale = Vector2.ONE / ART_SCALE
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			var atlas := _atlas_coords(x, y)
			if atlas.x >= 0:
				layer.set_cell(Vector2i(x, y), 0, atlas)
	return layer


func _tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE) * ART_SCALE
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)
	var source := TileSetAtlasSource.new()
	source.texture = load(ART + "tiles.png")
	source.texture_region_size = tile_set.tile_size
	tile_set.add_source(source, 0)
	var half := TILE * ART_SCALE / 2.0
	for y in 5:
		for x in 6:
			var coords := Vector2i(x, y)
			source.create_tile(coords)
			var data := source.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			if y == 1 and x <= 2:
				# Catwalk: only the deck collides, and only from above.
				data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + 12), Vector2(-half, -half + 12)]))
				data.set_collision_polygon_one_way(0, 0, true)
			else:
				data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	ResourceSaver.save(tile_set, TILESET_PATH)
	return load(TILESET_PATH)


func _at(x: int, y: int) -> String:
	if y < 0 or y >= LAYOUT.size() or x < 0 or x >= LAYOUT[y].length():
		return " "
	return LAYOUT[y][x]


## The atlas tile for the layout cell, picked by its neighbours; (-1, -1) for none.
func _atlas_coords(x: int, y: int) -> Vector2i:
	var cell := _at(x, y)
	if BLOCKS.has(cell):
		var top := _at(x, y - 1) != cell
		var side := 0 if _at(x - 1, y) != cell else (2 if _at(x + 1, y) != cell else 1)
		return Vector2i(side + (0 if top else 3), BLOCKS[cell])
	match cell:
		"=":
			return Vector2i(0 if _at(x - 1, y) != "=" else (2 if _at(x + 1, y) != "=" else 1), 1)
		"X":
			return Vector2i(3, 1)
		"W":
			return Vector2i(4 if _at(x, y - 1) != "W" else 5, 1)
	return Vector2i(-1, -1)


func _add_prop(cell: String, x: int, y: int, props: Node, spawns: Node, items: Node) -> void:
	# Props stand on the bottom middle of their tile.
	var feet := Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
	match cell:
		"o", "!":
			var barrel: Node2D = load("res://scenes/props/%s.tscn" % ("barrel" if cell == "o" else "explosive_barrel")).instantiate()
			barrel.position = feet
			_add(barrel, "Barrel", props)
		"L":
			var glow := _art("glow.png", feet + Vector2(4, -46))
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			glow.material = add
			glow.z_index = 5
			_add(_art("lamp.png", feet + Vector2(0, -25)), "Lamp", props)
			_add(glow, "Glow", props)
		"b":
			_add(_art("bollard.png", feet + Vector2(0, -4.5)), "Bollard", props)
		"1", "2":
			var marker := Marker2D.new()
			marker.position = feet
			_add(marker, "P" + cell, spawns)
		"w", "s":
			var spawner := ItemSpawner.new()
			spawner.position = feet + Vector2(0, -8)
			var names: Array = ["sniper"] if cell == "s" else WEAPONS + THROWABLES
			for item: String in names:
				spawner.items.append(load(("res://data/throwables/%s.tres" if item in THROWABLES else "res://data/weapons/%s.tres") % item))
			_add(spawner, "Spawner", items)
		"H":
			if _at(x, y - 1) == "=":
				var bottom := y
				while _at(x, bottom + 1) == "H":
					bottom += 1
				var ladder: Ladder = load("res://scenes/props/ladder.tscn").instantiate()
				ladder.position = Vector2(feet.x, (bottom + 1) * TILE)
				ladder.height = (bottom + 1 - (y - 1)) * TILE
				_add(ladder, "Ladder", props)
