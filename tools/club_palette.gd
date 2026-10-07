extends SceneTree
## Writes the club's palette (ClubMaterial.PALETTE) as assets/club/palette.png, 32x1.
##   godot --headless --path . -s tools/club_palette.gd


func _initialize() -> void:
	var img := ClubMaterial.palette_image()
	var path := ProjectSettings.globalize_path(ClubMaterial.PALETTE_PATH)
	var err := img.save_png(path)
	print("palette %dx%d -> %s (%s)" % [img.get_width(), img.get_height(), path, error_string(err)])
	quit(0 if err == OK else 1)
