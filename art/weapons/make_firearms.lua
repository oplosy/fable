-- Draws the firearm sprites from the pixel maps below, saves each as
-- art/weapons/<name>.aseprite and exports assets/weapons/<name>.png.
-- Run from the project root:
--   Aseprite.exe -b --script art/weapons/make_firearms.lua
-- Sprites face right; the WeaponData grip/muzzle pixels refer to these maps.

local palette = {
  o = Color{ r = 0x1a, g = 0x1c, b = 0x2c }, -- outline
  m = Color{ r = 0x5d, g = 0x63, b = 0x75 }, -- metal
  l = Color{ r = 0x8b, g = 0x93, b = 0xa6 }, -- light metal (scope glass)
  w = Color{ r = 0x8a, g = 0x5a, b = 0x3c }, -- wood
}

local firearms = {
  shotgun = {
    ".oooooooooooooo",
    "owwwmmmmmmmmmmo",
    "owoooowwwwwoooo",
    "oo.omo.ooooo...",
    "...oo..........",
  },
  smg = {
    "ooooooooooo",
    "ommmmmmmmmo",
    "ooooooooooo",
    ".omo.omo...",
    ".oo..omo...",
    ".....oo....",
  },
  sniper = {
    ".....ooooo..........",
    "oooooolllooooooooooo",
    "owwwwommmmmmmmmmmmmo",
    "owwoooommoooooooooo.",
    "oo...omo............",
  },
}

for name, rows in pairs(firearms) do
  local width = #rows[1]
  local sprite = Sprite(width, #rows, ColorMode.RGB)
  local image = sprite.cels[1].image
  for y, row in ipairs(rows) do
    assert(#row == width, name .. " row " .. y .. " has the wrong width")
    for x = 1, width do
      local color = palette[row:sub(x, x)]
      if color then
        image:drawPixel(x - 1, y - 1, color)
      end
    end
  end
  sprite:saveAs("art/weapons/" .. name .. ".aseprite")
  sprite:saveCopyAs("assets/weapons/" .. name .. ".png")
  sprite:close()
end
