# Modern Interiors Tile Concept

Rooms are authored as JSON, then rendered by one shared Godot `@tool` script.
The same JSON layout appears in the Godot editor, during play, and in captures.

- `tiles/tile_catalog.json` gives every usable tile and prop a semantic name.
- `rooms/*.json` defines a room with named tiles, operations, and props.
- `scripts/room_renderer.gd` validates and renders a layout into TileMapLayers.
- `scenes/editor_room.tscn` is a small editor/debug shell pointing at a layout.

Open `project.godot` and select `editor_room.tscn` to inspect the generated
room. To capture it, run `scripts/capture_screenshots.sh`; it writes
`artifacts/screenshots/room.png`.

The Limezu source artwork is intentionally left in `assets/` and ignored by
Git, so the project assumes the supplied asset pack remains in that location.

