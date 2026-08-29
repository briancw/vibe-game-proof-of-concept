@tool
class_name CharacterCanvas
extends Node2D

## Draws the parametric character in "native" units. The owning
## CharacterPreview scales this canvas down inside a low-resolution
## SubViewport, so every shape rasterizes directly onto the world pixel grid
## and the blitted texture matches the surrounding 16x16 tile art. Flat fills
## and hard edges are deliberate: antialiasing would read as fuzz once the
## result is magnified with nearest filtering.

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
]

var profile := {}
var anchors := {}


func _draw() -> void:
	if profile.is_empty() or anchors.is_empty():
		return
	var body_width := lerpf(0.82, 1.20, _frac(profile.weight))
	var chest_half := (9.6 + _frac(profile.bust_size) * 4.4) * body_width
	var waist_half := (7.9 + _frac(profile.weight) * 1.2) * body_width
	var hip_half := (9.9 + _frac(profile.hip_width) * 6.4) * body_width
	var skin := _skin_color(_frac(profile.skin_tone))
	var outfit_index := clampi(int(profile.outfit_index), 0, OUTFITS.size() - 1)
	var outfit: Dictionary = OUTFITS[outfit_index]
	var hair_index := clampi(int(profile.hair_index), 0, 3)
	var hair: Dictionary = HAIR_COLORS[clampi(int(profile.hair_color_index), 0, HAIR_COLORS.size() - 1)]
	var eye_style := clampi(int(profile.get("eye_index", 0)), 0, 2)

	var head: Vector2 = anchors.head
	var chest: Vector2 = anchors.chest
	var waist: Vector2 = anchors.spine
	var pelvis: Vector2 = anchors.pelvis

	_draw_shadow()
	_draw_hair_back(head, hair_index, hair)
	_draw_legs(outfit_index, outfit, skin)
	_draw_neck(chest, head, skin)
	match outfit_index:
		0:
			_draw_dress(chest, waist, pelvis, chest_half, waist_half, hip_half, outfit)
		1:
			_draw_sweater(chest, pelvis, chest_half, outfit)
		2:
			_draw_overalls(chest, waist, pelvis, chest_half, outfit)
		3:
			_draw_body_base(chest, waist, pelvis, chest_half, waist_half, hip_half, skin)
			_draw_tube_and_skirt(chest, waist, pelvis, chest_half, waist_half, hip_half, outfit)
		4:
			_draw_body_base(chest, waist, pelvis, chest_half, waist_half, hip_half, skin)
			_draw_bikini(chest, pelvis, chest_half, hip_half, outfit)
	_draw_arms(outfit_index, outfit, skin)
	_draw_head(head, skin, hair, eye_style)
	_draw_hair_front(head, hair_index, hair)
	if profile.show_rig_guides:
		_draw_rig_guides()


func _draw_shadow() -> void:
	var left: Vector2 = anchors.foot_left
	var right: Vector2 = anchors.foot_right
	_ellipse((left + right) * 0.5 + Vector2(0.0, 2.6), Vector2(13.0, 3.4), Color(0.22, 0.13, 0.12, 0.38))


func _draw_hair_back(head: Vector2, style: int, hair: Dictionary) -> void:
	match style:
		1:
			# Long hair falls behind the shoulders in one soft panel that
			# clearly peeks out beside the torso.
			_filled(PackedVector2Array([
				head + Vector2(-10.6, -6.0),
				head + Vector2(-12.8, 2.0),
				head + Vector2(-12.4, 14.0),
				head + Vector2(-7.0, 26.0),
				head + Vector2(7.0, 26.0),
				head + Vector2(12.4, 14.0),
				head + Vector2(12.8, 2.0),
				head + Vector2(10.6, -6.0),
			]), hair.base)
		3:
			# A high ponytail sweeping out of the face and hanging past the
			# jaw on one side.
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


func _draw_legs(outfit_index: int, outfit: Dictionary, skin: Color) -> void:
	var leg_color: Color = outfit.bottoms
	var leg_width := 7.4
	match outfit_index:
		0:
			leg_width = 6.4
		1:
			leg_width = 7.8
		2:
			leg_width = 8.0
		3:
			leg_color = skin
			leg_width = 5.8
		4:
			leg_color = skin
			leg_width = 5.6
	_limb(PackedVector2Array([anchors.thigh_left, anchors.shin_left, anchors.foot_left]), leg_color, leg_width)
	_limb(PackedVector2Array([anchors.thigh_right, anchors.shin_right, anchors.foot_right]), leg_color, leg_width)
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
		_:
			# Bare feet with a thin sandal sole; the skin above stays bare.
			_outlined_ellipse(anchors.foot_left + Vector2(0.0, 1.4), Vector2(4.0, 1.9), outfit.shoes)
			_outlined_ellipse(anchors.foot_right + Vector2(0.0, 1.4), Vector2(4.0, 1.9), outfit.shoes)


func _draw_neck(chest: Vector2, head: Vector2, skin: Color) -> void:
	var top := head + Vector2(0.0, 8.0)
	var bottom := chest + Vector2(0.0, -1.2)
	var mid := (top + bottom) * 0.5
	var half_length := top.distance_to(bottom) * 0.5 + 2.2
	_ellipse(mid, Vector2(3.0, half_length), OUTLINE)
	_ellipse(mid, Vector2(2.2, half_length - 0.7), skin)


func _draw_dress(chest: Vector2, waist: Vector2, pelvis: Vector2, chest_half: float, waist_half: float, hip_half: float, outfit: Dictionary) -> void:
	# One continuous bodice-to-skirt silhouette so no seam breaks the outline.
	var hem_y := pelvis.y + 10.0
	var hem_half := hip_half * 1.36
	_filled(PackedVector2Array([
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
	]), outfit.main)
	_filled(_rounded_box(Vector2(0.0, waist.y + 0.4), Vector2(waist_half * 1.02, 1.6), 1.2), outfit.accent, 1.6)
	draw_circle(Vector2(0.0, chest.y + 4.6), 1.8, outfit.accent.darkened(0.15))
	draw_circle(Vector2(0.0, chest.y + 8.2), 1.8, outfit.accent.darkened(0.15))


func _draw_sweater(chest: Vector2, pelvis: Vector2, chest_half: float, outfit: Dictionary) -> void:
	var top_y := chest.y - 4.6
	var bottom_y := pelvis.y + 6.5
	var half_width := chest_half + 1.1
	_filled(_rounded_box(Vector2(0.0, (top_y + bottom_y) * 0.5), Vector2(half_width, (bottom_y - top_y) * 0.5), 3.4), outfit.main)
	_filled(_rounded_box(Vector2(0.0, bottom_y - 1.7), Vector2(half_width, 1.7), 1.6), outfit.main.darkened(0.18), 1.6)
	_ellipse(Vector2(0.0, chest.y - 4.2), Vector2(4.6, 2.0), outfit.main.darkened(0.18))
	_ellipse(Vector2(0.0, chest.y - 4.4), Vector2(3.4, 1.3), outfit.main)


func _draw_overalls(chest: Vector2, waist: Vector2, pelvis: Vector2, chest_half: float, outfit: Dictionary) -> void:
	var top_y := chest.y - 4.2
	var bottom_y := pelvis.y + 5.0
	_filled(_rounded_box(Vector2(0.0, (top_y + bottom_y) * 0.5), Vector2(chest_half * 0.98, (bottom_y - top_y) * 0.5), 3.0), outfit.accent)
	var bib_top := chest.y + 1.6
	var bib_bottom := pelvis.y + 5.4
	draw_line(Vector2(-chest_half * 0.5, bib_top + 0.5), Vector2(-chest_half * 0.62, chest.y - 4.0), outfit.main, 2.6, false)
	draw_line(Vector2(chest_half * 0.5, bib_top + 0.5), Vector2(chest_half * 0.62, chest.y - 4.0), outfit.main, 2.6, false)
	_filled(_rounded_box(Vector2(0.0, (bib_top + bib_bottom) * 0.5), Vector2(chest_half * 0.66, (bib_bottom - bib_top) * 0.5), 2.4), outfit.main)
	draw_circle(Vector2(-chest_half * 0.44, bib_top + 1.2), 1.1, BRASS)
	draw_circle(Vector2(chest_half * 0.44, bib_top + 1.2), 1.1, BRASS)
	_filled(_rounded_box(Vector2(0.0, waist.y - 2.4), Vector2(3.4, 2.2), 1.2), outfit.main.darkened(0.12), 1.4)


func _draw_body_base(chest: Vector2, waist: Vector2, pelvis: Vector2, chest_half: float, waist_half: float, hip_half: float, skin: Color) -> void:
	# The bare silhouette under revealing outfits: shoulders, midriff, and hips
	# all read as skin, with garments layered on top of this base.
	_filled(PackedVector2Array([
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
	]), skin, 2.0)
	# A one-pixel navel keeps the bare midriff from reading as blank.
	draw_rect(Rect2(Vector2(-0.8, waist.y + 2.4), Vector2(1.6, 1.6)), skin.darkened(0.16))


func _draw_tube_and_skirt(chest: Vector2, waist: Vector2, pelvis: Vector2, chest_half: float, waist_half: float, hip_half: float, outfit: Dictionary) -> void:
	# Strapless band across the chest; shoulders, arms, and midriff stay bare.
	_filled(_rounded_box(Vector2(0.0, chest.y + 0.8), Vector2(chest_half * 0.98, 3.0), 2.2), outfit.main)
	# Low-rise flared skirt starting below the navel.
	var hem_y := pelvis.y + 9.0
	var hem_half := hip_half * 1.3
	_filled(PackedVector2Array([
		Vector2(-waist_half * 0.98, waist.y + 2.6),
		pelvis + Vector2(-hip_half * 1.05, 0.0),
		Vector2(-hem_half, hem_y),
		Vector2(-hem_half * 0.5, hem_y + 2.2),
		Vector2(hem_half * 0.5, hem_y + 2.2),
		Vector2(hem_half, hem_y),
		pelvis + Vector2(hip_half * 1.05, 0.0),
		Vector2(waist_half * 0.98, waist.y + 2.6),
	]), outfit.accent)


func _draw_bikini(chest: Vector2, pelvis: Vector2, chest_half: float, hip_half: float, outfit: Dictionary) -> void:
	# Neck straps first so the band overlaps their ends.
	draw_line(Vector2(-chest_half * 0.5, chest.y - 0.4), Vector2(-1.8, chest.y - 4.8), outfit.main, 1.6, false)
	draw_line(Vector2(chest_half * 0.5, chest.y - 0.4), Vector2(1.8, chest.y - 4.8), outfit.main, 1.6, false)
	_filled(_rounded_box(Vector2(0.0, chest.y + 1.0), Vector2(chest_half * 0.8, 2.4), 1.8), outfit.main)
	_filled(_rounded_box(Vector2(0.0, pelvis.y + 1.2), Vector2(hip_half * 0.88, 2.6), 1.8), outfit.main)
	# Small tie knots keep the pieces from reading as plain bands.
	_outlined_ellipse(Vector2(-chest_half * 0.72, chest.y + 1.0), Vector2(1.5, 1.5), outfit.accent)
	_outlined_ellipse(Vector2(chest_half * 0.72, chest.y + 1.0), Vector2(1.5, 1.5), outfit.accent)


func _draw_arms(outfit_index: int, outfit: Dictionary, skin: Color) -> void:
	var sleeve: Color = outfit.main
	var sleeve_width := 5.6
	var puff := false
	match outfit_index:
		0:
			sleeve = outfit.main.darkened(0.10)
			sleeve_width = 5.2
			puff = true
		1:
			sleeve = outfit.main.darkened(0.06)
			sleeve_width = 5.8
		2:
			sleeve = outfit.accent
			sleeve_width = 5.0
		3:
			sleeve = skin
			sleeve_width = 4.8
		4:
			sleeve = skin
			sleeve_width = 4.6
	var chains := [
		[anchors.upper_arm_left, anchors.forearm_left, anchors.hand_left],
		[anchors.upper_arm_right, anchors.forearm_right, anchors.hand_right],
	]
	for chain: Array in chains:
		var points := PackedVector2Array(chain)
		if puff:
			_outlined_ellipse(points[0] + Vector2(0.0, -0.6), Vector2(4.0, 3.8), sleeve)
		_limb(points, sleeve, sleeve_width)
	match outfit_index:
		0:
			pass
		1:
			_ellipse(anchors.hand_left + Vector2(0.0, -2.4), Vector2(3.0, 1.4), outfit.accent)
			_ellipse(anchors.hand_right + Vector2(0.0, -2.4), Vector2(3.0, 1.4), outfit.accent)
		2:
			_ellipse(anchors.hand_left + Vector2(0.0, -2.4), Vector2(2.8, 1.3), sleeve.darkened(0.12))
			_ellipse(anchors.hand_right + Vector2(0.0, -2.4), Vector2(2.8, 1.3), sleeve.darkened(0.12))
	_outlined_ellipse(anchors.hand_left + Vector2(0.0, 0.4), Vector2(2.4, 2.2), skin)
	_outlined_ellipse(anchors.hand_right + Vector2(0.0, 0.4), Vector2(2.4, 2.2), skin)


func _draw_head(head: Vector2, skin: Color, hair: Dictionary, eye_style: int) -> void:
	_ellipse(head, Vector2(13.0, 13.6), OUTLINE)
	_ellipse(head, Vector2(12.0, 12.6), skin)
	_ellipse(head + Vector2(-7.0, 4.6), Vector2(2.2, 1.5), BLUSH)
	_ellipse(head + Vector2(7.0, 4.6), Vector2(2.2, 1.5), BLUSH)
	# Blinking swaps any eye style for closed lids drawn as short dark bars.
	if profile.get("blink", false):
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


func _draw_hair_front(head: Vector2, style: int, hair: Dictionary) -> void:
	match style:
		0:
			# Bob with a rounded fringe low over the eyes and jaw-length
			# side locks.
			_filled(PackedVector2Array([
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
			]), hair.base)
			_outlined_ellipse(head + Vector2(-11.3, 3.0), Vector2(2.7, 5.6), hair.base)
			_outlined_ellipse(head + Vector2(11.3, 3.0), Vector2(2.7, 5.6), hair.base)
		1:
			# Long hair with a side-swept fringe framing the face.
			_filled(PackedVector2Array([
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
			]), hair.base)
			_outlined_ellipse(head + Vector2(-11.2, 4.5), Vector2(2.5, 7.4), hair.base)
			_outlined_ellipse(head + Vector2(11.2, 4.5), Vector2(2.5, 7.4), hair.base)
		2:
			# Short crop with a choppy fringe.
			_filled(PackedVector2Array([
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
			]), hair.base)
		3:
			# Swept-back cap feeding the ponytail drawn behind the head.
			_filled(PackedVector2Array([
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
			]), hair.base)
			# The tie sits at the tail's base, just outside the head silhouette.
			_outlined_ellipse(head + Vector2(9.5, -10.5), Vector2(2.4, 2.0), Color("e9c46a"))


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
