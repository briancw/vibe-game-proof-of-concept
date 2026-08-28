class_name TileIndex
extends RefCounted

## `tile_index.yaml` is the authoritative list of usable tiles and props.
## The TileSet is generated from this data solely for Godot rendering/browsing.

const INDEX_PATH := "res://tiles/tile_index.yaml"
const YAMLParser = preload("res://addons/yaml_dot_gd/yaml.gd")


static func load_index(path := INDEX_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read tile index: %s" % path)
		return {}
	var source := file.get_as_text()
	if _has_tab_indentation(source):
		push_error("Tile index uses tab indentation: %s" % path)
		return {}
	var parser = YAMLParser.new()
	var parsed: Variant = parser.parse(source)
	if not parsed is Dictionary:
		push_error("Tile index must parse to a YAML mapping: %s" % path)
		return {}
	return _validate_and_resolve(parsed, path)


static func _validate_and_resolve(raw: Dictionary, path: String) -> Dictionary:
	var result := raw.duplicate(true)
	var tile_size := _as_vector(result.get("tile_size", []))
	if tile_size.x <= 0 or tile_size.y <= 0:
		push_error("Tile index needs tile_size: [width, height]: %s" % path)
		return {}
	if not result.get("sheets") is Dictionary or not result.get("tiles") is Dictionary or not result.get("props") is Dictionary:
		push_error("Tile index requires sheets, tiles, and props mappings: %s" % path)
		return {}
	var source_ids := {}
	var source_names: Array[String] = []
	for sheet_name in result.sheets:
		source_names.append(String(sheet_name))
	source_names.sort()
	for source_id in source_names.size():
		var sheet_name := source_names[source_id]
		var sheet: Dictionary = result.sheets[sheet_name]
		if not sheet.get("file") is String or String(sheet.file).is_empty():
			push_error("Sheet %s needs a file path: %s" % [sheet_name, path])
			return {}
		if not ResourceLoader.exists(sheet.file):
			push_error("Sheet %s does not exist: %s" % [sheet_name, sheet.file])
			return {}
		source_ids[sheet_name] = source_id
	var addresses := {}
	var reverse_addresses := {}
	for tile_id in result.tiles:
		var definition: Dictionary = result.tiles[tile_id]
		var sheet_name := String(definition.get("sheet", ""))
		var atlas := _as_vector(definition.get("atlas", []))
		if not source_ids.has(sheet_name) or atlas.x < 0 or atlas.y < 0:
			push_error("Tile %s needs a known sheet and non-negative atlas: %s" % [tile_id, path])
			return {}
		var source_id: int = source_ids[sheet_name]
		var address_key := "%d:%d:%d" % [source_id, atlas.x, atlas.y]
		addresses[tile_id] = {
			"source_id": source_id,
			"sheet": sheet_name,
			"atlas_coords": atlas,
			"alternative_id": 0,
			"description": String(definition.get("description", "")),
		}
		if not reverse_addresses.has(address_key):
			reverse_addresses[address_key] = []
		reverse_addresses[address_key].append(tile_id)
	for prop_id in result.props:
		var prop: Dictionary = result.props[prop_id]
		if not prop.get("texture") is String or String(prop.texture).is_empty() or not ResourceLoader.exists(prop.texture):
			push_error("Prop %s needs an existing texture path: %s" % [prop_id, path])
			return {}
	result["tile_size_vector"] = tile_size
	result["source_ids"] = source_ids
	result["tiles_by_id"] = addresses
	result["tile_ids_by_address"] = reverse_addresses
	return result


static func describe_cell(tile_map: TileMapLayer, cell: Vector2i, index: Dictionary) -> Dictionary:
	var source_id := tile_map.get_cell_source_id(cell)
	if source_id == -1:
		return {}
	var atlas := tile_map.get_cell_atlas_coords(cell)
	var key := "%d:%d:%d" % [source_id, atlas.x, atlas.y]
	var tile_ids: Array = index.get("tile_ids_by_address", {}).get(key, [])
	var tile_id := ", ".join(PackedStringArray(tile_ids))
	var source := tile_map.tile_set.get_source(source_id)
	return {
		"cell": cell,
		"source_id": source_id,
		"source_name": source.resource_name if source else "",
		"atlas_coords": atlas,
		"alternative_id": tile_map.get_cell_alternative_tile(cell),
		"semantic_id": tile_id,
		"description": "" if tile_ids.size() != 1 else String(index.get("tiles", {}).get(tile_ids[0], {}).get("description", "")),
	}


static func _as_vector(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1])) if value.size() == 2 else Vector2i(-1, -1)


static func _has_tab_indentation(source: String) -> bool:
	for line in source.split("\n"):
		var leading := line.left(line.length() - line.lstrip(" \t").length())
		if "\t" in leading:
			return true
	return false
