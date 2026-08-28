@tool
extends SceneTree

## Materializes YAML layouts as ordinary TileMapLayer scenes for editor inspection.
## Run: godot --headless --path . --script res://scripts/generate_debug_scenes.gd

const TILE_SET := preload("res://tiles/interiors_tileset.tres")
const TileIndex = preload("res://scripts/tile_index.gd")
const RoomLayoutLoader = preload("res://scripts/room_layout_loader.gd")
const OUTPUT_DIR := "res://scenes/generated"


func _initialize() -> void:
	var index := TileIndex.load_index()
	if index.is_empty():
		quit(1)
		return
	var tiles: Dictionary = index.tiles_by_id
	var directory := DirAccess.open("res://rooms")
	if directory == null:
		push_error("Could not open res://rooms")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for filename in directory.get_files():
		if filename.get_extension().to_lower() not in ["yaml", "yml"]:
			continue
		var layout_path := "res://rooms/%s" % filename
		var layout := _read_json(layout_path)
		if layout.is_empty():
			quit(1)
			return
		var root := _build_room(layout, tiles, index.props, index.sheets)
		var output_path := "%s/%s_debug.tscn" % [OUTPUT_DIR, filename.get_basename()]
		var packed := PackedScene.new()
		var error := packed.pack(root)
		if error == OK:
			error = ResourceSaver.save(packed, output_path)
		if error != OK:
			push_error("Could not save %s: %s" % [output_path, error])
			quit(1)
			return
		print("Generated %s" % output_path)
	quit()


func _build_room(layout: Dictionary, tiles: Dictionary, prop_definitions: Dictionary, sheets: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.name = "%sDebug" % String(layout.get("name", "Room")).replace(" ", "")
	root.set_meta("source_layout", layout)
	for layer_data in layout.get("layers", []):
		var layer := TileMapLayer.new()
		layer.name = layer_data.get("name", "TileLayer")
		layer.z_index = int(layer_data.get("z_index", 0))
		layer.tile_set = TILE_SET
		root.add_child(layer)
		layer.owner = root
		_build_layer(layer, layer_data, _as_vector(layout.get("grid_size", [])), tiles)
	_build_props(root, layout.get("props", []), prop_definitions, sheets)
	return root


func _build_layer(layer: TileMapLayer, layer_data: Dictionary, grid_size: Vector2i, tiles: Dictionary) -> void:
	for operation in layer_data.get("operations", []):
		match operation.get("type", ""):
			"fill":
				for y in grid_size.y:
					for x in grid_size.x:
						_place(layer, Vector2i(x, y), operation.get("tile", ""), tiles)
			"frame":
				var top_rows: Array = operation.get("top_rows", [operation.get("top", "")])
				for row in range(top_rows.size()):
					for x in range(grid_size.x):
						_place(layer, Vector2i(x, row - top_rows.size()), top_rows[row], tiles)
				for x in range(grid_size.x):
					_place(layer, Vector2i(x, grid_size.y), operation.get("bottom", ""), tiles)
				for y in range(-top_rows.size() + 1, grid_size.y):
					_place(layer, Vector2i(-1, y), operation.get("left", ""), tiles)
					_place(layer, Vector2i(grid_size.x, y), operation.get("right", ""), tiles)
				_place(layer, Vector2i(-1, -top_rows.size()), operation.get("top_left", ""), tiles)
				_place(layer, Vector2i(grid_size.x, -top_rows.size()), operation.get("top_right", ""), tiles)
				_place(layer, Vector2i(-1, grid_size.y), operation.get("bottom_left", ""), tiles)
				_place(layer, Vector2i(grid_size.x, grid_size.y), operation.get("bottom_right", ""), tiles)


func _place(layer: TileMapLayer, cell: Vector2i, semantic_id: String, tiles: Dictionary) -> void:
	var tile: Dictionary = tiles.get(semantic_id, {})
	if tile.is_empty():
		push_error("Unknown TileSet semantic_id: %s" % semantic_id)
		return
	layer.set_cell(cell, tile.source_id, tile.atlas_coords, tile.alternative_id)


func _build_props(root: Node2D, placements: Array, definitions: Dictionary, sheets: Dictionary) -> void:
	var props := Node2D.new()
	props.name = "Props"
	root.add_child(props)
	props.owner = root
	for placement in placements:
		var definition: Dictionary = definitions.get(placement.get("id", ""), {})
		if definition.is_empty():
			push_error("Unknown prop ID: %s" % placement.get("id", ""))
			continue
		var sprite := Sprite2D.new()
		sprite.name = String(placement.get("id", "Prop")).replace(".", "_")
		sprite.texture = _prop_texture(definition, sheets, TILE_SET.tile_size)
		var anchor: String = definition.get("anchor", "bottom_left")
		_apply_prop_anchor(sprite, anchor)
		sprite.position = _as_vector(placement.get("at", [])) * TILE_SET.tile_size
		if anchor.begins_with("bottom_"):
			sprite.position.y += TILE_SET.tile_size.y
		sprite.z_index = int(placement.get("z_index", 2))
		props.add_child(sprite)
		sprite.owner = root


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


func _read_json(path: String) -> Dictionary:
	return RoomLayoutLoader.load_layout(path)


func _as_vector(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1])) if value.size() == 2 else Vector2i.ZERO
