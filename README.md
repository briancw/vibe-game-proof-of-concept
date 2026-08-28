# Modern Interiors Tile Concept

Rooms are authored as YAML, then rendered by one shared Godot `@tool` script.
The same YAML layout appears in the Godot editor, during play, and in captures.

- `tiles/tile_index.yaml` is the authoritative catalog of usable tiles and props.
- `tiles/interiors_tileset.tres` is generated from that index for Godot rendering
  and visual atlas inspection.
- `rooms/*.yaml` defines a room with named tiles, operations, and props.
- `scripts/room_renderer.gd` resolves those names from the Tile Index and renders a preview.
- `scenes/editor_room.tscn` is a small editor/debug shell pointing at a layout.

`tiles/tile_catalog.json` is a legacy migration artifact and is no longer read
by the prototype. JSON room loading remains temporarily supported for migration,
but new rooms should use YAML.

Room YAML is parsed by a pinned, vendored copy of
[YAML.gd](https://github.com/lowlevel-1989/YAML.gd). Prop IDs are keys, so a
placement needs only its coordinates:

```yaml
name: example
grid_size: [14, 11]
props:
  prop.rug.gray:
    at: [6, 4]
    z_index: 2
```

The renderer validates the room shape after parsing (room name, grid size,
layers, and prop structure) before building the scene. The vendored parser and
its exact upstream commit are recorded in `addons/yaml_dot_gd/UPSTREAM.md`.

YAML indentation must use spaces. To safely edit YAML in Godot, open **Editor
Settings → Text Editor → Behavior → Files** and disable **Convert Indent On
Save**. Alternatively set **Text Editor → Behavior → Indent → Type** to
**Spaces** (size 2). The loader rejects leading tab indentation with a clear
error instead of silently producing an empty room. An external editor or agent
is still the safest room-authoring path.

Open `project.godot` and select `editor_room.tscn` to inspect the generated
room. To capture it, run `scripts/capture_screenshots.sh`; it writes
`artifacts/screenshots/room.png`.

## Tile authoring and inspection

Edit `tiles/tile_index.yaml` to add, rename, or remove available tiles and
props. The TileSet is generated output: browse it in Godot, but do not edit
its metadata by hand.

The **Atlas Picker** bottom panel is enabled with the project. Select a sheet,
click any atlas cell, and it copies a YAML starter such as:

```yaml
new.tile.id:
  sheet: floors
  atlas: [7, 6]
```

Paste that into `tile_index.yaml`, assign its semantic name, then run the sync.

The initial TileSet was generated from the old catalog with:

```sh
godot --headless --path . --script res://scripts/build_interiors_tileset.gd
```

Run this after each Tile Index change. It validates sheet paths/coordinates and
recreates the TileSet with exactly the indexed tiles.

To produce regular, native `TileMapLayer` scenes from every YAML layout:

```sh
godot --headless --path . --script res://scripts/generate_debug_scenes.gd
```

Open `scenes/generated/living_room_debug.tscn` for the native TileMap editor
and TileSet inspector. These scenes are generated output: inspect them freely,
but change the YAML layout or Tile Index rather than hand-editing them.

The included **Semantic Tile Inspector** editor plugin is enabled for this
project. Select a `TileMapLayer` in a generated scene and Alt-click a placed
cell in the 2D viewport. Its bottom-panel report includes the semantic ID,
source sheet and ID, atlas coordinates, alternative ID, and description. The
friendly ID is resolved from `tile_index.yaml`, not TileSet metadata.

The Limezu source artwork is intentionally left in `assets/` and ignored by
Git, so the project assumes the supplied asset pack remains in that location.
