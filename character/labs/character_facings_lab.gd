extends Node2D

## Capture-only sheet grading the four facings (down, right, left, up) across
## four style combinations chosen to stress different subsystems: long hair
## with the meadow dress, the sweater with stoic eyes, overalls with angled
## eyes, and the ponytail with the bikini. Left must mirror right exactly.

const PREVIEW_SCENE := preload("res://character/character_preview.tscn")

# Row-major [hair, hair_color, outfit, skin, eyes].
const COMBOS := [
	{"hair": 1, "hair_color": 1, "outfit": 0, "skin": 0.115, "eyes": 0},
	{"hair": 2, "hair_color": 3, "outfit": 1, "skin": 0.05, "eyes": 1},
	{"hair": 0, "hair_color": 0, "outfit": 2, "skin": 0.185, "eyes": 2},
	{"hair": 3, "hair_color": 2, "outfit": 4, "skin": 0.08, "eyes": 0},
]
const FACINGS := [0, 1, 2, 3]
const FACING_NAMES := ["DOWN", "RIGHT", "LEFT", "UP"]
const ORIGIN := Vector2(72.0, 64.0)
const CELL := Vector2(62.0, 52.0)


func _ready() -> void:
	for row in range(FACINGS.size()):
		for column in range(COMBOS.size()):
			var combo: Dictionary = COMBOS[column]
			var preview: CharacterPreview = PREVIEW_SCENE.instantiate()
			preview.position = ORIGIN + Vector2(float(column) * CELL.x, float(row) * CELL.y)
			preview.animate = false
			preview.height = 0.1375
			preview.weight = 0.125
			preview.hip_width = 0.145
			preview.bust_size = 0.125
			preview.skin_tone = combo.skin
			preview.outfit_index = combo.outfit
			preview.hair_index = combo.hair
			preview.hair_color_index = combo.hair_color
			preview.eye_index = combo.eyes
			preview.facing = FACINGS[row]
			add_child(preview)
	if "--facings-capture" in OS.get_cmdline_user_args():
		capture_screenshot.call_deferred()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 240), Color("2b2733"), true)
	draw_rect(Rect2(0, 30, 320, 210), Color("8a6a4a"), true)
	for x in range(0, 321, 16):
		draw_line(Vector2(x, 30), Vector2(x, 240), Color(0, 0, 0, 0.06), 1.0, false)
	for y in range(30, 241, 16):
		draw_line(Vector2(0, y), Vector2(320, y), Color(0, 0, 0, 0.06), 1.0, false)
	_draw_text(Vector2(8, 14), "CHARACTER FACINGS / DOWN RIGHT LEFT UP", 9, Color("f2e6d0"))
	_draw_text(Vector2(8, 25), "16 PX TILES / MIRRORED LEFT", 6, Color("d9c9a8"))
	for column in range(COMBOS.size()):
		_draw_text(Vector2(ORIGIN.x - 18 + column * CELL.x, 40), "OUTFIT %d" % COMBOS[column].outfit, 6, Color("f2e6d0"))
	for row in range(FACINGS.size()):
		_draw_text(Vector2(2, ORIGIN.y + 2 + row * CELL.y), FACING_NAMES[row], 6, Color("f2e6d0"))


func _draw_text(position: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func capture_screenshot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://character_facings.png")
	get_tree().quit()
