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

## Character lab

`character/labs/character_lab.tscn` is an isolated visual test bench for the dynamic
character experiment. It does not replace the game entry scene. The character
is fully generated geometry: a real `Skeleton2D` rest pose provides every
anchor, and `character/character_canvas.gd` draws layered silhouettes from those
anchors. Its sliders drive height, weight, hips, bust, skin tone, outfit,
hair style, hair colour, and eye style. **Next Preset** (or Space) cycles
body studies, the facing button (or **F**) cycles DOWN/RIGHT/LEFT/UP,
**PIXELS** (or **P**) toggles the SubViewport rasterization to reveal the
smooth vector shapes underneath, and **EDIT** (or **E**) shows the authored
shape layer for direct editing in the editor.

Run `tools/capture_character_lab.sh` to render the lab through Godot and
write `artifacts/screenshots/character_lab.png`. This gives the character work
its own repeatable capture artifact without perturbing room captures.

### Editing body shapes in the editor

Open `character/edit_character.tscn`: a large, zoomed editing view of the
character in smooth (non-pixelated) mode with rig guides, preloaded with the
nude body so the base silhouette is editable without garment noise. The
preview instance is editable-children, so expanding `CharacterPreview` in the
scene tree exposes the full `Skeleton2D` bone hierarchy (bones are authored at
render scale, so gizmos line up with the pixels) and the `AuthoredShapes`
layer. In
the editor the `AuthoredShapes` layer shows **only the polygons for the current
outfit and hair**, so you never see every outfit stacked on one character:
change `outfit_index` or `hair_index` on the preview node and the visible
polygon set follows. Select a polygon and drag its points with Godot's
built-in polygon editor; edited shapes override the procedural silhouettes
for the down-facing view.

The main down-facing silhouettes — body base, every garment, and every hair
mass — exist twice: as procedural point builders in `character_canvas.gd`
(the default), and as `Polygon2D` nodes under `AuthoredShapes` in
`character_preview.tscn`. Authored polygons **override** the procedural
silhouettes for the down-facing view, so:

- In the Godot editor, select an `AuthoredShapes` child polygon (open
  `character/edit_character.tscn` for the comfortable editing view) and edit
  its points with the built-in polygon editor.
- Agent edits do the same thing through the text: node polygons in the tscn
  are grep-able and diffable scene data.
- Deleting a node falls back to the procedural generator; regenerating seeds
  is a `build_shape_library()` call away.
- Side/back views always stay procedural (they re-derive from the rig), so
  authored changes apply to the down view and are checked against the facings
  contact sheet.

### Pixel rasterization pipeline

The character never draws directly into the world. `CharacterPreview` renders
its canvas into a 30x48 `SubViewport` whose canvas is scaled so every shape
rasterizes onto the world pixel grid, then blits the result with nearest
filtering. Generated geometry therefore shares the exact pixel density of the
surrounding 16x16 tile art instead of floating over it as smooth vectors.
Shape colors and outlines were designed at that final pixel size: face
features, outlines, and clothing details are chosen so they land on whole
pixels. Drawing uses no antialiasing on purpose; hard edges are the aesthetic.

### Facings

The rig always models the down-facing character; `facing` selects the drawn
view. Down is the base art, right is the profile view (narrower silhouette,
single visible eye, nose bump, far arm and leg drawn darker behind the near
pair), up hides the face and hangs the hair over the back of the body, and
left mirrors the right-facing art inside the same texture rect, so one draw
path serves both sides. Side views narrow the torso silhouette by a fixed
depth factor rather than reposing the rig.

Run `tools/capture_character_facings.sh` to write the next
`artifacts/screenshots/character_facings/character_facings_NNN.png` sheet:
four facings across four style combinations chosen to stress hair, outfits,
and eye styles.

### Idle animation

The idle pose is a Skeleton2D override, not baked art: `_apply_idle_pose`
drops the spine (chest, head, hair, and arms ride down the bone chain while
the legs stay planted) for one frame, holds the rest pose for the next, and
every offset is a multiple of two native units so each frame lands on whole
world pixels — a 1 px, 0.75 s-per-frame breathing cycle, plus a ~0.26 s blink
every 4.6 s drawn as closed-lid bars. `animate` runs it live in the control
lab and room scenes; `idle_phase` deterministically reproduces any single
frame, which is how the captures stay reproducible.

Run `tools/capture_character_idle.sh` to write the next
`artifacts/screenshots/character_idle/character_idle_NNN.png` phase strip
(breathing frames plus the blink frame).

`character/character_preview.tscn` is the reusable procedural character rig used
by the control lab and `character/labs/character_room_lab.tscn`. The latter places it
in the intentionally tiny 3x4 `rooms/character_corner.yaml` room, using the
supplied pixel-art tiles and props as a gameplay-scale visual test. Its
character-only CanvasItem shader applies a deliberately restrained room
palette grade; the geometry, face, hair, clothing, and contact shadow remain
generated in GDScript.

Run `tools/capture_character_room_lab.sh` to save a new renderer-produced
comparison image under `artifacts/screenshots/character_room/`. The script
never overwrites an existing image: each invocation advances
`character_room_001.png`, `character_room_002.png`, and so on.

### Modular styles and the variants contact sheet

Hair styles (bob, long, crop, ponytail), hair colours, eye styles (round,
narrow, angled), and outfit silhouettes (meadow dress, sage sweater, denim
overalls, tube top + skirt, bikini, plus a nude body reference) are
independent, composable indices on the same rig. Side profiles draw a true
profile body — projected chest, seat curve, one front-edge arm — and back
views hang the hair over the body with arms outside the torso, per the
Stardew reference in `artifacts/ref/`. `character/labs/character_variants_lab.gd` renders every
hair style across every outfit at game scale on a 16 px grid, varying skin
tones per column, so the whole style system can be graded in one image.

Run `tools/capture_character_variants.sh` to write the next
`artifacts/screenshots/character_variants/character_variants_NNN.png`.

## Character v2 — polygon-skin prototype

`character-v2/` is a parallel take on the character: instead of painting
silhouettes in a `_draw()` pass, every body part is a real `Polygon2D` mesh
skinned to a `Skeleton2D` through bone weights, so the rig is authored,
posed, and edited entirely with Godot's own 2D tooling. The base body is
torso, arms (no hands), legs, neck, and head, in two views: front
(facing the camera) and side (profile, facing +x).

- `character-v2/character_rig_v2.tscn` is the reusable front character
  scene; `character_rig_v2_side.tscn` is the profile variant with the same
  script and bone layout (far-side limbs draw first, in a darker skin
  tone). Drop either into any scene at scale `1/16` to land on the
  16 px tile grid.
- `character-v2/character_rig_v2.gd` is a small `@tool` helper that derives
  each part's outline, layers outfits, and morphs the body shape; see below.
- `character-v2/outfits/` holds garment scenes (e.g. `casual.tscn`): plain
  skinned `Polygon2D`s with `skeleton = ../..` and the same bone chains.
  Add them to the rig's `outfits` array — instances are layered under the
  Skeleton2D right before `BackHair` (over the body and arms, under neck,
  head, and hair), in array order so later entries draw on top (shirt after
  pants). The rig itself ships as a nude skin-toned base. Garment parts get
  their own outline layer behind the garment, so clothes never expose the
  body's part seams.
- `character-v2/variants/` pairs of front/side scenes with the `body_preset`
  export set to `masculine` or `feminine`.
- `character-v2/labs/rig_lab_v2.tscn` is the visual test bench: masc, fem,
  and side figures at true game scale on a 16 px grid, plus rest-pose nude
  bodies, the side rig, and both bodies posed in outfits at comfortable
  editing zoom (`tools/capture_character_rig_v2.sh` saves a screenshot).

Authoring conventions:

- The rig is authored at **1 scene unit per authoring pixel** — the
  character is ~764 units tall, big enough to edit fine details in the
  Godot GUI and a good base for higher-res renders. Origin at the ground
  between the feet, facing down toward the camera; drop instances at
  scale `1/16` for the 16 px tile grid (16 units = 1 world pixel). Bones
  and polygons
  are plain scene data — drag bone gizmos, edit polygon points, or rotate
  bones in an `AnimationPlayer`; nothing is generated at runtime except
  outlines.
- Part polygons live in skeleton space at the rest pose. Rigid parts bind
  one bone with a little of its parent near the joint for smooth bending;
  the torso spans `Hips`/`Spine`/`Chest` so the spine can flex. Bone paths
  in a `Polygon2D`'s `bones` property resolve **relative to the
  Skeleton2D**, so nested bones need full chains such as
  `Hips/Spine/Chest`.
- Draw order is tree order: legs, torso, arms, back hair, neck, head, face
  parts, front hair (side rig: far limbs first, then torso, near limbs,
  back hair, neck, head). Body outlines live in one shared layer behind all
  parts, so the silhouette reads as one continuous shape instead of stacked
  per-part borders.
- Outlines are **derived, never authored**: the rig script maintains a
  sibling `<Part>Outline` polygon (radially expanded, same vertex count, so
  it reuses the part's weights) and rebuilds it live when a part's points
  change in the editor. Generated outline nodes are never saved into the
  `.tscn`; thickness and colour are exports on the rig root.

### Body morphs

The script also warps the authored base into distinct body shapes — a
piecewise-linear vertical remap through anatomical landmarks (feet, knee,
hip, waist, chest, shoulder, chin, head top) plus a per-band horizontal
scale and a localized radial bust bump. The same warp is sampled for bone
rest positions and every skinned polygon (garments included), so a morphed
body and its clothes stay registered, and the warp is idempotent: params at
their defaults reproduce the authored scene exactly.

- Exports: `leg_length`, `torso_length`, `neck_length`, `head_size`,
  `shoulder_width`, `chest_width`, `waist_width`, `hip_width`,
  `thigh_width`, `calf_width`, `bust` (+ `bust_center`/`bust_radius`,
  useful on the side rig), and `hair_length` (scales the back-hair bottom
  edge toward/away from the skull — short crops for masculine, long locks
  for feminine).
- `body_preset` copies a curated shape (`masculine` / `feminine`) into
  those exports; `variants/` scenes are just base scenes with a preset.

Run `tools/capture_character_rig_v2.sh` to write
`artifacts/screenshots/character_rig_v2.png`.

`tools/zoom_region.gd` is a small headless helper for inspecting captures
at true pixel scale:

```sh
godot --headless --path . --script res://tools/zoom_region.gd -- \
	src.png out.png <x> <y> <w> <h> <scale>
```

## Sprite sheet characters

`sprites/` is a simple, data-driven character system for compact generated
strips. It replaces the rig experiments for gameplay purposes: a character is
a texture plus a list of animation definitions, rendered by a lightweight
`CharacterSprite` node.

- `sprites/character_anim_def.gd` — one animation: name, frame origin in sheet
  pixels, frame count, fps, loop flag.
- `sprites/character_sheet.gd` — a `Resource` describing one character sheet:
  texture, uniform `frame_size`, and its `CharacterAnimDef` list. It builds and
  caches Godot `SpriteFrames` on demand, so any number of on-screen characters
  share one build. Adding a character means describing (or reusing) a layout
  and pointing it at a new texture.
- `sprites/character_sprite.gd` — the render node. One node per character;
  origin sits at the character's feet. `animation` is a base name (`stand`,
  `idle`, `walk`, `sleep`); directional animations resolve to
  `<animation>_<facing>`, so changing `facing` (`down`/`left`/`up`/`right`)
  retargets the animation automatically, and non-directional animations such
  as `sleep` play verbatim.
- `sprites/generated_characters.gd` — loads the YAML character definitions
  and their generated compact strips. The loader derives contiguous animation
  ranges from the configured action list.
- `sprites/character_generator_layout.gd` — source-atlas action definitions
  used by both the strip builder and runtime loader.
- `characters/generated_characters.yaml` — top-level action selections,
  followed by each character's layer selections. Run
  `tools/build_generated_characters.gd` after editing it.

`sprites/labs/character_sprites_lab.tscn` is the visual test bench: a focused
4x generated character. The button bar and keys change character
(Tab / Shift+Tab), animation (Q/E), and facing (arrow keys or WASD); the
facing cycle only offers directions the current animation can play; Space
pauses. Run `tools/capture_character_sprites.sh` to write the `stand_down`,
`idle_down`, `walk_right`, and `sleep` state captures to
`artifacts/screenshots/character_sprites/`.

## Project layout

Feature folders over file-type folders, per Godot convention as a project
grows:

- `sprites/` — compact character-strip resources, generated-strip loader,
  `CharacterSprite` render node, and its lab scene
- `character/` — the character system: rig scene (`character_preview.tscn`),
  canvas renderer (`character_canvas.gd`), palette grade shader, and
  `character/labs/` with every visual test bench
- `character-v2/` — the polygon-skin character prototype: real `Polygon2D`
  meshes skinned to a `Skeleton2D`, plus its own lab scene
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
