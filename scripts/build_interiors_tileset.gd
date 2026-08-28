@tool
extends SceneTree

## Generates the inspectable Godot TileSet from the authoritative YAML index.
## Run: godot --headless --path . --script res://scripts/build_interiors_tileset.gd

const TileIndex = preload("res://scripts/tile_index.gd")
const OUTPUT := "res://tiles/interiors_tileset.tres"


func _initialize() -> void:
	var index := TileIndex.load_index()
	if index.is_empty():
		quit(1)
		return
	var tile_set := TileSet.new()
	tile_set.tile_size = index.tile_size_vector
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, &"semantic_id")
	tile_set.set_custom_data_layer_type(0, TYPE_STRING)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(1, &"description")
	tile_set.set_custom_data_layer_type(1, TYPE_STRING)

	for sheet_name in index.source_ids:
		var sheet: Dictionary = index.sheets[sheet_name]
		var atlas := TileSetAtlasSource.new()
		atlas.resource_name = sheet_name
		atlas.texture = load(sheet.file)
		atlas.texture_region_size = index.tile_size_vector
		if atlas.texture == null:
			push_error("Could not load sheet %s: %s" % [sheet_name, sheet.file])
			quit(1)
			return
		tile_set.add_source(atlas, index.source_ids[sheet_name])

	for tile_id in index.tiles:
		var address: Dictionary = index.tiles_by_id[tile_id]
		var atlas: TileSetAtlasSource = tile_set.get_source(address.source_id)
		var grid_size := atlas.get_atlas_grid_size()
		var coords: Vector2i = address.atlas_coords
		if coords.x >= grid_size.x or coords.y >= grid_size.y:
			push_error("Tile %s lies outside %s atlas: %s" % [tile_id, address.sheet, coords])
			quit(1)
			return
		if not atlas.has_tile(coords):
			atlas.create_tile(coords)
		var data: TileData = atlas.get_tile_data(coords, 0)
		var existing_id := String(data.get_custom_data(&"semantic_id"))
		data.set_custom_data(&"semantic_id", tile_id if existing_id.is_empty() else "%s | %s" % [existing_id, tile_id])
		if String(data.get_custom_data(&"description")).is_empty():
			data.set_custom_data(&"description", address.description)

	var error := ResourceSaver.save(tile_set, OUTPUT)
	if error != OK:
		push_error("Could not save %s: %s" % [OUTPUT, error])
		quit(1)
		return
	print("Built %s from %s." % [OUTPUT, TileIndex.INDEX_PATH])
	quit()
