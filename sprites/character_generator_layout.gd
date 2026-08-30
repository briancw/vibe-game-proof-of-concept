class_name CharacterGeneratorLayout
extends RefCounted

## The complete fixed contract for generated character strips. `source_origin`
## is where art is read from a raw layer; `origin` is where it lives in every
## generated 928x32 runtime strip. Keep this table authoritative and explicit:
## it is the only place a human or tool needs to inspect animation indexing.

const FRAME_SIZE := Vector2i(16, 32)
const SOURCE_SHEET_SIZE := Vector2i(896, 656)
const STRIP_SIZE := Vector2i(928, 32)

const DEFINITIONS: Array[Dictionary] = [
	{"name": "stand_right", "source_origin": Vector2i(0, 0), "origin": Vector2i(0, 0), "frames": 1, "fps": 1.0, "loop": true, "frame_events": {}},
	{"name": "stand_up", "source_origin": Vector2i(16, 0), "origin": Vector2i(16, 0), "frames": 1, "fps": 1.0, "loop": true, "frame_events": {}},
	{"name": "stand_left", "source_origin": Vector2i(32, 0), "origin": Vector2i(32, 0), "frames": 1, "fps": 1.0, "loop": true, "frame_events": {}},
	{"name": "stand_down", "source_origin": Vector2i(48, 0), "origin": Vector2i(48, 0), "frames": 1, "fps": 1.0, "loop": true, "frame_events": {}},
	{"name": "idle_right", "source_origin": Vector2i(0, 32), "origin": Vector2i(64, 0), "frames": 6, "fps": 12.0, "loop": true, "frame_events": {}},
	{"name": "idle_up", "source_origin": Vector2i(96, 32), "origin": Vector2i(160, 0), "frames": 6, "fps": 12.0, "loop": true, "frame_events": {}},
	{"name": "idle_left", "source_origin": Vector2i(192, 32), "origin": Vector2i(256, 0), "frames": 6, "fps": 12.0, "loop": true, "frame_events": {}},
	{"name": "idle_down", "source_origin": Vector2i(288, 32), "origin": Vector2i(352, 0), "frames": 6, "fps": 12.0, "loop": true, "frame_events": {}},
	{"name": "walk_right", "source_origin": Vector2i(0, 64), "origin": Vector2i(448, 0), "frames": 6, "fps": 12.0, "loop": true, "frame_events": {}},
	{"name": "walk_up", "source_origin": Vector2i(96, 64), "origin": Vector2i(544, 0), "frames": 6, "fps": 12.0, "loop": true, "frame_events": {}},
	{"name": "walk_left", "source_origin": Vector2i(192, 64), "origin": Vector2i(640, 0), "frames": 6, "fps": 12.0, "loop": true, "frame_events": {}},
	{"name": "walk_down", "source_origin": Vector2i(288, 64), "origin": Vector2i(736, 0), "frames": 6, "fps": 12.0, "loop": true, "frame_events": {}},
	{"name": "sleep", "source_origin": Vector2i(0, 96), "origin": Vector2i(832, 0), "frames": 6, "fps": 4.0, "loop": true, "frame_events": {}},
]


static func frame_size() -> Vector2i:
	return FRAME_SIZE


static func sheet_size() -> Vector2i:
	return SOURCE_SHEET_SIZE


static func strip_size() -> Vector2i:
	return STRIP_SIZE


static func frame_count() -> int:
	var count := 0
	for definition in DEFINITIONS:
		count += int(definition.frames)
	return count


static func runtime_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in DEFINITIONS:
		result.append(definition.duplicate(true))
	return result


static func default_animation() -> StringName:
	return &"stand_down"
