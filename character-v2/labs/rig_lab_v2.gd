@tool
extends Node2D

## Visual test bench for the polygon-skinned character rigs (character-v2).
## Card 1: front (nude), front with the demo outfit layered on, and the side
## rig, all at true game scale on a 16 px tile grid. Cards 2-4: the rest
## pose, a scripted test pose that bends every joint to prove the skin
## weights deform the meshes, and the side rig under the same test pose, all
## at comfortable editing zoom. Not a game scene; captures stay deterministic.

@onready var game_front: CharacterRigV2 = %GameFront
@onready var game_clothed: CharacterRigV2 = %GameClothed
@onready var game_side: CharacterRigV2 = %GameSide
@onready var front_rest: CharacterRigV2 = %FrontRest
@onready var front_pose: CharacterRigV2 = %FrontPose
@onready var side_pose: CharacterRigV2 = %SidePose

## Skeleton-relative bone path -> test rotation (radians) applied to the
## posed figures. Bones live down the hierarchy, so paths are full chains.
## Both rigs share the bone layout, so one pose works for front and side.
const TEST_POSE := {
    "Hips/Spine": 0.10,
    "Hips/Spine/Chest": -0.14,
    "Hips/Spine/Chest/Head": 0.22,
    "Hips/Spine/Chest/UpperArmL": 0.45,
    "Hips/Spine/Chest/UpperArmL/ForearmL": 0.55,
    "Hips/Spine/Chest/UpperArmR": -0.30,
    "Hips/Spine/Chest/UpperArmR/ForearmR": -1.05,
    "Hips/ThighL": 0.18,
    "Hips/ThighL/ShinL": -0.24,
    "Hips/ThighR": -0.12,
    "Hips/ThighR/ShinR": 0.15,
}


func _ready() -> void:
    if not Engine.is_editor_hint():
        _apply_test_pose(front_pose)
        _apply_test_pose(side_pose)
    if "--capture" in OS.get_cmdline_user_args():
        capture_screenshot.call_deferred()


func _apply_test_pose(rig: CharacterRigV2) -> void:
    var skeleton := rig.get_node("Skeleton2D") as Skeleton2D
    for bone_name in TEST_POSE:
        var bone := skeleton.get_node_or_null(NodePath(bone_name)) as Bone2D
        if bone != null:
            bone.rotation = TEST_POSE[bone_name]


func _draw() -> void:
    draw_rect(Rect2(0, 0, 320, 240), Color("171923"), true)
    # Card 1: 16 px tile grid at world scale, floor along its bottom edge.
    draw_rect(Rect2(10, 26, 108, 196), Color("202534"), true)
    draw_rect(Rect2(10, 26, 108, 196), Color("465064"), false, 1.0)
    for x in range(16, 113, 16):
        draw_line(Vector2(x, 34), Vector2(x, 214), Color("2b3345"), 1.0, false)
    for y in range(38, 215, 16):
        draw_line(Vector2(16, y), Vector2(112, y), Color("2b3345"), 1.0, false)
    # Cards 2-4: authoring-scale zoom panels.
    draw_rect(Rect2(87, 26, 69, 196), Color("202534"), true)
    draw_rect(Rect2(87, 26, 69, 196), Color("465064"), false, 1.0)
    draw_rect(Rect2(164, 26, 69, 196), Color("202534"), true)
    draw_rect(Rect2(164, 26, 69, 196), Color("465064"), false, 1.0)
    draw_rect(Rect2(241, 26, 69, 196), Color("202534"), true)
    draw_rect(Rect2(241, 26, 69, 196), Color("465064"), false, 1.0)
    draw_line(Vector2(16, 214), Vector2(112, 214), Color("8c7183"), 1.0, false)
    draw_line(Vector2(93, 214), Vector2(304, 214), Color("8c7183"), 1.0, false)
    _draw_text(Vector2(10, 18), "CHARACTER RIG V2 / NUDE BASE + OUTFITS", 10, Color("e7dfd0"))
    _draw_text(Vector2(16, 36), "GAME 1/16x", 7, Color("8fa0b6"))
    _draw_text(Vector2(93, 36), "REST 2.7x", 7, Color("8fa0b6"))
    _draw_text(Vector2(170, 36), "POSE 2.7x", 7, Color("8fa0b6"))
    _draw_text(Vector2(247, 36), "SIDE 2.7x", 7, Color("8fa0b6"))


func _draw_text(position: Vector2, value: String, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func capture_screenshot() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png("user://character_rig_v2.png")
    get_tree().quit()
