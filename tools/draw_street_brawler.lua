-- Draws the Street Brawler, a character made for the cutout rig: strict side view, short
-- legs, big head and fists, every limb a capsule whose round ends overlap at the joints
-- (so turning a part never opens a gap), separate feet, no long stiff clothes.
-- Writes art/street_brawler.aseprite (one layer per part), the part PNGs and rig.json
-- into assets/characters/street_brawler/, and a standing preview.
-- Run from the project folder:
--   "C:\Program Files\Aseprite\Aseprite.exe" -b --script tools/draw_street_brawler.lua

local W, H = 64, 96
local OUT = "assets/characters/street_brawler/"
local SOURCE = "art/street_brawler.aseprite"

-- Rest pose joints (canvas px, pixel centres), facing right.
local J = {
  neck = {32, 34}, shoulder = {31, 39}, waist = {31, 55}, pelvis = {31, 59},
  hip = {31, 61}, knee = {32, 76}, ankle = {31, 87},
  elbow = {31, 50}, wrist = {31, 59}, fist = {32, 62},
}

local function rgb(r, g, b) return {r, g, b} end
-- Palettes: outline, shadow, base, light.
local SKIN = {rgb(92, 48, 40), rgb(200, 128, 96), rgb(236, 172, 132), rgb(252, 208, 172)}
local HAIR = {rgb(24, 20, 32), rgb(40, 36, 52), rgb(64, 58, 84), rgb(96, 88, 120)}
local SHIRT = {rgb(72, 16, 24), rgb(156, 32, 40), rgb(204, 52, 52), rgb(240, 104, 92)}
local PANTS = {rgb(20, 24, 44), rgb(40, 50, 92), rgb(58, 74, 128), rgb(84, 104, 160)}
local BOOT = {rgb(36, 22, 18), rgb(70, 42, 30), rgb(100, 62, 42), rgb(136, 90, 60)}
local WRAP = {rgb(80, 76, 72), rgb(186, 180, 170), rgb(232, 228, 218), rgb(255, 255, 250)}
local BELT = {rgb(30, 20, 16), rgb(70, 44, 30), rgb(96, 62, 40), rgb(130, 88, 58)}
local BAND = SHIRT

-- A part is a grid of palette tones (1 shadow, 2 base, 3 light) plus colour overrides.
local function new_part()
  return {tone = {}, pal = {}, color = {}}
end

local function key(x, y) return y * W + x end

-- Light comes from the upper front: the side of a shape facing (0.55, -0.83) is lit.
local LIGHT = {0.55, -0.83}
local function shade(nx, ny)
  local d = nx * LIGHT[1] + ny * LIGHT[2]
  if d > 0.45 then return 3 elseif d < -0.35 then return 1 else return 2 end
end

-- Fills a capsule from a to b with radius r (pixel centres inside), shaded as a cylinder.
local function capsule(part, a, b, r, pal)
  local ax, ay, bx, by = a[1] + 0.5, a[2] + 0.5, b[1] + 0.5, b[2] + 0.5
  local dx, dy = bx - ax, by - ay
  local len2 = dx * dx + dy * dy
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local px, py = x + 0.5, y + 0.5
      local t = len2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2)) or 0
      local cx, cy = ax + dx * t, ay + dy * t
      local ox, oy = px - cx, py - cy
      local d = math.sqrt(ox * ox + oy * oy)
      if d <= r then
        part.tone[key(x, y)] = shade(ox / r, oy / r)
        part.pal[key(x, y)] = pal
      end
    end
  end
end

-- Fills an ellipse, shaded as a ball.
local function ellipse(part, c, rx, ry, pal, keep)
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local nx, ny = (x + 0.5 - c[1] - 0.5) / rx, (y + 0.5 - c[2] - 0.5) / ry
      if nx * nx + ny * ny <= 1 and (not keep or keep(x, y)) then
        part.tone[key(x, y)] = shade(nx, ny)
        part.pal[key(x, y)] = pal
      end
    end
  end
end

-- Repaints already-filled pixels where `inside(x, y)` holds with another palette.
local function recolor(part, pal, inside)
  for k, _ in pairs(part.tone) do
    local x, y = k % W, k // W
    if inside(x, y) then part.pal[k] = pal end
  end
end

local function dot(part, x, y, color) part.color[key(x, y)] = color end

-- Clears pixels (for the flat sole).
local function cut(part, inside)
  for k, _ in pairs(part.tone) do
    local x, y = k % W, k // W
    if inside(x, y) then part.tone[k] = nil part.pal[k] = nil end
  end
end

local parts = {}

-- Head: a big round skull, short spiky hair on top and back, red headband, face to the right.
local head = new_part()
ellipse(head, {33, 22}, 11.5, 12, SKIN)
ellipse(head, {38, 28}, 6, 5, SKIN) -- jaw
-- Hair: everything above the band and the back of the skull.
recolor(head, HAIR, function(x, y) return y <= 14 or (x <= 27 and y <= 28) end)
-- Spikes swept back, each a tapering capsule growing out of the skull.
for _, sx in ipairs({24, 29, 34, 39}) do
  capsule(head, {sx, 13}, {sx - 5, 6}, 2, HAIR)
end
capsule(head, {23, 18}, {17, 16}, 2, HAIR)
recolor(head, BAND, function(x, y) return y >= 15 and y <= 17 and x >= 22 end)
-- Headband knot tails trailing behind.
capsule(head, {22, 16}, {16, 21}, 1.2, BAND)
capsule(head, {22, 17}, {18, 24}, 1.2, BAND)
parts.head = head

-- Torso: a broad chest in a sleeveless red shirt, narrowing to the waist; neck on top.
local torso = new_part()
capsule(torso, {31, 33}, {32, 38}, 3.5, SKIN) -- neck
ellipse(torso, {32, 44}, 10, 9, SHIRT)
capsule(torso, {31, 46}, {31, 55}, 7.5, SHIRT)
parts.torso = torso

-- Pelvis: belt and the top of the trousers.
local pelvis = new_part()
capsule(pelvis, {28, 59}, {34, 59}, 5.5, PANTS)
recolor(pelvis, BELT, function(x, y) return y >= 54 and y <= 56 end)
parts.pelvis = pelvis

-- Legs: trousers to the ankle; boots are the feet.
local function thigh() local p = new_part() capsule(p, J.hip, J.knee, 5.5, PANTS) return p end
local function shin() local p = new_part() capsule(p, J.knee, J.ankle, 4.5, PANTS) return p end
local function foot()
  local p = new_part()
  capsule(p, {30, 87}, {37, 90}, 3.5, BOOT)
  ellipse(p, {28, 90}, 3, 2.5, BOOT)
  cut(p, function(x, y) return y > 92 end)
  recolor(p, BELT, function(x, y) return y == 92 end) -- dark sole
  return p
end

-- Arms: bare muscled arms, white hand wraps on big fists.
-- A round shoulder in a short sleeve covers the joint, so the arm turns without a gap.
local function upper_arm()
  local p = new_part()
  capsule(p, J.shoulder, J.elbow, 4, SKIN)
  ellipse(p, J.shoulder, 5, 5.5, SHIRT)
  return p
end
local function lower_arm()
  local p = new_part()
  capsule(p, J.elbow, J.wrist, 3.5, SKIN)
  ellipse(p, J.fist, 4.5, 4.5, WRAP)
  recolor(p, WRAP, function(x, y) return y >= 57 end)
  return p
end

parts.leg_front_upper, parts.leg_back_upper = thigh(), thigh()
parts.leg_front_lower, parts.leg_back_lower = shin(), shin()
parts.foot_front, parts.foot_back = foot(), foot()
parts.arm_front_upper, parts.arm_back_upper = upper_arm(), upper_arm()
parts.arm_front_lower, parts.arm_back_lower = lower_arm(), lower_arm()

-- Face details on the head (drawn after shading so they stay crisp).
local EYE = app.pixelColor.rgba(24, 20, 32, 255)
local WHITE = app.pixelColor.rgba(255, 255, 250, 255)
local function c(t) return app.pixelColor.rgba(t[1], t[2], t[3], 255) end
dot(head, 39, 20, c(HAIR[2])) dot(head, 40, 20, c(HAIR[2])) dot(head, 41, 19, c(HAIR[2])) -- brow
dot(head, 40, 21, WHITE) dot(head, 40, 22, EYE) dot(head, 41, 22, EYE) dot(head, 41, 21, EYE) -- eye
dot(head, 45, 24, c(SKIN[3])) dot(head, 45, 25, c(SKIN[2])) dot(head, 46, 25, c(SKIN[2])) -- nose
dot(head, 41, 29, c(SKIN[1])) dot(head, 42, 29, c(SKIN[1])) dot(head, 43, 28, c(SKIN[1])) -- mouth
for _, p in ipairs({{29, 21}, {30, 20}, {31, 21}, {31, 22}, {31, 23}, {30, 24}, {29, 24}}) do
  dot(head, p[1], p[2], c(SKIN[1])) -- ear
end
dot(head, 30, 22, c(SKIN[2])) dot(head, 30, 23, c(SKIN[2]))
-- Knuckle lines on the fists and the belt buckle.
for _, arm in ipairs({parts.arm_front_lower, parts.arm_back_lower}) do
  dot(arm, 35, 61, c(WRAP[1])) dot(arm, 35, 63, c(WRAP[1]))
end
dot(pelvis, 37, 55, c(rgb(220, 190, 90))) dot(pelvis, 38, 55, c(rgb(220, 190, 90)))

-- Far limbs are darker, so they read as behind the body.
local FAR = {arm_back_upper = true, arm_back_lower = true, leg_back_upper = true, leg_back_lower = true, foot_back = true}

-- Renders a part: shaded fill, then a 1 px outline in its palette's darkest colour.
local function render(part, far)
  local img = Image(W, H, ColorMode.RGB)
  img:clear(app.pixelColor.rgba(0, 0, 0, 0))
  local function tone_color(pal, t)
    local col = pal[t + 1]
    local k = far and 0.72 or 1.0
    return app.pixelColor.rgba(math.floor(col[1] * k), math.floor(col[2] * k), math.floor(col[3] * k), 255)
  end
  for k, t in pairs(part.tone) do
    img:drawPixel(k % W, k // W, tone_color(part.pal[k], t))
  end
  for k, col in pairs(part.color) do
    if part.tone[k] then img:drawPixel(k % W, k // W, col) end
  end
  -- Outline: filled pixels touching the outside (4-neighbourhood) take the outline colour.
  local edge = {}
  for k, _ in pairs(part.tone) do
    local x, y = k % W, k // W
    for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
      local nx, ny = x + d[1], y + d[2]
      if nx < 0 or ny < 0 or nx >= W or ny >= H or not part.tone[key(nx, ny)] then
        edge[k] = true
      end
    end
  end
  for k, _ in pairs(edge) do
    img:drawPixel(k % W, k // W, tone_color(part.pal[k], 0))
  end
  return img
end

-- Draw order back to front, as CharacterRig.PARTS.
local ORDER = {"arm_back_upper", "arm_back_lower", "leg_back_upper", "leg_back_lower", "foot_back",
  "pelvis", "leg_front_upper", "leg_front_lower", "foot_front", "torso", "head",
  "arm_front_upper", "arm_front_lower"}

local sprite = Sprite(W, H, ColorMode.RGB)
local preview = Image(W, H, ColorMode.RGB)
preview:clear(app.pixelColor.rgba(0, 0, 0, 0))
for i, name in ipairs(ORDER) do
  local img = render(parts[name], FAR[name])
  img:saveAs(OUT .. name .. ".png")
  local layer = i == 1 and sprite.layers[1] or sprite:newLayer()
  layer.name = name
  sprite:newCel(layer, sprite.frames[1], img, Point(0, 0))
  preview:drawImage(img, Point(0, 0))
end
preview:saveAs("art/street_brawler_preview.png")
sprite:saveAs(SOURCE)

local function v(p) return string.format("[%d, %d]", p[1], p[2]) end
local rig = io.open(OUT .. "rig.json", "w")
rig:write(string.format([[{
  "character": "Street Brawler",
  "canvas": [%d, %d],
  "feet": [32, 93],
  "pivots": {
    "pelvis": %s,
    "torso": %s,
    "head": %s,
    "arm_back_upper": %s,
    "arm_back_lower": %s,
    "arm_front_upper": %s,
    "arm_front_lower": %s,
    "leg_back_upper": %s,
    "leg_back_lower": %s,
    "foot_back": %s,
    "leg_front_upper": %s,
    "leg_front_lower": %s,
    "foot_front": %s
  },
  "points": {
    "hand_front": %s,
    "hand_back": %s,
    "head_top": [33, 7]
  }
}
]], W, H, v(J.pelvis), v(J.waist), v(J.neck), v(J.shoulder), v(J.elbow), v(J.shoulder), v(J.elbow),
  v(J.hip), v(J.knee), v(J.ankle), v(J.hip), v(J.knee), v(J.ankle), v(J.fist), v(J.fist)))
rig:close()
