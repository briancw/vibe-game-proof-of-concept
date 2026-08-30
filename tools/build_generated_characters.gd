@tool
extends SceneTree

## Builds fixed-layout compact strips. --check rebuilds in memory and compares
## pixels, so it detects stale PNGs without writing manifest sidecar files.
##
##   godot --headless --path . --script res://tools/build_generated_characters.gd
##   godot --headless --path . --script res://tools/build_generated_characters.gd -- --check

const GeneratedCharacters = preload("res://sprites/generated_characters.gd")
const CharacterGeneratorLayout = preload("res://sprites/character_generator_layout.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var check_only := "--check" in args
	var config_path := _config_path(args)
	var config := GeneratedCharacters.load_config(config_path)
	if config.is_empty():
		quit(1)
		return
	if not check_only:
		var output_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GeneratedCharacters.OUTPUT_DIR))
		if output_error != OK:
			push_error("Could not create generated-character output directory: %s" % GeneratedCharacters.OUTPUT_DIR)
			quit(1)
			return
	var failures := 0
	for character_data in config.characters:
		if not _process_character(character_data, check_only):
			failures += 1
	quit(1 if failures > 0 else 0)


func _config_path(args: PackedStringArray) -> String:
	for arg in args:
		if arg != "--check":
			return arg
	return GeneratedCharacters.DEFAULT_CONFIG_PATH


func _process_character(character_data: Dictionary, check_only: bool) -> bool:
	var id := str(character_data.id)
	var composite := _compose(character_data)
	if composite == null:
		return false
	var strip := Image.create_empty(CharacterGeneratorLayout.strip_size().x, CharacterGeneratorLayout.strip_size().y, false, Image.FORMAT_RGBA8)
	for definition in CharacterGeneratorLayout.runtime_definitions():
		var source_origin: Vector2i = definition.source_origin
		var target_origin: Vector2i = definition.origin
		var region := Rect2i(source_origin, Vector2i(CharacterGeneratorLayout.frame_size().x * int(definition.frames), CharacterGeneratorLayout.frame_size().y))
		if not Rect2i(Vector2i.ZERO, composite.get_size()).encloses(region):
			push_error("%s on %s lies outside the source sheet." % [definition.name, id])
			return false
		strip.blend_rect(composite, region, target_origin)
	var path := GeneratedCharacters.sheet_path(id)
	if check_only:
		var existing := Image.load_from_file(ProjectSettings.globalize_path(path))
		if existing == null or existing.is_empty() or existing.get_size() != strip.get_size():
			push_error("Generated character is stale or missing: %s. Run tools/build_generated_characters.gd." % id)
			return false
		existing.convert(Image.FORMAT_RGBA8)
		if existing.get_data() != strip.get_data():
			push_error("Generated character is stale: %s. Run tools/build_generated_characters.gd." % id)
			return false
		print("Current: %s" % id)
		return true
	if strip.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("Could not save generated character strip: %s" % path)
		return false
	print("Generated %s (%d layers, %d frames, %s runtime strip)." % [id, GeneratedCharacters.selected_layers(character_data).size(), CharacterGeneratorLayout.frame_count(), strip.get_size()])
	return true


func _compose(character_data: Dictionary) -> Image:
	var canvas_size := CharacterGeneratorLayout.sheet_size()
	var composite := Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	var layers := GeneratedCharacters.selected_layers(character_data)
	if layers.is_empty():
		push_error("No usable layers were selected for %s." % character_data.id)
		return null
	for layer in layers:
		var image := Image.load_from_file(ProjectSettings.globalize_path(layer.path))
		if image == null or image.is_empty():
			push_error("Could not load %s layer: %s" % [layer.key, layer.path])
			return null
		if image.get_width() < canvas_size.x or image.get_height() < canvas_size.y:
			push_error("%s layer is %s; expected at least %s. Small prop sheets need a dedicated animation compositor." % [layer.path, image.get_size(), canvas_size])
			return null
		image.convert(Image.FORMAT_RGBA8)
		composite.blend_rect(image, Rect2i(Vector2i.ZERO, canvas_size), Vector2i.ZERO)
	return composite
