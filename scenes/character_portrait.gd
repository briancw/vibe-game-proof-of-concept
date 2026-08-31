extends Node2D

## Renders a single generated character with no background or other details.
## The character is drawn into a viewport sized exactly to one sprite frame at
## 6x (96x192 for the 16x32 generated strips), so `capture()` produces a
## tightly cropped, transparent screenshot of just the character with
## deterministic dimensions. The character ID comes from the exported
## `character_id` (or the first configured character when empty) and can be
## overridden on the command line with `--character-id=<id>`.

const PORTRAIT_SCALE := 6.0

@export var character_id := &""
@export var animation := &"stand"
@export var facing := &"down"

var character: CharacterSprite
var portrait_viewport: SubViewport


func _ready() -> void:
	get_viewport().transparent_bg = true
	var requested := _requested_character_id()
	if not requested.is_empty():
		character_id = requested
	if character_id.is_empty():
		var ids := GeneratedCharacters.character_ids()
		if ids.is_empty():
			push_error("No generated characters are configured.")
			return
		character_id = ids[0]
	var sheet := GeneratedCharacters.load_sheet(character_id)
	if sheet == null:
		return
	var frame_size := Vector2(sheet.frame_size)
	portrait_viewport = SubViewport.new()
	portrait_viewport.size = Vector2i(frame_size * PORTRAIT_SCALE)
	portrait_viewport.transparent_bg = true
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Subviewports do not inherit the project's nearest-neighbor texture filter.
	portrait_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(portrait_viewport)
	character = CharacterSprite.new()
	character.show_shadow = false
	character.scale = Vector2(PORTRAIT_SCALE, PORTRAIT_SCALE)
	character.position = Vector2(frame_size.x * 0.5, frame_size.y) * PORTRAIT_SCALE
	character.sheet = sheet
	character.animation = animation
	character.facing = facing
	portrait_viewport.add_child(character)
	var display := Sprite2D.new()
	display.texture = portrait_viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.position = get_viewport_rect().size * 0.5
	add_child(display)
	if "--capture" in OS.get_cmdline_user_args():
		_capture_and_quit.call_deferred()


## Saves a screenshot cropped to exactly the character's sprite frame and
## returns the path it was written to.
func capture(output_path := "") -> String:
	if output_path.is_empty():
		output_path = "user://character_portrait_%s.png" % character_id
	await get_tree().process_frame
	await get_tree().process_frame
	portrait_viewport.get_texture().get_image().save_png(output_path)
	print("Saved character portrait: %s" % ProjectSettings.globalize_path(output_path))
	return output_path


func _capture_and_quit() -> void:
	await capture()
	get_tree().quit()


func _requested_character_id() -> StringName:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--character-id="):
			return StringName(argument.trim_prefix("--character-id="))
	return &""
