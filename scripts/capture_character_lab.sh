#!/usr/bin/env sh

# Capture the isolated character lab through Godot's standard renderer.
# The main room capture remains scripts/capture_screenshots.sh.

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir="$project_dir/artifacts/screenshots"
user_data_dir="$project_dir/artifacts/godot-user-data"

mkdir -p "$output_dir" "$user_data_dir/data" "$user_data_dir/config" "$user_data_dir/cache"

export XDG_DATA_HOME="$user_data_dir/data"
export XDG_CONFIG_HOME="$user_data_dir/config"
export XDG_CACHE_HOME="$user_data_dir/cache"
export LIBGL_ALWAYS_SOFTWARE=1

xvfb-run -a -s "-screen 0 1920x1080x24 -ac -nolisten tcp" \
	"${GODOT_BIN:-godot}" --display-driver x11 --path "$project_dir" \
	--rendering-driver opengl3 --audio-driver Dummy res://scenes/character_lab.tscn -- --capture

mv "$user_data_dir/data/godot/app_userdata/Modern Interiors Tile Concept/character_lab.png" \
	"$output_dir/character_lab.png"
