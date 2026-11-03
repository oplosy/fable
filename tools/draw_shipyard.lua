-- Draws the Shipyard map pixel by pixel at 1 art px per world px (640x360), after the
-- user's reference picture (art/shipyard/reference.png, used only for layout and colour).
-- Writes the layered source art/shipyard/shipyard.aseprite, the flattened background
-- assets/arenas/shipyard/background.png and the barrel sprites in assets/props/.
-- The floors, ladders and barrels sit where tools/make_shipyard.py puts their collision
-- (it writes art/shipyard/layout.json, read here). Run make_shipyard.py, which runs this.
--
--   aseprite -b --script-param root=<project> --script tools/draw_shipyard.lua

local root = app.params.root or "."
local W, H = 640, 360

local function read_json(path)
	local file = assert(io.open(path, "r"))
	local text = file:read("a")
	file:close()
	return json.decode(text)
end

local layout = read_json(root .. "/art/shipyard/layout.json")

-- Palette, after the reference: night sky, dark steel, rusty red hull, white bridge.
local function hex(s)
	return app.pixelColor.rgba(tonumber(s:sub(2, 3), 16), tonumber(s:sub(4, 5), 16), tonumber(s:sub(6, 7), 16), 255)
end

local C = {
	ink = hex("#08090c"),
	sky0 = hex("#121a2a"), sky1 = hex("#172236"), sky2 = hex("#1d2b43"), sky3 = hex("#253852"), sky4 = hex("#2e4462"), sky5 = hex("#365072"),
	cloud = hex("#0f1624"), cloud_lip = hex("#1b273d"),
	rain = hex("#4a5f80"),
	city = hex("#22314b"), city_lit = hex("#3a5070"), city_far = hex("#2a3c5a"),
	steel0 = hex("#111317"), steel1 = hex("#1a1d23"), steel2 = hex("#25292f"), steel3 = hex("#33373f"), steel4 = hex("#474c55"), steel5 = hex("#5f646d"),
	wall0 = hex("#14171d"), wall1 = hex("#1b1f27"), wall2 = hex("#232832"), wall3 = hex("#2c323d"), wall4 = hex("#363d4a"),
	yellow = hex("#d1a024"), yellow_dk = hex("#8a6614"), stripe_k = hex("#15161a"),
	water0 = hex("#06080d"), water1 = hex("#0d131d"), water2 = hex("#1a2738"),
	red_ink = hex("#2a0c0c"), red0 = hex("#4e1714"), red1 = hex("#6a201c"), red2 = hex("#8a2b24"), red3 = hex("#a6392e"), red4 = hex("#c24d3c"),
	rust = hex("#6b3e2c"),
	grey0 = hex("#3e4248"), grey1 = hex("#585d65"), grey2 = hex("#7a7f87"), grey3 = hex("#9a9fa6"), grey4 = hex("#b9bdc2"),
	cab0 = hex("#24211d"), cab1 = hex("#302c27"), cab2 = hex("#3d3832"), cab3 = hex("#4b453d"), cab4 = hex("#5c554b"),
	beam0 = hex("#3a1513"), beam1 = hex("#5a201c"), beam2 = hex("#7a2e26"),
	white0 = hex("#6c6c6a"), white1 = hex("#93938f"), white2 = hex("#b6b6b0"), white3 = hex("#d4d4cc"), white4 = hex("#ececE4"),
	glass0 = hex("#141e30"), glass1 = hex("#25395a"), glass2 = hex("#4a6a92"),
	wood0 = hex("#2e2014"), wood1 = hex("#4a321e"), wood2 = hex("#6b4a2c"), wood3 = hex("#8a6238"), wood4 = hex("#a87c4a"),
	green = hex("#4cd65c"), lamp = hex("#fff2c0"), lamp_dim = hex("#c8b878"),
	gas_y = hex("#c8a020"), gas_y_dk = hex("#7a6014"), gas_r = hex("#b03428"), gas_r_dk = hex("#6a1e18"),
	sack0 = hex("#4a463c"), sack1 = hex("#6a6454"), sack2 = hex("#857e6a"),
	puddle = hex("#2a4a6a"), puddle_hi = hex("#4a7aa0"),
	machine0 = hex("#3a3e44"), machine1 = hex("#5a5f66"), machine2 = hex("#7d838b"), machine3 = hex("#9ea4ab"),
	locker = hex("#6a7078"), blue = hex("#2c5a9a"),
}

-- Deterministic noise, so every run draws the same picture.
local seed = 20261103
local function rnd()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function px(img, x, y, c)
	if x >= 0 and y >= 0 and x < img.width and y < img.height then
		img:drawPixel(x, y, c)
	end
end

local function rect(img, x0, y0, x1, y1, c)
	for y = math.max(y0, 0), math.min(y1, img.height - 1) do
		for x = math.max(x0, 0), math.min(x1, img.width - 1) do
			img:drawPixel(x, y, c)
		end
	end
end

local function hline(img, x0, x1, y, c) rect(img, x0, y, x1, y, c) end
local function vline(img, x, y0, y1, c) rect(img, x, y0, x, y1, c) end

local function frame(img, x0, y0, x1, y1, c)
	hline(img, x0, x1, y0, c)
	hline(img, x0, x1, y1, c)
	vline(img, x0, y0, y1, c)
	vline(img, x1, y0, y1, c)
end

local function line(img, x0, y0, x1, y1, c)
	local dx, dy = math.abs(x1 - x0), -math.abs(y1 - y0)
	local sx, sy = x0 < x1 and 1 or -1, y0 < y1 and 1 or -1
	local err = dx + dy
	while true do
		px(img, x0, y0, c)
		if x0 == x1 and y0 == y1 then break end
		local e2 = 2 * err
		if e2 >= dy then err = err + dy; x0 = x0 + sx end
		if e2 <= dx then err = err + dx; y0 = y0 + sy end
	end
end

-- Checkerboard of `c` over a rectangle: the pixel-art blend between two tones.
local function dither(img, x0, y0, x1, y1, c, phase)
	for y = y0, y1 do
		for x = x0, x1 do
			if (x + y + (phase or 0)) % 2 == 0 then px(img, x, y, c) end
		end
	end
end

local function disc(img, cx, cy, r, c)
	for y = -r, r do
		for x = -r, r do
			if x * x + y * y <= r * r + r then px(img, cx + x, cy + y, c) end
		end
	end
end

-- Even-odd scanline fill of a polygon given as {x, y, x, y, ...}.
local function polygon(img, pts, c)
	local n = #pts // 2
	local top, bottom = math.huge, -math.huge
	for i = 1, n do
		top = math.min(top, pts[2 * i]); bottom = math.max(bottom, pts[2 * i])
	end
	for y = math.floor(top), math.ceil(bottom) do
		local cy = y + 0.5
		local xs = {}
		for i = 1, n do
			local ax, ay = pts[2 * i - 1], pts[2 * i]
			local j = i % n + 1
			local bx, by = pts[2 * j - 1], pts[2 * j]
			if (ay <= cy and by > cy) or (by <= cy and ay > cy) then
				xs[#xs + 1] = ax + (cy - ay) / (by - ay) * (bx - ax)
			end
		end
		table.sort(xs)
		for k = 1, #xs - 1, 2 do
			for x = math.floor(xs[k] + 0.5), math.floor(xs[k + 1] - 0.5) do px(img, x, y, c) end
		end
	end
end

-- 1 px outline on the outside of everything opaque in `img` that is `c_in`-coloured or not.
local function outline(img, c)
	local solid = {}
	for y = 0, img.height - 1 do
		for x = 0, img.width - 1 do
			if app.pixelColor.rgbaA(img:getPixel(x, y)) > 0 then solid[y * img.width + x] = true end
		end
	end
	for y = 0, img.height - 1 do
		for x = 0, img.width - 1 do
			if not solid[y * img.width + x] then
				for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local nx, ny = x + d[1], y + d[2]
					if nx >= 0 and ny >= 0 and nx < img.width and ny < img.height and solid[ny * img.width + nx] then
						img:drawPixel(x, y, c)
						break
					end
				end
			end
		end
	end
end

-- Props --------------------------------------------------------------------------------

-- A steel ladder as wide as Ladder.WIDTH, `x` its middle, from `top` down to `bottom`.
local function ladder(img, x, top, bottom)
	vline(img, x - 5, top, bottom - 1, C.ink)
	vline(img, x + 4, top, bottom - 1, C.ink)
	vline(img, x - 4, top, bottom - 1, C.steel4)
	vline(img, x + 3, top, bottom - 1, C.steel3)
	for y = top + 2, bottom - 2, 4 do
		hline(img, x - 3, x + 2, y, C.steel5)
		hline(img, x - 3, x + 2, y + 1, C.ink)
	end
end

-- A railing standing on `y`: posts every 8 px, a top and a middle rail.
local function railing(img, x0, x1, y, hi, lo)
	hline(img, x0, x1, y - 7, hi)
	hline(img, x0, x1, y - 6, lo)
	hline(img, x0, x1, y - 4, lo)
	for x = x0, x1, 8 do vline(img, x, y - 7, y - 1, lo) end
end

local function crate(img, x0, bottom, w, h)
	local x1, y0, y1 = x0 + w - 1, bottom - h, bottom - 1
	rect(img, x0, y0, x1, y1, C.wood2)
	frame(img, x0, y0, x1, y1, C.wood0)
	frame(img, x0 + 1, y0 + 1, x1 - 1, y1 - 1, C.wood3)
	hline(img, x0 + 1, x1 - 1, y0 + 1, C.wood4)
	line(img, x0 + 2, y1 - 2, x1 - 2, y0 + 2, C.wood1)
	line(img, x0 + 3, y1 - 2, x1 - 2, y0 + 3, C.wood3)
	for x = x0 + 1, x1 - 1 do px(img, x, y1 - 1, C.wood1) end
end

local function gas_bottle(img, x, bottom, h, body, dark)
	rect(img, x, bottom - h + 3, x + 4, bottom - 1, body)
	vline(img, x + 3, bottom - h + 4, bottom - 1, dark)
	vline(img, x + 1, bottom - h + 4, bottom - 3, C.lamp_dim)
	rect(img, x + 1, bottom - h + 1, x + 3, bottom - h + 2, dark)
	px(img, x + 2, bottom - h, C.steel4)
	frame(img, x - 1, bottom - h + 2, x + 5, bottom, C.ink)
end

local function pipe_h(img, x0, x1, y)
	hline(img, x0, x1, y - 1, C.ink)
	hline(img, x0, x1, y, C.steel4)
	hline(img, x0, x1, y + 1, C.steel3)
	hline(img, x0, x1, y + 2, C.steel2)
	hline(img, x0, x1, y + 3, C.ink)
end

local function pipe_v(img, x, y0, y1)
	vline(img, x - 1, y0, y1, C.ink)
	vline(img, x, y0, y1, C.steel4)
	vline(img, x + 1, y0, y1, C.steel3)
	vline(img, x + 2, y0, y1, C.ink)
end

-- A steel lattice column: two rails and X braces in square bays.
local function lattice(img, x0, y0, x1, y1, c, hi)
	local bay = x1 - x0
	vline(img, x0, y0, y1, c); vline(img, x1, y0, y1, c)
	vline(img, x0 + 1, y0, y1, hi); vline(img, x1 - 1, y0, y1, hi)
	for y = y0, y1, bay do
		hline(img, x0, x1, y, c)
		line(img, x0 + 1, y, x1 - 1, math.min(y + bay, y1), c)
		line(img, x1 - 1, y, x0 + 1, math.min(y + bay, y1), c)
	end
end

local function lamp_post(img, x, bottom, top, light_to)
	vline(img, x, top, bottom - 1, C.steel3)
	vline(img, x + 1, top, bottom - 1, C.ink)
	hline(img, x - 3, x + 1, top, C.steel3)
	rect(img, x - 6, top, x - 2, top + 2, C.steel2)
	hline(img, x - 6, x - 2, top + 3, C.lamp)
	-- A cone of light down to `light_to`: everything inside a step brighter, its rim dithered.
	for y = top + 4, light_to do
		local spread = (y - top) // 3
		for xx = x - 4 - spread, x - 4 + spread do
			local rim = math.abs(xx - (x - 4)) >= spread - 1
			if xx >= 0 and xx < img.width and (not rim or (xx + y) % 2 == 0) then
				local c = img:getPixel(xx, y)
				if app.pixelColor.rgbaA(c) > 0 then
					img:drawPixel(xx, y, app.pixelColor.rgba(
						math.min(255, app.pixelColor.rgbaR(c) + 12), math.min(255, app.pixelColor.rgbaG(c) + 12),
						math.min(255, app.pixelColor.rgbaB(c) + 9), 255))
				end
			end
		end
	end
end

local function sacks(img, x0, bottom, count)
	for i = 0, count - 1 do
		local x = x0 + i * 9
		rect(img, x, bottom - 5, x + 9, bottom - 1, C.sack1)
		hline(img, x + 1, x + 8, bottom - 5, C.sack2)
		hline(img, x, x + 9, bottom - 1, C.sack0)
		frame(img, x, bottom - 6, x + 9, bottom, C.ink)
	end
	for i = 0, count - 2 do
		local x = x0 + 4 + i * 9
		rect(img, x, bottom - 10, x + 9, bottom - 6, C.sack1)
		hline(img, x + 1, x + 8, bottom - 10, C.sack2)
		frame(img, x, bottom - 11, x + 9, bottom - 6, C.ink)
	end
end

local function chain(img, x0, y0, x1, y1, sag)
	local steps = math.max(math.abs(x1 - x0), math.abs(y1 - y0))
	for i = 0, steps do
		local t = i / steps
		local x = math.floor(x0 + (x1 - x0) * t + 0.5)
		local y = math.floor(y0 + (y1 - y0) * t + sag * 4 * t * (1 - t) + 0.5)
		px(img, x, y, i % 2 == 0 and C.steel4 or C.ink)
	end
end

local function tire(img, x, y)
	disc(img, x, y, 3, C.ink)
	disc(img, x, y, 1, C.water1)
	px(img, x - 2, y - 2, C.steel3)
end

-- Layers -------------------------------------------------------------------------------

local function sky()
	local img = Image(W, H, ColorMode.RGB)
	local bands = { { 0, C.sky0 }, { 26, C.sky1 }, { 54, C.sky2 }, { 82, C.sky3 }, { 108, C.sky4 }, { 132, C.sky5 } }
	for i, band in ipairs(bands) do
		local next_y = bands[i + 1] and bands[i + 1][1] or H
		rect(img, 0, band[1], W - 1, next_y - 1, band[2])
		if bands[i + 1] then dither(img, 0, next_y - 2, W - 1, next_y - 1, bands[i + 1][2]) end
	end
	-- Heavy clouds rolling along the top, a lit lip under each.
	local x = -10
	while x < W + 10 do
		local r = 6 + math.floor(rnd() * 9)
		local cy = 6 + math.floor(rnd() * 16)
		disc(img, x, cy + 1, r, C.cloud_lip)
		disc(img, x, cy, r, C.cloud)
		x = x + r + math.floor(rnd() * 6)
	end
	for _ = 1, 9 do
		local cx, cy, r = math.floor(rnd() * W), 26 + math.floor(rnd() * 22), 4 + math.floor(rnd() * 5)
		for k = 0, 3 do
			disc(img, cx + k * r, cy + 1, r, C.sky1)
			disc(img, cx + k * r, cy, r, C.sky0)
		end
	end
	return img
end

local function skyline()
	local img = Image(W, H, ColorMode.RGB)
	-- Far city.
	local x = 0
	while x < W do
		local w = 8 + math.floor(rnd() * 22)
		local top = 100 + math.floor(rnd() * 28)
		rect(img, x, top, x + w - 1, 150, C.city)
		if rnd() < 0.4 then rect(img, x + 2, top - 6, x + 4, top - 1, C.city) end
		for wy = top + 3, 146, 4 do
			for wx = x + 2, x + w - 3, 3 do
				if rnd() < 0.12 then px(img, wx, wy, C.city_lit) end
			end
		end
		x = x + w + math.floor(rnd() * 3)
	end
	-- Far cranes against the glow.
	for _, crane in ipairs({ { 18, 62 }, { 250, 74 }, { 520, 58 } }) do
		local cx, top = crane[1], crane[2]
		lattice(img, cx, top, cx + 4, 150, C.city_far, C.city_far)
		rect(img, cx - 30, top - 2, cx + 46, top, C.city_far)
		for k = cx - 28, cx + 44, 4 do line(img, k, top - 2, k + 2, top, C.city) end
		line(img, cx + 2, top - 10, cx - 28, top - 2, C.city_far)
		line(img, cx + 2, top - 10, cx + 44, top - 2, C.city_far)
		vline(img, cx + 30, top + 1, top + 18, C.city_far)
	end
	-- Rain over the sky.
	for _ = 1, 360 do
		local rx, ry = math.floor(rnd() * W), math.floor(rnd() * 150)
		for k = 0, 3 do px(img, rx + k // 2, ry + k, C.rain) end
	end
	return img
end

local function dock()
	local img = Image(W, H, ColorMode.RGB)
	local quay = layout.quay_y
	local floor = layout.warehouse_y
	local ground = layout.ground_y
	-- Near crane towers and the hanging loads.
	lattice(img, 458, 0, 476, quay, C.steel0, C.steel2)
	rect(img, 452, 0, 482, 3, C.steel1)
	hline(img, 452, 482, 4, C.ink)
	lattice(img, 624, 0, 640, quay, C.steel0, C.steel2)
	for _, cable in ipairs({ { 371, 48 }, { 609, 40 }, { 80, 12 } }) do
		vline(img, cable[1], 0, cable[2], C.steel1)
		rect(img, cable[1] - 2, cable[2], cable[1] + 2, cable[2] + 2, C.yellow_dk)
		line(img, cable[1] + 1, cable[2] + 3, cable[1] + 2, cable[2] + 6, C.steel3)
		line(img, cable[1] + 2, cable[2] + 6, cable[1] - 1, cable[2] + 7, C.steel3)
	end
	line(img, 371, 51, 358, 60, C.steel1)
	line(img, 371, 51, 385, 60, C.steel1)
	crate(img, 357, 76, 29, 16)
	for k = 361, 383, 3 do vline(img, k, 62, 73, C.wood1) end
	vline(img, 416, 0, 26, C.steel1)
	line(img, 416, 26, 400, 38, C.steel1)
	line(img, 416, 26, 432, 38, C.steel1)
	rect(img, 398, 38, 434, 42, C.steel2)
	hline(img, 398, 434, 38, C.steel4)
	frame(img, 397, 37, 435, 43, C.ink)

	-- The dock's back wall from the upper quay down to the warehouse floor.
	rect(img, 0, quay, W - 1, floor - 1, C.wall1)
	for x = 0, W - 1, 38 do
		vline(img, x, quay + 6, floor - 1, C.wall0)
		vline(img, x + 1, quay + 6, floor - 1, C.wall2)
	end
	for y = quay + 30, floor - 1, 34 do hline(img, 0, W - 1, y, C.wall0) end
	for _ = 1, 140 do
		local sx, sy = math.floor(rnd() * W), quay + 8 + math.floor(rnd() * (floor - quay - 10))
		vline(img, sx, sy, sy + 2 + math.floor(rnd() * 8), C.wall0)
	end
	-- Quay deck along the top of the wall.
	rect(img, 0, quay, W - 1, quay + 5, C.steel2)
	hline(img, 0, W - 1, quay, C.steel4)
	hline(img, 0, W - 1, quay + 6, C.ink)
	for x = 2, W - 1, 6 do px(img, x, quay + 3, C.steel0) end
	-- Shadow under the hull.
	rect(img, 0, layout.keel_y, W - 1, layout.keel_y + 5, C.wall0)
	dither(img, 0, layout.keel_y + 6, W - 1, layout.keel_y + 9, C.wall0)
	-- Steel columns and pipes in the warehouse.
	for _, col in ipairs({ { 214, 230 }, { 330, 346 }, { 478, 494 } }) do
		lattice(img, col[1], layout.keel_y, col[2], floor - 1, C.ink, C.steel3)
	end
	pipe_h(img, 96, 410, 238)
	pipe_v(img, 260, 214, 237)
	pipe_h(img, 520, 640, 228)
	pipe_v(img, 520, 228, 260)
	chain(img, 405, layout.keel_y, 405, 246, 0)
	chain(img, 128, quay + 6, 128, 182, 0)
	-- Catwalk railing high on the west wall, and a lift door.
	railing(img, 0, 36, 196, C.steel4, C.steel2)
	hline(img, 0, 36, 196, C.steel3)
	hline(img, 0, 36, 197, C.ink)
	rect(img, 52, 252, 70, 287, C.steel2)
	frame(img, 51, 251, 71, 287, C.ink)
	vline(img, 61, 252, 287, C.ink)
	hline(img, 55, 67, 248, C.green)

	-- Warehouse floor girder.
	rect(img, 0, floor, W - 1, floor + 7, C.steel2)
	hline(img, 0, W - 1, floor, C.steel5)
	hline(img, 0, W - 1, floor + 1, C.steel3)
	hline(img, 0, W - 1, floor + 8, C.ink)
	for x = 1, W - 1, 5 do px(img, x, floor + 4, C.steel0) end
	for x = 0, 60, 8 do
		for k = 0, 3 do
			line(img, x + k, floor + 2, x + k + 3, floor + 5, C.yellow)
		end
	end

	-- Lower wall between the warehouse and the quay.
	rect(img, 0, floor + 9, W - 1, ground - 1, C.wall2)
	for y = floor + 9, ground - 1, 3 do dither(img, 0, y, W - 1, y, C.wall1, y) end
	for _ = 1, 90 do
		local sx, sy = math.floor(rnd() * W), floor + 10 + math.floor(rnd() * 30)
		vline(img, sx, sy, sy + 3 + math.floor(rnd() * 10), C.wall0)
	end
	for _, x in ipairs({ 14, 120, 178, 376, 484, 601 }) do
		rect(img, x - 5, floor + 9, x + 5, ground - 1, C.wall3)
		vline(img, x - 4, floor + 9, ground - 1, C.wall4)
		vline(img, x + 5, floor + 9, ground - 1, C.wall0)
		rect(img, x - 6, floor + 9, x + 6, floor + 12, C.steel3)
		hline(img, x - 6, x + 6, floor + 13, C.ink)
	end
	pipe_h(img, 128, 262, 318)
	pipe_v(img, 128, 318, 336)
	pipe_h(img, 300, 360, 330)
	chain(img, 232, floor + 9, 238, 330, 6)

	-- Quay at the water.
	rect(img, 0, ground, W - 1, H - 1, C.water0)
	for x = 0, W - 1, 8 do
		for k = 0, 3 do
			line(img, x + k, ground, x + k + 2, ground + 2, C.yellow)
		end
	end
	hline(img, 0, W - 1, ground + 3, C.ink)
	rect(img, 0, ground + 4, W - 1, ground + 5, C.steel1)
	rect(img, 0, ground + 6, W - 1, H - 1, C.water1)
	for _ = 1, 40 do
		local wx, wy = math.floor(rnd() * W), ground + 7 + math.floor(rnd() * 3)
		hline(img, wx, wx + 2 + math.floor(rnd() * 4), wy, C.water2)
	end
	for _, x in ipairs({ 30, 140, 236, 404, 520, 588 }) do tire(img, x, ground + 6) end

	-- Lamp posts.
	lamp_post(img, 8, quay, 76, quay - 1)
	lamp_post(img, 533, floor, 245, floor - 1)
	return img
end

local function hull_shape()
	local d, k = layout.deck_y, layout.keel_y
	return { 21, d, 600, d, 637, 74, 640, 74, 640, k - 7, 600, k, 62, k, 48, k - 12, 34, k - 44, 25, k - 80, 21, k - 100 }
end

local function ship()
	local img = Image(W, H, ColorMode.RGB)
	local d, k = layout.deck_y, layout.keel_y
	local cw, ce = layout.cabin_west, layout.cabin_east
	local upper, lower = layout.cabin_upper_y, layout.cabin_lower_y

	-- Funnel behind the bridge.
	polygon(img, { 78, 53, 82, 13, 108, 13, 112, 53 }, C.red3)
	rect(img, 80, 13, 110, 18, C.steel0)
	rect(img, 79, 30, 111, 36, C.white3)
	rect(img, 79, 42, 111, 46, C.white3)
	for y = 13, 53 do px(img, 104 + (53 - y) // 10, y, C.red1) end
	rect(img, 86, 0, 92, 12, C.steel1); rect(img, 97, 2, 103, 12, C.steel1)
	vline(img, 87, 0, 12, C.steel3); vline(img, 98, 2, 12, C.steel3)
	-- Mast.
	vline(img, 158, 0, 31, C.white2)
	vline(img, 159, 0, 31, C.white0)
	hline(img, 150, 168, 7, C.white2)
	hline(img, 152, 166, 15, C.white2)
	px(img, 167, 14, C.white3)

	-- Hull.
	local shape = hull_shape()
	polygon(img, shape, C.red2)
	-- Grey upper band, rust running from its edge.
	for y = d, d + 20 do
		for x = 0, W - 1 do
			if img:getPixel(x, y) == C.red2 then img:drawPixel(x, y, y == d + 1 and C.grey3 or (y == d + 20 and C.grey0 or C.grey2)) end
		end
	end
	for _ = 1, 70 do
		local rx = 22 + math.floor(rnd() * 616)
		local len = 2 + math.floor(rnd() * 7)
		for y = d + 14 - math.floor(rnd() * 8), d + 20 + len do
			if img:getPixel(rx, y) ~= 0 then img:drawPixel(rx, y, y <= d + 20 and C.rust or C.red1) end
		end
	end
	-- Lit top of the red, shade towards the keel, plate seams.
	for x = 0, W - 1 do
		for y = d + 21, k do
			local c = img:getPixel(x, y)
			if c == C.red2 then
				if y <= d + 22 then img:drawPixel(x, y, C.red3)
				elseif y >= k - 3 then img:drawPixel(x, y, C.red0)
				elseif y >= k - 26 and (x + y) % 2 == 0 then img:drawPixel(x, y, C.red1) end
			end
		end
	end
	for x = 44, 636, 42 do
		for y = d + 21, k - 2 do
			if img:getPixel(x, y) == C.red2 or img:getPixel(x, y) == C.red1 then img:drawPixel(x, y, C.red1) end
		end
	end
	for x = 22, 638 do
		local y = d + 52
		if img:getPixel(x, y) ~= 0 then img:drawPixel(x, y, C.red1) end
	end
	-- Light along the stern's curve.
	for y = d + 21, k - 20 do
		for x = 20, 60 do
			if img:getPixel(x, y) ~= 0 then
				img:drawPixel(x, y, C.red4); img:drawPixel(x + 1, y, C.red3)
				break
			end
		end
	end
	-- Rudder and propeller.
	polygon(img, { 22, 160, 34, 160, 36, k - 4, 24, k - 4 }, C.red1)
	vline(img, 23, 161, k - 5, C.red3)
	disc(img, 64, 188, 3, C.steel3)
	polygon(img, { 63, 172, 66, 172, 66, 186, 63, 186 }, C.steel4)
	polygon(img, { 63, 190, 66, 190, 67, 205, 62, 205 }, C.steel2)
	-- Openings in the stern and bow.
	for _, hole in ipairs({ { 101, 147, 128, 158 }, { 134, 157, 156, 176 } }) do
		rect(img, hole[1], hole[2], hole[3], hole[4], C.red_ink)
		for x = hole[1] + 4, hole[3] - 2, 5 do vline(img, x, hole[2] + 1, hole[4] - 1, C.red0) end
		hline(img, hole[1], hole[3], hole[4] + 1, C.red3)
	end
	rect(img, 494, 154, 533, 205, C.steel0)
	for x = 499, 530, 8 do vline(img, x, 155, 204, C.steel2) end
	for y = 160, 204, 11 do hline(img, 495, 532, y, C.steel2) end
	frame(img, 493, 153, 534, 206, C.red_ink)
	disc(img, 562, 199, 3, C.red_ink)
	-- Anchor at the bow.
	vline(img, 592, 104, 114, C.steel1)
	hline(img, 588, 596, 106, C.steel1)
	line(img, 586, 112, 592, 116, C.steel1)
	line(img, 598, 112, 592, 116, C.steel1)

	-- The cutaway: two decks open to the camera.
	-- Back walls: panels with seams, a dado rail and a darker skirting in each room.
	rect(img, cw, d, ce, k, C.cab2)
	for x = cw + 14, ce, 24 do
		vline(img, x, d + 6, k - 10, C.cab1)
		vline(img, x + 1, d + 6, k - 10, C.cab3)
	end
	for _, room in ipairs({ { d + 7, upper - 1 }, { upper + 5, lower - 1 } }) do
		local mid = (room[1] + room[2]) // 2 + 4
		hline(img, cw, ce, mid, C.cab1)
		hline(img, cw, ce, mid + 1, C.cab3)
		rect(img, cw, room[2] - 4, ce, room[2], C.cab1)
		dither(img, cw, room[2] - 6, ce, room[2] - 5, C.cab1)
	end
	-- Deck plate and floors.
	local function floor_beam(y0, y1)
		rect(img, cw, y0, ce, y1, C.beam1)
		hline(img, cw, ce, y0, C.beam2)
		hline(img, cw, ce, y1, C.beam0)
		for x = cw + 2, ce, 6 do px(img, x, (y0 + y1) // 2, C.beam0) end
	end
	floor_beam(d, d + 6)
	floor_beam(upper, upper + 4)
	floor_beam(lower, k)
	-- Upper deck: shelves, a dark doorway, a door with its light, pipes, lamps.
	for _, p in ipairs({ { 196, d + 7, upper - 1 }, { 262, d + 7, upper - 1 }, { 330, d + 7, k - 11 }, { 452, d + 7, upper - 1 } }) do
		vline(img, p[1], p[2], p[3], C.beam1)
		vline(img, p[1] + 1, p[2], p[3], C.beam2)
		vline(img, p[1] + 2, p[2], p[3], C.beam0)
	end
	pipe_h(img, cw + 2, ce - 2, d + 10)
	for _, s in ipairs({ 118, 128, 138 }) do
		hline(img, 172, 192, s, C.cab4)
		hline(img, 172, 192, s + 1, C.cab0)
	end
	vline(img, 172, 112, upper - 1, C.cab4)
	vline(img, 192, 112, upper - 1, C.cab4)
	rect(img, 281, 126, 312, upper - 1, C.ink)
	frame(img, 279, 124, 314, upper - 1, C.cab4)
	rect(img, 385, 131, 397, upper - 1, C.ink)
	frame(img, 384, 130, 398, upper - 1, C.cab4)
	hline(img, 388, 394, 127, C.green)
	for _, lx in ipairs({ 300, 400, 210 }) do
		hline(img, lx - 4, lx + 4, d + 7, C.lamp)
		dither(img, lx - 8, d + 8, lx + 8, d + 14, C.cab3)
	end
	-- Lower deck: seats, the engine, lockers, a door.
	for _, sx in ipairs({ 180, 196 }) do
		rect(img, sx, 190, sx + 13, lower - 1, C.machine1)
		rect(img, sx + 2, 183, sx + 11, 189, C.machine2)
		hline(img, sx + 2, sx + 11, 183, C.machine3)
		frame(img, sx - 1, 182, sx + 14, lower - 1, C.ink)
	end
	rect(img, 262, 176, 316, lower - 1, C.machine1)
	rect(img, 262, 176, 316, 180, C.machine2)
	hline(img, 262, 316, 176, C.machine3)
	rect(img, 280, 166, 286, 175, C.machine2)
	vline(img, 281, 166, 175, C.machine3)
	for x = 268, 312, 6 do vline(img, x, 183, lower - 3, C.machine0) end
	frame(img, 261, 175, 317, lower - 1, C.ink)
	frame(img, 279, 165, 287, 175, C.ink)
	pipe_v(img, 322, 168, lower - 1)
	pipe_h(img, 316, 340, 168)
	rect(img, 385, 178, 397, lower - 1, C.ink)
	frame(img, 384, 177, 398, lower - 1, C.cab4)
	hline(img, 388, 394, 174, C.green)
	for lx = 438, 460, 8 do
		rect(img, lx, 180, lx + 7, lower - 1, C.locker)
		vline(img, lx + 7, 180, lower - 1, C.machine0)
		hline(img, lx + 2, lx + 5, 184, C.machine0)
		hline(img, lx + 2, lx + 5, 186, C.machine0)
		frame(img, lx - 1, 179, lx + 8, lower - 1, C.ink)
	end
	for _, lx in ipairs({ 212, 300, 400 }) do
		hline(img, lx - 4, lx + 4, upper + 5, C.lamp)
		dither(img, lx - 8, upper + 6, lx + 8, upper + 12, C.cab3)
	end
	-- Cut edges of the hull at both ends of the cutaway.
	rect(img, cw - 5, d, cw, k, C.red1)
	vline(img, cw - 5, d, k, C.red3)
	vline(img, cw, d, k, C.red_ink)
	rect(img, ce, d, ce + 5, k, C.red1)
	vline(img, ce + 5, d, k, C.red0)
	vline(img, ce, d, k, C.red_ink)

	outline(img, C.red_ink)

	-- Deck railing along the whole ship.
	railing(img, 24, 602, d, C.grey3, C.grey1)
	for x = 602, 636 do
		local y = d - math.floor((x - 600) * 24 / 37 + 0.5)
		px(img, x, y - 7, C.grey3)
		px(img, x, y - 4, C.grey1)
		if x % 8 == 2 then vline(img, x, y - 7, y - 1, C.grey1) end
	end

	-- Deck crane at the stern and crates on deck.
	rect(img, 34, d - 10, 44, d - 1, C.grey1)
	frame(img, 33, d - 11, 45, d, C.ink)
	line(img, 40, d - 10, 26, d - 22, C.grey2)
	line(img, 41, d - 10, 27, d - 22, C.grey1)
	vline(img, 26, d - 22, d - 14, C.steel1)
	crate(img, 205, d, 22, 14)
	crate(img, 209, d - 14, 16, 10)

	-- Bridge: three white tiers.
	local function tier(x0, x1, top, bottom)
		rect(img, x0, top, x1, bottom, C.white3)
		hline(img, x0, x1, top, C.white4)
		rect(img, x1 - 3, top, x1, bottom, C.white1)
		hline(img, x0, x1, bottom, C.white0)
		frame(img, x0 - 1, top - 1, x1 + 1, bottom + 1, C.ink)
		for _ = 1, 10 do
			local sx = x0 + math.floor(rnd() * (x1 - x0))
			local sy = top + 2 + math.floor(rnd() * (bottom - top - 2))
			vline(img, sx, sy, sy + 2, C.rust)
		end
	end
	tier(79, 196, layout.balcony_y + 1, d - 1)
	tier(84, 190, layout.bridge_deck_y + 1, layout.balcony_y - 1)
	tier(135, 196, layout.roof_y + 1, layout.bridge_deck_y - 1)
	for _, wx in ipairs({ 92, 108, 160 }) do
		rect(img, wx, 80, wx + 4, 84, C.glass0)
		px(img, wx + 1, 81, C.glass2)
	end
	rect(img, 182, 82, 192, d - 1, C.red3)
	frame(img, 181, 81, 193, d - 1, C.ink)
	hline(img, 184, 190, 85, C.red1)
	rect(img, 108, 58, 115, layout.balcony_y - 1, C.red3)
	frame(img, 107, 57, 116, layout.balcony_y - 1, C.ink)
	for wx = 140, 190, 10 do
		rect(img, wx, 36, wx + 7, 43, C.glass1)
		hline(img, wx, wx + 7, 36, C.glass2)
		frame(img, wx - 1, 35, wx + 8, 44, C.ink)
	end
	-- Railings round the tiers and the stairs between them.
	railing(img, 67, 166, layout.balcony_y, C.white3, C.white1)
	hline(img, 67, 166, layout.balcony_y, C.white2)
	railing(img, 81, 190, layout.bridge_deck_y, C.white3, C.white1)
	hline(img, 81, 190, layout.bridge_deck_y, C.white2)
	railing(img, 135, 195, layout.roof_y, C.white3, C.white1)
	line(img, 128, d - 1, 146, layout.balcony_y + 1, C.white1)
	line(img, 128, d - 8, 146, layout.balcony_y - 6, C.white3)
	line(img, 132, layout.balcony_y - 1, 150, layout.bridge_deck_y + 1, C.white1)
	line(img, 132, layout.balcony_y - 8, 150, layout.bridge_deck_y - 6, C.white3)
	return img
end

-- Ladders, and the props in front of the dock: crates, gas bottles, sacks.
local function props()
	local img = Image(W, H, ColorMode.RGB)
	local floor, ground = layout.warehouse_y, layout.ground_y
	crate(img, 40, floor, 18, 16)
	crate(img, 60, floor, 14, 12)
	for k = 0, 2 do pipe_h(img, 110, 178, floor - 3 - k * 4) end
	crate(img, 240, floor, 16, 16)
	crate(img, 258, floor, 12, 12)
	crate(img, 244, floor - 16, 12, 11)
	gas_bottle(img, 356, floor, 16, C.gas_r, C.gas_r_dk)
	gas_bottle(img, 398, floor, 16, C.gas_r, C.gas_r_dk)
	crate(img, 403, floor, 16, 15)
	crate(img, 405, floor - 15, 13, 11)
	gas_bottle(img, 421, floor, 16, C.gas_r, C.gas_r_dk)
	crate(img, 456, floor, 14, 13)
	crate(img, 456, floor - 13, 14, 13)
	crate(img, 457, floor - 26, 13, 12)
	rect(img, 562, floor - 22, 600, floor - 1, C.grey1)
	hline(img, 562, 600, floor - 22, C.grey3)
	rect(img, 597, floor - 22, 600, floor - 1, C.grey0)
	frame(img, 561, floor - 23, 601, floor, C.ink)
	sacks(img, 568, floor - 22, 3)
	sacks(img, 603, floor, 3)

	crate(img, 146, ground, 22, 26)
	for k = 148, 166, 4 do hline(img, 148, 166, ground - 24 + (k - 148), C.wood1) end
	crate(img, 196, ground, 16, 15)
	crate(img, 213, ground, 16, 15)
	crate(img, 230, ground, 16, 15)
	crate(img, 205, ground - 15, 16, 14)
	line(img, 172, ground - 1, 186, ground - 14, C.wood1)
	line(img, 173, ground - 1, 187, ground - 14, C.wood3)
	line(img, 176, ground - 1, 190, ground - 14, C.wood1)
	chain(img, 30, ground - 2, 120, ground - 3, 4)
	chain(img, 340, ground - 2, 410, ground - 2, 3)
	gas_bottle(img, 476, ground, 18, C.gas_r, C.gas_r_dk)
	gas_bottle(img, 493, ground, 16, C.gas_y, C.gas_y_dk)
	gas_bottle(img, 501, ground, 16, C.gas_y, C.gas_y_dk)
	rect(img, 530, ground - 12, 562, ground - 1, C.grey1)
	hline(img, 530, 562, ground - 12, C.grey3)
	frame(img, 529, ground - 13, 563, ground, C.ink)
	sacks(img, 566, ground, 3)
	for _, p in ipairs({ { 92, 6 }, { 250, 8 }, { 380, 5 }, { 600, 9 } }) do
		hline(img, p[1], p[1] + p[2], ground - 1, C.puddle)
		px(img, p[1] + 2, ground - 1, C.puddle_hi)
	end

	for _, l in ipairs(layout.ladders) do ladder(img, l.x, l.top, l.bottom) end
	return img
end

-- Barrels: the art of scenes/props/explosive_drum.tscn and oil_drum.tscn, 12x18 like
-- their collision, origin at the bottom middle.
local function barrel(body, shade, light, rim, ink, sign)
	local img = Image(12, 18, ColorMode.RGB)
	rect(img, 1, 1, 10, 16, body)
	vline(img, 1, 2, 15, shade); vline(img, 2, 2, 15, shade)
	vline(img, 9, 2, 15, shade)
	vline(img, 4, 2, 15, light)
	hline(img, 2, 9, 1, rim)
	hline(img, 1, 10, 4, rim)
	hline(img, 1, 10, 13, rim)
	hline(img, 2, 9, 16, rim)
	if sign then
		px(img, 6, 7, C.yellow); hline(img, 5, 7, 8, C.yellow); hline(img, 4, 8, 9, C.yellow); hline(img, 4, 8, 10, C.yellow_dk)
		px(img, 6, 9, C.ink)
	end
	-- Outline with rounded corners.
	hline(img, 2, 9, 0, ink); hline(img, 2, 9, 17, ink)
	vline(img, 0, 2, 15, ink); vline(img, 11, 2, 15, ink)
	px(img, 1, 1, ink); px(img, 10, 1, ink); px(img, 1, 16, ink); px(img, 10, 16, ink)
	return img
end

local spr = Sprite(W, H, ColorMode.RGB)
local layers = { { "Sky", sky }, { "Skyline", skyline }, { "Dock", dock }, { "Ship", ship }, { "Props", props } }
for i, entry in ipairs(layers) do
	local layer = i == 1 and spr.layers[1] or spr:newLayer()
	layer.name = entry[1]
	spr:newCel(layer, 1, entry[2](), Point(0, 0))
end
spr:saveAs(root .. "/art/shipyard/shipyard.aseprite")
local flat = Image(spr.spec)
flat:drawSprite(spr, 1)
flat:saveAs(root .. "/assets/arenas/shipyard/background.png")
spr:close()

local barrels = {
	explosive_barrel = barrel(C.red3, C.red1, C.red4, C.red0, C.red_ink, true),
	plain_barrel = barrel(C.wood2, C.wood1, C.wood3, C.wood0, C.ink, false),
}
for name, img in pairs(barrels) do
	local s = Sprite(img.width, img.height, ColorMode.RGB)
	s.cels[1].image = img
	s:saveAs(root .. "/art/shipyard/" .. name .. ".aseprite")
	img:saveAs(root .. "/assets/props/" .. name .. ".png")
	s:close()
end
print("drew the Shipyard")
