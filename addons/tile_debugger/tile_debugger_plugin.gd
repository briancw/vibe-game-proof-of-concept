@tool
extends EditorPlugin

const TileIndex = preload("res://scripts/tile_index.gd")

class AtlasCanvas extends Control:
	var atlas_texture: Texture2D
	var tile_size := Vector2i.ONE
	var zoom := 1.0

	func set_atlas(texture: Texture2D, cell_size: Vector2i) -> void:
		atlas_texture = texture
		tile_size = cell_size
		_refresh_size()

	func set_zoom(value: float) -> void:
		zoom = clampf(value, 0.25, 8.0)
		_refresh_size()

	func _refresh_size() -> void:
		custom_minimum_size = Vector2.ZERO if atlas_texture == null else atlas_texture.get_size() * zoom
		queue_redraw()

	func _draw() -> void:
		if atlas_texture == null:
			return
		var texture_size := atlas_texture.get_size()
		var scaled_size := texture_size * zoom
		draw_texture_rect(atlas_texture, Rect2(Vector2.ZERO, scaled_size), false)
		var grid_color := Color(1.0, 0.82, 0.15, 0.72)
		for x in range(0, int(texture_size.x) + 1, tile_size.x):
			draw_line(Vector2(x * zoom, 0), Vector2(x * zoom, scaled_size.y), grid_color)
		for y in range(0, int(texture_size.y) + 1, tile_size.y):
			draw_line(Vector2(0, y * zoom), Vector2(scaled_size.x, y * zoom), grid_color)
		draw_rect(Rect2(Vector2.ZERO, scaled_size), grid_color, false)

var _layer: TileMapLayer
var _output: RichTextLabel
var _index: Dictionary
var _picker: VBoxContainer
var _sheet_picker: OptionButton
var _atlas_canvas: AtlasCanvas
var _picker_status: RichTextLabel
var _zoom_label: Label
var _picker_zoom := 1.0


func _enter_tree() -> void:
	_index = TileIndex.load_index()
	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.fit_content = true
	_output.custom_minimum_size = Vector2(420, 88)
	_output.text = "Select a TileMapLayer, then [b]Alt-click[/b] a cell in the 2D viewport."
	add_control_to_bottom_panel(_output, "Tile Inspector")
	_build_atlas_picker()


func _exit_tree() -> void:
	if _output:
		remove_control_from_bottom_panel(_output)
		_output.queue_free()
	if _picker:
		remove_control_from_bottom_panel(_picker)
		_picker.queue_free()


func _build_atlas_picker() -> void:
	_picker = VBoxContainer.new()
	_picker.custom_minimum_size = Vector2(480, 280)
	var toolbar := HBoxContainer.new()
	_picker.add_child(toolbar)
	_sheet_picker = OptionButton.new()
	_sheet_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_sheet_picker)
	for sheet_name in _index.get("source_ids", {}):
		_sheet_picker.add_item(sheet_name)
	var reload := Button.new()
	reload.text = "Reload index"
	reload.pressed.connect(_reload_index)
	toolbar.add_child(reload)
	var zoom_out := Button.new()
	zoom_out.text = "−"
	zoom_out.tooltip_text = "Zoom out"
	zoom_out.pressed.connect(_change_picker_zoom.bind(-0.25))
	toolbar.add_child(zoom_out)
	_zoom_label = Label.new()
	_zoom_label.custom_minimum_size.x = 60
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar.add_child(_zoom_label)
	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.tooltip_text = "Zoom in"
	zoom_in.pressed.connect(_change_picker_zoom.bind(0.25))
	toolbar.add_child(zoom_in)
	_picker_status = RichTextLabel.new()
	_picker_status.bbcode_enabled = true
	_picker_status.fit_content = true
	_picker_status.custom_minimum_size = Vector2(0, 62)
	_picker.add_child(_picker_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker.add_child(scroll)
	_atlas_canvas = AtlasCanvas.new()
	_atlas_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_atlas_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_atlas_canvas.gui_input.connect(_atlas_gui_input)
	scroll.add_child(_atlas_canvas)
	_sheet_picker.item_selected.connect(_select_sheet)
	add_control_to_bottom_panel(_picker, "Atlas Picker")
	if _sheet_picker.item_count > 0:
		_select_sheet(0)
	else:
		_picker_status.text = "[color=orange]Tile index could not be loaded.[/color]"


func _reload_index() -> void:
	_index = TileIndex.load_index()
	_sheet_picker.clear()
	for sheet_name in _index.get("source_ids", {}):
		_sheet_picker.add_item(sheet_name)
	if _sheet_picker.item_count > 0:
		_select_sheet(0)


func _select_sheet(item_index: int) -> void:
	var sheet_name := _sheet_picker.get_item_text(item_index)
	var sheet: Dictionary = _index.sheets.get(sheet_name, {})
	var texture: Texture2D = load(sheet.get("file", ""))
	if texture == null:
		_picker_status.text = "[color=red]Could not load %s[/color]" % sheet.get("file", "")
		return
	_atlas_canvas.set_atlas(texture, _index.tile_size_vector)
	_set_picker_zoom(_picker_zoom)
	_picker_status.text = "Click an atlas cell to copy a YAML starter. Use the zoom controls or [b]Ctrl + mouse wheel[/b]. [b]Sheet:[/b] %s" % sheet_name


func _change_picker_zoom(amount: float) -> void:
	_set_picker_zoom(_picker_zoom + amount)


func _set_picker_zoom(value: float) -> void:
	_picker_zoom = clampf(value, 0.25, 8.0)
	if _atlas_canvas:
		_atlas_canvas.set_zoom(_picker_zoom)
	if _zoom_label:
		_zoom_label.text = "%d %%" % roundi(_picker_zoom * 100.0)


func _atlas_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.ctrl_pressed and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_picker_zoom(0.25)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_picker_zoom(-0.25)
			get_viewport().set_input_as_handled()
			return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var sheet_name := _sheet_picker.get_item_text(_sheet_picker.selected)
	var tile_size: Vector2i = _index.tile_size_vector
	var atlas := Vector2i(event.position / (Vector2(tile_size) * _picker_zoom))
	var source_id: int = _index.source_ids[sheet_name]
	var address_key := "%d:%d:%d" % [source_id, atlas.x, atlas.y]
	var known: Array = _index.tile_ids_by_address.get(address_key, [])
	var starter := "new.tile.id:\n  sheet: %s\n  atlas: [%d, %d]" % [sheet_name, atlas.x, atlas.y]
	DisplayServer.clipboard_set(starter)
	_picker_status.text = "[b]%s[/b] at [b](%d, %d)[/b] %s\nCopied:\n[code]%s[/code]" % [
		sheet_name,
		atlas.x,
		atlas.y,
		"— existing: %s" % ", ".join(PackedStringArray(known)) if not known.is_empty() else "",
		starter,
	]


func _handles(object: Object) -> bool:
	return object is TileMapLayer


func _edit(object: Object) -> void:
	_layer = object as TileMapLayer


func _clear() -> void:
	_layer = null


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _layer == null or _layer.tile_set == null:
		return false
	if not event is InputEventMouseButton:
		return false
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or not event.alt_pressed:
		return false
	var viewport := get_editor_interface().get_editor_viewport_2d()
	var canvas_position: Vector2 = viewport.global_canvas_transform.affine_inverse() * event.position
	var cell := _layer.local_to_map(_layer.to_local(canvas_position))
	_show_cell(cell)
	return true # Alt-click is inspector-only and never paints a tile.


func _show_cell(cell: Vector2i) -> void:
	var info := TileIndex.describe_cell(_layer, cell, _index)
	if info.is_empty():
		_output.text = "[b]Cell:[/b] %s\n(empty)" % cell
		return
	_output.text = "[b]Cell:[/b] %s    [b]Tile ID:[/b] %s\n[b]Source:[/b] %s (ID %s)    [b]Atlas:[/b] %s    [b]Alternative:[/b] %s\n%s" % [
		info.cell,
		info.semantic_id if not info.semantic_id.is_empty() else "(unnamed)",
		info.source_name,
		info.source_id,
		info.atlas_coords,
		info.alternative_id,
		info.description,
	]
