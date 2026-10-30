extends SceneTree

## Copies item art from downloaded packs to each item's `ItemData.art`. The packs' licences
## forbid public repositories or are unknown, so the zips stay outside the repo and the output
## is git-ignored: run this once per checkout, then reimport. Without it items show grey boxes.
##
## <godot> --headless --path . -s res://tools/import_items.gd -- <folder holding the zips>

const GUNS := "GunsAssetPack.zip"
const GUNS_DIR := "GunsAssetPack/Individual_Gun_Sprites/Black_Outline/"
const FANTASY := "FreePixelFantasyWeaponPack.zip"
const FANTASY_DIR := "FreePixelFantasyWeaponPack/Weapons/"
const DEMO := "PixelGuns_DemoPack.zip"
## Item -> [zip, file in it, upscale]. GunsAssetPack draws at the characters' pixel size, so it
## is scaled to the 3x of item art; the others already have that detail.
const ITEMS := {
	"res://data/weapons/pistol.tres": [GUNS, GUNS_DIR + "Pistol.png", 3],
	"res://data/weapons/shotgun.tres": [GUNS, GUNS_DIR + "Shotgun.png", 3],
	"res://data/weapons/smg.tres": [GUNS, GUNS_DIR + "AssaultRifle2.png", 3],
	"res://data/weapons/sniper.tres": [GUNS, GUNS_DIR + "SniperRifle.png", 3],
	"res://data/weapons/knife.tres": [FANTASY, FANTASY_DIR + "15.png", 1],
	"res://data/weapons/bat.tres": [FANTASY, FANTASY_DIR + "33.png", 1],
	"res://data/throwables/grenade.tres": [DEMO, "Fragmentation Grenade.png", 1],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("usage: -s res://tools/import_items.gd -- <folder holding the zips>")
		quit(1)
		return
	var ok := true
	for path: String in ITEMS:
		ok = _import(path, args[0]) and ok
	quit(0 if ok else 1)


func _import(path: String, folder: String) -> bool:
	var item := load(path) as ItemData
	var source: Array = ITEMS[path]
	var zip := ZIPReader.new()
	if zip.open(folder.path_join(source[0])) != OK or not zip.file_exists(source[1]):
		push_error("%s: cannot read %s in %s" % [path, source[1], source[0]])
		return false
	var image := Image.new()
	var loaded := image.load_png_from_buffer(zip.read_file(source[1]))
	zip.close()
	if loaded != OK:
		push_error("%s: broken png %s" % [path, source[1]])
		return false
	image.convert(Image.FORMAT_RGBA8)
	image = image.get_region(image.get_used_rect())
	image.resize(image.get_width() * source[2], image.get_height() * source[2], Image.INTERPOLATE_NEAREST)
	# Grip, muzzle and the pickup's body are measured on the placeholder.
	if image.get_size() != Vector2i(item.texture.get_size()):
		push_error("%s: art is %s, placeholder %s" % [path, image.get_size(), item.texture.get_size()])
		return false
	DirAccess.make_dir_recursive_absolute(item.art.get_base_dir())
	return image.save_png(item.art) == OK
