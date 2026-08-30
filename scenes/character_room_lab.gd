extends Node2D

## Game-scale visual test: one generated sprite character standing in the tiny
## 3x4 `rooms/character_corner.yaml` room, rendered by the shared room renderer.

const TILE_SET := preload("res://tiles/interiors_tileset.tres")

## Zero-based room grid cell. `CharacterSprite`'s origin is its feet, so the
## cell resolves to the cell's bottom-center, matching the props' anchor style.
@export var character_cell := Vector2i(1, 3)

@onready var character: CharacterSprite = %Character


func _ready() -> void:
	character.position = _feet_position(character_cell)
	character.sheet = GeneratedCharacters.load_sheet(&"example_adult")
	character.animation = &"idle"
	if "--character-room-capture" in OS.get_cmdline_user_args():
		capture_screenshot.call_deferred()


func _feet_position(cell: Vector2i) -> Vector2:
	var tile_size := Vector2(TILE_SET.tile_size)
	return Vector2(cell) * tile_size + Vector2(tile_size.x * 0.5, tile_size.y)


func capture_screenshot() -> void:
	# Allow the room, camera, and sprite to settle before reading the viewport.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://character_room_lab.png")
	get_tree().quit()
