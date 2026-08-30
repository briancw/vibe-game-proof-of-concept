class_name CharacterSprite
extends Node2D

## Renders one character from a `CharacterSheet`. Place one node per on-screen
## character; sheet data and `SpriteFrames` are shared, so extra characters are
## cheap. The node origin sits at the character's feet, centered horizontally.
##
## `animation` is a base name (`stand`, `idle`, `walk`, `sit`, `sleep`); directional
## animations resolve to `<animation>_<facing>`, so changing `facing`
## (`down`/`left`/`up`/`right`) retargets the animation automatically.
## Non-directional animations (`sleep`) play verbatim, and animations that
## lack some facings (sit: right/left only) fall back to a sibling facing.

signal animation_changed(anim: StringName)
signal animation_finished

const FACINGS: Array[StringName] = CharacterSheet.FACINGS

@export var sheet: CharacterSheet:
    set(value):
        sheet = value
        _rebuild()
@export var animation := &"stand":
    set(value):
        animation = value
        _refresh()
@export var facing := &"down":
    set(value):
        facing = value
        _refresh()
@export var playing := true:
    set(value):
        playing = value
        _refresh()
@export var speed_scale := 1.0:
    set(value):
        speed_scale = value
        _sprite.speed_scale = value
@export var show_shadow := true:
    set(value):
        show_shadow = value
        queue_redraw()

var _sprite := AnimatedSprite2D.new()


func _init() -> void:
    _sprite.name = "Sprite"
    add_child(_sprite)
    _sprite.animation_finished.connect(func() -> void: animation_finished.emit())


## The animation actually being displayed after facing/default resolution.
func resolved_animation() -> StringName:
    return _resolve_animation()


func play_anim(anim: StringName) -> void:
    animation = anim
    playing = true


func _resolve_animation() -> StringName:
    if sheet == null:
        return &""
    var directional := StringName("%s_%s" % [animation, facing])
    if sheet.has_animation(directional):
        return directional
    if sheet.has_animation(animation):
        return animation
    # Animations without every facing (e.g. sit: right/left only) fall back to
    # a sibling directional variant of the same base animation.
    var prefix := String(animation) + "_"
    for name in sheet.animation_names():
        if String(name).begins_with(prefix):
            return name
    if sheet.has_animation(sheet.default_animation):
        return sheet.default_animation
    return &""


func _rebuild() -> void:
    _sprite.sprite_frames = sheet.build_sprite_frames() if sheet != null else null
    _sprite.offset = Vector2(0.0, -float(sheet.frame_size.y) * 0.5) if sheet != null else Vector2.ZERO
    _sprite.animation = &""
    queue_redraw()
    _refresh()


func _refresh() -> void:
    if _sprite.sprite_frames == null:
        return
    var anim := _resolve_animation()
    if anim == &"":
        return
    if _sprite.animation != anim:
        _sprite.play(anim)
        animation_changed.emit(anim)
    if playing and not _sprite.is_playing():
        _sprite.play(anim)
    elif not playing and _sprite.is_playing():
        _sprite.pause()


func _draw() -> void:
    if not show_shadow or sheet == null:
        return
    var width := float(sheet.frame_size.x) * 0.75
    draw_set_transform(Vector2(0.0, -1.0), 0.0, Vector2(1.0, 0.35))
    draw_circle(Vector2.ZERO, width * 0.5, Color(0.0, 0.0, 0.0, 0.25))
