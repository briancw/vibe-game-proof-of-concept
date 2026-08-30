@tool
class_name CharacterRigV2
extends Node2D

## Polygon-skinned character rig (the character-v2 prototype).
##
## Unlike the v1 canvas painter, every body part here is a real Polygon2D
## node parented to the Skeleton2D and deformed through bone weights, so the
## character is authored, posed, and edited with Godot's own 2D tooling:
## drag polygon points in the editor, rotate bones, and everything follows.
##
## Authoring conventions:
##   - 1 scene unit = 1 authoring pixel; the character stands on y = 0,
##     facing down (toward the camera) and is ~764 units tall. Drop an
##     instance into a scene at scale 1.0/16 to land it on the 16x16 tile
##     grid at the same size as the v1 character (16 units = 1 world pixel).
##   - Part polygons live in skeleton space at the rest pose. Rigid parts
##     bind one bone (plus a little of its parent near joints for smooth
##     bending); the torso spans Hips/Spine/Chest so it can flex.
##   - Outlines are DERIVED, never authored: this script maintains sibling
##     "<Part>Outline" polygons for every part, expanded radially from the
##     part's centroid. All outlines for a layer render together BEHIND that
##     layer's parts (an "Outlines" container under the Skeleton2D, or under
##     each outfit root), so neighboring parts cover each other's outlines
##     and the body reads as one continuous silhouette with no seams at the
##     knees, waist, or collar. Editing a part's points updates its outline
##     automatically in the editor. Generated outline nodes are never saved
##     into the .tscn. Parts named with a "Face" prefix opt out of outlines.
##
## The rig ships as a NUDE base: every part is skin, and clothing is added
## through the `outfits` array. An outfit is any scene whose root holds
## skinned Polygon2D garments (same bone chains, `skeleton = ../..`); the
## instances are layered under the Skeleton2D right before `BackHair`, in
## array order, so later outfits draw on top (shirt after pants).
##
## BODY SHAPES: the rig is one androgynous base plus a morph layer. The
## `Body Shape` exports define a smooth warp field over skeleton space — a
## vertical landmark remap (leg/torso/neck/head length), per-band horizontal
## scaling (shoulders/chest/waist/hips/thighs/calves), and a localized bust
## bump. The same field is applied to every bone rest and every skinned
## polygon (body AND garments), so a morphed character stays perfectly
## coherent and clothing automatically follows the body it hangs on.
## `body_preset` fills the parameters with curated masculine/feminine
## values; individual exports override from there. All 1.0 / no-bust values
## reproduce the authored base exactly. Warps always recompute from the
## authored shapes cached at load, so tweaking sliders never compounds.
## Persist a shape by saving a variant scene that sets `body_preset` (plus
## any overrides) on an instance — the base scene stays untouched.

const OUTLINE_META := "v2_outline_of"
const OUTLINE_LAYER_META := "v2_outline_layer"
const SIGNATURE_META := "v2_outline_signature"
const OUTFIT_META := "v2_outfit_instance"
const OUTFIT_SIG_META := "v2_outfit_signature"
const MORPH_SIG_META := "v2_morph_signature"
const BASE_POLYGON_META := "v2_base_polygon"
const BASE_BONE_META := "v2_base_bone_origin"

# Rest-pose landmarks in skeleton space (see the warp field below).
const Y_FEET := 0.0
const Y_KNEE := -180.0
const Y_HIP := -360.0
const Y_WAIST := -440.0
const Y_CHEST := -520.0
const Y_SHOULDER := -576.0
const Y_CHIN := -598.0
const Y_HEAD_TOP := -760.0

## Curated body shapes; `body_preset` copies these into the exports.
const BODY_PRESETS := {
    "masculine": {
        "leg_length": 1.04, "torso_length": 1.08, "neck_length": 1.25,
        "head_size": 0.95, "shoulder_width": 1.24, "chest_width": 1.1,
        "waist_width": 0.98, "hip_width": 0.95, "thigh_width": 1.04,
        "calf_width": 1.04, "bust": 0.0, "hair_length": 0.1,
    },
    "feminine": {
        "leg_length": 1.12, "torso_length": 0.92, "neck_length": 0.88,
        "head_size": 1.14, "shoulder_width": 0.85, "chest_width": 0.96,
        "waist_width": 0.76, "hip_width": 1.16, "thigh_width": 1.08,
        "calf_width": 0.9, "bust": 0.6, "hair_length": 1.3,
    },
}

@export_group("Outline")

@export var outline_enabled := true:
    set(value):
        outline_enabled = value
        _sync_outlines()

@export var outline_color := Color("43394a"):
    set(value):
        outline_color = value
        _sync_outlines()

## Outline thickness in scene units (16 units = 1 world pixel at game scale).
@export_range(0.0, 40.0, 0.5) var outline_width := 14.0:
    set(value):
        outline_width = value
        _sync_outlines()

## Garments usually read better with their own derived outline; turn off for
## outfits that ship pre-outlined art.
@export var garment_outlines := true:
    set(value):
        garment_outlines = value
        _sync_outlines()

@export_tool_button("Rebuild Outlines") var rebuild_outlines: Callable = func() -> void: _sync_outlines(true)

@export_group("Body Shape")

## Curated starting point: "masculine", "feminine", or "custom" to keep the
## current values as-is.
@export_enum("custom", "masculine", "feminine") var body_preset: String = "custom":
    set(value):
        body_preset = value
        if BODY_PRESETS.has(value):
            for key: String in BODY_PRESETS[value]:
                set(key, BODY_PRESETS[value][key])

## Scales everything below the hips (knee/hip landmark heights).
@export_range(0.7, 1.3, 0.01) var leg_length := 1.0:
    set(value):
        leg_length = value
        _invalidate_morphs()

## Scales the hip-to-shoulder span.
@export_range(0.7, 1.3, 0.01) var torso_length := 1.0:
    set(value):
        torso_length = value
        _invalidate_morphs()

## Scales the shoulder-to-chin span.
@export_range(0.6, 1.5, 0.01) var neck_length := 1.0:
    set(value):
        neck_length = value
        _invalidate_morphs()

## Scales the head band (both axes).
@export_range(0.7, 1.4, 0.01) var head_size := 1.0:
    set(value):
        head_size = value
        _invalidate_morphs()

@export_range(0.7, 1.5, 0.01) var shoulder_width := 1.0:
    set(value):
        shoulder_width = value
        _invalidate_morphs()

@export_range(0.7, 1.5, 0.01) var chest_width := 1.0:
    set(value):
        chest_width = value
        _invalidate_morphs()

@export_range(0.6, 1.5, 0.01) var waist_width := 1.0:
    set(value):
        waist_width = value
        _invalidate_morphs()

@export_range(0.7, 1.5, 0.01) var hip_width := 1.0:
    set(value):
        hip_width = value
        _invalidate_morphs()

@export_range(0.7, 1.5, 0.01) var thigh_width := 1.0:
    set(value):
        thigh_width = value
        _invalidate_morphs()

@export_range(0.7, 1.5, 0.01) var calf_width := 1.0:
    set(value):
        calf_width = value
        _invalidate_morphs()

## Scales the BackHair bottom edge toward/away from the head (1.0 = authored
## length, 0.1 = ear-length crop, >1.0 = longer locks), so presets can vary
## hairstyle length.
@export_range(0.05, 1.4, 0.01) var hair_length := 1.0:
    set(value):
        hair_length = value
        _invalidate_morphs()

## Localized chest bump strength (0 = flat, 1 = pronounced).
@export_range(0.0, 1.0, 0.01) var bust := 0.0:
    set(value):
        bust = value
        _invalidate_morphs()

## Bust bump center in base skeleton space; side-view rigs aim it forward
## along +x.
@export var bust_center := Vector2(0, -516):
    set(value):
        bust_center = value
        _invalidate_morphs()

@export_range(30.0, 140.0, 1.0) var bust_radius := 78.0:
    set(value):
        bust_radius = value
        _invalidate_morphs()

## Garment scenes layered over the nude body, in draw order (later entries
## draw on top, so put the shirt after the pants). Instances live under the
## Skeleton2D right before `BackHair` and are never saved into the .tscn.
@export var outfits: Array[PackedScene] = []:
    set(value):
        outfits = value
        _sync_outfits()

# Warp tables: (base_y, warped_y) top-to-bottom, and (warped_y, x_scale).
var _warp_y: Array[Vector2] = []
var _warp_x: Array[Vector2] = []


func _ready() -> void:
    _sync_outfits()
    _apply_morphs()
    _sync_outlines()


func _process(_delta: float) -> void:
    # In the editor, keep morphs and outlines following live polygon edits
    # made in the 2D view. The signature checks inside make no-change frames
    # cheap.
    if Engine.is_editor_hint():
        _sync_outfits()
        _apply_morphs()
        _sync_outlines()


func _sync_outlines(force := false) -> void:
    var skeleton := get_node_or_null("Skeleton2D") as Skeleton2D
    if skeleton == null:
        return
    var layer := _ensure_outline_layer(skeleton)
    for child in skeleton.get_children():
        var part := child as Polygon2D
        if part == null or part.has_meta(OUTLINE_META) or String(part.name).begins_with("Face"):
            continue
        _sync_part_outline(layer, skeleton, part, force)
    for child in skeleton.get_children():
        if not child.has_meta(OUTFIT_META):
            continue
        var garment_layer := _ensure_outline_layer(child)
        for part in child.get_children():
            var polygon := part as Polygon2D
            if polygon == null or String(polygon.name).begins_with("Face"):
                continue
            _sync_part_outline(garment_layer, skeleton, polygon, force)
        if not garment_outlines or not outline_enabled:
            _remove_outline_layer(child)


## Instance (or refresh) the outfit scenes under the Skeleton2D, right
## before `BackHair` so garments cover the body but sit under hair, neck,
## and head.
func _sync_outfits() -> void:
    var skeleton := get_node_or_null("Skeleton2D") as Skeleton2D
    if skeleton == null:
        return
    var signature := ""
    for scene in outfits:
        signature += str(scene.resource_path, ";")
    if get_meta(OUTFIT_SIG_META, "") == signature:
        return
    set_meta(OUTFIT_SIG_META, signature)
    for child in skeleton.get_children():
        if child.has_meta(OUTFIT_META):
            skeleton.remove_child(child)
            child.queue_free()
    var anchor := skeleton.get_node_or_null(NodePath("BackHair")) as Node2D
    if anchor == null:
        anchor = skeleton.get_node_or_null(NodePath("Neck")) as Node2D
    var index := anchor.get_index() if anchor != null else skeleton.get_child_count()
    for scene in outfits:
        if scene == null:
            continue
        var outfit := scene.instantiate() as Node2D
        outfit.set_meta(OUTFIT_META, true)
        skeleton.add_child(outfit)
        skeleton.move_child(outfit, index)
        index += 1
    # Fresh garment polygons need a morph pass even when the body is done.
    set_meta(MORPH_SIG_META, "")


func _ensure_outline_layer(parent: Node) -> Node2D:
    var layer := parent.get_node_or_null(NodePath("Outlines")) as Node2D
    if layer == null:
        layer = Node2D.new()
        layer.name = "Outlines"
        layer.set_meta(OUTLINE_LAYER_META, true)
        parent.add_child(layer)
        parent.move_child(layer, 0)
    return layer


func _remove_outline_layer(parent: Node) -> void:
    var layer := parent.get_node_or_null(NodePath("Outlines")) as Node2D
    if layer != null:
        parent.remove_child(layer)
        layer.queue_free()


func _sync_part_outline(layer: Node2D, skeleton: Skeleton2D, part: Polygon2D, force: bool) -> void:
    var outline_name := String(part.name) + "Outline"
    var signature := str(outline_enabled, "|", outline_color.to_html(), "|", outline_width, "|", part.polygon)
    var outline := layer.get_node_or_null(NodePath(outline_name)) as Polygon2D
    if outline == null and outline_enabled:
        outline = Polygon2D.new()
        outline.name = outline_name
        outline.set_meta(OUTLINE_META, String(part.name))
        layer.add_child(outline)
    if outline != null and not force and outline.get_meta(SIGNATURE_META, "") == signature:
        return
    if not outline_enabled:
        if outline != null:
            outline.queue_free()
        return
    outline.polygon = _expanded_points(part.polygon, outline_width)
    outline.color = outline_color
    # Mirror the part's skinning so the outline deforms with the same bones.
    # The skeleton path is recomputed because the outline lives in a layer
    # container, not next to its part.
    outline.skeleton = outline.get_path_to(skeleton)
    outline.bones = part.bones
    outline.set_meta(SIGNATURE_META, signature)


## Radial expansion from the polygon centroid: same vertex count, so a
## skinned outline reuses its part's bone weights verbatim.
func _expanded_points(points: PackedVector2Array, amount: float) -> PackedVector2Array:
    var center := Vector2.ZERO
    if points.is_empty():
        return points
    for point in points:
        center += point
    center /= float(points.size())
    var expanded := PackedVector2Array()
    expanded.resize(points.size())
    for index in range(points.size()):
        var offset := points[index] - center
        var length := offset.length()
        expanded[index] = points[index] if length < 0.01 else center + offset * (length + amount) / length
    return expanded


# --- Body shape morphs -------------------------------------------------------
#
# The warp field is a vertical landmark remap (piecewise linear through the
# Y_* landmarks, so limb segments stretch while feet stay planted), a
# per-band horizontal scale sampled in the warped space, and an optional
# localized bust bump. Bones and polygons sample the same field, so a
# morphed body and its garments stay registered to the skeleton.


func _morph_signature() -> String:
    return str(leg_length, "|", torso_length, "|", neck_length, "|", head_size,
        "|", shoulder_width, "|", chest_width, "|", waist_width, "|", hip_width,
        "|", thigh_width, "|", calf_width, "|", hair_length, "|", bust,
        "|", bust_center, "|", bust_radius)


func _invalidate_morphs() -> void:
    if is_inside_tree():
        _apply_morphs()


func _apply_morphs() -> void:
    var skeleton := get_node_or_null("Skeleton2D") as Skeleton2D
    if skeleton == null:
        return
    var signature := _morph_signature()
    if get_meta(MORPH_SIG_META, "") == signature:
        return
    set_meta(MORPH_SIG_META, signature)
    _rebuild_warp_tables()
    for child in skeleton.get_children():
        if child is Bone2D:
            _morph_bone_chain(child, Vector2.ZERO)
    _morph_polygon_tree(skeleton)


func _morph_bone_chain(bone: Bone2D, parent_base: Vector2) -> void:
    if not bone.has_meta(BASE_BONE_META):
        bone.set_meta(BASE_BONE_META, parent_base + bone.position)
    var base: Vector2 = bone.get_meta(BASE_BONE_META)
    bone.position = _warp_point(base) - _warp_point(parent_base)
    bone.rest = Transform2D(0.0, bone.position)
    for child in bone.get_children():
        if child is Bone2D:
            _morph_bone_chain(child, base)


func _morph_polygon_tree(node: Node) -> void:
    for child in node.get_children():
        var polygon := child as Polygon2D
        if polygon != null and not polygon.skeleton.is_empty() and not polygon.has_meta(OUTLINE_META):
            if not polygon.has_meta(BASE_POLYGON_META):
                polygon.set_meta(BASE_POLYGON_META, polygon.polygon.duplicate())
            var points := _warp_points(polygon.get_meta(BASE_POLYGON_META) as PackedVector2Array)
            if String(polygon.name).begins_with("BackHair"):
                points = _shorten_hair(points)
            polygon.polygon = points
        else:
            _morph_polygon_tree(child)


## Hair length scales each BackHair point toward/away from the skull anchor
## just above the *warped* chin (1.0 = authored length, 0.1 = ear-length
## crop, >1.0 = longer locks). Points below the anchor also ease toward the
## skull axis in x, so short crops hug the head instead of spiking outward.
func _shorten_hair(points: PackedVector2Array) -> PackedVector2Array:
    if hair_length >= 0.999:
        return points
    var anchor := _warp_point(Vector2(0.0, Y_CHIN)).y - 42.0
    var x_scale := 1.0 + (hair_length - 1.0) * 0.5
    var shortened := PackedVector2Array()
    shortened.resize(points.size())
    for index in range(points.size()):
        var point := points[index]
        if point.y > anchor:
            point.y = anchor + (point.y - anchor) * hair_length
            point.x *= x_scale
        shortened[index] = point
    return shortened


func _rebuild_warp_tables() -> void:
    var knee_y := Y_KNEE * leg_length
    var hip_y := Y_HIP * leg_length
    var shoulder_y := hip_y + (Y_SHOULDER - Y_HIP) * torso_length
    var waist_y := hip_y + (Y_WAIST - Y_HIP) * torso_length
    var chest_y := hip_y + (Y_CHEST - Y_HIP) * torso_length
    var chin_y := shoulder_y + (Y_CHIN - Y_SHOULDER) * neck_length
    var top_y := chin_y + (Y_HEAD_TOP - Y_CHIN) * head_size
    _warp_y = [
        Vector2(Y_FEET, Y_FEET),
        Vector2(Y_KNEE, knee_y),
        Vector2(Y_HIP, hip_y),
        Vector2(Y_WAIST, waist_y),
        Vector2(Y_CHEST, chest_y),
        Vector2(Y_SHOULDER, shoulder_y),
        Vector2(Y_CHIN, chin_y),
        Vector2(Y_HEAD_TOP, top_y),
    ]
    _warp_x = []
    for band: Array in [
        [Y_FEET, 1.0], [-90.0, calf_width], [-270.0, thigh_width],
        [Y_HIP, hip_width], [Y_WAIST, waist_width], [Y_CHEST, chest_width],
        [Y_SHOULDER, shoulder_width], [-640.0, head_size], [Y_HEAD_TOP - 40.0, head_size],
    ]:
        _warp_x.append(Vector2(_map_y(band[0]), band[1]))


func _map_y(y: float) -> float:
    return _interp_table(_warp_y, y)


func _warp_point(point: Vector2) -> Vector2:
    var warped := Vector2(point.x * _interp_table(_warp_x, _map_y(point.y)), _map_y(point.y))
    if bust > 0.001 and not _warp_x.is_empty():
        var base_center := Vector2(
            bust_center.x * _interp_table(_warp_x, _map_y(bust_center.y)),
            _map_y(bust_center.y))
        var offset := warped - base_center
        var distance := offset.length()
        if distance < bust_radius:
            var falloff := exp(-2.0 * pow(distance / bust_radius, 2.0))
            warped += offset / maxf(distance, 0.01) * bust * 26.0 * falloff
    return warped


func _warp_points(points: PackedVector2Array) -> PackedVector2Array:
    var warped := PackedVector2Array()
    warped.resize(points.size())
    for index in range(points.size()):
        warped[index] = _warp_point(points[index])
    return warped


## Piecewise-linear interpolation over a table of (y, value) pairs sorted
## from y = 0 down to the most negative y. Clamps at the feet and
## extrapolates linearly above the head.
func _interp_table(table: Array[Vector2], y: float) -> float:
    if table.is_empty():
        return y
    if y >= table[0].x:
        return table[0].y
    var last := table[table.size() - 1]
    if y <= last.x:
        var previous := table[table.size() - 2]
        var slope := (last.y - previous.y) / (last.x - previous.x)
        return last.y + (y - last.x) * slope
    for index in range(table.size() - 1):
        var a := table[index]
        var b := table[index + 1]
        if y >= b.x:
            var t := (a.x - y) / (a.x - b.x)
            return lerpf(a.y, b.y, t)
    return last.y
