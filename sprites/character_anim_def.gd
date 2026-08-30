class_name CharacterAnimDef
extends Resource

## One animation carved out of a character sprite sheet: a run of uniformly
## spaced frames starting at `origin` (sheet pixels, top-left of frame 0).

@export var name: StringName = &""
@export var origin := Vector2i.ZERO
@export var frames := 1
@export var fps := 8.0
@export var loop := true

## Event name -> zero-based frame index, e.g. {"impact": 3}.
@export var frame_events: Dictionary = {}
