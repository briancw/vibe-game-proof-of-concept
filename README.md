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

Set `player_start` to choose the player's starting tile. Coordinates are
zero-based cells and resolve to the center of the tile, so with this project's
16×16 tiles `[7, 9]` becomes world position `(120, 152)`:

```yaml
player_start: [7, 9]
```

Room edges use a `frame` operation. Its four straight-edge tile IDs apply
inside the corners, while the four corner tile IDs fill the outer cells:

```yaml
- type: frame
  top: border.white.top
  bottom: border.white.bottom
  left: border.white.left
  right: border.white.right
  top_left: border.corner.top_left
  top_right: border.corner.top_right
  bottom_left: border.corner.bottom_left
  bottom_right: border.corner.bottom_right
```

For a taller back wall, replace `top` with `top_rows`. Rows are listed from
the outer/topmost row to the row nearest the floor; the frame automatically
moves the top corners up and continues its side edges beside each extra row.

```yaml
top_rows:
  - wall.wood.vertical.top
  - wall.wood.vertical.bottom
```

Props use an explicit visual anchor. `bottom_left` makes `at: [x, y]` the
bottom-left of the visible artwork at the lower edge of that floor cell,
automatically extending furniture upward regardless of its texture dimensions
or transparent padding. `bottom_center` uses the same vertical convention but
centers the visible artwork in the authored column; use it for narrow props
such as tables, lamps, or posts.

Props can reference either a standalone image or a region on any indexed
sheet. `atlas` and optional `size` use tile-grid units; `size` defaults to one
cell in each direction.

```yaml
prop.chair.right:
  sheet: generic
  atlas: [4, 10]
  size: [1, 2]
  anchor: bottom_center
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
room. To capture it, run `tools/capture_screenshots.sh`; it writes
`artifacts/screenshots/room.png`.

## Aseprite source inspection

`tools/inspect_ase.js` reads Aseprite document metadata without requiring
Aseprite itself. It emits JSON with the canvas, layers, frame durations, cels,
and named animation tags; it does not modify or decompress the artwork.

```sh
node tools/inspect_ase.js assets/characters/Premade_Characters.ase
```

## Player prototype

Run the project to control the temporary red-circle player with **WASD** or
the **arrow keys**. Movement is smooth, eight-directional, normalized on
diagonals, and blocked at the authored room's floor boundary. The player uses
the reusable `scenes/player.tscn`; replace only its `PlaceholderVisual` child
when character artwork is ready. Furniture is currently visual-only and does
not yet block movement.

`tools/zoom_region.gd` is a small headless helper for inspecting captures
at true pixel scale:

```sh
godot --headless --path . --script res://tools/zoom_region.gd -- 	src.png out.png <x> <y> <w> <h> <scale>
```

## Sprite characters

`characters/` is a simple, data-driven character system for compact generated
strips: a character is a texture plus a list of animation definitions,
rendered by a lightweight `CharacterSprite` node.

- `characters/character_anim_def.gd` — one animation: name, frame origin in sheet
  pixels, frame count, fps, loop flag.
- `characters/character_sheet.gd` — a `Resource` describing one character sheet:
  texture, uniform `frame_size`, and its `CharacterAnimDef` list. It builds and
  caches Godot `SpriteFrames` on demand, so any number of on-screen characters
  share one build. Adding a character means describing (or reusing) a layout
  and pointing it at a new texture.
- `characters/character_sprite.gd` — the render node. One node per character;
  origin sits at the character's feet. `animation` is a base name (`stand`,
  `idle`, `walk`, `sleep`); directional animations resolve to
  `<animation>_<facing>`, so changing `facing` (`down`/`left`/`up`/`right`)
  retargets the animation automatically, and non-directional animations such
  as `sleep` play verbatim.
- `characters/generated_characters.gd` — loads YAML appearance definitions at
  build time and fixed-layout compact strips with cached `CharacterSheet`
  resources at runtime.
- `characters/character_generator_layout.gd` — source-atlas action definitions
  used by both the strip builder and runtime loader.
- `assets/characters/generated_characters.yaml` — each character's layer
  selections. Run `tools/build_generated_characters.gd` after editing it; use
  `-- --check` to validate generated strips in automation.

`scenes/character_sprites_lab.tscn` is the visual test bench: a focused
4x generated character. The button bar and keys change character
(Tab / Shift+Tab), animation (Q/E), and facing (arrow keys or WASD); the
facing cycle only offers directions the current animation can play; Space
pauses. Run `tools/capture_character_sprites.sh` to write the `stand_down`,
`idle_down`, `walk_right`, and `sleep` state captures to
`artifacts/screenshots/character_sprites/`.

`scenes/character_room_lab.tscn` is the gameplay-scale visual test: a
generated character standing in the intentionally tiny 3x4
`rooms/character_corner.yaml` room, rendered by the shared room renderer. Run
`tools/capture_character_room_lab.sh` to save a renderer-produced comparison
image under `artifacts/screenshots/character_room/`; each invocation advances
`character_room_001.png`, `character_room_002.png`, and so on, never
overwriting an existing capture.

## Project layout

Feature folders over file-type folders, per Godot convention as a project
grows:

- `characters/` — compact character-strip resources, generated-strip loader,
  `CharacterSprite` render node, and lab scenes in `scenes/`
- `tools/` — capture shell scripts and editor helper scripts; not game code
- `scenes/`, `scripts/` — the game itself: rooms, player, main scenes
- `tiles/`, `rooms/` — tile index, generated TileSet, and room YAML

## Tile authoring and inspection

Edit `tiles/tile_index.yaml` to add, rename, or remove available tiles and
props. The TileSet is generated output: browse it in Godot, but do not edit
its metadata by hand.

The **Atlas Picker** bottom panel is enabled with the project. Select a sheet,
use its +/- controls (or Ctrl + mouse wheel) to zoom, and click any gridded
atlas cell to copy a YAML starter such as:

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
