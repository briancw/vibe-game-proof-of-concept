class_name CharacterGeneratorLayout
extends RefCounted

## The generator's fixed 16x16 source-sheet layout, expressed in top-left
## pixel coordinates.

const FRAME_SIZE := Vector2i(16, 32)
const SHEET_SIZE := Vector2i(896, 656)

const ACTIONS: Dictionary = {
	"stand": {
		"fps": 1.0,
		"frames": 1,
		"directions": [
			{"name": "right", "origin": [0, 0]},
			{"name": "up", "origin": [16, 0]},
			{"name": "left", "origin": [32, 0]},
			{"name": "down", "origin": [48, 0]},
		],
	},
	"idle": {
		"fps": 12.0,
		"frames": 6,
		"directions": [
			{"name": "right", "origin": [0, 32]},
			{"name": "up", "origin": [96, 32]},
			{"name": "left", "origin": [192, 32]},
			{"name": "down", "origin": [288, 32]},
		],
	},
	"walk": {
		"fps": 12.0,
		"frames": 6,
		"directions": [
			{"name": "right", "origin": [0, 64]},
			{"name": "up", "origin": [96, 64]},
			{"name": "left", "origin": [192, 64]},
			{"name": "down", "origin": [288, 64]},
		],
	},
	"sleep": {
		"fps": 4.0,
		"frames": 6,
		"directions": [{"name": "", "origin": [0, 96]}],
	},
	"sit": {
		"fps": 12.0,
		"frames": 6,
		"directions": [
			{"name": "right", "origin": [0, 128]},
			{"name": "left", "origin": [96, 128]},
		],
	},
	"read": {
		"fps": 12.0,
		"frames": 12,
		"directions": [{"name": "", "origin": [0, 224]}],
	},
	"pickup": {
		"fps": 12.0,
		"frames": 12,
		"directions": [
			{"name": "right", "origin": [0, 288]},
			{"name": "up", "origin": [192, 288]},
			{"name": "left", "origin": [384, 288]},
			{"name": "down", "origin": [576, 288]},
		],
	},
	"gift": {
		"fps": 12.0,
		"frames": 10,
		"directions": [
			{"name": "right", "origin": [0, 320]},
			{"name": "up", "origin": [160, 320]},
			{"name": "left", "origin": [320, 320]},
			{"name": "down", "origin": [480, 320]},
		],
	},
	"lift": {
		"fps": 12.0,
		"frames": 14,
		"directions": [
			{"name": "right", "origin": [0, 352]},
			{"name": "up", "origin": [224, 352]},
			{"name": "left", "origin": [448, 352]},
			{"name": "down", "origin": [672, 352]},
		],
	},
	"throw": {
		"fps": 12.0,
		"frames": 14,
		"directions": [
			{"name": "right", "origin": [0, 384]},
			{"name": "up", "origin": [224, 384]},
			{"name": "left", "origin": [448, 384]},
			{"name": "down", "origin": [672, 384]},
		],
	},
	"hit": {
		"fps": 12.0,
		"frames": 6,
		"directions": [
			{"name": "right", "origin": [0, 416]},
			{"name": "up", "origin": [96, 416]},
			{"name": "left", "origin": [192, 416]},
			{"name": "down", "origin": [288, 416]},
		],
	},
	"hurt": {
		"fps": 6.0,
		"frames": 3,
		"directions": [
			{"name": "right", "origin": [0, 608]},
			{"name": "up", "origin": [48, 608]},
			{"name": "left", "origin": [96, 608]},
			{"name": "down", "origin": [144, 608]},
		],
	},
}


static func supports(action: String) -> bool:
	return ACTIONS.has(action.to_lower())


static func available_actions() -> PackedStringArray:
	var names: PackedStringArray = []
	for action in ACTIONS:
		names.append(action)
	names.sort()
	return names


static func frame_size() -> Vector2i:
	return FRAME_SIZE


static func sheet_size() -> Vector2i:
	return SHEET_SIZE


## Returns one runtime/export definition per direction. A definition's name is
## e.g. `walk_left`; non-directional actions retain their action name.
static func definitions(actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for requested_action in actions:
		var action := String(requested_action).to_lower()
		if not ACTIONS.has(action):
			continue
		var action_data: Dictionary = ACTIONS[action]
		for direction_data in action_data.directions:
			var direction := String(direction_data.name)
			var point: Array = direction_data.origin
			result.append({
				"name": action if direction.is_empty() else "%s_%s" % [action, direction],
				"origin": Vector2i(int(point[0]), int(point[1])),
				"frames": int(action_data.frames),
				"fps": float(action_data.fps),
				"loop": true,
			})
	return result
