#!/usr/bin/env sh

# Capture a 6x portrait of a single character design (by ID) into
# artifacts/screenshots/character_portraits/. Usage:
#   tools/capture_character_portrait.sh <character-id>

set -eu

if [ $# -ne 1 ]; then
	echo "usage: $0 <character-id>" >&2
	exit 1
fi
character_id=$1

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir="$project_dir/artifacts/screenshots/character_portraits"
user_data_dir="$project_dir/artifacts/godot-user-data"

mkdir -p "$output_dir" "$user_data_dir/data" "$user_data_dir/config" "$user_data_dir/cache"

export XDG_DATA_HOME="$user_data_dir/data"
export XDG_CONFIG_HOME="$user_data_dir/config"
export XDG_CACHE_HOME="$user_data_dir/cache"
export LIBGL_ALWAYS_SOFTWARE=1

xvfb-run -a -s "-screen 0 1920x1080x24 -ac -nolisten tcp" \
	"${GODOT_BIN:-godot}" --display-driver x11 --path "$project_dir" \
	--rendering-driver opengl3 --audio-driver Dummy \
	res://scenes/character_portrait.tscn -- --capture --character-id="$character_id"

mv "$user_data_dir/data/godot/app_userdata/Modern Interiors Tile Concept/character_portrait_$character_id.png" \
	"$output_dir/"
