# Generated character sheets

`tools/build_generated_characters.gd` composes pre-aligned PNG layers from
`assets/characters/Character_Generator/` into compact runtime strips.

The authoring file is
[`assets/characters/generated_characters.yaml`](../assets/characters/generated_characters.yaml).
It contains only character appearance selections; every generated character
uses the same fixed strip layout.

```yaml
characters:
  - id: example_adult
    body: Body_01
    eyes: Eyes_01
    outfit: Outfit_01_01
    hairstyle: Hairstyle_01_01
    accessory: null
    held_item: null
```

Layer IDs are PNG filenames without `.png`. The compositing order is always
body, eyes, outfit, hairstyle, accessory, then held item. `held_item`
currently supports full-sheet Book assets; Smartphone assets have their own
smaller layout and need a dedicated action compositor before they can be
safely enabled.

Run the builder from the project root:

```sh
godot --headless --path . --script res://tools/build_generated_characters.gd
```

It writes one `assets/characters/generated/<id>.png` strip per character. No
runtime YAML parsing or JSON sidecar files are required: each strip is always
928×32 pixels and uses the animation table in
[`sprites/character_generator_layout.gd`](../sprites/character_generator_layout.gd).
That table explicitly shows the raw source origin, packed strip origin, frame
count, FPS, loop setting, and optional frame events for every animation.

```gdscript
var sheet := GeneratedCharacters.load_sheet(&"example_adult")
```

Use `--check` to rebuild every configured strip in memory and compare its
pixels with the corresponding PNG. It exits with failure if output is missing
or stale, without creating sidecar metadata:

```sh
godot --headless --path . --script res://tools/build_generated_characters.gd -- --check
```

The fixed strip contains `stand_*` (four one-frame poses), `idle_*`,
`walk_*`, and non-directional `sleep`. `stand_down` is the default. Add any
future shared animation or frame event directly to the layout table so the
builder and runtime stay in lockstep.
