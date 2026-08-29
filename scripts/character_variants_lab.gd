extends Node2D

## Capture-only contact sheet: every hair style across every outfit at game
## scale on a 16 px tile grid, for grading the modular style system in one
## image. Rows vary hair style (and hair colour), columns vary outfit and
## skin tone.

const PREVIEW_SCENE := preload("res://scenes/character_preview.tscn")

# Row-major [hair_style, hair_color] and per-column [outfit, skin_tone, eyes].
const ROWS := [
	{"hair": 0, "hair_color": 1},
	{"hair": 1, "hair_color": 3},
	{"hair": 2, "hair_color": 0},
	{"hair": 3, "hair_color": 2},
]
const COLUMNS := [
	{"outfit": 0, "skin": 0.05, "eyes": 0},
	{"outfit": 1, "skin": 0.115, "eyes": 1},
	{"outfit": 2, "skin": 0.185, "eyes": 2},
	{"outfit": 3, "skin": 0.08, "eyes": 0},
	{"outfit": 4, "skin": 0.15, "eyes": 1},
]
const ORIGIN := Vector2(52.0, 66.0)
const CELL := Vector2(54.0, 52.0)


func _ready() -> void:
	for row in range(ROWS.size()):
		for column in range(COLUMNS.size()):
			var preview: CharacterPreview = PREVIEW_SCENE.instantiate()
			preview.position = ORIGIN + Vector2(float(column) * CELL.x, float(row) * CELL.y)
			preview.height = 0.1375
			preview.weight = 0.125
			preview.hip_width = 0.145
			preview.bust_size = 0.125
			preview.skin_tone = COLUMNS[column].skin
			preview.outfit_index = COLUMNS[column].outfit
			preview.hair_index = ROWS[row].hair
			preview.hair_color_index = ROWS[row].hair_color
			preview.eye_index = COLUMNS[column].eyes
			add_child(preview)
	if "--variants-capture" in OS.get_cmdline_user_args():
		capture_screenshot.call_deferred()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 240), Color("2b2733"), true)
	# A warm floor band and 16 px grid echo the game room's visual language.
	draw_rect(Rect2(0, 30, 320, 210), Color("8a6a4a"), true)
	for x in range(0, 321, 16):
		draw_line(Vector2(x, 30), Vector2(x, 240), Color(0, 0, 0, 0.06), 1.0, false)
	for y in range(30, 241, 16):
		draw_line(Vector2(0, y), Vector2(320, y), Color(0, 0, 0, 0.06), 1.0, false)
	_draw_text(Vector2(8, 14), "CHARACTER VARIANTS / HAIR STYLES x OUTFITS", 9, Color("f2e6d0"))
	_draw_text(Vector2(8, 25), "GAME SCALE / 16 PX TILES", 6, Color("d9c9a8"))
	for column in range(COLUMNS.size()):
		_draw_text(Vector2(ORIGIN.x - 18 + column * CELL.x, 40), "OUTFIT %d" % COLUMNS[column].outfit, 6, Color("f2e6d0"))
	for row in range(ROWS.size()):
		_draw_text(Vector2(4, ORIGIN.y + 2 + row * CELL.y), "HAIR %d" % ROWS[row].hair, 6, Color("f2e6d0"))


func _draw_text(position: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func capture_screenshot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://character_variants.png")
	get_tree().quit()
