@tool
class_name CharacterCanvas
extends Node2D

## Draws the parametric character in "native" units. The owning
## CharacterPreview scales this canvas down inside a low-resolution
## SubViewport, so every shape rasterizes directly onto the world pixel grid
## and the blitted texture matches the surrounding 16x16 tile art. Flat fills
## and hard edges are deliberate: antialiasing would read as fuzz once the
## result is magnified with nearest filtering.
##
## The canvas receives the rig's anchor positions and the character profile
## as dictionaries, unpacks them once in _prepare() into typed members, and
## every draw helper reads those members directly. Adding a new knob means
## adding one member, one _prepare() line, and one export upstream.
##
## Views: the rig always faces down. FACING_RIGHT is drawn natively and
## FACING_LEFT is the same art mirrored by the owning preview's sprite.

const FACING_DOWN := 0
const FACING_RIGHT := 1
const FACING_LEFT := 2
const FACING_UP := 3

const OUTLINE := Color("43394a")
const EYE_COLOR := Color("332b3a")
const HIGHLIGHT := Color("fff6ea")
const MOUTH_COLOR := Color("6f3b42")
const BLUSH := Color(0.88, 0.42, 0.40, 0.32)
const BRASS := Color("d8b04a")

const SKIN_TONES: Array[Color] = [
    Color("ffe3c8"),
    Color("f2bd93"),
    Color("c9885c"),
    Color("8a5a3b"),
]

const HAIR_COLORS := [
    {"base": Color("35293a"), "shine": Color("54425e")},
    {"base": Color("6b4642"), "shine": Color("8d6053")},
    {"base": Color("a15c3e"), "shine": Color("c17c54")},
    {"base": Color("d8a878"), "shine": Color("eec99c")},
]

const OUTFITS := [
    {"main": Color("c4766a"), "accent": Color("e9c46a"), "bottoms": Color("50404e"), "shoes": Color("a06a4e")},
    {"main": Color("8aa07a"), "accent": Color("efe3c2"), "bottoms": Color("6b584c"), "shoes": Color("453943")},
    {"main": Color("5c6e92"), "accent": Color("ecd9b8"), "bottoms": Color("5c6e92"), "shoes": Color("6b4a3e")},
    {"main": Color("efe6d2"), "accent": Color("5f8f8a"), "bottoms": Color("50404e"), "shoes": Color("7a4a42")},
    {"main": Color("d9756a"), "accent": Color("f4e6c8"), "bottoms": Color("50404e"), "shoes": Color("a06a4e")},
    {"main": Color("f2bd93"), "accent": Color("f2bd93"), "bottoms": Color("f2bd93"), "shoes": Color("f2bd93")},
]

var profile := {}
var anchors := {}

# Optional authored-shape overrides: name -> PackedVector2Array of final
# native-space points, fed by the editable Polygon2D layer the preview
# builds. When a shape has an override it is drawn verbatim; otherwise the
# procedural builder below runs exactly as before.
var shape_points := {}

# Everything below is derived in _prepare() for the current redraw.
var facing := FACING_DOWN
var side_view := false
var back_view := false
var skin := Color.WHITE
var outfit := {}
var outfit_index := 0
var hair := {}
var hair_style := 0
var eye_style := 0
var blink := false

var head := Vector2.ZERO
var chest := Vector2.ZERO
var waist := Vector2.ZERO
var pelvis := Vector2.ZERO
var body_width := 1.0
var chest_half := 9.6
var waist_half := 7.9
var hip_half := 9.9


func _draw() -> void:
    if profile.is_empty() or anchors.is_empty():
        return
    _prepare()
    _draw_shadow()
    _draw_hair_back()
    if side_view:
        _draw_far_leg()
    _draw_legs()
    _draw_neck()
    _draw_torso()
    _draw_arms()
    _draw_head()
    if back_view:
        _draw_hair_back_view()
    else:
        _draw_hair_front()
    if profile.show_rig_guides:
        _draw_rig_guides()


func _prepare() -> void:
    facing = clampi(int(profile.get("facing", FACING_DOWN)), FACING_DOWN, FACING_UP)
    side_view = facing == FACING_RIGHT or facing == FACING_LEFT
    back_view = facing == FACING_UP
    skin = _skin_color(_frac(profile.skin_tone))
    outfit_index = clampi(int(profile.outfit_index), 0, OUTFITS.size() - 1)
    outfit = OUTFITS[outfit_index]
    hair_style = clampi(int(profile.hair_index), 0, 3)
    hair = HAIR_COLORS[clampi(int(profile.hair_color_index), 0, HAIR_COLORS.size() - 1)]
    eye_style = clampi(int(profile.get("eye_index", 0)), 0, 2)
    blink = profile.get("blink", false)

    head = anchors.head
    chest = anchors.chest
    waist = anchors.spine
    pelvis = anchors.pelvis
    body_width = lerpf(0.82, 1.20, _frac(profile.weight))
    # Side views narrow the silhouette hard: Stardew-style, the profile body
    # is barely half the front width, with one arm hanging at the center line.
    var depth := 0.62 if side_view else 1.0
    chest_half = (9.6 + _frac(profile.bust_size) * 4.4) * body_width * depth
    waist_half = (7.9 + _frac(profile.weight) * 1.2) * body_width * depth
    hip_half = (9.9 + _frac(profile.hip_width) * 6.4) * body_width * (0.7 if side_view else 1.0)


func _draw_shadow() -> void:
    var left: Vector2 = anchors.foot_left
    var right: Vector2 = anchors.foot_right
    var radii := Vector2(9.5, 3.0) if side_view else Vector2(13.0, 3.4)
    _ellipse((left + right) * 0.5 + Vector2(0.0, 2.6), radii, Color(0.22, 0.13, 0.12, 0.38))


func _draw_hair_back() -> void:
    # Panels that hang behind the body. The back view draws its hair in
    # _draw_hair_back_view instead, over the body.
    if back_view:
        return
    match hair_style:
        1:
            # Long hair falls behind the shoulders in one soft panel that
            # clearly peeks out beside the torso.
            if not side_view and not back_view:
                _filled(_authored("hair_back_long", PackedVector2Array([
                    head + Vector2(-10.6, -6.0),
                    head + Vector2(-12.8, 2.0),
                    head + Vector2(-12.4, 14.0),
                    head + Vector2(-7.0, 26.0),
                    head + Vector2(7.0, 26.0),
                    head + Vector2(12.4, 14.0),
                    head + Vector2(12.8, 2.0),
                    head + Vector2(10.6, -6.0),
                ])), hair.base)
                return
            var x_shift := -2.0 if side_view else 0.0
            _filled(PackedVector2Array([
                head + Vector2(-10.6 + x_shift, -6.0),
                head + Vector2(-12.8 + x_shift, 2.0),
                head + Vector2(-12.4 + x_shift, 14.0),
                head + Vector2(-7.0 + x_shift, 26.0),
                head + Vector2(7.0 + x_shift, 26.0),
                head + Vector2(12.4 + x_shift, 14.0),
                head + Vector2(12.8 + x_shift, 2.0),
                head + Vector2(10.6 + x_shift, -6.0),
            ]), hair.base)
        3:
            if not side_view and not back_view:
                _filled(_authored("hair_back_ponytail", PackedVector2Array([
                    head + Vector2(6.0, -12.0),
                    head + Vector2(13.0, -14.0),
                    head + Vector2(17.0, -9.0),
                    head + Vector2(16.5, -1.0),
                    head + Vector2(13.5, 6.0),
                    head + Vector2(10.5, 9.5),
                    head + Vector2(10.0, 2.0),
                    head + Vector2(8.5, -6.0),
                ])), hair.base)
                return
            if side_view:
                # From the side the tail hangs fully visible down the back.
                _filled(PackedVector2Array([
                    head + Vector2(0.0, -12.5),
                    head + Vector2(-9.0, -14.5),
                    head + Vector2(-16.5, -10.0),
                    head + Vector2(-17.5, -3.0),
                    head + Vector2(-14.5, 4.0),
                    head + Vector2(-10.5, 9.0),
                    head + Vector2(-8.5, 2.0),
                    head + Vector2(-5.0, -8.5),
                ]), hair.base)
            else:
                # A high ponytail sweeping out of the face to one side.
                _filled(PackedVector2Array([
                    head + Vector2(6.0, -12.0),
                    head + Vector2(13.0, -14.0),
                    head + Vector2(17.0, -9.0),
                    head + Vector2(16.5, -1.0),
                    head + Vector2(13.5, 6.0),
                    head + Vector2(10.5, 9.5),
                    head + Vector2(10.0, 2.0),
                    head + Vector2(8.5, -6.0),
                ]), hair.base)


func _draw_hair_back_view() -> void:
    # Back view: the hair mass covers the whole back of the head, drawn after
    # the body so long styles lie over the back of the torso.
    match hair_style:
        0:
            _outlined_ellipse(head + Vector2(0.0, -0.6), Vector2(12.2, 12.4), hair.base)
        1:
            _outlined_ellipse(head + Vector2(0.0, -0.8), Vector2(12.2, 12.2), hair.base)
            _filled(PackedVector2Array([
                head + Vector2(-10.6, -8.0),
                head + Vector2(-12.0, 4.0),
                head + Vector2(-9.5, 18.0),
                head + Vector2(0.0, 21.0),
                head + Vector2(9.5, 18.0),
                head + Vector2(12.0, 4.0),
                head + Vector2(10.6, -8.0),
            ]), hair.base)
        2:
            _outlined_ellipse(head + Vector2(0.0, -0.4), Vector2(12.6, 12.4), hair.base)
        3:
            _outlined_ellipse(head + Vector2(0.0, -0.8), Vector2(12.0, 11.8), hair.base)
            _filled(PackedVector2Array([
                head + Vector2(0.0, -11.0),
                head + Vector2(-6.5, -8.0),
                head + Vector2(-6.0, 4.0),
                head + Vector2(-3.5, 11.0),
                head + Vector2(0.0, 13.5),
                head + Vector2(3.5, 11.0),
                head + Vector2(6.0, 4.0),
                head + Vector2(6.5, -8.0),
            ]), hair.base)


func _chain(key_suffix: String, x_shift: float, parts: Array) -> PackedVector2Array:
    var points := PackedVector2Array()
    for part: String in parts:
        var point: Vector2 = anchors[part + "_" + key_suffix]
        point.x += x_shift
        points.append(point)
    return points


func _chain_abs(key_suffix: String, xs: Array, parts: Array) -> PackedVector2Array:
    var points := PackedVector2Array()
    for part_index in range(parts.size()):
        var point: Vector2 = anchors[parts[part_index] + "_" + key_suffix]
        point.x = xs[part_index]
        points.append(point)
    return points


func _draw_far_leg() -> void:
    var leg_color := _leg_color().darkened(0.22)
    _limb(_chain_abs("left", [-1.6, -1.8, -2.0], ["thigh", "shin", "foot"]), leg_color, _leg_width() - 0.4)
    var far_shoe: Color = outfit.shoes.darkened(0.25) if outfit_index < 5 else skin.darkened(0.2)
    _outlined_ellipse(Vector2(-2.4, anchors.foot_left.y + 1.0), _shoe_radii() * 0.9, far_shoe)


func _draw_legs() -> void:
    if side_view:
        # Near leg only: it hangs from the torso centre, slightly forward;
        # the far leg was already drawn darker behind it.
        _limb(_chain_abs("right", [1.2, 1.5, 1.8], ["thigh", "shin", "foot"]), _leg_color(), _leg_width())
        var foot := Vector2(2.4, anchors.foot_right.y + 1.0)
        if outfit_index == 5:
            _outlined_ellipse(foot, Vector2(3.8, 2.0), skin)
        else:
            _outlined_ellipse(foot, _shoe_radii(), outfit.shoes)
        return
    _limb(_chain("left", 0.0, ["thigh", "shin", "foot"]), _leg_color(), _leg_width())
    _limb(_chain("right", 0.0, ["thigh", "shin", "foot"]), _leg_color(), _leg_width())
    match outfit_index:
        0:
            _outlined_ellipse(anchors.foot_left + Vector2(0.0, 0.8), Vector2(4.2, 2.3), outfit.shoes)
            _outlined_ellipse(anchors.foot_right + Vector2(0.0, 0.8), Vector2(4.2, 2.3), outfit.shoes)
        1:
            _outlined_ellipse(anchors.foot_left + Vector2(0.0, 1.0), Vector2(4.6, 2.7), outfit.shoes)
            _outlined_ellipse(anchors.foot_right + Vector2(0.0, 1.0), Vector2(4.6, 2.7), outfit.shoes)
        2:
            _outlined_ellipse(anchors.foot_left + Vector2(0.0, 1.2), Vector2(4.4, 3.0), outfit.shoes)
            _outlined_ellipse(anchors.foot_right + Vector2(0.0, 1.2), Vector2(4.4, 3.0), outfit.shoes)
        3, 4:
            # Bare feet with a thin sandal sole; the skin above stays bare.
            _outlined_ellipse(anchors.foot_left + Vector2(0.0, 1.4), Vector2(4.0, 1.9), outfit.shoes)
            _outlined_ellipse(anchors.foot_right + Vector2(0.0, 1.4), Vector2(4.0, 1.9), outfit.shoes)
        5:
            # Nude: bare skin feet.
            _outlined_ellipse(anchors.foot_left + Vector2(0.0, 1.0), Vector2(3.8, 2.0), skin)
            _outlined_ellipse(anchors.foot_right + Vector2(0.0, 1.0), Vector2(3.8, 2.0), skin)


func _leg_color() -> Color:
    return skin if outfit_index >= 3 else outfit.bottoms


func _leg_width() -> float:
    match outfit_index:
        0:
            return 6.4
        1:
            return 7.8
        2:
            return 8.0
        3:
            return 5.8
    return 5.6


func _shoe_radii() -> Vector2:
    match outfit_index:
        0:
            return Vector2(4.2, 2.3)
        1:
            return Vector2(4.6, 2.7)
        2:
            return Vector2(4.4, 3.0)
    return Vector2(4.0, 1.9)


func _draw_neck() -> void:
    var top := head + Vector2(0.0, 8.0)
    var bottom := chest + Vector2(0.0, -1.2)
    var mid := (top + bottom) * 0.5
    var half_length := top.distance_to(bottom) * 0.5 + 2.2
    _ellipse(mid, Vector2(3.0, half_length), OUTLINE)
    _ellipse(mid, Vector2(2.2, half_length - 0.7), skin)


func _draw_torso() -> void:
    match outfit_index:
        0:
            _draw_dress()
        1:
            _draw_sweater()
        2:
            _draw_overalls()
        3:
            _draw_body_base()
            _draw_tube_and_skirt()
        4:
            _draw_body_base()
            _draw_bikini()
        5:
            _draw_body_base()


## Every authored down-facing silhouette, for the editable Polygon2D layer.
## Points are absolute native coordinates at base morphology; the preview
## translates each entry into its parent bone's local space. Only silhouettes
## are listed here — face, limbs, and small details stay procedural. When a
## shape has an authored override (user-edited Polygon2D node), it wins.
func build_shape_library() -> Dictionary:
    var library := {}
    _add_shape(library, "body_base", "Pelvis", "skin", _build_body_base_points())
    _add_shape(library, "dress", "Pelvis", "outfit_main", _build_dress_points())
    _add_shape(library, "sweater", "Pelvis", "outfit_main", _build_sweater_points())
    _add_shape(library, "sweater_hem", "Pelvis", "outfit_dark", _build_sweater_hem_points())
    _add_shape(library, "overalls_body", "Pelvis", "outfit_accent", _build_overalls_body_points())
    _add_shape(library, "overalls_bib", "Chest", "outfit_main", _build_overalls_bib_points())
    _add_shape(library, "tube", "Chest", "outfit_main", _build_tube_points())
    _add_shape(library, "skirt", "Pelvis", "outfit_accent", _build_skirt_points())
    _add_shape(library, "bikini_top", "Chest", "outfit_main", _build_bikini_top_points())
    _add_shape(library, "bikini_bottom", "Pelvis", "outfit_main", _build_bikini_bottom_points())
    _add_shape(library, "hair_front_0", "Head", "hair", _build_hair_front_points(0))
    _add_shape(library, "hair_front_1", "Head", "hair", _build_hair_front_points(1))
    _add_shape(library, "hair_front_2", "Head", "hair", _build_hair_front_points(2))
    _add_shape(library, "hair_front_3", "Head", "hair", _build_hair_front_points(3))
    _add_shape(library, "hair_back_long", "Head", "hair", _build_hair_back_long_points())
    _add_shape(library, "hair_back_ponytail", "Head", "hair", _build_hair_back_ponytail_points())
    return library


func _add_shape(library: Dictionary, name: String, bone: String, role: String, points: PackedVector2Array) -> void:
    library[name] = {"bone": bone, "role": role, "points": points}


func _build_body_base_points() -> PackedVector2Array:
    return PackedVector2Array([
        chest + Vector2(-chest_half * 0.82, -4.6),
        chest + Vector2(-chest_half * 0.95, -0.6),
        chest + Vector2(-chest_half * 0.9, 3.4),
        waist + Vector2(-waist_half * 1.02, -1.0),
        pelvis + Vector2(-hip_half * 0.98, -1.5),
        pelvis + Vector2(-hip_half * 0.9, 3.0),
        pelvis + Vector2(-hip_half * 0.4, 6.2),
        pelvis + Vector2(hip_half * 0.4, 6.2),
        pelvis + Vector2(hip_half * 0.9, 3.0),
        pelvis + Vector2(hip_half * 0.98, -1.5),
        waist + Vector2(waist_half * 1.02, -1.0),
        chest + Vector2(chest_half * 0.9, 3.4),
        chest + Vector2(chest_half * 0.95, -0.6),
        chest + Vector2(chest_half * 0.82, -4.6),
    ])


func _build_dress_points() -> PackedVector2Array:
    var hem_y := pelvis.y + 10.0
    var hem_half := hip_half * 1.36
    return PackedVector2Array([
        chest + Vector2(-chest_half * 0.82, -4.6),
        chest + Vector2(-chest_half * 0.97, -0.6),
        chest + Vector2(-chest_half * 0.92, 3.4),
        waist + Vector2(-waist_half * 1.06, -1.0),
        pelvis + Vector2(-hip_half * 1.18, -4.0),
        Vector2(-hem_half, hem_y),
        Vector2(-hem_half * 0.5, hem_y + 2.4),
        Vector2(hem_half * 0.5, hem_y + 2.4),
        Vector2(hem_half, hem_y),
        pelvis + Vector2(hip_half * 1.18, -4.0),
        waist + Vector2(waist_half * 1.06, -1.0),
        chest + Vector2(chest_half * 0.92, 3.4),
        chest + Vector2(chest_half * 0.97, -0.6),
        chest + Vector2(chest_half * 0.82, -4.6),
    ])


func _build_sweater_points() -> PackedVector2Array:
    var top_y := chest.y - 4.6
    var bottom_y := pelvis.y + 6.5
    return _rounded_box(Vector2(0.0, (top_y + bottom_y) * 0.5), Vector2(chest_half + 1.1, (bottom_y - top_y) * 0.5), 3.4)


func _build_sweater_hem_points() -> PackedVector2Array:
    var bottom_y := pelvis.y + 6.5
    return _rounded_box(Vector2(0.0, bottom_y - 1.7), Vector2(chest_half + 1.1, 1.7), 1.6)


func _build_overalls_body_points() -> PackedVector2Array:
    var top_y := chest.y - 4.2
    var bottom_y := pelvis.y + 5.0
    return _rounded_box(Vector2(0.0, (top_y + bottom_y) * 0.5), Vector2(chest_half * 0.98, (bottom_y - top_y) * 0.5), 3.0)


func _build_overalls_bib_points() -> PackedVector2Array:
    var bib_top := chest.y + 1.6
    var bib_bottom := pelvis.y + 5.4
    return _rounded_box(Vector2(0.0, (bib_top + bib_bottom) * 0.5), Vector2(chest_half * 0.66, (bib_bottom - bib_top) * 0.5), 2.4)


func _build_tube_points() -> PackedVector2Array:
    return _rounded_box(Vector2(0.0, chest.y + 0.8), Vector2(chest_half * 0.98, 3.0), 2.2)


func _build_skirt_points() -> PackedVector2Array:
    var hem_y := pelvis.y + 9.0
    var hem_half := hip_half * 1.3
    return PackedVector2Array([
        Vector2(-waist_half * 0.98, waist.y + 2.6),
        pelvis + Vector2(-hip_half * 1.05, 0.0),
        Vector2(-hem_half, hem_y),
        Vector2(-hem_half * 0.5, hem_y + 2.2),
        Vector2(hem_half * 0.5, hem_y + 2.2),
        Vector2(hem_half, hem_y),
        pelvis + Vector2(hip_half * 1.05, 0.0),
        Vector2(waist_half * 0.98, waist.y + 2.6),
    ])


func _build_bikini_top_points() -> PackedVector2Array:
    return _rounded_box(Vector2(0.0, chest.y + 1.0), Vector2(chest_half * 0.8, 2.4), 1.8)


func _build_bikini_bottom_points() -> PackedVector2Array:
    return _rounded_box(Vector2(0.0, pelvis.y + 1.2), Vector2(hip_half * 0.88, 2.6), 1.8)


func _build_hair_front_points(style: int) -> PackedVector2Array:
    match style:
        0:
            return PackedVector2Array([
                head + Vector2(-11.6, -0.8),
                head + Vector2(-11.0, -7.0),
                head + Vector2(-6.4, -11.2),
                head + Vector2(0.4, -12.4),
                head + Vector2(6.8, -10.4),
                head + Vector2(10.8, -5.6),
                head + Vector2(11.4, -0.8),
                head + Vector2(8.4, -4.4),
                head + Vector2(3.8, -6.2),
                head + Vector2(-0.8, -7.2),
                head + Vector2(-5.2, -6.2),
                head + Vector2(-9.0, -4.0),
            ])
        1:
            return PackedVector2Array([
                head + Vector2(-11.4, -0.6),
                head + Vector2(-10.8, -7.2),
                head + Vector2(-6.0, -11.4),
                head + Vector2(0.6, -12.6),
                head + Vector2(7.0, -10.6),
                head + Vector2(11.0, -5.8),
                head + Vector2(11.6, -0.6),
                head + Vector2(7.6, -5.2),
                head + Vector2(2.4, -7.0),
                head + Vector2(-3.2, -7.6),
                head + Vector2(-8.2, -5.6),
            ])
        2:
            return PackedVector2Array([
                head + Vector2(-11.2, -1.0),
                head + Vector2(-10.4, -7.4),
                head + Vector2(-5.8, -11.2),
                head + Vector2(0.8, -12.0),
                head + Vector2(6.6, -10.0),
                head + Vector2(10.6, -5.2),
                head + Vector2(11.0, -1.0),
                head + Vector2(7.6, -3.4),
                head + Vector2(4.6, -5.4),
                head + Vector2(1.0, -3.6),
                head + Vector2(-2.2, -5.8),
                head + Vector2(-5.8, -4.2),
                head + Vector2(-8.8, -5.2),
            ])
    return PackedVector2Array([
        head + Vector2(-11.4, -0.8),
        head + Vector2(-10.6, -7.2),
        head + Vector2(-5.8, -11.4),
        head + Vector2(0.8, -12.4),
        head + Vector2(6.6, -10.8),
        head + Vector2(10.6, -6.0),
        head + Vector2(11.2, -1.4),
        head + Vector2(6.0, -5.4),
        head + Vector2(0.4, -7.2),
        head + Vector2(-5.4, -6.2),
        head + Vector2(-9.2, -4.2),
    ])


func _build_hair_back_long_points() -> PackedVector2Array:
    return PackedVector2Array([
        head + Vector2(-10.6, -6.0),
        head + Vector2(-12.8, 2.0),
        head + Vector2(-12.4, 14.0),
        head + Vector2(-7.0, 26.0),
        head + Vector2(7.0, 26.0),
        head + Vector2(12.4, 14.0),
        head + Vector2(12.8, 2.0),
        head + Vector2(10.6, -6.0),
    ])


func _build_hair_back_ponytail_points() -> PackedVector2Array:
    return PackedVector2Array([
        head + Vector2(6.0, -12.0),
        head + Vector2(13.0, -14.0),
        head + Vector2(17.0, -9.0),
        head + Vector2(16.5, -1.0),
        head + Vector2(13.5, 6.0),
        head + Vector2(10.5, 9.5),
        head + Vector2(10.0, 2.0),
        head + Vector2(8.5, -6.0),
    ])


func _sleeve() -> Color:
    match outfit_index:
        0:
            return outfit.main.darkened(0.10)
        1:
            return outfit.main.darkened(0.06)
        2:
            return outfit.accent
    # Bare arms take a half-step darker than the torso so the side-view arm
    # reads against same-colour skin instead of vanishing into it.
    return skin.darkened(0.07)


func _sleeve_width() -> float:
    match outfit_index:
        0:
            return 5.2
        1:
            return 5.8
        2:
            return 5.0
        3:
            return 4.8
    return 4.6


func _draw_body_base() -> void:
    # The bare silhouette under revealing outfits: shoulders, midriff, and
    # hips all read as skin, with garments layered on top of this base.
    if side_view:
        # True profile: the chest projects forward and the seat curves back,
        # while the back edge stays comparatively straight. The contour walks
        # the silhouette monotonically so no outline doubles back inside.
        _filled(PackedVector2Array([
            chest + Vector2(-chest_half * 0.7, -4.6),
            chest + Vector2(-chest_half * 0.8, 1.0),
            waist + Vector2(-waist_half * 0.85, -0.5),
            pelvis + Vector2(-hip_half * 0.88, 0.5),
            pelvis + Vector2(-hip_half * 0.78, 3.5),
            pelvis + Vector2(-hip_half * 0.35, 6.2),
            pelvis + Vector2(hip_half * 0.4, 4.6),
            pelvis + Vector2(hip_half * 0.8, 1.0),
            waist + Vector2(waist_half * 0.9, 1.5),
            chest + Vector2(chest_half * 0.95, 5.2),
            chest + Vector2(chest_half * 1.28, 3.0),
            chest + Vector2(chest_half * 1.02, 0.4),
            chest + Vector2(chest_half * 0.85, -2.2),
            chest + Vector2(chest_half * 0.72, -4.6),
        ]), skin, 2.0)
        return
    _filled(_authored("body_base", _build_body_base_points()), skin, 2.0)
    if not back_view and not side_view:
        # A one-pixel navel keeps the bare midriff from reading as blank.
        draw_rect(Rect2(Vector2(-0.8, waist.y + 2.4), Vector2(1.6, 1.6)), skin.darkened(0.16))


func _draw_dress() -> void:
    # One continuous bodice-to-skirt silhouette so no seam breaks the outline.
    _filled(_authored("dress", _build_dress_points()), outfit.main)
    _filled(_rounded_box(Vector2(0.0, waist.y + 0.4), Vector2(waist_half * 1.02, 1.6), 1.2), outfit.accent, 1.6)
    if back_view:
        # A short back seam replaces the front buttons.
        draw_line(chest + Vector2(0.0, -1.0), chest + Vector2(0.0, 3.0), outfit.main.darkened(0.18), 1.2, false)
    elif not side_view:
        draw_circle(Vector2(0.0, chest.y + 4.6), 1.8, outfit.accent.darkened(0.15))
        draw_circle(Vector2(0.0, chest.y + 8.2), 1.8, outfit.accent.darkened(0.15))


func _draw_sweater() -> void:
    _filled(_authored("sweater", _build_sweater_points()), outfit.main)
    _filled(_authored("sweater_hem", _build_sweater_hem_points()), outfit.main.darkened(0.18), 1.6)
    if not back_view and not side_view:
        _ellipse(Vector2(0.0, chest.y - 4.2), Vector2(4.6, 2.0), outfit.main.darkened(0.18))
        _ellipse(Vector2(0.0, chest.y - 4.4), Vector2(3.4, 1.3), outfit.main)


func _draw_overalls() -> void:
    _filled(_authored("overalls_body", _build_overalls_body_points()), outfit.accent)
    var bib_top := chest.y + 1.6
    var bib_bottom := pelvis.y + 5.4
    if back_view:
        # From the back: two straps crossing low, over a waistband.
        draw_line(Vector2(-chest_half * 0.5, chest.y - 3.6), Vector2(chest_half * 0.3, pelvis.y + 1.0), outfit.main, 2.6, false)
        draw_line(Vector2(chest_half * 0.5, chest.y - 3.6), Vector2(-chest_half * 0.3, pelvis.y + 1.0), outfit.main, 2.6, false)
        _filled(_rounded_box(Vector2(0.0, pelvis.y + 2.6), Vector2(hip_half * 0.92, 2.6), 1.6), outfit.main)
        return
    _filled(_authored("overalls_bib", _build_overalls_bib_points()), outfit.main)
    if side_view:
        # One shoulder strap over the near shoulder plus a waistband.
        draw_line(Vector2(-chest_half * 0.2, chest.y - 3.8), Vector2(-chest_half * 0.1, bib_top + 1.0), outfit.main, 2.6, false)
        _filled(_rounded_box(Vector2(0.0, pelvis.y + 2.6), Vector2(hip_half * 0.92, 2.6), 1.6), outfit.main)
        return
    draw_line(Vector2(-chest_half * 0.5, bib_top + 0.5), Vector2(-chest_half * 0.62, chest.y - 4.0), outfit.main, 2.6, false)
    draw_line(Vector2(chest_half * 0.5, bib_top + 0.5), Vector2(chest_half * 0.62, chest.y - 4.0), outfit.main, 2.6, false)
    draw_circle(Vector2(-chest_half * 0.44, bib_top + 1.2), 1.1, BRASS)
    draw_circle(Vector2(chest_half * 0.44, bib_top + 1.2), 1.1, BRASS)
    _filled(_rounded_box(Vector2(0.0, waist.y - 2.4), Vector2(3.4, 2.2), 1.2), outfit.main.darkened(0.12), 1.4)


func _draw_tube_and_skirt() -> void:
    # Strapless band across the chest; shoulders, arms, and midriff stay bare.
    _filled(_authored("tube", _build_tube_points()), outfit.main)
    # Low-rise flared skirt starting below the navel.
    _filled(_authored("skirt", _build_skirt_points()), outfit.accent)


func _draw_bikini() -> void:
    if back_view:
        _filled(_rounded_box(Vector2(0.0, chest.y + 1.0), Vector2(chest_half * 0.8, 2.4), 1.8), outfit.main)
        _filled(_rounded_box(Vector2(0.0, pelvis.y + 1.2), Vector2(hip_half * 0.88, 2.6), 1.8), outfit.main)
        # A single bow where the straps would tie.
        _outlined_ellipse(Vector2(2.4, chest.y - 3.2), Vector2(1.6, 1.4), outfit.accent)
        return
    # Neck straps first so the band overlaps their ends.
    draw_line(Vector2(-chest_half * 0.5, chest.y - 0.4), Vector2(-1.8, chest.y - 4.8), outfit.main, 1.6, false)
    draw_line(Vector2(chest_half * 0.5, chest.y - 0.4), Vector2(1.8, chest.y - 4.8), outfit.main, 1.6, false)
    _filled(_authored("bikini_top", _build_bikini_top_points()), outfit.main)
    _filled(_authored("bikini_bottom", _build_bikini_bottom_points()), outfit.main)
    # Small tie knots keep the pieces from reading as plain bands.
    _outlined_ellipse(Vector2(-chest_half * 0.72, chest.y + 1.0), Vector2(1.5, 1.5), outfit.accent)
    _outlined_ellipse(Vector2(chest_half * 0.72, chest.y + 1.0), Vector2(1.5, 1.5), outfit.accent)


func _draw_arms() -> void:
    var sleeve := _sleeve()
    var width := _sleeve_width()
    var puff := outfit_index == 0 and not side_view
    if side_view:
        # One arm hanging along the profile's front edge: it may protrude a
        # pixel past the torso silhouette but never floats off the chest.
        # Anchors keep the rig's y positions; x is profile-native.
        var parts := ["upper_arm", "forearm", "hand"]
        var xs := [chest_half * 0.5, chest_half * 0.64, chest_half * 0.72]
        var points := PackedVector2Array()
        for part_index in range(3):
            var point: Vector2 = anchors[parts[part_index] + "_right"]
            point.x = xs[part_index]
            points.append(point)
        if outfit_index == 0:
            _outlined_ellipse(points[0] + Vector2(0.0, -0.6), Vector2(3.8, 3.6), sleeve)
        _limb(points, sleeve, width)
        var hand: Vector2 = anchors.hand_right
        hand.x = xs[2]
        _outlined_ellipse(hand + Vector2(0.2, 0.4), Vector2(2.4, 2.2), skin)
        return
    if back_view:
        # Arms hang outside the torso silhouette so hands stay visible, but
        # the shift tapers from shoulder to hand so the sleeve stays attached.
        var back_shift := hip_half * 0.2 + 1.4
        for side in ["left", "right"]:
            var direction := -1.0 if side == "left" else 1.0
            var points := PackedVector2Array()
            for part_index in range(3):
                var part: Vector2 = anchors[["upper_arm", "forearm", "hand"][part_index] + "_" + side]
                part.x += direction * back_shift * (0.35 + 0.425 * float(part_index))
                points.append(part)
            _limb(points, sleeve, width)
            _outlined_ellipse(anchors["hand_" + side] + Vector2(direction * back_shift, 0.4), Vector2(2.4, 2.2), skin)
        return
    var left_chain := _chain("left", 0.0, ["upper_arm", "forearm", "hand"])
    var right_chain := _chain("right", 0.0, ["upper_arm", "forearm", "hand"])
    var chains := [left_chain, right_chain]
    for chain: Array in chains:
        var points := PackedVector2Array(chain)
        if puff:
            _outlined_ellipse(points[0] + Vector2(0.0, -0.6), Vector2(4.0, 3.8), sleeve)
        _limb(points, sleeve, width)
    match outfit_index:
        1:
            _ellipse(anchors.hand_left + Vector2(0.0, -2.4), Vector2(3.0, 1.4), outfit.accent)
            _ellipse(anchors.hand_right + Vector2(0.0, -2.4), Vector2(3.0, 1.4), outfit.accent)
        2:
            _ellipse(anchors.hand_left + Vector2(0.0, -2.4), Vector2(2.8, 1.3), sleeve.darkened(0.12))
            _ellipse(anchors.hand_right + Vector2(0.0, -2.4), Vector2(2.8, 1.3), sleeve.darkened(0.12))
    _outlined_ellipse(anchors.hand_left + Vector2(0.0, 0.4), Vector2(2.4, 2.2), skin)
    _outlined_ellipse(anchors.hand_right + Vector2(0.0, 0.4), Vector2(2.4, 2.2), skin)


func _draw_head() -> void:
    _ellipse(head, Vector2(13.0, 13.6), OUTLINE)
    _ellipse(head, Vector2(12.0, 12.6), skin)
    if back_view:
        return
    if side_view:
        _draw_head_side()
        return
    _ellipse(head + Vector2(-7.0, 4.6), Vector2(2.2, 1.5), BLUSH)
    _ellipse(head + Vector2(7.0, 4.6), Vector2(2.2, 1.5), BLUSH)
    # Blinking swaps any eye style for closed lids drawn as short dark bars.
    if blink:
        draw_rect(Rect2(head + Vector2(-7.0, 0.0), Vector2(4.8, 1.8)), EYE_COLOR)
        draw_rect(Rect2(head + Vector2(2.2, 0.0), Vector2(4.8, 1.8)), EYE_COLOR)
    else:
        match eye_style:
            0:
                # Round glossy eyes: soft, open, and cute.
                draw_circle(head + Vector2(-4.6, 0.9), 2.8, EYE_COLOR)
                draw_circle(head + Vector2(4.6, 0.9), 2.8, EYE_COLOR)
                draw_rect(Rect2(head + Vector2(-5.2, -0.6), Vector2(1.5, 1.5)), HIGHLIGHT)
                draw_rect(Rect2(head + Vector2(4.0, -0.6), Vector2(1.5, 1.5)), HIGHLIGHT)
            1:
                # Flat, narrow eyes with a straight brow: stoic and masculine.
                var brow: Color = hair.base.darkened(0.05)
                draw_rect(Rect2(head + Vector2(-7.2, -0.3), Vector2(5.2, 2.4)), EYE_COLOR)
                draw_rect(Rect2(head + Vector2(2.0, -0.3), Vector2(5.2, 2.4)), EYE_COLOR)
                draw_rect(Rect2(head + Vector2(-7.2, -3.6), Vector2(5.2, 1.7)), brow)
                draw_rect(Rect2(head + Vector2(2.0, -3.6), Vector2(5.2, 1.7)), brow)
            2:
                # Angled eyes sweeping down toward the nose: determined.
                var brow: Color = hair.base.darkened(0.05)
                draw_colored_polygon(PackedVector2Array([
                    head + Vector2(-7.4, -1.4),
                    head + Vector2(-2.0, 0.0),
                    head + Vector2(-2.0, 1.6),
                    head + Vector2(-7.4, 0.4),
                ]), EYE_COLOR)
                draw_colored_polygon(PackedVector2Array([
                    head + Vector2(7.4, -1.4),
                    head + Vector2(2.0, 0.0),
                    head + Vector2(2.0, 1.6),
                    head + Vector2(7.4, 0.4),
                ]), EYE_COLOR)
                draw_rect(Rect2(head + Vector2(-7.2, -2.6), Vector2(1.4, 1.4)), HIGHLIGHT)
                draw_rect(Rect2(head + Vector2(5.8, -2.6), Vector2(1.4, 1.4)), HIGHLIGHT)
                draw_line(head + Vector2(-7.6, -3.8), head + Vector2(-2.4, -2.6), brow, 1.8, false)
                draw_line(head + Vector2(7.6, -3.8), head + Vector2(2.4, -2.6), brow, 1.8, false)
    draw_polyline(PackedVector2Array([
        head + Vector2(-1.2, 6.9),
        head + Vector2(0.4, 7.5),
        head + Vector2(1.6, 6.9),
    ]), MOUTH_COLOR, 1.2, false)


func _draw_head_side() -> void:
    # A proper profile: nose wedge, chin notch, and all features pushed
    # forward so the face reads as facing right, not a front face squinting.
    var nose := PackedVector2Array([
        head + Vector2(10.8, 1.0),
        head + Vector2(14.6, 3.4),
        head + Vector2(10.8, 5.0),
    ])
    draw_colored_polygon(nose, skin)
    draw_polyline(PackedVector2Array([nose[0], nose[1], nose[2]]), OUTLINE, 1.8, false)
    # Chin: a short forward jaw line under the mouth.
    draw_line(head + Vector2(10.6, 6.6), head + Vector2(12.0, 7.8), OUTLINE, 1.8, false)
    # One ear, set back toward the head's center of mass.
    _outlined_ellipse(head + Vector2(-1.4, 2.6), Vector2(1.7, 2.5), skin)
    draw_line(head + Vector2(-1.4, 1.4), head + Vector2(-1.4, 3.8), skin.darkened(0.16), 1.2, false)
    _ellipse(head + Vector2(6.8, 4.8), Vector2(2.0, 1.4), BLUSH)
    var brow: Color = hair.base.darkened(0.05)
    if blink:
        draw_rect(Rect2(head + Vector2(4.6, 0.2), Vector2(5.0, 1.8)), EYE_COLOR)
    else:
        match eye_style:
            0:
                draw_circle(head + Vector2(7.2, 0.7), 2.8, EYE_COLOR)
                draw_rect(Rect2(head + Vector2(6.8, -0.8), Vector2(1.5, 1.5)), HIGHLIGHT)
            1:
                draw_rect(Rect2(head + Vector2(4.8, -0.3), Vector2(5.0, 2.4)), EYE_COLOR)
                draw_rect(Rect2(head + Vector2(4.8, -3.5), Vector2(5.0, 1.7)), brow)
            2:
                draw_colored_polygon(PackedVector2Array([
                    head + Vector2(4.8, -0.8),
                    head + Vector2(9.6, 0.2),
                    head + Vector2(9.6, 1.8),
                    head + Vector2(4.8, 1.6),
                ]), EYE_COLOR)
                draw_line(head + Vector2(4.8, -3.6), head + Vector2(9.8, -2.2), brow, 1.8, false)
    draw_line(head + Vector2(10.2, 5.8), head + Vector2(11.6, 5.6), MOUTH_COLOR, 1.2, false)


func _draw_hair_front() -> void:
    if side_view:
        _draw_hair_side()
        return
    match hair_style:
        0:
            _filled(_authored("hair_front_bob", PackedVector2Array([
                head + Vector2(-11.6, -0.8),
                head + Vector2(-11.0, -7.0),
                head + Vector2(-6.4, -11.2),
                head + Vector2(0.4, -12.4),
                head + Vector2(6.8, -10.4),
                head + Vector2(10.8, -5.6),
                head + Vector2(11.4, -0.8),
                head + Vector2(8.4, -4.4),
                head + Vector2(3.8, -6.2),
                head + Vector2(-0.8, -7.2),
                head + Vector2(-5.2, -6.2),
                head + Vector2(-9.0, -4.0),
            ])), hair.base)
            _outlined_ellipse(head + Vector2(-11.3, 3.0), Vector2(2.7, 5.6), hair.base)
            _outlined_ellipse(head + Vector2(11.3, 3.0), Vector2(2.7, 5.6), hair.base)
        1:
            _filled(_authored("hair_front_long", PackedVector2Array([
                head + Vector2(-11.4, -0.6),
                head + Vector2(-10.8, -7.2),
                head + Vector2(-6.0, -11.4),
                head + Vector2(0.6, -12.6),
                head + Vector2(7.0, -10.6),
                head + Vector2(11.0, -5.8),
                head + Vector2(11.6, -0.6),
                head + Vector2(7.6, -5.2),
                head + Vector2(2.4, -7.0),
                head + Vector2(-3.2, -7.6),
                head + Vector2(-8.2, -5.6),
            ])), hair.base)
            _outlined_ellipse(head + Vector2(-11.2, 4.5), Vector2(2.5, 7.4), hair.base)
            _outlined_ellipse(head + Vector2(11.2, 4.5), Vector2(2.5, 7.4), hair.base)
        2:
            _filled(_authored("hair_front_crop", PackedVector2Array([
                head + Vector2(-11.2, -1.0),
                head + Vector2(-10.4, -7.4),
                head + Vector2(-5.8, -11.2),
                head + Vector2(0.8, -12.0),
                head + Vector2(6.6, -10.0),
                head + Vector2(10.6, -5.2),
                head + Vector2(11.0, -1.0),
                head + Vector2(7.6, -3.4),
                head + Vector2(4.6, -5.4),
                head + Vector2(1.0, -3.6),
                head + Vector2(-2.2, -5.8),
                head + Vector2(-5.8, -4.2),
                head + Vector2(-8.8, -5.2),
            ])), hair.base)
        3:
            _filled(_authored("hair_front_ponytail", PackedVector2Array([
                head + Vector2(-11.4, -0.8),
                head + Vector2(-10.6, -7.2),
                head + Vector2(-5.8, -11.4),
                head + Vector2(0.8, -12.4),
                head + Vector2(6.6, -10.8),
                head + Vector2(10.6, -6.0),
                head + Vector2(11.2, -1.4),
                head + Vector2(6.0, -5.4),
                head + Vector2(0.4, -7.2),
                head + Vector2(-5.4, -6.2),
                head + Vector2(-9.2, -4.2),
            ])), hair.base)
            # The tie sits at the tail's base, just outside the head silhouette.
            _outlined_ellipse(head + Vector2(9.5, -10.5), Vector2(2.4, 2.0), Color("e9c46a"))


func _draw_hair_side() -> void:
    match hair_style:
        0:
            # Bob: a low fringe over the eye and a rounded mass at the back.
            _filled(PackedVector2Array([
                head + Vector2(-11.6, -2.6),
                head + Vector2(-11.8, -7.8),
                head + Vector2(-6.0, -11.2),
                head + Vector2(0.8, -12.2),
                head + Vector2(7.0, -10.2),
                head + Vector2(11.0, -5.4),
                head + Vector2(11.4, -1.6),
                head + Vector2(7.4, -3.6),
                head + Vector2(2.8, -5.6),
                head + Vector2(-2.4, -6.0),
                head + Vector2(-6.8, -4.6),
            ]), hair.base)
            _outlined_ellipse(head + Vector2(-8.5, 3.0), Vector2(5.6, 6.8), hair.base)
        1:
            # Long: swept fringe and the panel hanging down the back.
            _filled(PackedVector2Array([
                head + Vector2(-11.8, -2.2),
                head + Vector2(-12.0, -8.0),
                head + Vector2(-5.8, -11.4),
                head + Vector2(0.8, -12.4),
                head + Vector2(7.2, -10.4),
                head + Vector2(11.2, -5.6),
                head + Vector2(11.6, -1.2),
                head + Vector2(7.0, -4.4),
                head + Vector2(1.6, -6.4),
                head + Vector2(-4.4, -6.2),
                head + Vector2(-8.6, -4.6),
            ]), hair.base)
            _outlined_ellipse(head + Vector2(-9.0, 5.0), Vector2(5.4, 8.4), hair.base)
        2:
            # Crop: tight cap with a choppy edge over the eye.
            _filled(PackedVector2Array([
                head + Vector2(-11.2, -3.2),
                head + Vector2(-11.4, -8.2),
                head + Vector2(-5.6, -11.2),
                head + Vector2(1.0, -12.0),
                head + Vector2(6.8, -10.0),
                head + Vector2(10.8, -5.0),
                head + Vector2(11.2, -1.4),
                head + Vector2(7.8, -2.8),
                head + Vector2(4.8, -4.8),
                head + Vector2(1.2, -3.2),
                head + Vector2(-2.6, -5.2),
                head + Vector2(-6.6, -4.4),
            ]), hair.base)
        3:
            # Swept-back cap feeding the tail hanging down the back.
            _filled(PackedVector2Array([
                head + Vector2(-11.4, -3.6),
                head + Vector2(-11.6, -8.4),
                head + Vector2(-5.6, -11.4),
                head + Vector2(1.0, -12.2),
                head + Vector2(7.0, -10.2),
                head + Vector2(11.0, -5.2),
                head + Vector2(11.4, -1.6),
                head + Vector2(6.4, -4.6),
                head + Vector2(0.8, -6.4),
                head + Vector2(-5.0, -5.8),
            ]), hair.base)
            _outlined_ellipse(head + Vector2(-9.5, -11.0), Vector2(2.2, 1.9), Color("e9c46a"))


func _draw_rig_guides() -> void:
    var chains := [
        ["pelvis", "spine", "chest", "head"],
        ["chest", "upper_arm_left", "forearm_left", "hand_left"],
        ["chest", "upper_arm_right", "forearm_right", "hand_right"],
        ["pelvis", "thigh_left", "shin_left", "foot_left"],
        ["pelvis", "thigh_right", "shin_right", "foot_right"],
    ]
    for chain: Array in chains:
        var points := PackedVector2Array()
        for key: String in chain:
            points.append(anchors[key])
        draw_polyline(points, Color("f6d8a8", 0.85), 1.0, false)
        for point in points:
            draw_circle(point, 1.8, Color("f6d8a8"))


func _frac(value: float) -> float:
    return clampf(value / 0.25, 0.0, 1.0)


func _authored(name: String, fallback: PackedVector2Array) -> PackedVector2Array:
    if facing != FACING_DOWN:
        return fallback
    return shape_points[name] if shape_points.has(name) else fallback


func _skin_color(t: float) -> Color:
    var scaled := clampf(t, 0.0, 1.0) * float(SKIN_TONES.size() - 1)
    var index := mini(int(scaled), SKIN_TONES.size() - 2)
    return SKIN_TONES[index].lerp(SKIN_TONES[index + 1], scaled - float(index))


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    const SEGMENTS := 20
    for segment in range(SEGMENTS):
        var angle := TAU * float(segment) / float(SEGMENTS)
        points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
    draw_colored_polygon(points, color)


func _outlined_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
    _ellipse(center, radii * 1.22, OUTLINE)
    _ellipse(center, radii, color)


func _filled(points: PackedVector2Array, color: Color, outline_width := 2.4) -> void:
    draw_colored_polygon(points, color)
    var closed := PackedVector2Array(points)
    closed.append(points[0])
    draw_polyline(closed, OUTLINE, outline_width, false)


func _limb(points: PackedVector2Array, color: Color, width: float) -> void:
    for point in points:
        draw_circle(point, (width + 2.6) * 0.5, OUTLINE)
    draw_polyline(points, OUTLINE, width + 2.6, false)
    for point in points:
        draw_circle(point, width * 0.5, color)
    draw_polyline(points, color, width, false)


func _rounded_box(center: Vector2, half: Vector2, radius: float) -> PackedVector2Array:
    var corner_radius := minf(radius, minf(half.x, half.y))
    var points := PackedVector2Array()
    var corners := [
        {"center": center + Vector2(half.x - corner_radius, -half.y + corner_radius), "from": -PI * 0.5, "to": 0.0},
        {"center": center + Vector2(half.x - corner_radius, half.y - corner_radius), "from": 0.0, "to": PI * 0.5},
        {"center": center + Vector2(-half.x + corner_radius, half.y - corner_radius), "from": PI * 0.5, "to": PI},
        {"center": center + Vector2(-half.x + corner_radius, -half.y + corner_radius), "from": PI, "to": PI * 1.5},
    ]
    for corner: Dictionary in corners:
        for step in range(5):
            var angle := lerpf(corner.from, corner.to, float(step) / 4.0)
            points.append(corner.center + Vector2(cos(angle), sin(angle)) * corner_radius)
    return points
