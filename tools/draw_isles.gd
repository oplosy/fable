extends SceneTree

## Draws the Isles arena (scenes/arenas/isles.tscn) and the shared prop art in the cartoon
## map look (user, session 6: flat colours, thick dark outlines, rounded stones, moss caps
## with drips). Each picture is an SVG under art/ (world px), rendered at the art zoom (3x)
## to a PNG under assets/. Platform positions here must match the arena scene.
## Run: <godot> --headless --path . -s res://tools/draw_isles.gd

const W := 640.0
const H := 360.0
const ART_SCALE := 3.0
const LINE := "#1c1620"
const STROKE := 1.3
const DIRT := "#5b4434"
const STONE := "#7a5f49"
const STONE_DARK := "#43322a"
const MOSS := "#78ad45"
const MOSS_LIGHT := "#b7e06a"
const MOSS_DARK := "#4c7a2b"
const WOOD := "#9c663a"
const WOOD_DARK := "#5d3b22"
const WOOD_LIGHT := "#c48a52"
const IRON := "#4a4e5c"

var rng := RandomNumberGenerator.new()
var defs := PackedStringArray()
var body := PackedStringArray()
var clip_count := 0


func _init() -> void:
	rng.seed = 6
	draw_background()
	save("arenas/isles/background", W, H)

	draw_pit(300.0, 340.0, 300.0)
	# The hanging bridge (a one-way platform) over the pit, low enough to jump onto.
	draw_chain(300.0, 192.0, 282.0)
	draw_chain(340.0, 192.0, 282.0)
	draw_ground([Vector2(-60, 300), Vector2(302, 300), Vector2(305, 314), Vector2(300, 330),
			Vector2(304, 346), Vector2(301, H + 20), Vector2(-60, H + 20)], 300.0)
	draw_ground([Vector2(338, 300), Vector2(W + 60, 300), Vector2(W + 60, H + 20),
			Vector2(339, H + 20), Vector2(336, 346), Vector2(341, 330), Vector2(335, 314)], 300.0)
	draw_island(40, 190, 226, 34)
	draw_island(240, 400, 160, 42)
	draw_island(450, 600, 226, 34)
	draw_island(70, 170, 106, 26)
	draw_island(470, 570, 100, 26)
	draw_plank(294.0, 346.0, 282.0)
	draw_bush(20, 300, 14)
	draw_bush(250, 300, 10)
	draw_bush(600, 300, 13)
	draw_bush(380, 160, 9)
	draw_torch(140, 300)
	draw_torch(500, 300)
	draw_torch(262, 160)
	draw_torch(586, 226)
	draw_crate(228, 300, 18)
	draw_crate(246, 300, 16)
	draw_crate(236, 282, 16)
	draw_crate(612, 300, 18)
	draw_crate(372, 160, 16)
	draw_crate(70, 226, 14)
	draw_sign(272, 300, 1)
	draw_sign(368, 300, -1)
	save("arenas/isles/terrain", W, H)

	# Props are drawn with their floor point at (8, 19), the scenes' sprite offset (-8, -19).
	draw_barrel(8, 19, false)
	save("props/barrel", 16, 20)
	draw_barrel(8, 19, true)
	save("props/explosive_barrel", 16, 20)
	draw_ladder_section(8)
	save("props/ladder", 16, 7)
	quit()


## Writes the drawing so far to art/<path>.svg and assets/<path>.png, then starts a new one.
func save(path: String, w: float, h: float) -> void:
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">\n" % [w, h, w, h]
	svg += "<defs>\n%s\n</defs>\n%s\n</svg>\n" % ["\n".join(defs), "\n".join(body)]
	body.clear()
	for dir in ["res://art/", "res://assets/"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + path.get_base_dir()))
	var file := FileAccess.open("res://art/%s.svg" % path, FileAccess.WRITE)
	file.store_string(svg)
	file.close()
	var image := Image.new()
	var err := image.load_svg_from_string(svg, ART_SCALE)
	if err != OK:
		push_error("%s did not render: %s" % [path, error_string(err)])
		quit(1)
		return
	image.save_png("res://assets/%s.png" % path)
	print("Wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])


func f(v: float) -> String:
	return "%.1f" % v


func p(v: Vector2) -> String:
	return "%s,%s" % [f(v.x), f(v.y)]


## A closed outline through the midpoints of `pts`, each point a curve handle: rounded corners.
func blob(pts: Array) -> String:
	var n := pts.size()
	var d := "M %s" % p((pts[n - 1] + pts[0]) / 2.0)
	for i in n:
		d += " Q %s %s" % [p(pts[i]), p((pts[i] + pts[(i + 1) % n]) / 2.0)]
	return d + " Z"


func outlined(d: String, fill: String, width := STROKE) -> String:
	return "<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>" % [d, fill, LINE, f(width)]


func new_clip(d: String) -> String:
	clip_count += 1
	var id := "clip%d" % clip_count
	defs.append("<clipPath id=\"%s\"><path d=\"%s\"/></clipPath>" % [id, d])
	return id


func draw_background() -> void:
	defs.append("<linearGradient id=\"sky\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#202842\"/><stop offset=\"1\" stop-color=\"#46557a\"/></linearGradient>")
	defs.append("<linearGradient id=\"fog\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#6b7ea6\" stop-opacity=\"0\"/><stop offset=\"1\" stop-color=\"#6b7ea6\" stop-opacity=\"0.45\"/></linearGradient>")
	defs.append("<radialGradient id=\"glow\"><stop offset=\"0\" stop-color=\"#ffc66a\" stop-opacity=\"0.45\"/><stop offset=\"1\" stop-color=\"#ffc66a\" stop-opacity=\"0\"/></radialGradient>")
	defs.append("<radialGradient id=\"moonglow\"><stop offset=\"0\" stop-color=\"#e9e3c0\" stop-opacity=\"0.35\"/><stop offset=\"1\" stop-color=\"#e9e3c0\" stop-opacity=\"0\"/></radialGradient>")
	defs.append("<linearGradient id=\"pit\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#2a2438\"/><stop offset=\"1\" stop-color=\"#0e0b14\"/></linearGradient>")
	body.append("<rect width=\"%s\" height=\"%s\" fill=\"url(#sky)\"/>" % [f(W), f(H)])
	for i in 40:
		body.append("<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"#d6defc\" opacity=\"%s\"/>" % [
				f(rng.randf_range(0, W)), f(rng.randf_range(0, 150)), f(rng.randf_range(0.4, 0.9)), f(rng.randf_range(0.3, 0.8))])
	body.append("<circle cx=\"420\" cy=\"58\" r=\"60\" fill=\"url(#moonglow)\"/>")
	body.append("<circle cx=\"420\" cy=\"58\" r=\"20\" fill=\"#efe6c2\"/>")
	body.append("<circle cx=\"412\" cy=\"52\" r=\"4\" fill=\"#d9cfa6\"/><circle cx=\"426\" cy=\"66\" r=\"3\" fill=\"#d9cfa6\"/>")
	# Far mountains, then a nearer line of pines.
	var d := "M 0,%s" % f(H)
	var x := 0.0
	while x <= W + 40:
		d += " L %s,%s L %s,%s" % [f(x + 30), f(rng.randf_range(150, 200)), f(x + 60), f(rng.randf_range(200, 225))]
		x += 60.0
	body.append("<path d=\"%s L %s,%s Z\" fill=\"#34405e\"/>" % [d, f(W + 100), f(H)])
	body.append("<rect y=\"250\" width=\"%s\" height=\"%s\" fill=\"#2b3450\"/>" % [f(W), f(H - 250)])
	x = -10.0
	while x < W + 10:
		var h := rng.randf_range(28, 62)
		var half := h * 0.32
		body.append("<path d=\"M %s,252 L %s,%s L %s,252 Z\" fill=\"#2b3450\"/>" % [f(x - half), f(x), f(252 - h), f(x + half)])
		x += rng.randf_range(10, 22)
	body.append("<rect y=\"200\" width=\"%s\" height=\"100\" fill=\"url(#fog)\"/>" % f(W))


func draw_pit(x0: float, x1: float, top: float) -> void:
	body.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"url(#pit)\"/>" % [f(x0), f(top), f(x1 - x0), f(H - top)])
	var x := x0 + 2.0
	while x < x1 - 4:
		body.append(outlined("M %s,%s L %s,%s L %s,%s Z" % [f(x), f(H), f(x + 3), f(H - 9), f(x + 6), f(H)], "#8a8f9c", 0.9))
		x += 6.0


## Stones and a lower shadow inside `d`, then its outline drawn again on top.
func fill_rock(d: String, box: Rect2, top: float) -> void:
	body.append(outlined(d, DIRT))
	body.append("<g clip-path=\"url(#%s)\">" % new_clip(d))
	var count := int(box.get_area() / 170.0)
	var placed := []
	for i in count:
		var c := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(top + 7, box.end.y))
		var rx := rng.randf_range(2.5, 5.5)
		var ry := rx * rng.randf_range(0.5, 0.75)
		# Stones sit apart, with dirt showing between them.
		if placed.any(func(o: Vector3) -> bool: return Vector2(o.x, o.y).distance_to(c) < o.z + rx + 1.5):
			continue
		placed.append(Vector3(c.x, c.y, rx))
		body.append("<ellipse cx=\"%s\" cy=\"%s\" rx=\"%s\" ry=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"0.8\"/>" % [f(c.x), f(c.y), f(rx), f(ry), STONE, STONE_DARK])
		body.append("<ellipse cx=\"%s\" cy=\"%s\" rx=\"%s\" ry=\"%s\" fill=\"#93765d\"/>" % [f(c.x - rx * 0.25), f(c.y - ry * 0.35), f(rx * 0.45), f(ry * 0.3)])
	var shade_top := top + (box.end.y - top) * 0.55
	body.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"#0b0710\" opacity=\"0.32\"/>" % [f(box.position.x - 10), f(shade_top), f(box.size.x + 20), f(box.end.y - shade_top + 30)])
	body.append("</g>")
	body.append("<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\" stroke-linejoin=\"round\"/>" % [d, LINE, f(STROKE)])


## The moss cap on a walkable top at `y` from x0 to x1, dripping over the edge.
func draw_cap(x0: float, x1: float, y: float) -> void:
	var a := x0 - 3.0
	var b := x1 + 3.0
	var d := "M %s,%s Q %s,%s %s,%s L %s,%s Q %s,%s %s,%s L %s,%s" % [
			f(a), f(y + 1), f(a), f(y - 1.5), f(a + 3), f(y - 1.5), f(b - 3), f(y - 1.5),
			f(b), f(y - 1.5), f(b), f(y + 1), f(b), f(y + 4)]
	var x := b
	while x > a + 4:
		var seg := minf(rng.randf_range(5, 10), x - a)
		if rng.randf() < 0.55:
			d += " Q %s,%s %s,%s" % [f(x - seg / 2.0), f(y + 4 + rng.randf_range(4, 10)), f(x - seg), f(y + 4)]
		else:
			d += " L %s,%s" % [f(x - seg), f(y + 4)]
		x -= seg
	d += " L %s,%s Z" % [f(a), f(y + 4)]
	body.append(outlined(d, MOSS))
	body.append("<path d=\"M %s,%s L %s,%s\" stroke=\"%s\" stroke-width=\"1.1\" stroke-linecap=\"round\"/>" % [f(a + 2), f(y - 0.6), f(b - 2), f(y - 0.6), MOSS_LIGHT])
	x = x0 + rng.randf_range(4, 14)
	while x < x1 - 6:
		var t := "M %s,%s l 1,-3.5 l 1,2.5 l 1.2,-4.5 l 1.2,4.5 l 1,-2.5 l 1,3.5 Z" % [f(x), f(y - 1)]
		body.append(outlined(t, MOSS, 0.7))
		x += rng.randf_range(18, 40)


func draw_ground(pts: Array, top: float) -> void:
	var d := blob(pts)
	var box := Rect2(pts[0], Vector2.ZERO)
	for pt in pts:
		box = box.expand(pt)
	fill_rock(d, box, top)
	draw_cap(maxf(box.position.x, -10.0) + 3.0, minf(box.end.x, W + 10.0) - 3.0, top)


## A floating island whose walkable top is `y` from x0 to x1, hanging `depth` below.
func draw_island(x0: float, x1: float, y: float, depth: float) -> void:
	var w := x1 - x0
	var j := func(v: float) -> float: return v + rng.randf_range(-2.0, 2.0)
	var pts := [Vector2(x0, y), Vector2(x1, y), Vector2(x1 + 3, j.call(y + depth * 0.35)),
			Vector2(j.call(x1 - w * 0.12), y + depth * 0.75), Vector2(j.call(x0 + w * 0.64), y + depth * 0.95),
			Vector2(x0 + w * 0.52, y + depth * 1.3), Vector2(j.call(x0 + w * 0.38), y + depth * 0.95),
			Vector2(j.call(x0 + w * 0.12), y + depth * 0.75), Vector2(x0 - 3, j.call(y + depth * 0.35))]
	fill_rock(blob(pts), Rect2(x0 - 3, y, w + 6, depth * 1.2), y)
	draw_cap(x0, x1, y)


func draw_chain(x: float, y0: float, y1: float) -> void:
	var y := y0
	while y < y1:
		body.append("<ellipse cx=\"%s\" cy=\"%s\" rx=\"1.3\" ry=\"2.2\" fill=\"none\" stroke=\"%s\" stroke-width=\"1.6\"/>" % [f(x), f(y + 2), LINE])
		body.append("<ellipse cx=\"%s\" cy=\"%s\" rx=\"1.3\" ry=\"2.2\" fill=\"none\" stroke=\"#8a8f9c\" stroke-width=\"0.7\"/>" % [f(x), f(y + 2)])
		y += 3.6


func draw_plank(x0: float, x1: float, y: float) -> void:
	body.append(outlined("M %s,%s L %s,%s L %s,%s L %s,%s Z" % [f(x0), f(y), f(x1), f(y), f(x1 - 1), f(y + 6), f(x0 + 1), f(y + 6)], WOOD))
	body.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"1.8\" fill=\"%s\"/>" % [f(x0 + 1), f(y + 3.6), f(x1 - x0 - 2), WOOD_DARK])
	body.append("<path d=\"M %s,%s L %s,%s\" stroke=\"%s\" stroke-width=\"1\"/>" % [f(x0 + 2), f(y + 1), f(x1 - 2), f(y + 1), WOOD_LIGHT])
	var x := x0 + 9.0
	while x < x1 - 4:
		body.append("<path d=\"M %s,%s L %s,%s\" stroke=\"%s\" stroke-width=\"0.9\"/>" % [f(x), f(y), f(x), f(y + 6), LINE])
		x += 9.0


## One tile of a wooden ladder centred on `x`: a rung and the rails, 7 px tall, open at
## the top and bottom so the `Ladder` scene can repeat it any height.
func draw_ladder_section(x: float) -> void:
	body.append(outlined("M %s,2.5 L %s,2.5 L %s,4.5 L %s,4.5 Z" % [f(x - 6), f(x + 6), f(x + 6), f(x - 6)], WOOD_LIGHT, 0.9))
	for side in [-7.0, 5.0]:
		body.append("<rect x=\"%s\" y=\"0\" width=\"2.2\" height=\"7\" fill=\"%s\"/>" % [f(x + side), WOOD])
		for edge in [x + side, x + side + 2.2]:
			body.append("<path d=\"M %s,0 L %s,7\" stroke=\"%s\" stroke-width=\"1\"/>" % [f(edge), f(edge), LINE])


func draw_bush(x: float, y: float, r: float) -> void:
	var pts := []
	for i in 9:
		var a := PI + PI * i / 8.0
		var rr := r * (1.0 if i % 2 == 0 else 0.75)
		pts.append(Vector2(x + cos(a) * rr * 1.3, y + sin(a) * rr))
	pts.append(Vector2(x + r * 1.3, y + 1))
	pts.append(Vector2(x - r * 1.3, y + 1))
	body.append(outlined(blob(pts), MOSS_DARK))


func draw_torch(x: float, y: float) -> void:
	body.append("<circle cx=\"%s\" cy=\"%s\" r=\"26\" fill=\"url(#glow)\"/>" % [f(x), f(y - 28)])
	body.append(outlined("M %s,%s L %s,%s L %s,%s L %s,%s Z" % [f(x - 1.2), f(y), f(x - 1.2), f(y - 22), f(x + 1.2), f(y - 22), f(x + 1.2), f(y)], WOOD_DARK, 1.0))
	body.append(outlined("M %s,%s L %s,%s L %s,%s L %s,%s Z" % [f(x - 4), f(y - 25), f(x + 4), f(y - 25), f(x + 2.5), f(y - 21), f(x - 2.5), f(y - 21)], IRON, 1.0))
	body.append(outlined("M %s,%s Q %s,%s %s,%s Q %s,%s %s,%s Q %s,%s %s,%s Q %s,%s %s,%s Z" % [
			f(x), f(y - 37), f(x + 1), f(y - 31), f(x + 4), f(y - 29), f(x + 4), f(y - 25), f(x), f(y - 25),
			f(x - 4), f(y - 25), f(x - 4), f(y - 29), f(x - 1), f(y - 33), f(x), f(y - 37)], "#ff9d2e", 1.0))
	body.append("<path d=\"M %s,%s Q %s,%s %s,%s Q %s,%s %s,%s Z\" fill=\"#ffe27a\"/>" % [f(x), f(y - 31), f(x + 2.5), f(y - 26), f(x), f(y - 26), f(x - 2.5), f(y - 26), f(x), f(y - 31)])


## A 12x18 barrel standing on `y` (the size of the game's barrel collision).
func draw_barrel(x: float, y: float, explosive: bool) -> void:
	var d := "M %s,%s Q %s,%s %s,%s L %s,%s Q %s,%s %s,%s Z" % [
			f(x - 5), f(y), f(x - 7.5), f(y - 9), f(x - 5), f(y - 18), f(x + 5), f(y - 18), f(x + 7.5), f(y - 9), f(x + 5), f(y)]
	body.append(outlined(d, "#c4402e" if explosive else WOOD))
	body.append("<g clip-path=\"url(#%s)\">" % new_clip(d))
	body.append("<rect x=\"%s\" y=\"%s\" width=\"3\" height=\"18\" fill=\"#ffffff\" opacity=\"0.18\"/>" % [f(x - 4), f(y - 18)])
	body.append("<rect x=\"%s\" y=\"%s\" width=\"4\" height=\"18\" fill=\"#000000\" opacity=\"0.2\"/>" % [f(x + 2.5), f(y - 18)])
	for hy in [y - 4.5, y - 14.5]:
		body.append("<rect x=\"%s\" y=\"%s\" width=\"16\" height=\"2\" fill=\"%s\" stroke=\"%s\" stroke-width=\"0.6\"/>" % [f(x - 8), f(hy - 1), IRON, LINE])
	body.append("</g>")
	body.append("<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\" stroke-linejoin=\"round\"/>" % [d, LINE, f(STROKE)])
	if explosive:
		body.append(outlined("M %s,%s L %s,%s L %s,%s L %s,%s Z" % [f(x), f(y - 13), f(x + 3.5), f(y - 9.5), f(x), f(y - 6), f(x - 3.5), f(y - 9.5)], "#ffd23a", 0.8))
		body.append("<path d=\"M %s,%s L %s,%s\" stroke=\"%s\" stroke-width=\"1\" stroke-linecap=\"round\"/>" % [f(x), f(y - 11.3), f(x), f(y - 9.4), LINE])
		body.append("<circle cx=\"%s\" cy=\"%s\" r=\"0.5\" fill=\"%s\"/>" % [f(x), f(y - 7.9), LINE])


func draw_crate(x: float, y: float, s: float) -> void:
	var x0 := x - s / 2.0
	var y0 := y - s
	body.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\"1\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\"/>" % [f(x0), f(y0), f(s), f(s), WOOD_LIGHT, LINE, f(STROKE)])
	body.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"1.4\"/>" % [f(x0 + 2), f(y0 + 2), f(s - 4), f(s - 4), WOOD])
	body.append("<path d=\"M %s,%s L %s,%s\" stroke=\"%s\" stroke-width=\"1.8\"/>" % [f(x0 + 2.5), f(y - 2.5), f(x0 + s - 2.5), f(y0 + 2.5), WOOD])
	body.append("<path d=\"M %s,%s L %s,%s\" stroke=\"%s\" stroke-width=\"0.6\"/>" % [f(x0 + 2), f(y - 1.2), f(x0 + s - 1.2), f(y0 + 2), WOOD_DARK])
	body.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"#000000\" opacity=\"0.15\"/>" % [f(x0 + s * 0.7), f(y0), f(s * 0.3), f(s)])


## A wooden arrow sign; `dir` 1 points right, -1 left.
func draw_sign(x: float, y: float, dir: int) -> void:
	body.append(outlined("M %s,%s L %s,%s L %s,%s L %s,%s Z" % [f(x - 1.2), f(y), f(x - 1.2), f(y - 16), f(x + 1.2), f(y - 16), f(x + 1.2), f(y)], WOOD_DARK, 1.0))
	var tip := x + 11.0 * dir
	var back := x - 7.0 * dir
	var neck := x + 7.0 * dir
	body.append(outlined("M %s,%s L %s,%s L %s,%s L %s,%s L %s,%s Z" % [
			f(back), f(y - 19), f(neck), f(y - 19), f(tip), f(y - 15), f(neck), f(y - 11), f(back), f(y - 11)], WOOD))
	body.append("<path d=\"M %s,%s L %s,%s\" stroke=\"%s\" stroke-width=\"0.9\"/>" % [f(back + 1.5 * dir), f(y - 15), f(neck - 1.0 * dir), f(y - 15), WOOD_DARK])

