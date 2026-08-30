extends Node2D

## Capture-only close-up sheet: one character, the room-scene signature look,
## rendered large in the down, right, and up facings for quality assessment.

const PREVIEW_SCENE := preload("res://character/character_preview.tscn")

const SPECS := [
	{"facing": 0, "label": "FRONT"},
	{"facing": 1, "label": "RIGHT"},
	{"facing": 3, "label": "BACK"},
]
const SPACING := 34.0


func _ready() -> void:
	for index in range(SPECS.size()):
		var preview: CharacterPreview = PREVIEW_SCENE.instantiate()
		preview.position = Vector2(float(index) * SPACING, 0.0)
		preview.animate = false
		preview.height = 0.1375
		preview.weight = 0.125
		preview.hip_width = 0.145
		preview.bust_size = 0.125
		preview.skin_tone = 0.115
		preview.outfit_index = 5
		preview.hair_index = 1
		preview.hair_color_index = 1
		preview.facing = SPECS[index].facing
		add_child(preview)
	var camera := Camera2D.new()
	camera.position = Vector2(SPACING, -17.0)
	camera.zoom = Vector2(3.2, 3.2)
	add_child(camera)
	if "--closeup-capture" in OS.get_cmdline_user_args():
		capture_screenshot.call_deferred()


func _draw() -> void:
	var left := -SPACING * 0.5 - 8.0
	var right := SPACING * 2.5 + 8.0
	draw_rect(Rect2(left, -60.0, right - left, 80.0), Color("2b2733"), true)
	for index in range(SPECS.size()):
		var center_x := float(index) * SPACING
		_draw_text(Vector2(center_x - 10.0, 12.0), SPECS[index].label, 4, Color("f2e6d0"))


func _draw_text(position: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func capture_screenshot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://character_closeup.png")
	get_tree().quit()
