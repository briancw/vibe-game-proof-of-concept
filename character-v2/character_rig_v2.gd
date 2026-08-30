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
##   - Outlines are DERIVED, never authored: this script maintains a sibling
##     "<Part>Outline" polygon for every part, expanded radially from the
##     part's centroid. Editing a part's points updates its outline
##     automatically in the editor, so the two can never drift apart. The
##     generated outline nodes are deliberately not owned by the scene root
##     and never saved into the .tscn file.
##
## The rig ships as a NUDE base: every part is skin, and clothing is added
## through the `outfits` array. An outfit is any scene whose root holds
## skinned Polygon2D garments (same bone chains, `skeleton = ../..`); the
## instances are layered under the Skeleton2D right before `Neck`, in array
## order, so later outfits draw on top (shirt after pants). The rig comes in
## two views sharing this script and bone layout: `character_rig_v2.tscn`
## (front, facing the camera) and `character_rig_v2_side.tscn` (profile,
## facing +x).

const OUTLINE_META := "v2_outline_of"
const SIGNATURE_META := "v2_outline_signature"
const OUTFIT_META := "v2_outfit_instance"
const OUTFIT_SIG_META := "v2_outfit_signature"

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

@export_tool_button("Rebuild Outlines") var rebuild_outlines: Callable = func() -> void: _sync_outlines(true)

## Garment scenes layered over the nude body, in draw order (later entries
## draw on top, so put the shirt after the pants). Instances live under the
## Skeleton2D right before `Neck` and are never saved into the .tscn.
@export var outfits: Array[PackedScene] = []:
    set(value):
        outfits = value
        _sync_outfits()


func _ready() -> void:
    _sync_outfits()
    _sync_outlines()


func _process(_delta: float) -> void:
    # In the editor, keep outlines following live polygon edits made in the
    # 2D view. The signature check inside makes no-change frames cheap.
    if Engine.is_editor_hint():
        _sync_outfits()
        _sync_outlines()


func _sync_outlines(force := false) -> void:
    var skeleton := get_node_or_null("Skeleton2D") as Skeleton2D
    if skeleton == null:
        return
    for child in skeleton.get_children():
        var part := child as Polygon2D
        if part == null or part.has_meta(OUTLINE_META):
            continue
        _sync_part_outline(skeleton, part, force)


## Instance (or refresh) the outfit scenes under the Skeleton2D, right
## before `Neck` so garments cover the body but sit under neck and head.
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
    var neck := skeleton.get_node_or_null(NodePath("Neck")) as Node2D
    var index := neck.get_index() if neck != null else skeleton.get_child_count()
    for scene in outfits:
        if scene == null:
            continue
        var outfit := scene.instantiate() as Node2D
        outfit.set_meta(OUTFIT_META, true)
        skeleton.add_child(outfit)
        skeleton.move_child(outfit, index)
        index += 1


func _sync_part_outline(skeleton: Skeleton2D, part: Polygon2D, force: bool) -> void:
    var outline_name := String(part.name) + "Outline"
    var signature := str(outline_enabled, "|", outline_color.to_html(), "|", outline_width, "|", part.polygon)
    var outline := skeleton.get_node_or_null(NodePath(outline_name)) as Polygon2D
    if outline == null and outline_enabled:
        outline = Polygon2D.new()
        outline.name = outline_name
        outline.set_meta(OUTLINE_META, String(part.name))
        skeleton.add_child(outline)
        # Draw directly behind its part: outlines and parts stay adjacent so
        # the tree order remains the draw order.
        skeleton.move_child(outline, part.get_index())
    if outline != null and not force and outline.get_meta(SIGNATURE_META, "") == signature:
        return
    if not outline_enabled:
        if outline != null:
            outline.queue_free()
        return
    outline.polygon = _expanded_points(part.polygon, outline_width)
    outline.color = outline_color
    # Mirror the part's skinning so the outline deforms with the same bones.
    # The skeleton path is recomputed because the outline always sits directly
    # under the Skeleton2D, while its part may be nested inside an outfit.
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
