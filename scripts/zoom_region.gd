extends SceneTree

## Crops and nearest-upscales a region of a screenshot for close inspection.
## Usage: godot --headless --script zoom.gd -- <src> <dst> <x> <y> <w> <h> <scale>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 7:
		push_error("expected: <src> <dst> <x> <y> <w> <h> <scale>")
		quit(1)
		return
	var source := Image.load_from_file(args[0])
	if source == null:
		push_error("cannot load " + args[0])
		quit(1)
		return
	var rect := Rect2i(int(args[2]), int(args[3]), int(args[4]), int(args[5]))
	var scale := int(args[6])
	var crop := source.get_region(rect)
	crop.resize(crop.get_width() * scale, crop.get_height() * scale, Image.INTERPOLATE_NEAREST)
	crop.save_png(args[1])
	print("saved ", args[1])
	quit(0)
