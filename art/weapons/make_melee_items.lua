-- Draws the melee item sprites from the pixel maps below, saves each as
-- art/weapons/<name>.aseprite and exports assets/weapons/<name>.png.
-- Run from the project root:
--   Aseprite.exe -b --script art/weapons/make_melee_items.lua
-- Sprites face right; the MeleeItemData grip pixel refers to these maps.

local palette = {
  o = Color{ r = 0x1a, g = 0x1c, b = 0x2c }, -- outline
  l = Color{ r = 0xc8, g = 0xcd, b = 0xd8 }, -- blade
  w = Color{ r = 0x8a, g = 0x5a, b = 0x3c }, -- wood
  t = Color{ r = 0x3b, g = 0x2a, b = 0x24 }, -- grip tape
}

local items = {
  knife = {
    "oooo.oooo.",
    "owwooolllo",
    "oooo.oooo.",
  },
  bat = {
    "oooooo.......ooo.",
    "ottttoooooooowwwo",
    "otttowwwwwwwwwwwo",
    "oooooooooooooooo.",
  },
}

for name, rows in pairs(items) do
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
