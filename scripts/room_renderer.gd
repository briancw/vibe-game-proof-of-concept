@tool
extends Node2D

## JSON is the authored room format. This script renders the same layout in
## the editor, during play, and when screenshot capture passes --capture.

const CATALOG_PATH := "res://tiles/tile_catalog.json"

@export_file("*.json") var layout_path := "res://rooms/living_room.json":
	set(value):
		layout_path = value
		if is_inside_tree():
			call_deferred("rebuild_room")

var _generated: Node2D


func _ready() -> void:
	rebuild_room()
	if not Engine.is_editor_hint() and "--capture" in OS.get_cmdline_user_args():
		capture_screenshot.call_deferred()


func rebuild_room() -> void:
	var catalog := _read_json(CATALOG_PATH)
	var layout := _read_json(layout_path)
	if catalog.is_empty() or layout.is_empty():
		return
	if is_instance_valid(_generated):
		_generated.queue_free()

	_generated = Node2D.new()
	_generated.name = "GeneratedRoom"
	add_child(_generated)

	var grid_size := _as_vector(layout.get("grid_size", []))
	var tile_size := _as_vector(catalog.get("tile_size", []))
	if grid_size.x <= 0 or grid_size.y <= 0 or tile_size.x <= 0 or tile_size.y <= 0:
		push_error("Room layout needs positive grid_size and tile_size values.")
		return

	var context := _make_tile_set(catalog, tile_size)
	for layer_data in layout.get("layers", []):
		_build_tile_layer(layer_data, catalog, context, grid_size)
	_build_props(layout.get("props", []), catalog, tile_size)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read JSON file: %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("Invalid JSON in %s: %s" % [path, json.get_error_message()])
		return {}
	return json.data


func _make_tile_set(catalog: Dictionary, tile_size: Vector2i) -> Dictionary:
	var tile_set := TileSet.new()
	tile_set.tile_size = tile_size
	var source_ids := {}
	var atlas_sources := {}
	var next_source_id := 0

	for sheet_name in catalog.get("sheets", {}):
		var sheet: Dictionary = catalog["sheets"][sheet_name]
		var atlas := TileSetAtlasSource.new()
		atlas.texture = load(sheet.get("path", ""))
		atlas.texture_region_size = tile_size
		tile_set.add_source(atlas, next_source_id)
		source_ids[sheet_name] = next_source_id
		atlas_sources[sheet_name] = atlas
		next_source_id += 1

	for tile_name in catalog.get("tiles", {}):
		var tile: Dictionary = catalog["tiles"][tile_name]
		var sheet_name: String = tile.get("sheet", "")
		if not atlas_sources.has(sheet_name):
			push_error("Tile %s references unknown sheet %s." % [tile_name, sheet_name])
			continue
		var atlas: TileSetAtlasSource = atlas_sources[sheet_name]
		var atlas_coordinates := _as_vector(tile.get("atlas", []))
		if not atlas.has_tile(atlas_coordinates):
			atlas.create_tile(atlas_coordinates)
	return { "tile_set": tile_set, "source_ids": source_ids }


func _build_tile_layer(layer_data: Dictionary, catalog: Dictionary, context: Dictionary, grid_size: Vector2i) -> void:
	var map := TileMapLayer.new()
	map.name = layer_data.get("name", "TileLayer")
	map.z_index = int(layer_data.get("z_index", 0))
	map.tile_set = context["tile_set"]
	_generated.add_child(map)

	for operation in layer_data.get("operations", []):
		match operation.get("type", ""):
			"fill":
				for y in range(grid_size.y):
					for x in range(grid_size.x):
						_place_tile(map, Vector2i(x, y), operation.get("tile", ""), catalog, context)
			"frame":
				for x in range(-1, grid_size.x + 1):
					_place_tile(map, Vector2i(x, -1), operation.get("top", ""), catalog, context)
					_place_tile(map, Vector2i(x, grid_size.y), operation.get("bottom", ""), catalog, context)
				for y in range(grid_size.y):
					_place_tile(map, Vector2i(-1, y), operation.get("left", ""), catalog, context)
					_place_tile(map, Vector2i(grid_size.x, y), operation.get("right", ""), catalog, context)
			_:
				push_error("Unknown room operation: %s" % operation.get("type", ""))


func _place_tile(map: TileMapLayer, cell: Vector2i, tile_name: String, catalog: Dictionary, context: Dictionary) -> void:
	var tile: Dictionary = catalog.get("tiles", {}).get(tile_name, {})
	if tile.is_empty():
		push_error("Unknown tile ID: %s" % tile_name)
		return
	var source_ids: Dictionary = context["source_ids"]
	map.set_cell(cell, source_ids[tile["sheet"]], _as_vector(tile["atlas"]))


func _build_props(prop_data: Array, catalog: Dictionary, tile_size: Vector2i) -> void:
	var props := Node2D.new()
	props.name = "Props"
	_generated.add_child(props)
	for placement in prop_data:
		var prop_id: String = placement.get("id", "")
		var definition: Dictionary = catalog.get("props", {}).get(prop_id, {})
		if definition.is_empty():
			push_error("Unknown prop ID: %s" % prop_id)
			continue
		var sprite := Sprite2D.new()
		sprite.name = prop_id.replace(".", "_")
		sprite.texture = load(definition.get("texture", ""))
		sprite.centered = definition.get("anchor", "top_left") != "top_left"
		sprite.position = _as_vector(placement.get("at", [])) * tile_size
		sprite.z_index = int(placement.get("z_index", 2))
		props.add_child(sprite)


func _as_vector(value: Array) -> Vector2i:
	if value.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(value[0]), int(value[1]))


func capture_screenshot() -> void:
	var layout := _read_json(layout_path)
	var catalog := _read_json(CATALOG_PATH)
	var tile_size := _as_vector(catalog.get("tile_size", []))
	var grid_size := _as_vector(layout.get("grid_size", []))
	var camera := Camera2D.new()
	camera.position = Vector2(grid_size * tile_size) * 0.5
	add_child(camera)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://room.png")
	get_tree().quit()

