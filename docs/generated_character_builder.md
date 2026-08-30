# Generated character sheets

`tools/build_generated_characters.gd` composes pre-aligned PNG layers from
`assets/characters/Character_Generator/` into compact runtime strips.

The authoring file is [`characters/generated_characters.yaml`](../characters/generated_characters.yaml).
Its exported animations are shared top-level settings. Each character has an
`id` plus six direct selections—there is no nested `layers` object.

```yaml
animations:
  - stand
  - idle
  - walk
  - sleep

characters:
  - id: example_adult
    body: Body_01
    eyes: Eyes_01
    outfit: Outfit_01_01
    hairstyle: Hairstyle_01_01
    accessory: null
    held_item: null
```

Layer IDs are the 16×16 PNG filenames without `.png`. The compositing order is
always body, eyes, outfit, hairstyle, accessory, then held item. `held_item`
currently supports full-sheet Book assets; Smartphone assets have their own
smaller layout and need a dedicated action compositor before they can be
safely enabled.

Run the builder from the project root:

```sh
godot --headless --path . --script res://tools/build_generated_characters.gd
```

It writes one compact runtime strip per character at
`assets/characters/generated/<id>.png`. The selected animation/direction
groups are concatenated into that one 32-pixel-tall (at 16×16) texture, with
no unused action rows and no duplicate sub-sheets. The strip can be loaded at
runtime with:

```gdscript
var sheet := GeneratedCharacters.load_sheet(&"example_adult")
```

`stand` exports four one-frame directional poses and is the default animation
when it is present. `idle` is the separate animated idle loop.

The supported actions are `stand`, `idle`, `walk`, `sleep`, `sit`, `read`,
`pickup`, `gift`, `lift`, `throw`, `hit`, and `hurt`. Their source rectangles,
frame counts, and FPS live in `sprites/character_generator_layout.gd` and are
documented in
[`assets/characters/premade_character_animation_layout.md`](../assets/characters/premade_character_animation_layout.md).

This is deliberately a conservative exporter. It validates full-sheet layers
and crops all oversized layers to the standard 56×41-cell canvas before
packing the requested frames. That handles the generator's 927-pixel-wide
body/accessory files while keeping every output compatible with the animation
layout. Special prop interactions (phone, cart, weapons, and similar) remain
a future extension rather than silently misaligning artwork.
