-- Draws the throwable sprites from the pixel maps below, saves each as
-- art/throwables/<name>.aseprite and exports assets/throwables/<name>.png.
-- Run from the project root:
--   Aseprite.exe -b --script art/throwables/make_throwables.lua
-- The ThrowableData grip pixel refers to these maps.

local palette = {
  o = Color{ r = 0x1a, g = 0x1c, b = 0x2c }, -- outline
  m = Color{ r = 0x5d, g = 0x63, b = 0x75 }, -- metal
  g = Color{ r = 0x38, g = 0x5a, b = 0x3a }, -- grenade green
  b = Color{ r = 0x6e, g = 0x9a, b = 0x5a }, -- bottle glass
  c = Color{ r = 0xe8, g = 0xe0, b = 0xc8 }, -- cloth wick
  f = Color{ r = 0xff, g = 0x8a, b = 0x2a }, -- flame
}

local items = {
  grenade = {
    "..oom",
    ".oomo",
    "oggggo",
    "oggggo",
    "oggggo",
    ".oooo.",
  },
  molotov = {
    ".f..",
    ".c..",
    "ooo.",
    ".bo.",
    "obbo",
    "obbo",
    "obbo",
    "oooo",
  },
}

for name, rows in pairs(items) do
  local width = 0
  for _, row in ipairs(rows) do
    width = math.max(width, #row)
  end
  local sprite = Sprite(width, #rows, ColorMode.RGB)
  local image = sprite.cels[1].image
  for y, row in ipairs(rows) do
    for x = 1, #row do
      local color = palette[row:sub(x, x)]
      if color then
        image:drawPixel(x - 1, y - 1, color)
      end
    end
  end
  sprite:saveAs("art/throwables/" .. name .. ".aseprite")
  sprite:saveCopyAs("assets/throwables/" .. name .. ".png")
  sprite:close()
end
