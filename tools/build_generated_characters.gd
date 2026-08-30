@tool
extends SceneTree

## Composes raw Character Generator PNG layers according to YAML and writes a
## compact, one-row runtime strip containing only the requested animations.
##
## Run:
##   godot --headless --path . --script res://tools/build_generated_characters.gd
##   godot --headless --path . --script res://tools/build_generated_characters.gd -- res://characters/generated_characters.yaml

const GeneratedCharacters = preload("res://sprites/generated_characters.gd")
const CharacterGeneratorLayout = preload("res://sprites/character_generator_layout.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var config_path := GeneratedCharacters.DEFAULT_CONFIG_PATH if args.is_empty() else String(args[0])
	var config := GeneratedCharacters.load_config(config_path)
	if config.is_empty():
		quit(1)
		return
	var output_dir: String = GeneratedCharacters.OUTPUT_DIR
	var output_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if output_error != OK:
		push_error("Could not create generated-character output directory: %s" % output_dir)
		quit(1)
		return

	var failures := 0
	for character_data in config.characters:
		if not _build_character(character_data, config):
			failures += 1
	quit(1 if failures > 0 else 0)


func _build_character(character_data: Dictionary, config: Dictionary) -> bool:
	var id := str(character_data.id)
	var composite := _compose(character_data)
	if composite == null:
		return false

	var source_definitions := CharacterGeneratorLayout.definitions(config.animations)
	var packed_size := GeneratedCharacters.packed_strip_size(config.animations)
	var packed_strip := Image.create_empty(packed_size.x, packed_size.y, false, Image.FORMAT_RGBA8)
	var next_x := 0
	for definition in source_definitions:
		var strip_size := Vector2i(CharacterGeneratorLayout.frame_size().x * int(definition.frames), CharacterGeneratorLayout.frame_size().y)
		var region := Rect2i(definition.origin, strip_size)
		if not Rect2i(Vector2i.ZERO, composite.get_size()).encloses(region):
			push_error("%s on %s lies outside the generated sheet." % [definition.name, id])
			return false
		packed_strip.blend_rect(composite, region, Vector2i(next_x, 0))
		next_x += strip_size.x

	var sheet_path := GeneratedCharacters.sheet_path(id)
	if packed_strip.save_png(ProjectSettings.globalize_path(sheet_path)) != OK:
		push_error("Could not save generated character strip: %s" % sheet_path)
		return false

	print("Generated %s (%d layers, %d frames, %s runtime strip)." % [id, GeneratedCharacters.selected_layers(character_data).size(), packed_size.x / CharacterGeneratorLayout.frame_size().x, packed_size])
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
