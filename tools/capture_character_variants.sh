#!/usr/bin/env sh

# Produces an incrementing contact-sheet image grading every hair style
# across every outfit at game scale. Existing captures are never overwritten.

set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir="$project_dir/artifacts/screenshots/character_variants"
user_data_dir="$project_dir/artifacts/godot-user-data"
capture_index=1

mkdir -p "$output_dir" "$user_data_dir/data" "$user_data_dir/config" "$user_data_dir/cache"

while [ -e "$output_dir/character_variants_$(printf '%03d' "$capture_index").png" ]; do
	capture_index=$((capture_index + 1))
done
capture_version=$(printf '%03d' "$capture_index")

export XDG_DATA_HOME="$user_data_dir/data"
export XDG_CONFIG_HOME="$user_data_dir/config"
export XDG_CACHE_HOME="$user_data_dir/cache"
export LIBGL_ALWAYS_SOFTWARE=1

xvfb-run -a -s "-screen 0 1920x1080x24 -ac -nolisten tcp" \
	"${GODOT_BIN:-godot}" --display-driver x11 --path "$project_dir" \
	--rendering-driver opengl3 --audio-driver Dummy res://character/labs/character_variants_lab.tscn -- --variants-capture

mv "$user_data_dir/data/godot/app_userdata/Modern Interiors Tile Concept/character_variants.png" \
	"$output_dir/character_variants_$capture_version.png"
