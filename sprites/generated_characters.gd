class_name GeneratedCharacters
extends RefCounted

## Loads the declarative generator config and creates CharacterSheet resources
## for the compact runtime strips produced by tools/build_generated_characters.gd.

const YAMLParser = preload("res://addons/yaml_dot_gd/yaml.gd")
const CharacterGeneratorLayout = preload("res://sprites/character_generator_layout.gd")
const CharacterSheetScript = preload("res://sprites/character_sheet.gd")
const CharacterAnimDefScript = preload("res://sprites/character_anim_def.gd")

const DEFAULT_CONFIG_PATH := "res://characters/generated_characters.yaml"
const OUTPUT_DIR := "res://assets/characters/generated"
const LAYER_KEYS: PackedStringArray = ["body", "eyes", "outfit", "hairstyle", "accessory", "held_item"]

const LAYER_FOLDERS: Dictionary = {
	"body": ["Bodies"],
	"eyes": ["Eyes"],
	"outfit": ["Outfits"],
	"hairstyle": ["Hairstyles"],
	"accessory": ["Accessories"],
	"held_item": ["Books", "Smartphones"],
}

static var _texture_cache: Dictionary = {}


static func load_config(config_path: String = DEFAULT_CONFIG_PATH) -> Dictionary:
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("Could not read generated character config: %s" % config_path)
		return {}
	var source := file.get_as_text()
	if _has_tab_indentation(source):
		push_error("Generated character YAML uses tab indentation: %s" % config_path)
		return {}
	var parser = YAMLParser.new()
	var parsed: Variant = parser.parse(source)
	if not parsed is Dictionary:
		push_error("Generated character config must be a YAML mapping: %s" % config_path)
		return {}
	return _validate(parsed, config_path)


static func load_sheet(id: StringName, config_path: String = DEFAULT_CONFIG_PATH) -> CharacterSheet:
	var config := load_config(config_path)
	if config.is_empty():
		return null
	var character := find_character(config, String(id))
	if character.is_empty():
		push_error("Generated character ID not found: %s" % id)
		return null
	var output_path := sheet_path(String(id))
	var texture := _load_generated_texture(output_path)
	if texture == null:
		push_error("Generated strip is missing or unreadable: %s. Run tools/build_generated_characters.gd first." % output_path)
		return null

	var sheet := CharacterSheetScript.new() as CharacterSheet
	sheet.texture = texture
	sheet.frame_size = CharacterGeneratorLayout.frame_size()
	sheet.default_animation = &"stand_down" if sheet_has_animation(config.animations, "stand_down") else &"idle_down" if sheet_has_animation(config.animations, "idle_down") else StringName(CharacterGeneratorLayout.definitions(config.animations)[0].name)
	var definitions := packed_definitions(config.animations)
	for definition in definitions:
		var animation := CharacterAnimDefScript.new() as CharacterAnimDef
		animation.name = StringName(definition.name)
		animation.origin = definition.origin
		animation.frames = definition.frames
		animation.fps = definition.fps
		animation.loop = definition.loop
		sheet.animations.append(animation)
	return sheet


static func find_character(config: Dictionary, id: String) -> Dictionary:
	for character_data in config.characters:
		if str(character_data.id) == id:
			return character_data
	return {}


static func sheet_path(id: String) -> String:
	return "%s/%s.png" % [OUTPUT_DIR, id]


## Generated PNGs can be written by a headless build moments before this code
## runs, before Godot's editor importer has created a Texture2D resource. Load
## the pixels directly and cache the resulting GPU texture instead.
static func _load_generated_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[path] = texture
	return texture


## Replaces source-atlas coordinates with contiguous strip positions. This is
## the definition set used both by the builder and by the runtime renderer.
static func packed_definitions(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var next_frame := 0
	var frame_width := CharacterGeneratorLayout.frame_size().x
	for source_definition in CharacterGeneratorLayout.definitions(actions):
		var definition := source_definition.duplicate()
		definition["origin"] = Vector2i(next_frame * frame_width, 0)
		next_frame += int(definition.frames)
		result.append(definition)
	return result


static func packed_strip_size(actions: Array) -> Vector2i:
	var frame_size := CharacterGeneratorLayout.frame_size()
	var frame_count := 0
	for definition in CharacterGeneratorLayout.definitions(actions):
		frame_count += int(definition.frames)
	return Vector2i(frame_count * frame_size.x, frame_size.y)


static func layer_path(layer_key: String, asset_id: Variant) -> String:
	if asset_id == null or String(asset_id).is_empty():
		return ""
	if not LAYER_FOLDERS.has(layer_key):
		push_error("Unknown generated character layer: %s" % layer_key)
		return ""
	var filename := String(asset_id)
	if not filename.ends_with(".png"):
		filename += ".png"
	if filename.contains("/") or filename.contains("\\"):
		push_error("Character asset IDs must be filenames, not paths: %s" % asset_id)
		return ""
	for folder in LAYER_FOLDERS[layer_key]:
		var candidate := "res://assets/characters/Character_Generator/%s/%s" % [folder, filename]
		if FileAccess.file_exists(candidate):
			return candidate
	push_error("Could not find %s asset %s" % [layer_key, asset_id])
	return ""


static func selected_layers(character: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for layer_key in LAYER_KEYS:
		var asset_id: Variant = character.get(layer_key)
		if asset_id == null or String(asset_id).is_empty():
			continue
		var path := layer_path(layer_key, asset_id)
		if path.is_empty():
			return []
		result.append({"key": layer_key, "path": path})
	return result


static func sheet_has_animation(actions: Array, target: String) -> bool:
	for definition in packed_definitions(actions):
		if definition.name == target:
			return true
	return false


static func _validate(parsed: Dictionary, config_path: String) -> Dictionary:
	var result := parsed.duplicate(true)
	if not result.get("animations") is Array or result.animations.is_empty():
		push_error("animations must be a non-empty YAML list: %s" % config_path)
		return {}
	for action in result.animations:
		if not CharacterGeneratorLayout.supports(String(action)):
			push_error("Unsupported animation '%s' in %s. Available: %s" % [action, config_path, ", ".join(CharacterGeneratorLayout.available_actions())])
			return {}
	if not result.get("characters") is Array or result.characters.is_empty():
		push_error("characters must be a non-empty YAML list: %s" % config_path)
		return {}

	var seen_ids: Dictionary = {}
	for index in result.characters.size():
		var character_data: Variant = result.characters[index]
		if not character_data is Dictionary:
			push_error("Character %d must be a mapping: %s" % [index + 1, config_path])
			return {}
		var id := str(character_data.get("id", ""))
		if id.is_empty() or not id.is_valid_filename() or id.contains("."):
			push_error("Character %d needs a filename-safe id without dots: %s" % [index + 1, config_path])
			return {}
		if seen_ids.has(id):
			push_error("Duplicate generated character id '%s': %s" % [id, config_path])
			return {}
		seen_ids[id] = true
		for layer_key in LAYER_KEYS:
			if not character_data.has(layer_key):
				character_data[layer_key] = null
		if character_data.body == null or String(character_data.body).is_empty():
			push_error("Character '%s' needs a body: %s" % [id, config_path])
			return {}
		if character_data.eyes == null or String(character_data.eyes).is_empty():
			push_error("Character '%s' needs eyes: %s" % [id, config_path])
			return {}
	return result


static func _has_tab_indentation(source: String) -> bool:
	for line in source.split("\n"):
		var leading := line.left(line.length() - line.lstrip(" \t").length())
		if "\t" in leading:
			return true
	return false
