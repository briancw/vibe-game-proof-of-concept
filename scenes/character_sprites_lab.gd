extends Node2D

## Visual test bench for generated compact-strip characters. It reads the
## YAML appearance list; gameplay can load a known character ID directly.

const FOCUS_SCALE := 4.0
const FLOOR_Y := 176.0

var character_ids: Array[StringName] = []
var character_index := 0
var animation_bases: Array[StringName] = []
var anim_index := 0
var focused := true
var sheets: Dictionary = {}

var focus: CharacterSprite
@onready var sheet_label: Label = %SheetLabel
@onready var anim_label: Label = %AnimLabel
@onready var pause_button: Button = %PauseButton


func _ready() -> void:
    character_ids = GeneratedCharacters.character_ids()
    if character_ids.is_empty():
        push_error("No generated characters are configured.")
        return
    focus = CharacterSprite.new()
    focus.position = Vector2(160, FLOOR_Y)
    focus.scale = Vector2(FOCUS_SCALE, FOCUS_SCALE)
    add_child(focus)
    %PrevCharacterButton.pressed.connect(func() -> void: _cycle_character(-1))
    %NextCharacterButton.pressed.connect(func() -> void: _cycle_character(1))
    %PrevAnimButton.pressed.connect(func() -> void: _cycle_animation(-1))
    %NextAnimButton.pressed.connect(func() -> void: _cycle_animation(1))
    %PrevFacingButton.pressed.connect(func() -> void: _cycle_facing(-1))
    %NextFacingButton.pressed.connect(func() -> void: _cycle_facing(1))
    pause_button.pressed.connect(_toggle_playing)
    _apply_state()
    if "--capture" in OS.get_cmdline_user_args():
        _capture.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
    if Engine.is_editor_hint() or not event is InputEventKey:
        return
    if not event.is_pressed() or event.is_echo():
        return
    match event.keycode:
        KEY_TAB:
            _cycle_character(-1 if event.shift_pressed else 1)
        KEY_Q:
            _cycle_animation(-1)
        KEY_E:
            _cycle_animation(1)
        KEY_SPACE:
            _toggle_playing()
        KEY_LEFT, KEY_A:
            focus.facing = &"left"
        KEY_RIGHT, KEY_D:
            focus.facing = &"right"
        KEY_UP, KEY_W:
            focus.facing = &"up"
        KEY_DOWN, KEY_S:
            focus.facing = &"down"
        _:
            return
    _apply_state()


func _cycle_character(step: int) -> void:
    if character_ids.is_empty():
        return
    character_index = posmod(character_index + step, character_ids.size())
    _apply_state()


func _cycle_animation(step: int) -> void:
    if animation_bases.is_empty():
        return
    anim_index = posmod(anim_index + step, animation_bases.size())
    _snap_facing()
    _apply_state()


func _cycle_facing(step: int) -> void:
    var facings: Array[StringName] = focus.sheet.facings_for(animation_bases[anim_index])
    if facings.is_empty():
        return
    var index := maxi(facings.find(focus.facing), 0)
    focus.facing = facings[posmod(index + step, facings.size())]
    _apply_state()


## Returns the facing to a playable one when the new animation cannot play the
## current facing (e.g. sit has no up/down art).
func _snap_facing() -> void:
    var facings: Array[StringName] = focus.sheet.facings_for(animation_bases[anim_index])
    if not facings.is_empty() and not facings.has(focus.facing):
        focus.facing = facings[0]


func _toggle_playing() -> void:
    focused = not focused
    _apply_state()


func _apply_state() -> void:
    var sheet := _current_sheet()
    if sheet == null:
        return
    focus.sheet = sheet
    animation_bases = _animation_bases(sheet)
    if animation_bases.is_empty():
        push_error("Generated character '%s' has no animations." % character_ids[character_index])
        return
    anim_index = posmod(anim_index, animation_bases.size())
    focus.animation = animation_bases[anim_index]
    _snap_facing()
    focus.playing = focused
    sheet_label.text = "CHARACTER %02d/%02d  %s" % [character_index + 1, character_ids.size(), character_ids[character_index].to_upper()]
    anim_label.text = "ANIM %s  ·  FACING %s  ·  %s" % [
        focus.resolved_animation().to_upper(),
        focus.facing.to_upper(),
        "PLAYING" if focused else "PAUSED",
    ]
    pause_button.text = "PAUSE" if focused else "PLAY"


func _current_sheet() -> CharacterSheet:
    var id := character_ids[character_index]
    if not sheets.has(id):
        sheets[id] = GeneratedCharacters.load_sheet(id)
    return sheets[id] as CharacterSheet


func _animation_bases(sheet: CharacterSheet) -> Array[StringName]:
    var result: Array[StringName] = []
    for animation_name in sheet.animation_names():
        var base := String(animation_name)
        for facing in CharacterSheet.FACINGS:
            var suffix := "_%s" % facing
            if base.ends_with(suffix):
                base = base.trim_suffix(suffix)
                break
        var name := StringName(base)
        if not result.has(name):
            result.append(name)
    return result


func _draw() -> void:
    draw_rect(Rect2(0, 0, 320, 240), Color("171923"), true)
    for x in range(12, 309, 16):
        draw_line(Vector2(x, 36), Vector2(x, FLOOR_Y), Color("202534"), 1.0, false)
    for y in range(44, int(FLOOR_Y), 16):
        draw_line(Vector2(12, y), Vector2(308, y), Color("202534"), 1.0, false)
    draw_line(Vector2(12, FLOOR_Y), Vector2(308, FLOOR_Y), Color("8c7183"), 1.0, false)


func _capture() -> void:
    var shots := [
        {"anim": &"stand", "facing": &"down", "wait": 0.1, "out": "stand_down"},
        {"anim": &"idle", "facing": &"down", "wait": 0.35, "out": "idle_down"},
        {"anim": &"walk", "facing": &"right", "wait": 0.35, "out": "walk_right"},
        {"anim": &"sleep", "facing": &"down", "wait": 0.75, "out": "sleep"},
    ]
    await get_tree().process_frame
    await get_tree().process_frame
    for shot in shots:
        character_index = 0
        anim_index = animation_bases.find(shot.anim)
        focus.facing = shot.facing
        focused = true
        _apply_state()
        await get_tree().create_timer(shot.wait).timeout
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("user://character_sprites_%s.png" % shot.out)
    get_tree().quit()
