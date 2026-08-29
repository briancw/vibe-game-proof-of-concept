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
	_place_player(layout, grid_size, tile_size)

	var tiles: Dictionary = index.tiles_by_id
	for layer_data in layout.get("layers", []):
		_build_tile_layer(layer_data, tiles, grid_size)
	_build_props(layout.get("props", []), index.props, index.sheets, tile_size)
	_build_room_boundaries(grid_size, tile_size)


func _place_player(layout: Dictionary, grid_size: Vector2i, tile_size: Vector2i) -> void:
	var player := get_node_or_null("Player") as CharacterBody2D
	if player == null or not layout.has("player_start"):
		return
	var start_cell := _as_vector(layout.player_start)
	if start_cell.x < 0 or start_cell.y < 0 or start_cell.x >= grid_size.x or start_cell.y >= grid_size.y:
		push_error("Room player_start must be inside grid_size.")
		return
	player.position = (Vector2(start_cell) + Vector2(0.5, 0.5)) * Vector2(tile_size)


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
				var top_rows: Array = operation.get("top_rows", [operation.get("top", "")])
				for row in range(top_rows.size()):
					for x in range(grid_size.x):
						_place_tile(map, Vector2i(x, row - top_rows.size()), top_rows[row], tiles)
				for x in range(grid_size.x):
					_place_tile(map, Vector2i(x, grid_size.y), operation.get("bottom", ""), tiles)
				for y in range(-top_rows.size() + 1, grid_size.y):
					_place_tile(map, Vector2i(-1, y), operation.get("left", ""), tiles)
					_place_tile(map, Vector2i(grid_size.x, y), operation.get("right", ""), tiles)
				_place_tile(map, Vector2i(-1, -top_rows.size()), operation.get("top_left", ""), tiles)
				_place_tile(map, Vector2i(grid_size.x, -top_rows.size()), operation.get("top_right", ""), tiles)
				_place_tile(map, Vector2i(-1, grid_size.y), operation.get("bottom_left", ""), tiles)
				_place_tile(map, Vector2i(grid_size.x, grid_size.y), operation.get("bottom_right", ""), tiles)
			_:
				push_error("Unknown room operation: %s" % operation.get("type", ""))


func _place_tile(map: TileMapLayer, cell: Vector2i, tile_name: String, tiles: Dictionary) -> void:
	var tile: Dictionary = tiles.get(tile_name, {})
	if tile.is_empty():
		push_error("Unknown tile ID: %s" % tile_name)
		return
	map.set_cell(cell, tile.source_id, tile.atlas_coords, tile.alternative_id)


func _build_props(prop_data: Array, definitions: Dictionary, sheets: Dictionary, tile_size: Vector2i) -> void:
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
		sprite.texture = _prop_texture(definition, sheets, tile_size)
		var anchor: String = definition.get("anchor", "bottom_left")
		_apply_prop_anchor(sprite, anchor)
		sprite.position = _as_vector(placement.get("at", [])) * tile_size
		if anchor.begins_with("bottom_"):
			sprite.position.y += tile_size.y
		sprite.z_index = int(placement.get("z_index", 2))
		props.add_child(sprite)


func _build_room_boundaries(grid_size: Vector2i, tile_size: Vector2i) -> void:
	# Keep the player within the authored floor. Furniture collision will be
	# added with prop metadata later; this only supplies the room perimeter.
	var boundaries := StaticBody2D.new()
	boundaries.name = "RoomBoundaries"
	boundaries.collision_layer = 1
	boundaries.collision_mask = 1
	_generated.add_child(boundaries)

	var width := float(grid_size.x * tile_size.x)
	var height := float(grid_size.y * tile_size.y)
	var thickness := float(tile_size.x)
	_add_boundary(boundaries, Vector2(width * 0.5, -thickness * 0.5), Vector2(width + thickness * 2.0, thickness))
	_add_boundary(boundaries, Vector2(width * 0.5, height + thickness * 0.5), Vector2(width + thickness * 2.0, thickness))
	_add_boundary(boundaries, Vector2(-thickness * 0.5, height * 0.5), Vector2(thickness, height))
	_add_boundary(boundaries, Vector2(width + thickness * 0.5, height * 0.5), Vector2(thickness, height))


func _add_boundary(parent: StaticBody2D, position: Vector2, size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position
	parent.add_child(collision)


func _prop_texture(definition: Dictionary, sheets: Dictionary, tile_size: Vector2i) -> Texture2D:
	if definition.has("texture"):
		return load(definition.texture)
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = load(sheets[definition.sheet].file)
	var atlas := _as_vector(definition.get("atlas", []))
	var size := _as_vector(definition.get("size", [1, 1]))
	atlas_texture.region = Rect2(Vector2(atlas * tile_size), Vector2(size * tile_size))
	return atlas_texture


func _apply_prop_anchor(sprite: Sprite2D, anchor: String) -> void:
	sprite.centered = false
	match anchor:
		"top_left":
			sprite.offset = Vector2.ZERO
		"bottom_left": # Align to the lower edge of the authored floor cell.
			var used_rect := sprite.texture.get_image().get_used_rect()
			sprite.offset = Vector2(-used_rect.position.x, -used_rect.position.y - used_rect.size.y)
		"bottom_center": # Center the visible artwork in the authored floor cell.
			var used_rect := sprite.texture.get_image().get_used_rect()
			sprite.offset = Vector2(
				TILE_SET.tile_size.x * 0.5 - used_rect.position.x - used_rect.size.x * 0.5,
				-used_rect.position.y - used_rect.size.y
			)
		_:
			push_error("Unknown prop anchor: %s" % anchor)


func _as_vector(value: Array) -> Vector2i:
	if value.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(value[0]), int(value[1]))


func capture_screenshot() -> void:
	var layout := _read_json(layout_path)
	var tile_size := TILE_SET.tile_size
	var grid_size := _as_vector(layout.get("grid_size", []))
	var top_frame_height := _top_frame_height(layout)
	var player_camera := get_node_or_null("Player/Camera2D") as Camera2D
	if player_camera != null:
		player_camera.enabled = false
	var camera := Camera2D.new()
	var top_left := Vector2(-tile_size.x, -top_frame_height * tile_size.y)
	var bottom_right := Vector2((grid_size.x + 1) * tile_size.x, (grid_size.y + 1) * tile_size.y)
	camera.position = (top_left + bottom_right) * 0.5
	add_child(camera)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://room.png")
	get_tree().quit()


func _top_frame_height(layout: Dictionary) -> int:
	var height := 1
	for layer_data in layout.get("layers", []):
		for operation in layer_data.get("operations", []):
			if operation.get("type", "") != "frame":
				continue
			var top_rows: Variant = operation.get("top_rows", [operation.get("top", "")])
			if top_rows is Array:
				height = max(height, top_rows.size())
	return height
