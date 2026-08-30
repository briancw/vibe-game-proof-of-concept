extends Node2D

## Capture-only shell for judging the procedural character at play scale.
## RoomRenderer intentionally receives no --capture argument; this scene owns
## its own screenshot so it can store a versioned character-room comparison.


func _ready() -> void:
	if "--character-room-capture" in OS.get_cmdline_user_args():
		capture_screenshot.call_deferred()


func capture_screenshot() -> void:
	# Allow the generated room, camera, and CanvasItem material to settle before
	# reading the rendered viewport.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://character_room_lab.png")
	get_tree().quit()
