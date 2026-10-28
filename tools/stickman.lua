-- Turns the stick figure's frame strips (art/stickman/strips/<clip>.png, drawn by
-- tools/make_stickman.gd) into one .aseprite file per clip, a frame per drawing, and
-- exports the strip the game loads to assets/characters/stickman/<clip>.png.
-- Run from the project root:
-- "C:\Program Files\Aseprite\Aseprite.exe" -b --script tools/stickman.lua

local W, H = 192, 128
local strips = app.fs.joinPath(app.fs.currentPath, "art", "stickman", "strips")
local sources = app.fs.joinPath(app.fs.currentPath, "art", "stickman")
local out = app.fs.joinPath(app.fs.currentPath, "assets", "characters", "stickman")

for _, file in ipairs(app.fs.listFiles(strips)) do
  if app.fs.fileExtension(file) == "png" then
    local name = app.fs.fileTitle(file)
    local strip = Image{ fromFile = app.fs.joinPath(strips, file) }
    local count = strip.width // W
    local sprite = Sprite(W, H, ColorMode.RGB)
    for i = 0, count - 1 do
      if i > 0 then sprite:newEmptyFrame() end
      local frame = Image(W, H, ColorMode.RGB)
      frame:drawImage(strip, Point(-i * W, 0))
      sprite:newCel(sprite.layers[1], i + 1, frame, Point(0, 0))
      sprite.frames[i + 1].duration = 1 / 24
    end
    sprite:saveAs(app.fs.joinPath(sources, name .. ".aseprite"))
    app.command.ExportSpriteSheet{
      ui = false, type = SpriteSheetType.HORIZONTAL,
      textureFilename = app.fs.joinPath(out, name .. ".png"),
      trim = false, shapePadding = 0, borderPadding = 0, innerPadding = 0,
    }
    sprite:close()
  end
end
