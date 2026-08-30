class_name GeneratedCharacters
extends RefCounted

## Builds character appearances from YAML and loads fixed-layout runtime strips.
## Animation indexing lives in character_generator_layout.gd, not in YAML.

const YAMLParser = preload("res://addons/yaml_dot_gd/yaml.gd")
const CharacterGeneratorLayout = preload("res://characters/character_generator_layout.gd")
const CharacterSheetScript = preload("res://characters/character_sheet.gd")
const CharacterAnimDefScript = preload("res://characters/character_anim_def.gd")

const DEFAULT_CONFIG_PATH := "res://assets/characters/generated_characters.yaml"
const OUTPUT_DIR := "res://assets/characters/generated"
const LAYER_KEYS: PackedStringArray = ["body", "eyes", "outfit", "hairstyle", "accessory", "held_item"]
const LAYER_FOLDERS: Dictionary = {
	"body": ["Bodies"], "eyes": ["Eyes"], "outfit": ["Outfits"],
	"hairstyle": ["Hairstyles"], "accessory": ["Accessories"],
	"held_item": ["Books", "Smartphones"],
}

static var _texture_cache: Dictionary = {}
static var _sheet_cache: Dictionary = {}


## Build/lab helper: reads appearance selections only.
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


## Runtime entry point. Every ID uses the same explicit strip layout.
static func load_sheet(id: StringName) -> CharacterSheet:
	var cache_key := String(id)
	if _sheet_cache.has(cache_key):
		return _sheet_cache[cache_key] as CharacterSheet
	var texture := _load_generated_texture(sheet_path(cache_key))
	if texture == null:
		push_error("Generated strip is missing or unreadable for '%s'. Run tools/build_generated_characters.gd first." % id)
		return null
	var sheet := CharacterSheetScript.new() as CharacterSheet
	sheet.texture = texture
	sheet.frame_size = CharacterGeneratorLayout.frame_size()
	sheet.default_animation = CharacterGeneratorLayout.default_animation()
	for definition in CharacterGeneratorLayout.runtime_definitions():
		var animation := CharacterAnimDefScript.new() as CharacterAnimDef
		animation.name = StringName(definition.name)
		animation.origin = definition.origin
		animation.frames = definition.frames
		animation.fps = definition.fps
		animation.loop = definition.loop
		animation.frame_events = definition.frame_events.duplicate(true)
		sheet.animations.append(animation)
	_sheet_cache[cache_key] = sheet
	return sheet


## Developer tooling only; gameplay can request a known character ID directly.
static func character_ids() -> Array[StringName]:
	var config := load_config()
	var ids: Array[StringName] = []
	for character_data in config.get("characters", []):
		ids.append(StringName(str(character_data.id)))
	return ids


static func sheet_path(id: String) -> String:
	return "%s/%s.png" % [OUTPUT_DIR, id]


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


static func _load_generated_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[path] = texture
	return texture


static func _validate(parsed: Dictionary, config_path: String) -> Dictionary:
	var result := parsed.duplicate(true)
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
