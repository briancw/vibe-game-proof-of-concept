extends Node2D

## Capture-only strip of the idle animation: the same character rendered at
## successive idle_phase values, so the breathing frames and the blink frame
## can be graded in still captures exactly as they will appear in motion.
## Every instance has animate=false; the phase is set explicitly.

const PREVIEW_SCENE := preload("res://character/character_preview.tscn")

# Breathing alternates up/down every IDLE_FRAME_SECONDS (0.75 s); the blink
# occupies the last 0.26 s of every 4.6 s. The last entry samples that window.
const PHASES := [0.0, 0.75, 1.5, 2.25, 4.4]
const ORIGIN := Vector2(56.0, 176.0)
const SPACING := 56.0


func _ready() -> void:
	for index in range(PHASES.size()):
		var preview: CharacterPreview = PREVIEW_SCENE.instantiate()
		preview.position = ORIGIN + Vector2(float(index) * SPACING, 0.0)
		preview.animate = false
		preview.idle_phase = PHASES[index]
		preview.height = 0.1375
		preview.weight = 0.125
		preview.hip_width = 0.145
		preview.bust_size = 0.125
		preview.skin_tone = 0.115
		preview.outfit_index = 0
		preview.hair_index = 1
		preview.hair_color_index = 1
		add_child(preview)
	if "--idle-capture" in OS.get_cmdline_user_args():
		capture_screenshot.call_deferred()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 240), Color("2b2733"), true)
	draw_rect(Rect2(0, 40, 320, 200), Color("8a6a4a"), true)
	for x in range(0, 321, 16):
		draw_line(Vector2(x, 40), Vector2(x, 240), Color(0, 0, 0, 0.06), 1.0, false)
	for y in range(40, 241, 16):
		draw_line(Vector2(0, y), Vector2(320, y), Color(0, 0, 0, 0.06), 1.0, false)
	_draw_text(Vector2(8, 14), "IDLE ANIMATION / BREATHING + BLINK", 9, Color("f2e6d0"))
	_draw_text(Vector2(8, 25), "PHASE STRIP / 0.75 S PER FRAME", 6, Color("d9c9a8"))
	for index in range(PHASES.size()):
		var label := "T=%.2f" % PHASES[index]
		if index == PHASES.size() - 1:
			label = "BLINK"
		_draw_text(Vector2(ORIGIN.x - 22 + index * SPACING, 222), label, 6, Color("f2e6d0"))


func _draw_text(position: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func capture_screenshot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://character_idle.png")
	get_tree().quit()
