@tool
extends Node2D

## YAML is the authored room format. This script renders the same layout in
## the editor, during play, and when screenshot capture passes --capture.

const TILE_SET := preload("res://tiles/interiors_tileset.tres")
const TileIndex = preload("res://scripts/tile_index.gd")
const RoomLayoutLoader = preload("res://scripts/room_layout_loader.gd")

@export_file("*.yaml", "*.yml", "*.json") var layout_path := "res://rooms/living_room.yaml":
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
	var layout := _read_json(layout_path)
	var index := TileIndex.load_index()
	if layout.is_empty() or index.is_empty():
		return
	if is_instance_valid(_generated):
		_generated.queue_free()

	_generated = Node2D.new()
	_generated.name = "GeneratedRoom"
	add_child(_generated)

	var grid_size := _as_vector(layout.get("grid_size", []))
	var tile_size := TILE_SET.tile_size
	if grid_size.x <= 0 or grid_size.y <= 0 or tile_size.x <= 0 or tile_size.y <= 0:
		push_error("Room layout needs positive grid_size and tile_size values.")
		return

	var tiles: Dictionary = index.tiles_by_id
	for layer_data in layout.get("layers", []):
		_build_tile_layer(layer_data, tiles, grid_size)
	_build_props(layout.get("props", []), index.props, tile_size)


func _read_json(path: String) -> Dictionary:
	return RoomLayoutLoader.load_layout(path)


func _build_tile_layer(layer_data: Dictionary, tiles: Dictionary, grid_size: Vector2i) -> void:
	var map := TileMapLayer.new()
	map.name = layer_data.get("name", "TileLayer")
	map.z_index = int(layer_data.get("z_index", 0))
	map.tile_set = TILE_SET
	_generated.add_child(map)

	for operation in layer_data.get("operations", []):
		match operation.get("type", ""):
			"fill":
				for y in range(grid_size.y):
					for x in range(grid_size.x):
						_place_tile(map, Vector2i(x, y), operation.get("tile", ""), tiles)
			"frame":
				for x in range(-1, grid_size.x + 1):
					_place_tile(map, Vector2i(x, -1), operation.get("top", ""), tiles)
					_place_tile(map, Vector2i(x, grid_size.y), operation.get("bottom", ""), tiles)
				for y in range(grid_size.y):
					_place_tile(map, Vector2i(-1, y), operation.get("left", ""), tiles)
					_place_tile(map, Vector2i(grid_size.x, y), operation.get("right", ""), tiles)
			_:
				push_error("Unknown room operation: %s" % operation.get("type", ""))


func _place_tile(map: TileMapLayer, cell: Vector2i, tile_name: String, tiles: Dictionary) -> void:
	var tile: Dictionary = tiles.get(tile_name, {})
	if tile.is_empty():
		push_error("Unknown tile ID: %s" % tile_name)
		return
	map.set_cell(cell, tile.source_id, tile.atlas_coords, tile.alternative_id)


func _build_props(prop_data: Array, definitions: Dictionary, tile_size: Vector2i) -> void:
	var props := Node2D.new()
	props.name = "Props"
	_generated.add_child(props)
	for placement in prop_data:
		var prop_id: String = placement.get("id", "")
		var definition: Dictionary = definitions.get(prop_id, {})
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
	var tile_size := TILE_SET.tile_size
	var grid_size := _as_vector(layout.get("grid_size", []))
	var camera := Camera2D.new()
	camera.position = Vector2(grid_size * tile_size) * 0.5
	add_child(camera)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://room.png")
	get_tree().quit()
