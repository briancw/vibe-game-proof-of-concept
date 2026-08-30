class_name CharacterSheet
extends Resource

## Data-driven description of a uniform-grid character sprite sheet. Adding a
## new character to the game means pointing one of these at a new texture and
## listing its animations; `CharacterSprite` renders any number of instances
## from a single shared sheet.

@export var texture: Texture2D
@export var frame_size := Vector2i(16, 32)
@export var animations: Array[CharacterAnimDef] = []

## Used when a CharacterSprite asks for an animation this sheet does not have.
@export var default_animation := &"idle_down"

## Canonical facing cycle order, shared by every sheet and the UI controls.
const FACINGS: Array[StringName] = [&"down", &"right", &"up", &"left"]

var _sprite_frames: SpriteFrames


## The facings this sheet can actually play for a base animation, in canonical
## order. Empty for non-directional animations such as `sleep`.
func facings_for(base: StringName) -> Array[StringName]:
    var result: Array[StringName] = []
    if has_animation(base):
        return result
    for facing in FACINGS:
        if has_animation(StringName("%s_%s" % [base, facing])):
            result.append(facing)
    return result


func has_animation(anim: StringName) -> bool:
    return find_animation(anim) != null


func find_animation(anim: StringName) -> CharacterAnimDef:
    for def in animations:
        if def.name == anim:
            return def
    return null


func animation_names() -> Array[StringName]:
    var names: Array[StringName] = []
    for def in animations:
        names.append(def.name)
    return names


## Builds (and caches) the Godot `SpriteFrames` for this sheet. Cached for the
## lifetime of the resource, so N on-screen characters share one build.
func build_sprite_frames() -> SpriteFrames:
    if _sprite_frames != null:
        return _sprite_frames
    _sprite_frames = SpriteFrames.new()
    _sprite_frames.remove_animation(&"default")
    var sheet_size := texture.get_size() if texture else Vector2.ZERO
    for def in animations:
        _sprite_frames.add_animation(def.name)
        _sprite_frames.set_animation_speed(def.name, def.fps)
        _sprite_frames.set_animation_loop(def.name, def.loop)
        for i in def.frames:
            var origin := Vector2(def.origin) + Vector2(frame_size.x * i, 0)
            if origin.x + frame_size.x > sheet_size.x or origin.y + frame_size.y > sheet_size.y:
                push_warning("CharacterSheet: animation %s frame %d is outside the texture." % [def.name, i])
                break
            var frame := AtlasTexture.new()
            frame.atlas = texture
            frame.region = Rect2(origin, Vector2(frame_size))
            _sprite_frames.add_frame(def.name, frame)
    return _sprite_frames
