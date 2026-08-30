@tool
extends Node2D

## Visual test bench for the polygon-skinned character rigs (character-v2).
## Card 1: game-scale masc + fem presets in their outfits plus the side rig,
## on a 16 px tile grid. Cards 2-6: the masc and fem bodies at rest (nude,
## to show the morph silhouettes), the side rig up close, and both bodies
## posed in their outfits, proving the warped bodies still deform cleanly
## through the skin weights. Not a game scene; captures stay deterministic.

@onready var game_masc: CharacterRigV2 = %GameMasc
@onready var game_fem: CharacterRigV2 = %GameFem
@onready var game_side_fem: CharacterRigV2 = %GameSideFem
@onready var masc_rest: CharacterRigV2 = %MascRest
@onready var fem_rest: CharacterRigV2 = %FemRest
@onready var side_rest: CharacterRigV2 = %SideRest
@onready var masc_pose: CharacterRigV2 = %MascPose
@onready var fem_pose: CharacterRigV2 = %FemPose

## Skeleton-relative bone path -> test rotation (radians) applied to the
## posed figures. Bones live down the hierarchy, so paths are full chains.
const TEST_POSE := {
    "Hips/Spine": 0.10,
    "Hips/Spine/Chest": -0.14,
    "Hips/Spine/Chest/Head": 0.22,
    "Hips/Spine/Chest/UpperArmL": 0.32,
    "Hips/Spine/Chest/UpperArmL/ForearmL": 0.38,
    "Hips/Spine/Chest/UpperArmR": -0.22,
    "Hips/Spine/Chest/UpperArmR/ForearmR": -0.8,
    "Hips/ThighL": 0.18,
    "Hips/ThighL/ShinL": -0.24,
    "Hips/ThighR": -0.12,
    "Hips/ThighR/ShinR": 0.15,
}


func _ready() -> void:
    if not Engine.is_editor_hint():
        _apply_test_pose(masc_pose)
        _apply_test_pose(fem_pose)
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
    draw_rect(Rect2(10, 26, 46, 196), Color("202534"), true)
    draw_rect(Rect2(10, 26, 46, 196), Color("465064"), false, 1.0)
    for x in [26, 42]:
        draw_line(Vector2(x, 34), Vector2(x, 214), Color("2b3345"), 1.0, false)
    for y in range(38, 215, 16):
        draw_line(Vector2(12, y), Vector2(54, y), Color("2b3345"), 1.0, false)
    # Cards 2-6: authoring-scale zoom panels.
    for card_x in [60, 110, 160, 210, 260]:
        draw_rect(Rect2(card_x, 26, 48, 196), Color("202534"), true)
        draw_rect(Rect2(card_x, 26, 48, 196), Color("465064"), false, 1.0)
    draw_line(Vector2(12, 214), Vector2(54, 214), Color("8c7183"), 1.0, false)
    draw_line(Vector2(62, 214), Vector2(306, 214), Color("8c7183"), 1.0, false)
    _draw_text(Vector2(10, 18), "CHARACTER RIG V2 / MASC + FEM MORPHS", 10, Color("e7dfd0"))
    _draw_text(Vector2(12, 36), "GAME", 7, Color("8fa0b6"))
    _draw_text(Vector2(62, 36), "MASC", 7, Color("8fa0b6"))
    _draw_text(Vector2(112, 36), "FEM", 7, Color("8fa0b6"))
    _draw_text(Vector2(162, 36), "SIDE FEM", 7, Color("8fa0b6"))
    _draw_text(Vector2(212, 36), "MASC OUTFIT", 7, Color("8fa0b6"))
    _draw_text(Vector2(262, 36), "FEM OUTFIT", 7, Color("8fa0b6"))


func _draw_text(position: Vector2, value: String, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func capture_screenshot() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png("user://character_rig_v2.png")
    get_tree().quit()
