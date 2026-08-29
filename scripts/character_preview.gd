@tool
class_name CharacterPreview
extends Node2D

## A procedural illustration renderer backed by a real Skeleton2D hierarchy.
## The renderer owns no character artwork: it derives its layered silhouettes
## from named bones and a compact, text-friendly set of body parameters.

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
		queue_redraw()

@export_range(0.0, 1.0, 1.0) var outfit_index := 0:
	set(value):
		outfit_index = int(value)
		queue_redraw()

@export var show_rig_guides := false:
	set(value):
		show_rig_guides = value
		queue_redraw()

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

const OUTLINE := Color("241d27")
const HAIR := Color("4a2f31")
const HAIR_LIGHT := Color("6e4941")
const SKIN_LIGHT := Color("f5d0aa")
const SKIN_DARK := Color("74442f")
const OUTFITS := [Color("6ba7a7"), Color("bd6e63"), Color("8f82b8")]
const TROUSERS := [Color("405d70"), Color("62464d"), Color("4d496e")]


func _ready() -> void:
	_rebuild_rig()


func _refresh_character() -> void:
	if is_node_ready():
		_rebuild_rig()
	queue_redraw()


func _rebuild_rig() -> void:
	# These are the parametric rest-pose anchors. Animation will later apply
	# pose overrides to this same hierarchy rather than moving any art nodes.
	var height_fraction := _morph_fraction(height)
	var weight_fraction := _morph_fraction(weight)
	var hip_fraction := _morph_fraction(hip_width)
	var bust_fraction := _morph_fraction(bust_size)
	var stature := lerpf(0.84, 1.18, height_fraction)
	var body_width := lerpf(0.82, 1.20, weight_fraction)
	var shoulder_half := (11.5 + bust_fraction * 6.5) * body_width
	var hip_half := (10.5 + hip_fraction * 7.0) * body_width
	var leg_gap := 3.7 * body_width

	_set_bone_anchor(pelvis, Vector2(0.0, -18.0 * stature))
	_set_bone_anchor(spine, Vector2(0.0, -12.0 * stature))
	_set_bone_anchor(chest, Vector2(0.0, -12.0 * stature))
	# The head joins the chest directly. Omitting a neck bone is intentional for
	# this compact character language and keeps the silhouette more iconic.
	_set_bone_anchor(head, Vector2(0.0, -15.0 * stature))

	_set_bone_anchor(upper_arm_left, Vector2(-shoulder_half, 1.0))
	_set_bone_anchor(forearm_left, Vector2(-3.0 * body_width, 12.5 * stature))
	_set_bone_anchor(hand_left, Vector2(-1.0, 12.5 * stature))
	_set_bone_anchor(upper_arm_right, Vector2(shoulder_half, 1.0))
	_set_bone_anchor(forearm_right, Vector2(3.0 * body_width, 12.5 * stature))
	_set_bone_anchor(hand_right, Vector2(1.0, 12.5 * stature))

	_set_bone_anchor(thigh_left, Vector2(-leg_gap, 1.0))
	_set_bone_anchor(shin_left, Vector2(-0.5, 9.5 * stature))
	_set_bone_anchor(foot_left, Vector2(-1.0, 10.5 * stature))
	_set_bone_anchor(thigh_right, Vector2(leg_gap, 1.0))
	_set_bone_anchor(shin_right, Vector2(0.5, 9.5 * stature))
	_set_bone_anchor(foot_right, Vector2(1.0, 10.5 * stature))

	# Store the generated morphology as the Skeleton2D rest pose. This is key
	# for a later Polygon2D skin: it can deform from the profile's own body
	# shape rather than from one fixed, generic mesh.
	skeleton.force_update_transform()
	queue_redraw()


func _set_bone_anchor(bone: Bone2D, local_position: Vector2) -> void:
	bone.position = local_position
	# Bone2D's default rest is a zero transform, not an identity transform.
	# Construct the rest explicitly so Skeleton2D can invert every generated
	# joint transform when a future Polygon2D is bound to this rig.
	bone.rest = Transform2D(Vector2.RIGHT, Vector2.DOWN, local_position)


func _draw() -> void:
	if not is_node_ready():
		return
	var weight_fraction := _morph_fraction(weight)
	var hip_fraction := _morph_fraction(hip_width)
	var bust_fraction := _morph_fraction(bust_size)
	var body_width := lerpf(0.82, 1.20, weight_fraction)
	var skin := SKIN_LIGHT.lerp(SKIN_DARK, _morph_fraction(skin_tone))
	var clothing: Color = OUTFITS[outfit_index % OUTFITS.size()]
	var trousers: Color = TROUSERS[outfit_index % TROUSERS.size()]
	var chest_center := _bone_anchor(chest)
	var waist_center := _bone_anchor(spine)
	var pelvis_center := _bone_anchor(pelvis)
	var head_center := _bone_anchor(head)

	var chest_half := (11.5 + bust_fraction * 6.5) * body_width
	var waist_half := (6.3 + weight_fraction * 1.9) * body_width
	var hip_half := (10.5 + hip_fraction * 7.0) * body_width

	# Each limb is built between real rig joints. The pose may change later,
	# while the body recipe remains entirely text/parameter driven.
	_draw_limb(_bone_anchor(upper_arm_left), _bone_anchor(forearm_left), skin, 6.5)
	_draw_limb(_bone_anchor(forearm_left), _bone_anchor(hand_left), skin, 5.8)
	_draw_limb(_bone_anchor(upper_arm_right), _bone_anchor(forearm_right), skin, 6.5)
	_draw_limb(_bone_anchor(forearm_right), _bone_anchor(hand_right), skin, 5.8)
	_draw_limb(_bone_anchor(thigh_left), _bone_anchor(shin_left), trousers, 10.0)
	_draw_limb(_bone_anchor(shin_left), _bone_anchor(foot_left), trousers, 8.8)
	_draw_limb(_bone_anchor(thigh_right), _bone_anchor(shin_right), trousers, 10.0)
	_draw_limb(_bone_anchor(shin_right), _bone_anchor(foot_right), trousers, 8.8)

	# The torso contour deliberately contracts at the waist then returns to the
	# chest and hips. It is a generated figure-eight silhouette, not a scaled
	# rectangle, so bust/hip changes stay readable as separate features.
	_draw_filled_shape(_figure_eight_torso(chest_center, waist_center, pelvis_center, chest_half, waist_half, hip_half), clothing)
	_draw_waist_seam(pelvis_center, hip_half, clothing)

	_draw_hand(_bone_anchor(hand_left), skin)
	_draw_hand(_bone_anchor(hand_right), skin)

	_draw_ellipse(head_center, Vector2(13.0, 14.0), OUTLINE)
	_draw_ellipse(head_center, Vector2(11.2, 12.0), skin)
	_draw_hair(head_center)
	_draw_face(head_center, skin)

	_draw_foot(_bone_anchor(foot_left))
	_draw_foot(_bone_anchor(foot_right))
	if show_rig_guides:
		_draw_rig_guides()


func _bone_anchor(bone: Bone2D) -> Vector2:
	return to_local(bone.global_position)


func _morph_fraction(value: float) -> float:
	return clampf(value / MORPH_PARAMETER_MAX, 0.0, 1.0)


func _figure_eight_torso(chest_center: Vector2, waist_center: Vector2, pelvis_center: Vector2, chest_half: float, waist_half: float, hip_half: float) -> PackedVector2Array:
	return PackedVector2Array([
		chest_center + Vector2(-chest_half * 0.90, -2.0),
		chest_center + Vector2(-chest_half, 2.5),
		chest_center + Vector2(-chest_half * 0.91, 7.0),
		waist_center + Vector2(-waist_half * 1.14, -3.0),
		waist_center + Vector2(-waist_half, 1.0),
		waist_center + Vector2(-waist_half * 1.10, 5.0),
		pelvis_center + Vector2(-hip_half * 0.76, -5.0),
		pelvis_center + Vector2(-hip_half, -0.2),
		pelvis_center + Vector2(-hip_half * 0.88, 4.5),
		pelvis_center + Vector2(hip_half * 0.88, 4.5),
		pelvis_center + Vector2(hip_half, -0.2),
		pelvis_center + Vector2(hip_half * 0.76, -5.0),
		waist_center + Vector2(waist_half * 1.10, 5.0),
		waist_center + Vector2(waist_half, 1.0),
		waist_center + Vector2(waist_half * 1.14, -3.0),
		chest_center + Vector2(chest_half * 0.91, 7.0),
		chest_center + Vector2(chest_half, 2.5),
		chest_center + Vector2(chest_half * 0.90, -2.0),
	])


func _draw_waist_seam(pelvis_center: Vector2, hip_half: float, clothing: Color) -> void:
	var seam := PackedVector2Array([
		pelvis_center + Vector2(-hip_half * 0.72, -1.0),
		pelvis_center + Vector2(0.0, 1.6),
		pelvis_center + Vector2(hip_half * 0.72, -1.0),
	])
	draw_polyline(seam, clothing.lightened(0.14), 1.2, true)


func _draw_limb(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, OUTLINE, width + 3.0, true)
	draw_line(from, to, color, width, true)


func _draw_hand(position: Vector2, skin: Color) -> void:
	draw_circle(position, 3.2, OUTLINE, true)
	draw_circle(position, 2.0, skin, true)


func _draw_foot(position: Vector2) -> void:
	_draw_ellipse(position + Vector2(0.0, 1.0), Vector2(5.7, 3.0), OUTLINE)


func _draw_filled_shape(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	var outline_points := PackedVector2Array(points)
	outline_points.append(points[0])
	draw_polyline(outline_points, OUTLINE, 2.0, true)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	const SEGMENTS := 20
	for index in range(SEGMENTS):
		var angle := TAU * float(index) / float(SEGMENTS)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _draw_hair(head_center: Vector2) -> void:
	# A cap, fringe, and side locks are independent generated layers; later
	# recipes will swap this contour without requiring texture painting.
	var cap := PackedVector2Array([
		head_center + Vector2(-10.5, -1.0),
		head_center + Vector2(-10.0, -8.0),
		head_center + Vector2(-5.0, -12.0),
		head_center + Vector2(3.0, -12.5),
		head_center + Vector2(10.5, -7.0),
		head_center + Vector2(10.0, -0.5),
		head_center + Vector2(5.0, -4.0),
		head_center + Vector2(1.0, -1.0),
		head_center + Vector2(-3.5, -4.0),
	])
	draw_colored_polygon(cap, HAIR)
	draw_line(head_center + Vector2(-8.0, -8.0), head_center + Vector2(6.5, -9.5), HAIR_LIGHT, 1.2, true)
	_draw_ellipse(head_center + Vector2(-10.5, 3.0), Vector2(2.6, 5.5), HAIR)
	_draw_ellipse(head_center + Vector2(10.5, 3.0), Vector2(2.6, 5.5), HAIR)


func _draw_face(head_center: Vector2, skin: Color) -> void:
	var eye_y := head_center.y + 1.5
	draw_circle(Vector2(-4.0, eye_y), 1.45, OUTLINE, true)
	draw_circle(Vector2(4.0, eye_y), 1.45, OUTLINE, true)
	draw_line(head_center + Vector2(-2.2, 6.1), head_center + Vector2(2.2, 6.1), OUTLINE, 1.2, true)
	draw_circle(head_center + Vector2(-6.8, 5.0), 1.0, skin.lightened(0.08), true)


func _draw_rig_guides() -> void:
	var chains := [
		[pelvis, spine, chest, head],
		[chest, upper_arm_left, forearm_left, hand_left],
		[chest, upper_arm_right, forearm_right, hand_right],
		[pelvis, thigh_left, shin_left, foot_left],
		[pelvis, thigh_right, shin_right, foot_right],
	]
	for chain: Array in chains:
		var points := PackedVector2Array()
		for bone: Bone2D in chain:
			points.append(_bone_anchor(bone))
		draw_polyline(points, Color("f6d8a8", 0.85), 1.0, true)
		for point in points:
			draw_circle(point, 1.8, Color("f6d8a8"), true)
