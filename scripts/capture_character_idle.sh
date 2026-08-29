#!/usr/bin/env sh

# Produces an incrementing phase-strip image of the idle animation (breathing
# frames plus the blink frame). Existing captures are never overwritten.

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir="$project_dir/artifacts/screenshots/character_idle"
user_data_dir="$project_dir/artifacts/godot-user-data"
capture_index=1

mkdir -p "$output_dir" "$user_data_dir/data" "$user_data_dir/config" "$user_data_dir/cache"

while [ -e "$output_dir/character_idle_$(printf '%03d' "$capture_index").png" ]; do
	capture_index=$((capture_index + 1))
done
capture_version=$(printf '%03d' "$capture_index")

export XDG_DATA_HOME="$user_data_dir/data"
export XDG_CONFIG_HOME="$user_data_dir/config"
export XDG_CACHE_HOME="$user_data_dir/cache"
export LIBGL_ALWAYS_SOFTWARE=1

xvfb-run -a -s "-screen 0 1920x1080x24 -ac -nolisten tcp" \
	"${GODOT_BIN:-godot}" --display-driver x11 --path "$project_dir" \
	--rendering-driver opengl3 --audio-driver Dummy res://scenes/character_idle_strip.tscn -- --idle-capture

mv "$user_data_dir/data/godot/app_userdata/Modern Interiors Tile Concept/character_idle.png" \
	"$output_dir/character_idle_$capture_version.png"
