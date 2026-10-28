-- Draws the art of the Docks arena, a harbour at sunset: the tile atlas (concrete quay,
-- steel catwalks, shipping containers, crates, warehouse wall), props (ladder, barrels,
-- lamp, bollard) and the background (sky, sun, city, cranes, sea).
-- Everything is 3x art (48 px per 16 px tile). Writes each sheet's source to art/docks/
-- and its PNG to assets/arenas/docks/. Fixed seed, so every run draws the same pixels.
-- Run from the project folder:
--   "C:\Program Files\Aseprite\Aseprite.exe" -b --script tools/draw_docks.lua

local OUT = "assets/arenas/docks/"
local SOURCE = "art/docks/"
local T = 48

local function C(r, g, b, a) return app.pixelColor.rgba(r, g, b, a or 255) end
local function c(t, a) return C(t[1], t[2], t[3], a) end
local CLEAR = C(0, 0, 0, 0)

local seed = 7
local function rnd()
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed / 2147483648
end

local BAYER = {{0, 8, 2, 10}, {12, 4, 14, 6}, {3, 11, 1, 9}, {15, 7, 13, 5}}
-- True on a share `t` (0..1) of pixels, in an even ordered pattern.
local function dither(x, y, t) return t > (BAYER[y % 4 + 1][x % 4 + 1] + 0.5) / 16 end

local function lerp(a, b, t)
  return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t}
end

local function new_image(w, h)
  local img = Image(w, h, ColorMode.RGB)
  img:clear(CLEAR)
  return img
end

local function px(img, x, y, col)
  if x >= 0 and y >= 0 and x < img.width and y < img.height then img:drawPixel(x, y, col) end
end

local function rect(img, x, y, w, h, col)
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do px(img, xx, yy, col) end
  end
end

-- A thick straight line of round dots.
local function line(img, x0, y0, x1, y1, r, col)
  local steps = math.max(math.abs(x1 - x0), math.abs(y1 - y0), 1)
  for i = 0, steps do
    local x, y = x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps
    for dy = -r, r do
      for dx = -r, r do
        if dx * dx + dy * dy <= r * r + r then px(img, math.floor(x + dx + 0.5), math.floor(y + dy + 0.5), col) end
      end
    end
  end
end

-- Saves the image as an .aseprite source and the PNG the game loads.
local function save(img, name)
  local sprite = Sprite(img.width, img.height, ColorMode.RGB)
  sprite:newCel(sprite.layers[1], sprite.frames[1], img, Point(0, 0))
  sprite.layers[1].name = name
  sprite:saveAs(SOURCE .. name .. ".aseprite")
  sprite:close()
  img:saveAs(OUT .. name .. ".png")
end

-- Palettes: outline, shadow, base, light. The sun sets on the right, so tops and
-- right-facing sides catch a warm rim light.
local RIM = {240, 170, 118}
local CONCRETE = {{38, 32, 50}, {70, 62, 84}, {100, 92, 108}, {136, 124, 132}}
local STEEL = {{30, 30, 48}, {58, 60, 84}, {88, 92, 118}, {150, 150, 172}}
local REDC = {{60, 18, 22}, {118, 36, 34}, {168, 56, 46}, {212, 96, 70}}
local BLUEC = {{16, 28, 58}, {34, 62, 108}, {52, 96, 150}, {96, 146, 196}}
local GREENC = {{18, 40, 30}, {38, 82, 58}, {62, 122, 82}, {108, 166, 110}}
local WOOD = {{58, 34, 24}, {106, 64, 38}, {150, 98, 56}, {194, 138, 80}}
local WALL = {{22, 18, 34}, {42, 38, 58}, {60, 56, 80}, {86, 80, 106}}
local RUST = {132, 72, 44}

---------------------------------------------------------------- tiles

-- Concrete quay: block seams, speckles; `top` adds the slab, `left`/`right` the side faces.
local function quay(img, ox, oy, top, left, right)
  for y = 0, T - 1 do
    for x = 0, T - 1 do
      local col = CONCRETE[3]
      local band = y // 16
      if y % 16 == 15 or (x + band * 24) % 48 == 0 then
        col = CONCRETE[2]
      elseif y % 16 == 0 or (x + band * 24) % 48 == 1 then
        col = CONCRETE[4]
      else
        local r = rnd()
        if r < 0.06 then col = CONCRETE[2] elseif r < 0.1 then col = CONCRETE[4] end
      end
      px(img, ox + x, oy + y, c(col))
    end
  end
  if top then
    for y = 0, 11 do
      for x = 0, T - 1 do
        local col = CONCRETE[4]
        if y < 2 then col = RIM
        elseif y >= 10 then col = CONCRETE[1]
        elseif rnd() < 0.08 then col = CONCRETE[3] end
        px(img, ox + x, oy + y, c(col))
      end
    end
    -- A worn yellow paint line along the quay.
    for x = 0, T - 1 do
      if x % 12 < 8 and rnd() > 0.15 then px(img, ox + x, oy + 5, C(214, 168, 64)) end
    end
  end
  if left then
    for y = 0, T - 1 do
      px(img, ox, oy + y, c(CONCRETE[1]))
      px(img, ox + 1, oy + y, c(CONCRETE[2]))
      px(img, ox + 2, oy + y, c(CONCRETE[2]))
    end
  end
  if right then
    for y = 0, T - 1 do
      px(img, ox + T - 1, oy + y, c(CONCRETE[1]))
      px(img, ox + T - 2, oy + y, c(RIM))
      px(img, ox + T - 3, oy + y, c(CONCRETE[4]))
    end
  end
end

-- Steel catwalk: a deck bar over a truss, see-through below the deck.
local function catwalk(img, ox, oy, left, right)
  for x = 0, T - 1 do
    px(img, ox + x, oy, c(RIM))
    px(img, ox + x, oy + 1, c(STEEL[4]))
    for y = 2, 5 do px(img, ox + x, oy + y, c(x % 6 == 0 and STEEL[2] or STEEL[3])) end
    px(img, ox + x, oy + 6, c(STEEL[1]))
    for y = 7, 16 do
      if (x + y) % 12 == 0 or (x - y) % 12 == 0 then px(img, ox + x, oy + y, c(STEEL[2])) end
    end
    px(img, ox + x, oy + 17, c(STEEL[3]))
    px(img, ox + x, oy + 18, c(STEEL[1]))
  end
  local function post(x0)
    for y = 0, 26 do
      for x = x0, x0 + 3 do
        px(img, ox + x, oy + y, c((x == x0 or x == x0 + 3) and STEEL[1] or (y < 2 and RIM or STEEL[3])))
      end
    end
  end
  if left then post(0) end
  if right then post(T - 4) end
end

-- Corrugated container wall; `top` adds the roof rail, sides add the frame and corner castings.
local function container(img, ox, oy, pal, top, left, right)
  local ribs = {4, 3, 3, 3, 2, 2, 3, 3}
  for y = 0, T - 1 do
    for x = 0, T - 1 do
      local col = pal[ribs[x % 8 + 1]]
      if rnd() < 0.012 then col = RUST end
      px(img, ox + x, oy + y, c(col))
    end
  end
  if top then
    for x = 0, T - 1 do
      px(img, ox + x, oy, c(RIM))
      px(img, ox + x, oy + 1, c(pal[4]))
      for y = 2, 4 do px(img, ox + x, oy + y, c(pal[3])) end
      px(img, ox + x, oy + 5, c(pal[1]))
    end
  end
  local function frame(x0, lit)
    for y = 0, T - 1 do
      px(img, ox + x0, oy + y, c(pal[1]))
      for x = x0 + 1, x0 + 3 do px(img, ox + x, oy + y, c(lit and pal[4] or pal[2])) end
      px(img, ox + x0 + 4, oy + y, c(pal[1]))
    end
    if top then
      rect(img, ox + x0, oy, 5, 6, c(pal[1]))
      rect(img, ox + x0 + 1, oy + 1, 3, 4, c(STEEL[2]))
      px(img, ox + x0 + 2, oy + 2, c(pal[1]))
    end
  end
  if left then frame(0, false) end
  if right then frame(T - 5, true) end
end

local function crate(img, ox, oy)
  rect(img, ox, oy, T, T, c(WOOD[1]))
  for y = 1, T - 2 do
    for x = 1, T - 2 do
      local col = WOOD[3]
      if y % 10 == 0 then col = WOOD[2] elseif y % 10 == 1 then col = WOOD[4] end
      if rnd() < 0.05 then col = WOOD[2] end
      px(img, ox + x, oy + y, c(col))
    end
  end
  -- Frame and the diagonal brace.
  for i = 1, T - 2 do
    for k = 1, 5 do
      px(img, ox + i, oy + k, c(k == 1 and RIM or WOOD[4]))
      px(img, ox + i, oy + T - 1 - k, c(WOOD[2]))
      px(img, ox + k, oy + i, c(WOOD[2]))
      px(img, ox + T - 1 - k, oy + i, c(k == 1 and RIM or WOOD[4]))
    end
  end
  for i = 6, T - 7 do
    for k = -2, 2 do px(img, ox + i + k, oy + T - 1 - i, c(k == 2 and WOOD[2] or WOOD[4])) end
  end
  for i = 0, T - 1 do
    px(img, ox + i, oy, c(WOOD[1])) px(img, ox + i, oy + T - 1, c(WOOD[1]))
    px(img, ox, oy + i, c(WOOD[1])) px(img, ox + T - 1, oy + i, c(WOOD[1]))
  end
  for _, p in ipairs({{3, 3}, {T - 4, 3}, {3, T - 4}, {T - 4, T - 4}}) do px(img, ox + p[1], oy + p[2], c(STEEL[4])) end
end

local function wall(img, ox, oy, top)
  for y = 0, T - 1 do
    for x = 0, T - 1 do
      local col = WALL[({3, 3, 4, 3, 2, 2})[x % 6 + 1]]
      if y % 48 == 30 then col = WALL[1] elseif y % 48 == 31 then col = WALL[4] end
      px(img, ox + x, oy + y, c(col))
    end
  end
  if top then
    for x = 0, T - 1 do
      px(img, ox + x, oy, c(RIM))
      for y = 1, 6 do px(img, ox + x, oy + y, c(y < 3 and WALL[4] or WALL[3])) end
      px(img, ox + x, oy + 7, c(WALL[1]))
    end
  end
end

local tiles = new_image(6 * T, 5 * T)
quay(tiles, 0, 0, true, true, false)
quay(tiles, T, 0, true, false, false)
quay(tiles, 2 * T, 0, true, false, true)
quay(tiles, 3 * T, 0, false, true, false)
quay(tiles, 4 * T, 0, false, false, false)
quay(tiles, 5 * T, 0, false, false, true)
catwalk(tiles, 0, T, true, false)
catwalk(tiles, T, T, false, false)
catwalk(tiles, 2 * T, T, false, true)
crate(tiles, 3 * T, T)
wall(tiles, 4 * T, T, true)
wall(tiles, 5 * T, T, false)
for row, pal in ipairs({REDC, BLUEC, GREENC}) do
  local oy = (row + 1) * T
  container(tiles, 0, oy, pal, true, true, false)
  container(tiles, T, oy, pal, true, false, false)
  container(tiles, 2 * T, oy, pal, true, false, true)
  container(tiles, 3 * T, oy, pal, false, true, false)
  container(tiles, 4 * T, oy, pal, false, false, false)
  container(tiles, 5 * T, oy, pal, false, false, true)
end
save(tiles, "tiles")

---------------------------------------------------------------- props

-- One ladder section: two rails and two rungs, tiled upwards.
local LADDER = {{70, 46, 20}, {160, 112, 36}, {222, 168, 58}, {250, 214, 120}}
local ladder = new_image(36, T)
for y = 0, T - 1 do
  for _, x0 in ipairs({1, 29}) do
    px(ladder, x0, y, c(LADDER[1]))
    px(ladder, x0 + 1, y, c(LADDER[2]))
    px(ladder, x0 + 2, y, c(LADDER[3]))
    px(ladder, x0 + 3, y, c(LADDER[4]))
    px(ladder, x0 + 4, y, c(LADDER[3]))
    px(ladder, x0 + 5, y, c(LADDER[1]))
  end
end
for _, y0 in ipairs({8, 32}) do
  for x = 7, 28 do
    px(ladder, x, y0, c(LADDER[4]))
    px(ladder, x, y0 + 1, c(LADDER[3]))
    px(ladder, x, y0 + 2, c(LADDER[2]))
    px(ladder, x, y0 + 3, c(LADDER[1]))
  end
end
save(ladder, "ladder")

-- An oil drum (42x57, bottom middle on the floor), lit from the right.
local function barrel(pal, explosive)
  local img = new_image(42, 57)
  local function tone(x)
    local t = (x - 3) / 35
    if t < 0.12 then return pal[2] elseif t < 0.55 then return pal[3] elseif t < 0.8 then return pal[4] elseif t < 0.9 then return RIM else return pal[3] end
  end
  for y = 6, 56 do
    for x = 3, 38 do
      local col = tone(x)
      if y == 19 or y == 40 then col = pal[1] elseif y == 20 or y == 41 then col = lerp(tone(x), {255, 255, 255}, 0.25) end
      px(img, x, y, c(col))
    end
  end
  if explosive then
    local YEL = {{90, 64, 10}, {200, 150, 30}, {240, 196, 60}, {255, 230, 130}}
    for y = 25, 35 do
      for x = 3, 38 do
        local stripe = ((x + y) // 4) % 2 == 0
        px(img, x, y, c(stripe and {30, 24, 30} or tone(x) == pal[2] and YEL[2] or YEL[3]))
      end
    end
    -- A flame mark on the band.
    for _, p in ipairs({{20, 27}, {19, 28}, {20, 28}, {21, 28}, {18, 29}, {19, 29}, {20, 29}, {21, 29}, {22, 29}, {18, 30}, {19, 30}, {21, 30}, {22, 30}, {19, 31}, {20, 31}, {21, 31}, {20, 32}}) do
      rect(img, p[1], p[2], 1, 1, C(255, 250, 230))
    end
  end
  -- Lid.
  for y = 1, 8 do
    for x = 3, 38 do
      local dx, dy = (x - 20.5) / 18, (y - 5) / 4
      if dx * dx + dy * dy <= 1 then
        local inner = dx * dx * 1.4 + dy * dy * 1.6 <= 0.6
        px(img, x, y, c(inner and pal[2] or (dy < 0 and pal[4] or pal[3])))
      end
    end
  end
  px(img, 28, 4, c(pal[1])) px(img, 29, 4, c(pal[1]))
  -- Outline.
  local copy = img:clone()
  for y = 0, 56 do
    for x = 0, 41 do
      if app.pixelColor.rgbaA(copy:getPixel(x, y)) > 0 then
        for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
          local nx, ny = x + d[1], y + d[2]
          if nx < 0 or ny < 0 or nx > 41 or ny > 56 or app.pixelColor.rgbaA(copy:getPixel(nx, ny)) == 0 then
            px(img, x, y, c(pal[1]))
          end
        end
      end
    end
  end
  return img
end
save(barrel(BLUEC, false), "barrel")
save(barrel(REDC, true), "barrel_explosive")

-- A harbour lamp post (30x150, bottom middle on the floor) and its light.
local lamp = new_image(30, 150)
rect(lamp, 9, 140, 12, 10, c(STEEL[1]))
rect(lamp, 10, 141, 10, 8, c(STEEL[2]))
rect(lamp, 13, 24, 4, 117, c(STEEL[1]))
rect(lamp, 14, 24, 2, 117, c(STEEL[2]))
for y = 24, 140 do px(lamp, 16, y, c(STEEL[3])) end
rect(lamp, 13, 18, 14, 3, c(STEEL[1]))
rect(lamp, 18, 8, 12, 4, c(STEEL[1]))
rect(lamp, 19, 12, 10, 6, C(255, 226, 150))
rect(lamp, 20, 13, 8, 3, C(255, 250, 220))
rect(lamp, 22, 4, 4, 4, c(STEEL[2]))
save(lamp, "lamp")

local glow = new_image(240, 240)
for y = 0, 239 do
  for x = 0, 239 do
    local d = math.sqrt((x - 119.5) ^ 2 + (y - 119.5) ^ 2) / 120
    local a = 0
    if d < 0.25 then a = 90 elseif d < 0.5 then a = 52 elseif d < 0.75 then a = 28 elseif d < 1 then a = 12 end
    if a > 0 then px(glow, x, y, C(255, 176, 96, a)) end
  end
end
save(glow, "glow")

local bollard = new_image(24, 27)
rect(bollard, 1, 4, 22, 6, c(STEEL[1]))
rect(bollard, 2, 5, 20, 4, c(STEEL[3]))
rect(bollard, 5, 9, 14, 18, c(STEEL[1]))
rect(bollard, 6, 9, 12, 17, c(STEEL[2]))
rect(bollard, 14, 9, 3, 17, c(STEEL[3]))
rect(bollard, 16, 5, 4, 2, c(RIM))
rect(bollard, 16, 10, 1, 15, c(RIM))
save(bollard, "bollard")

---------------------------------------------------------------- background

-- Dusk sky (tiled sideways), from night at the top to the glow over the horizon.
local SKY = {{22, 18, 48}, {44, 26, 78}, {92, 38, 100}, {160, 58, 102}, {222, 98, 86}, {248, 152, 94}, {255, 204, 132}}
local function sky_color(p, x, y)
  local levels = (#SKY - 1) * 5
  local v = p * levels
  local base = math.floor(v)
  local f = v - base
  if f > 0.6 and dither(x, y, (f - 0.6) / 0.4) then base = base + 1 end
  base = math.min(base, levels)
  local s = base / 5
  local i = math.min(math.floor(s), #SKY - 2)
  return lerp(SKY[i + 1], SKY[i + 2], s - i)
end
local sky = new_image(384, 1920)
for y = 0, 1919 do
  for x = 0, 383 do
    px(sky, x, y, c(sky_color(math.min(y / 1560, 1), x, y)))
  end
end
for _ = 1, 140 do
  local x, y = math.floor(rnd() * 384), math.floor(rnd() * 620)
  local bright = rnd() < 0.2
  px(sky, x, y, bright and C(255, 246, 220) or C(196, 176, 220))
  if bright and x > 0 and x < 383 and y > 0 then
    px(sky, x - 1, y, C(150, 120, 190)) px(sky, x + 1, y, C(150, 120, 190))
    px(sky, x, y - 1, C(150, 120, 190)) px(sky, x, y + 1, C(150, 120, 190))
  end
end
save(sky, "sky")

-- The setting sun with the classic gaps across its lower half.
local sun = new_image(432, 432)
for y = 0, 431 do
  for x = 0, 431 do
    local dx, dy = x - 215.5, y - 215.5
    if dx * dx + dy * dy <= 214 * 214 then
      local gap = false
      if dy > 30 then
        local k = math.floor((dy - 30) / 22)
        gap = (dy - 30) % 22 < 3 + k * 2
      end
      if not gap then
        local col = lerp({255, 244, 196}, {255, 132, 92}, (dy + 214) / 428)
        px(sun, x, y, c(col))
      end
    end
  end
end
save(sun, "sun")

-- Far city skyline over the sea (tiles sideways); its sea line sits at y 780.
local CITY = {86, 44, 96}
local CITY_LIT = {116, 60, 112}
local HORIZON = 780
local city = new_image(1536, 978)
local x = 0
while x < 1536 do
  local w = 30 + math.floor(rnd() * 90)
  local top = 380 + math.floor(rnd() * 330)
  if rnd() < 0.15 then top = 230 + math.floor(rnd() * 120) end
  for xx = x, math.min(x + w - 1, 1535) do
    for y = top, HORIZON - 1 do
      px(city, xx, y, c(xx >= x + w - 3 and CITY_LIT or CITY))
    end
  end
  for wy = top + 10, HORIZON - 12, 12 do
    for wx = x + 5, x + w - 8, 9 do
      if wx + 3 < 1536 and rnd() < 0.22 then
        rect(city, wx, wy, 3, 4, rnd() < 0.7 and C(255, 196, 120) or C(240, 140, 100))
      end
    end
  end
  if rnd() < 0.3 and w > 50 then
    local ax = x + w // 2
    rect(city, ax, top - 40, 2, 40, c(CITY))
    px(city, ax, top - 42, C(255, 60, 60)) px(city, ax + 1, top - 42, C(255, 60, 60))
  end
  x = x + w + math.floor(rnd() * 6)
end
-- Sea under the skyline, with the sun's glints.
for y = HORIZON, 977 do
  for xx = 0, 1535 do
    local t = (y - HORIZON) / (978 - HORIZON)
    local col = lerp({120, 60, 110}, {34, 34, 76}, t)
    if (y - HORIZON) % 6 == 0 and dither(xx, y, 0.5) then col = lerp(col, {20, 20, 50}, 0.3) end
    px(city, xx, y, c(col))
  end
end
for _ = 1, 260 do
  local gx, gy = math.floor(rnd() * 1500), HORIZON + 4 + math.floor(rnd() * 190)
  local len = 4 + math.floor(rnd() * 18)
  rect(city, gx, gy, len, 1, rnd() < 0.5 and C(252, 170, 110) or C(230, 110, 96))
end
save(city, "city")

-- Nearer silhouettes: two container cranes and a cargo ship (tiles sideways).
local DARK = c({48, 26, 66})
local DARK_RIM = c({150, 70, 96})
local cranes = new_image(2304, 978)
local function crane(cx)
  local base = 800
  -- Legs (an A-frame on each side) and the cross beams.
  line(cranes, cx - 120, base, cx - 90, 330, 6, DARK)
  line(cranes, cx - 30, base, cx - 60, 330, 6, DARK)
  line(cranes, cx + 120, base, cx + 90, 330, 6, DARK)
  line(cranes, cx + 30, base, cx + 60, 330, 6, DARK)
  rect(cranes, cx - 125, 560, 250, 12, DARK)
  rect(cranes, cx - 100, 320, 200, 18, DARK)
  -- Boom out over the water, its backstay and the cab.
  rect(cranes, cx - 260, 300, 620, 22, DARK)
  rect(cranes, cx - 260, 300, 620, 2, DARK_RIM)
  for bx = cx - 250, cx + 340, 24 do line(cranes, bx, 304, bx + 12, 320, 1, c({30, 16, 44})) end
  rect(cranes, cx - 20, 160, 40, 140, DARK)
  line(cranes, cx, 165, cx + 340, 302, 2, DARK)
  line(cranes, cx, 165, cx - 250, 302, 2, DARK)
  rect(cranes, cx + 140, 322, 44, 34, DARK)
  rect(cranes, cx + 146, 328, 32, 10, C(255, 200, 120))
  line(cranes, cx + 260, 322, cx + 260, 520, 1, DARK)
  rect(cranes, cx + 244, 520, 32, 12, DARK)
  px(cranes, cx, 156, C(255, 70, 60)) px(cranes, cx + 1, 156, C(255, 70, 60))
end
crane(420)
crane(1450)
-- Ship hull with container stacks.
rect(cranes, 1750, 690, 460, 110, DARK)
line(cranes, 2210, 690, 2250, 690, 2, DARK)
line(cranes, 2210, 800, 2250, 690, 2, DARK)
for i = 0, 7 do
  local h = 30 + ((i * 37) % 4) * 18
  rect(cranes, 1770 + i * 48, 690 - h, 44, h, DARK)
  rect(cranes, 1770 + i * 48, 690 - h, 44, 1, DARK_RIM)
end
rect(cranes, 2150, 600, 50, 90, DARK)
rect(cranes, 2158, 612, 34, 6, C(255, 200, 120))
save(cranes, "cranes")

-- Harbour water in front of everything (tiles sideways): fighters that fall in sink out of view.
local water = new_image(96, 192)
for y = 0, 191 do
  for xx = 0, 95 do
    local t = math.min(y / 150, 1)
    local band = math.floor(t * 4)
    local f = t * 4 - band
    if dither(xx, y, f) then band = band + 1 end
    local col = lerp({58, 50, 104}, {14, 16, 40}, math.min(band, 4) / 4)
    px(water, xx, y, c(col))
  end
end
for xx = 0, 95 do
  local wave = math.floor(1.5 + 1.5 * math.sin(xx / 96 * math.pi * 4))
  for y = 0, wave do px(water, xx, y, CLEAR) end
  px(water, xx, wave + 1, C(252, 196, 150))
  px(water, xx, wave + 2, C(200, 112, 112))
end
for _ = 1, 26 do
  local gx, gy = math.floor(rnd() * 84), 10 + math.floor(rnd() * 120)
  rect(water, gx, gy, 3 + math.floor(rnd() * 9), 1, gy < 60 and C(236, 128, 100) or C(110, 70, 120))
end
save(water, "water")
