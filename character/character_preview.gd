@tool
class_name CharacterPreview
extends Node2D

## Parametric character with no artwork assets. A real Skeleton2D hierarchy
## provides every anchor; CharacterCanvas renders the layered silhouettes into
## a tiny SubViewport at world-pixel density, and the resulting texture is
## blitted with nearest filtering so the generated geometry shares the exact
## pixel grid of the surrounding 16x16 tile art.

const CANVAS_SCALE := 0.5
const CANVAS_OFFSET := Vector2(15.0, 42.0)
const VIEWPORT_SIZE := Vector2i(30, 48)
const CANVAS_SCRIPT := preload("res://character/character_canvas.gd")

@export_group("Body parameters")
const MORPH_PARAMETER_MAX := 0.25

@export_range(0.0, 0.25, 0.0125) var height := 0.125:
    set(value):
        height = value
        _refresh_character()

@export_range(0.0, 0.25, 0.0125) var weight := 0.1125:
    set(value):
        weight = value
        _refresh_character()

@export_range(0.0, 0.25, 0.0125) var hip_width := 0.125:
    set(value):
        hip_width = value
        _refresh_character()

@export_range(0.0, 0.25, 0.0125) var bust_size := 0.0875:
    set(value):
        bust_size = value
        _refresh_character()

@export_range(0.0, 0.25, 0.0125) var skin_tone := 0.1125:
    set(value):
        skin_tone = value
        _refresh_character()

@export_group("Style")

@export_range(0.0, 3.0, 1.0) var hair_index := 1.0:
    set(value):
        hair_index = value
        _refresh_character()

@export_range(0.0, 3.0, 1.0) var hair_color_index := 1.0:
    set(value):
        hair_color_index = value
        _refresh_character()

@export_range(0.0, 5.0, 1.0) var outfit_index := 0.0:
    set(value):
        outfit_index = value
        _refresh_character()

@export_range(0.0, 2.0, 1.0) var eye_index := 0.0:
    set(value):
        eye_index = value
        _refresh_character()

@export var show_rig_guides := false:
    set(value):
        show_rig_guides = value
        _refresh_character()

@export_group("View")

## Which way the character faces: 0 down (toward camera), 1 right, 2 left,
## 3 up (away from camera). Left mirrors the right-facing art.
@export_range(0.0, 3.0, 1.0) var facing := 0.0:
    set(value):
        facing = value
        _refresh_character()

## When on, the canvas rasterizes through the low-resolution SubViewport and
## the result is blitted with nearest filtering (the shipped look). When off,
## the same canvas draws directly at half scale, revealing the smooth vector
## shape that drives the final pixels — a debugging view, not a style.
@export var pixelated := true:
    set(value):
        pixelated = value
        if is_node_ready():
            _apply_pixel_mode()

func _build_pixel_pipeline() -> void:
    _viewport = SubViewport.new()
    _viewport.size = VIEWPORT_SIZE
    _viewport.transparent_bg = true
    _viewport.disable_3d = true
    _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    _viewport.snap_2d_transforms_to_pixel = true
    add_child(_viewport)

    _canvas = CANVAS_SCRIPT.new()
    _canvas.position = CANVAS_OFFSET
    _canvas.scale = Vector2(CANVAS_SCALE, CANVAS_SCALE)
    _viewport.add_child(_canvas)

    # The scene material (room palette grade) is authored on this root node by
    # the enclosing scenes; forward it so the blit itself is graded.
    _sprite = Sprite2D.new()
    _sprite.texture = _viewport.get_texture()
    _sprite.centered = false
    _sprite.offset = -CANVAS_OFFSET
    _sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _sprite.material = material
    add_child(_sprite)

## Feeds the authored Polygon2D layer (saved scene data under
## AuthoredShapes) to the canvas as overrides. Authored nodes live at the
## canvas's own coordinate space, so points edited in the editor land exactly
## where the procedural shapes drew them. The layer is hidden at runtime —
## the canvas draws the same silhouettes through the pixel pipeline — and in
## the editor only the shapes for the current outfit and hair are shown, so
## only those polygons appear in the 2D view for direct point editing.
func _sync_authored_layer() -> void:
    var layer := get_node_or_null("AuthoredShapes") as Node2D
    if layer != null:
        layer.visible = not Engine.is_editor_hint()
        _update_authored_visibility(layer)
    _apply_overrides()


## The shape names drawn for the current outfit and hair. In the editor the
## authored layer shows only these, so editing views are never a pile of
## every outfit stacked on one character.
func _active_shape_names() -> Dictionary:
    var names := {}
    match int(outfit_index):
        0:
            names["dress"] = true
        1:
            names["sweater"] = true
            names["sweater_hem"] = true
        2:
            names["overalls_body"] = true
            names["overalls_bib"] = true
        3:
            names["body_base"] = true
            names["tube"] = true
            names["skirt"] = true
        4:
            names["body_base"] = true
            names["bikini_top"] = true
            names["bikini_bottom"] = true
        5:
            names["body_base"] = true
    names["hair_front_%d" % int(hair_index)] = true
    if int(hair_index) == 1:
        names["hair_back_long"] = true
    if int(hair_index) == 3:
        names["hair_back_ponytail"] = true
    return names


func _update_authored_visibility(layer: Node2D) -> void:
    if not Engine.is_editor_hint():
        return
    var active := _active_shape_names()
    for child in layer.get_children():
        var polygon := child as Polygon2D
        if polygon != null:
            polygon.visible = String(polygon.name) in active



func _apply_overrides() -> void:
    if _canvas == null:
        return
    var layer := get_node_or_null("AuthoredShapes")
    var overrides := {}
    if layer != null:
        for child in layer.get_children():
            var polygon := child as Polygon2D
            if polygon != null:
                overrides[String(polygon.name)] = polygon.polygon
    _canvas.shape_points = overrides

## Drives the procedural idle pose while the scene runs. The editor stays on
## the rest pose; scrub idle_phase by hand to inspect frames in the editor.
@export var animate := true

## Seconds into the idle cycle. Whole seconds are not meaningful; any value
## deterministically reproduces one idle frame, which the capture strips use.
@export_range(0.0, 60.0, 0.05) var idle_phase := 0.0:
    set(value):
        idle_phase = value
        if is_node_ready():
            _apply_idle_pose()

## One idle "frame" lasts this many seconds: two poses, body up and body
## down, each held while the phase advances one frame.
const IDLE_FRAME_SECONDS := 0.75
## Everything the idle pose moves is snapped to multiples of two native units
## so each rendered frame lands on whole world pixels — the animation reads
## as authentic hand-keyed pixel art rather than smooth vector motion.
const IDLE_BODY_DROP := 2.0
const BLINK_PERIOD := 4.6
const BLINK_SECONDS := 0.26

@onready var skeleton: Skeleton2D = $Skeleton2D
@onready var pelvis: Bone2D = $Skeleton2D/Pelvis
@onready var spine: Bone2D = $Skeleton2D/Pelvis/Spine
@onready var chest: Bone2D = $Skeleton2D/Pelvis/Spine/Chest
@onready var head: Bone2D = $Skeleton2D/Pelvis/Spine/Chest/Head
@onready var upper_arm_left: Bone2D = $Skeleton2D/Pelvis/Spine/Chest/UpperArmLeft
@onready var forearm_left: Bone2D = $Skeleton2D/Pelvis/Spine/Chest/UpperArmLeft/ForearmLeft
@onready var hand_left: Bone2D = $Skeleton2D/Pelvis/Spine/Chest/UpperArmLeft/ForearmLeft/HandLeft
@onready var upper_arm_right: Bone2D = $Skeleton2D/Pelvis/Spine/Chest/UpperArmRight
@onready var forearm_right: Bone2D = $Skeleton2D/Pelvis/Spine/Chest/UpperArmRight/ForearmRight
@onready var hand_right: Bone2D = $Skeleton2D/Pelvis/Spine/Chest/UpperArmRight/ForearmRight/HandRight
@onready var thigh_left: Bone2D = $Skeleton2D/Pelvis/ThighLeft
@onready var shin_left: Bone2D = $Skeleton2D/Pelvis/ThighLeft/ShinLeft
@onready var foot_left: Bone2D = $Skeleton2D/Pelvis/ThighLeft/ShinLeft/FootLeft
@onready var thigh_right: Bone2D = $Skeleton2D/Pelvis/ThighRight
@onready var shin_right: Bone2D = $Skeleton2D/Pelvis/ThighRight/ShinRight
@onready var foot_right: Bone2D = $Skeleton2D/Pelvis/ThighRight/ShinRight/FootRight

var _viewport: SubViewport
var _canvas: Node2D
var _sprite: Sprite2D
var _rest_positions := {}


func _ready() -> void:
    _build_pixel_pipeline()
    _rebuild_rig()
    _sync_authored_layer()


func _process(delta: float) -> void:
    if not animate or Engine.is_editor_hint():
        return
    idle_phase = fmod(idle_phase + delta, BLINK_PERIOD * 2.0)


func _refresh_character() -> void:
    if is_node_ready() and _canvas != null:
        _rebuild_rig()


func _apply_pixel_mode() -> void:
    if _canvas == null or _viewport == null or _sprite == null:
        return
    if pixelated:
        if _canvas.get_parent() == self:
            remove_child(_canvas)
        if _canvas.get_parent() != _viewport:
            _viewport.add_child(_canvas)
        _canvas.position = CANVAS_OFFSET
        _canvas.scale = Vector2(CANVAS_SCALE, CANVAS_SCALE)
        _sprite.visible = true
    else:
        if _canvas.get_parent() == _viewport:
            _viewport.remove_child(_canvas)
        if _canvas.get_parent() != self:
            add_child(_canvas)
        # Same final size as the blitted texture; only the rasterization
        # differs, so the two views compare one-to-one.
        _canvas.position = Vector2.ZERO
        _canvas.scale = Vector2(CANVAS_SCALE, CANVAS_SCALE)
        _sprite.visible = false
    _canvas.queue_redraw()


func _rebuild_rig() -> void:
    # Parametric rest-pose anchors. Animation later applies pose overrides to
    # this same hierarchy rather than moving any art nodes.
    var height_fraction := _morph_fraction(height)
    var weight_fraction := _morph_fraction(weight)
    var bust_fraction := _morph_fraction(bust_size)
    var stature := lerpf(0.84, 1.18, height_fraction)
    var body_width := lerpf(0.82, 1.20, weight_fraction)
    var shoulder_half := (9.6 + bust_fraction * 4.4) * body_width + 1.2
    var leg_gap := 4.4 * body_width

    _set_bone_anchor(pelvis, Vector2(0.0, -18.0 * stature))
    _set_bone_anchor(spine, Vector2(0.0, -12.0 * stature))
    _set_bone_anchor(chest, Vector2(0.0, -12.0 * stature))
    # The head joins the chest directly. Omitting a neck bone is intentional for
    # this compact character language and keeps the silhouette more iconic.
    _set_bone_anchor(head, Vector2(0.0, -15.0 * stature))

    # A deliberately uneven neutral pose feels more lived-in than mirrored arms
    # and gives the rig a useful baseline for later idle animation.
    _set_bone_anchor(upper_arm_left, Vector2(-shoulder_half, 1.8))
    _set_bone_anchor(forearm_left, Vector2(-0.2 * body_width, 8.7 * stature))
    _set_bone_anchor(hand_left, Vector2(2.6, 8.4 * stature))
    _set_bone_anchor(upper_arm_right, Vector2(shoulder_half, 0.6))
    _set_bone_anchor(forearm_right, Vector2(0.2 * body_width, 9.2 * stature))
    _set_bone_anchor(hand_right, Vector2(-2.6, 8.8 * stature))

    _set_bone_anchor(thigh_left, Vector2(-leg_gap, 1.0))
    _set_bone_anchor(shin_left, Vector2(-0.8, 9.5 * stature))
    _set_bone_anchor(foot_left, Vector2(-1.4, 10.5 * stature))
    _set_bone_anchor(thigh_right, Vector2(leg_gap, 1.0))
    _set_bone_anchor(shin_right, Vector2(0.8, 9.5 * stature))
    _set_bone_anchor(foot_right, Vector2(1.4, 10.5 * stature))

    # Store the generated morphology as the Skeleton2D rest pose. This is key
    # for a later Polygon2D skin: it can deform from the profile's own body
    # shape rather than from one fixed, generic mesh. The idle pose is applied
    # as additive overrides on top of these rests, never by rewriting them.
    _rest_positions = {
        "pelvis": pelvis.position,
        "spine": spine.position,
        "chest": chest.position,
        "head": head.position,
        "upper_arm_left": upper_arm_left.position,
        "forearm_left": forearm_left.position,
        "hand_left": hand_left.position,
        "upper_arm_right": upper_arm_right.position,
        "forearm_right": forearm_right.position,
        "hand_right": hand_right.position,
        "thigh_left": thigh_left.position,
        "shin_left": shin_left.position,
        "foot_left": foot_left.position,
        "thigh_right": thigh_right.position,
        "shin_right": shin_right.position,
        "foot_right": foot_right.position,
    }
    skeleton.force_update_transform()
    _apply_idle_pose()


func _apply_idle_pose() -> void:
    if _rest_positions.is_empty():
        return
    # Bone positions are at render scale, so the native-unit drop shrinks too.
    var body_drop := Vector2(0.0, IDLE_BODY_DROP * CANVAS_SCALE) if _idle_body_down() else Vector2.ZERO
    # Dropping the spine lowers the whole upper body — chest, head, hair, and
    # arms ride along because the anchors sum down the bone chain — while the
    # pelvis and legs stay planted, which reads as a cozy breathing squash.
    spine.position = _rest_positions.spine + body_drop
    chest.position = _rest_positions.chest
    head.position = _rest_positions.head
    pelvis.position = _rest_positions.pelvis
    upper_arm_left.position = _rest_positions.upper_arm_left
    forearm_left.position = _rest_positions.forearm_left
    hand_left.position = _rest_positions.hand_left
    upper_arm_right.position = _rest_positions.upper_arm_right
    forearm_right.position = _rest_positions.forearm_right
    hand_right.position = _rest_positions.hand_right
    thigh_left.position = _rest_positions.thigh_left
    shin_left.position = _rest_positions.shin_left
    foot_left.position = _rest_positions.foot_left
    thigh_right.position = _rest_positions.thigh_right
    shin_right.position = _rest_positions.shin_right
    foot_right.position = _rest_positions.foot_right
    skeleton.force_update_transform()
    _push_profile(_is_blinking())


func _idle_body_down() -> bool:
    return int(idle_phase / IDLE_FRAME_SECONDS) % 2 == 1


func _is_blinking() -> bool:
    return fmod(idle_phase, BLINK_PERIOD) > BLINK_PERIOD - BLINK_SECONDS


func _push_profile(blink := false) -> void:
    _canvas.profile = {
        "height": height,
        "weight": weight,
        "hip_width": hip_width,
        "bust_size": bust_size,
        "skin_tone": skin_tone,
        "outfit_index": int(outfit_index),
        "hair_index": int(hair_index),
        "hair_color_index": int(hair_color_index),
        "eye_index": int(eye_index),
        "facing": int(facing),
        "show_rig_guides": show_rig_guides,
        "blink": blink,
    }
    _apply_overrides()
    _canvas.anchors = _compute_anchors()
    if Engine.is_editor_hint():
        var layer := get_node_or_null("AuthoredShapes") as Node2D
        if layer != null:
            _update_authored_visibility(layer)
    # Left is the right-facing art mirrored inside the same texture rect, so
    # the viewport, the pixel grid, and every draw path stay single-sourced.
    _sprite.flip_h = int(facing) == 2
    _canvas.queue_redraw()


func _compute_anchors() -> Dictionary:
    # Bones live at render scale; the canvas draws in native units, so divide
    # the summed chains back out by CANVAS_SCALE before handing them over.
    var pelvis_position := pelvis.position
    var spine_position := pelvis_position + spine.position
    var chest_position := spine_position + chest.position
    var head_position := chest_position + head.position
    var upper_arm_left_position := chest_position + upper_arm_left.position
    var forearm_left_position := upper_arm_left_position + forearm_left.position
    var upper_arm_right_position := chest_position + upper_arm_right.position
    var forearm_right_position := upper_arm_right_position + forearm_right.position
    var thigh_left_position := pelvis_position + thigh_left.position
    var shin_left_position := thigh_left_position + shin_left.position
    var thigh_right_position := pelvis_position + thigh_right.position
    var shin_right_position := thigh_right_position + shin_right.position
    var anchors := {
        "pelvis": pelvis_position,
        "spine": spine_position,
        "chest": chest_position,
        "head": head_position,
        "upper_arm_left": upper_arm_left_position,
        "forearm_left": forearm_left_position,
        "hand_left": forearm_left_position + hand_left.position,
        "upper_arm_right": upper_arm_right_position,
        "forearm_right": forearm_right_position,
        "hand_right": forearm_right_position + hand_right.position,
        "thigh_left": thigh_left_position,
        "shin_left": shin_left_position,
        "foot_left": shin_left_position + foot_left.position,
        "thigh_right": thigh_right_position,
        "shin_right": shin_right_position,
        "foot_right": shin_right_position + foot_right.position,
    }
    for key in anchors:
        anchors[key] = anchors[key] / CANVAS_SCALE
    return anchors


func _set_bone_anchor(bone: Bone2D, local_position: Vector2) -> void:
    # Bones are authored at render (pixel) scale so the editor's bone gizmos
    # line up with the drawn character 1:1. The canvas consumes native units,
    # so _compute_anchors rescales summed bone positions back up.
    var display_position := local_position * CANVAS_SCALE
    bone.position = display_position
    # Bone2D's default rest is a zero transform, not an identity transform.
    # Construct the rest explicitly so Skeleton2D can invert every generated
    # joint transform when a future Polygon2D is bound to this rig.
    bone.rest = Transform2D(Vector2.RIGHT, Vector2.DOWN, display_position)


func _morph_fraction(value: float) -> float:
    return clampf(value / MORPH_PARAMETER_MAX, 0.0, 1.0)
