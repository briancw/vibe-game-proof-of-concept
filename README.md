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
room. To capture it, run `scripts/capture_screenshots.sh`; it writes
`artifacts/screenshots/room.png`.

## Player prototype

Run the project to control the temporary red-circle player with **WASD** or
the **arrow keys**. Movement is smooth, eight-directional, normalized on
diagonals, and blocked at the authored room's floor boundary. The player uses
the reusable `scenes/player.tscn`; replace only its `PlaceholderVisual` child
when character artwork is ready. Furniture is currently visual-only and does
not yet block movement.

## Character lab

`scenes/character_lab.tscn` is an isolated visual test bench for the dynamic
character experiment. It does not replace the game entry scene. The character
is fully generated geometry: a real `Skeleton2D` rest pose provides every
anchor, and `scripts/character_canvas.gd` draws layered silhouettes from those
anchors. Its sliders drive height, weight, hips, bust, skin tone, outfit,
hair style, and hair colour; **Next Preset** (or Space) cycles deliberately
different body studies.

Run `scripts/capture_character_lab.sh` to render the lab through Godot and
write `artifacts/screenshots/character_lab.png`. This gives the character work
its own repeatable capture artifact without perturbing room captures.

### Pixel rasterization pipeline

The character never draws directly into the world. `CharacterPreview` renders
its canvas into a 30x48 `SubViewport` whose canvas is scaled so every shape
rasterizes onto the world pixel grid, then blits the result with nearest
filtering. Generated geometry therefore shares the exact pixel density of the
surrounding 16x16 tile art instead of floating over it as smooth vectors.
Shape colors and outlines were designed at that final pixel size: face
features, outlines, and clothing details are chosen so they land on whole
pixels. Drawing uses no antialiasing on purpose; hard edges are the aesthetic.

### Idle animation

The idle pose is a Skeleton2D override, not baked art: `_apply_idle_pose`
drops the spine (chest, head, hair, and arms ride down the bone chain while
the legs stay planted) for one frame, holds the rest pose for the next, and
every offset is a multiple of two native units so each frame lands on whole
world pixels — a 1 px, 0.75 s-per-frame breathing cycle, plus a ~0.26 s blink
every 4.6 s drawn as closed-lid bars. `animate` runs it live in the control
lab and room scenes; `idle_phase` deterministically reproduces any single
frame, which is how the captures stay reproducible.

Run `scripts/capture_character_idle.sh` to write the next
`artifacts/screenshots/character_idle/character_idle_NNN.png` phase strip
(breathing frames plus the blink frame).

`scenes/character_preview.tscn` is the reusable procedural character rig used
by the control lab and `scenes/character_room_lab.tscn`. The latter places it
in the intentionally tiny 3x4 `rooms/character_corner.yaml` room, using the
supplied pixel-art tiles and props as a gameplay-scale visual test. Its
character-only CanvasItem shader applies a deliberately restrained room
palette grade; the geometry, face, hair, clothing, and contact shadow remain
generated in GDScript.

Run `scripts/capture_character_room_lab.sh` to save a new renderer-produced
comparison image under `artifacts/screenshots/character_room/`. The script
never overwrites an existing image: each invocation advances
`character_room_001.png`, `character_room_002.png`, and so on.

### Modular styles and the variants contact sheet

Hair styles (bob, long, crop, ponytail), hair colours, and outfit silhouettes
(meadow dress, sage sweater, denim overalls) are independent, composable
indices on the same rig. `scripts/character_variants_lab.gd` renders every
hair style across every outfit at game scale on a 16 px grid, varying skin
tones per column, so the whole style system can be graded in one image.

Run `scripts/capture_character_variants.sh` to write the next
`artifacts/screenshots/character_variants/character_variants_NNN.png`.

`scripts/zoom_region.gd` is a small headless helper for inspecting captures
at true pixel scale:

```sh
godot --headless --path . --script res://scripts/zoom_region.gd -- \
	src.png out.png <x> <y> <w> <h> <scale>
```

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
