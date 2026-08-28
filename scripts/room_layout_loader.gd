class_name RoomLayoutLoader
extends RefCounted

## Adapter between the vendored YAML.gd parser and the room renderer's schema.
## Upstream: lowlevel-1989/YAML.gd @ da258fc49ab3de88fb2af6f7400ece3800e779e7

const YAMLParser = preload("res://addons/yaml_dot_gd/yaml.gd")


static func load_layout(path: String) -> Dictionary:
	if path.get_extension().to_lower() == "json":
		return _load_json(path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read room layout: %s" % path)
		return {}
	var source := file.get_as_text()
	if _has_tab_indentation(source):
		push_error("Room YAML uses tab indentation: %s. In Godot, disable Text Editor > Behavior > Files > Convert Indent On Save, or set Text Editor > Behavior > Indent > Type to Spaces." % path)
		return {}
	var parser = YAMLParser.new()
	var parsed: Variant = parser.parse(source)
	if not parsed is Dictionary:
		push_error("Room YAML must parse to a mapping: %s" % path)
		return {}
	return _validate_and_normalize(parsed, path)


static func _has_tab_indentation(source: String) -> bool:
	for line in source.split("\n"):
		var leading := line.left(line.length() - line.lstrip(" \t").length())
		if "\t" in leading:
			return true
	return false


static func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read room layout: %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("Invalid JSON in %s: %s" % [path, json.get_error_message()])
		return {}
	return _validate_and_normalize(json.data, path)


static func _validate_and_normalize(layout: Dictionary, path: String) -> Dictionary:
	var result := layout.duplicate(true)
	if not result.get("name") is String or String(result.name).is_empty():
		push_error("Room requires a non-empty name: %s" % path)
		return {}
	if not result.get("grid_size") is Array or result.grid_size.size() != 2:
		push_error("Room requires grid_size: [width, height]: %s" % path)
		return {}
	if not result.get("layers") is Array:
		push_error("Room requires layers as a YAML list: %s" % path)
		return {}
	if result.has("props") and not result.props is Dictionary and not result.props is Array:
		push_error("Room props must be a mapping or list: %s" % path)
		return {}
	if result.get("props") is Dictionary:
		var props: Array = []
		for id in result.props:
			if not result.props[id] is Dictionary:
				push_error("Prop %s must be a mapping: %s" % [id, path])
				return {}
			var placement: Dictionary = result.props[id].duplicate(true)
			placement["id"] = id
			props.append(placement)
		result["props"] = props
	return result
