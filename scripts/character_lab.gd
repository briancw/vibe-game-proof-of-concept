@tool
extends Node2D

## Isolated visual test bench for the parametric character work. It is not a
## game scene and does not modify the project main scene, so captures here are
## deterministic and easy to compare from iteration to iteration.

@onready var preview: CharacterPreview = $CharacterPreview
@onready var height_slider: HSlider = %HeightSlider
@onready var weight_slider: HSlider = %WeightSlider
@onready var hip_slider: HSlider = %HipSlider
@onready var bust_slider: HSlider = %BustSlider
@onready var skin_slider: HSlider = %SkinSlider
@onready var outfit_slider: HSlider = %OutfitSlider
@onready var preset_label: Label = %PresetLabel

var _preset_index := 0
var _presets := [
	{"height": 0.08, "weight": 0.0625, "hips": 0.075, "bust": 0.0375, "skin": 0.055, "outfit": 0},
	{"height": 0.1375, "weight": 0.125, "hips": 0.145, "bust": 0.125, "skin": 0.12, "outfit": 1},
	{"height": 0.205, "weight": 0.18, "hips": 0.195, "bust": 0.18, "skin": 0.195, "outfit": 2},
]


func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		return
	height_slider.value_changed.connect(_on_height_changed)
	weight_slider.value_changed.connect(_on_weight_changed)
	hip_slider.value_changed.connect(_on_hips_changed)
	bust_slider.value_changed.connect(_on_bust_changed)
	skin_slider.value_changed.connect(_on_skin_changed)
	outfit_slider.value_changed.connect(_on_outfit_changed)
	%PresetButton.pressed.connect(_cycle_preset)
	_apply_slider_values()
	if "--capture" in OS.get_cmdline_user_args():
		capture_screenshot.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_SPACE:
		_cycle_preset()


func _on_height_changed(value: float) -> void:
	preview.height = value


func _on_weight_changed(value: float) -> void:
	preview.weight = value


func _on_hips_changed(value: float) -> void:
	preview.hip_width = value


func _on_bust_changed(value: float) -> void:
	preview.bust_size = value


func _on_skin_changed(value: float) -> void:
	preview.skin_tone = value


func _on_outfit_changed(value: float) -> void:
	preview.outfit_index = int(value)


func _cycle_preset() -> void:
	_preset_index = (_preset_index + 1) % _presets.size()
	var preset: Dictionary = _presets[_preset_index]
	height_slider.value = preset.height
	weight_slider.value = preset.weight
	hip_slider.value = preset.hips
	bust_slider.value = preset.bust
	skin_slider.value = preset.skin
	outfit_slider.value = preset.outfit
	preset_label.text = "PRESET 0%d / 03" % (_preset_index + 1)


func _apply_slider_values() -> void:
	_on_height_changed(height_slider.value)
	_on_weight_changed(weight_slider.value)
	_on_hips_changed(hip_slider.value)
	_on_bust_changed(bust_slider.value)
	_on_skin_changed(skin_slider.value)
	_on_outfit_changed(outfit_slider.value)


func _draw() -> void:
	# The left card uses a 16 px tile grid, exactly matching the room scale.
	draw_rect(Rect2(0, 0, 320, 240), Color("171923"), true)
	draw_rect(Rect2(12, 28, 148, 198), Color("202534"), true)
	draw_rect(Rect2(12, 28, 148, 198), Color("465064"), false, 1.0)
	for x in range(20, 160, 16):
		draw_line(Vector2(x, 36), Vector2(x, 218), Color("2b3345"), 1.0, false)
	for y in range(42, 219, 16):
		draw_line(Vector2(20, y), Vector2(152, y), Color("2b3345"), 1.0, false)
	draw_line(Vector2(20, 202), Vector2(152, 202), Color("8c7183"), 1.0, false)
	_draw_text(Vector2(12, 18), "CHARACTER LAB / BODY STUDY", 10, Color("e7dfd0"))
	_draw_text(Vector2(21, 42), "16 PX TILE SCALE", 7, Color("8fa0b6"))
	_draw_text(Vector2(21, 216), "LAYERED BODY + CLOTHING", 7, Color("8fa0b6"))


func _draw_text(position: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func capture_screenshot() -> void:
	# Two frames ensure all Control theme and draw updates reach the viewport.
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://character_lab.png")
	get_tree().quit()
