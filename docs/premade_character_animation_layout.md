# Legacy premade character sheet layout

This document describes the generator-style premade character sheets in
`assets/characters/16x16/`.

## Coordinate convention

- Every character cel is **16 × 32 pixels**.
- Origins below are pixel positions measured from the **top-left** of a sheet.
- Horizontal frames are contiguous: frame `n` begins at `origin.x + 16 * n`.
- The generator's adult reference atlas is 896 × 640. These premade PNGs are
  896 × 656; their animation layout begins at the same top edge, and the final
  16 pixels are outside the documented animation strips.

## Static poses and core movement rows

These names are descriptive labels; they are not embedded in the PNG or the
Aseprite file.

| Label | Frame origins | Frames | FPS | Notes |
| --- | --- | ---: | ---: | --- |
| `stand_right`, `stand_up`, `stand_left`, `stand_down` | `(0, 0)`, `(16, 0)`, `(32, 0)`, `(48, 0)` | 1 | 1 | Four static directional poses. |
| `idle_*` | `(0, 32)`, `(96, 32)`, `(192, 32)`, `(288, 32)` | 6 | 12 | Generator’s named Idle animation. |
| `walk_*` | `(0, 64)`, `(96, 64)`, `(192, 64)`, `(288, 64)` | 6 | 12 | Generator’s named Walk animation. |
| `sleep` | `(0, 96)` | 6 | 4 | First six cells of the Sleep export row. |

## Generator-authoritative preview animations

The generator's Unity project supplies named sprite rectangles and animation
clips for these actions. It plays all of these as loops. Their direction order
is **right → up → left → down** unless a row says otherwise.

| Generator action | Direction origins (x, y) | Frames per direction | FPS | Directions |
| --- | --- | ---: | ---: | --- |
| Idle | `(0, 32)`, `(96, 32)`, `(192, 32)`, `(288, 32)` | 6 | 12 | right, up, left, down |
| Walk | `(0, 64)`, `(96, 64)`, `(192, 64)`, `(288, 64)` | 6 | 12 | right, up, left, down |
| Sit | `(0, 128)`, `(96, 128)` | 6 | 12 | right, left |
| Read | `(0, 224)` | 12 | 12 | one non-directional strip |
| Pick Up | `(0, 288)`, `(192, 288)`, `(384, 288)`, `(576, 288)` | 12 | 12 | right, up, left, down |
| Gift | `(0, 320)`, `(160, 320)`, `(320, 320)`, `(480, 320)` | 10 | 12 | right, up, left, down |
| Lift | `(0, 352)`, `(224, 352)`, `(448, 352)`, `(672, 352)` | 14 | 12 | right, up, left, down |
| Throw | `(0, 384)`, `(224, 384)`, `(448, 384)`, `(672, 384)` | 14 | 12 | right, up, left, down |
| Hit | `(0, 416)`, `(96, 416)`, `(192, 416)`, `(288, 416)` | 6 | 12 | right, up, left, down |
| Hurt | `(0, 608)`, `(48, 608)`, `(96, 608)`, `(144, 608)` | 3 | 6 | right, up, left, down |

## Other named export strips

The generator's Save Character feature defines these complete horizontal
regions. Only the ten preview actions above have individually named animation
clips; the export regions alone do not specify direction groups or playback
rates for every row.

| Top y | Export name | Strip width | 16 px cells |
| ---: | --- | ---: | ---: |
| 32 | Idle | 384 | 24 |
| 64 | Walk | 384 | 24 |
| 96 | Sleep | 208 | 13 |
| 128 | Sit 1 | 192 | 12 |
| 160 | Sit 2 | 192 | 12 |
| 192 | Phone | 192 | 12 |
| 224 | Read | 192 | 12 |
| 256 | Push Cart | 768 | 48 |
| 288 | Pickup | 768 | 48 |
| 320 | Gift | 640 | 40 |
| 352 | Lift | 896 | 56 |
| 384 | Throw | 896 | 56 |
| 416 | Hit | 384 | 24 |
| 448 | Punch | 384 | 24 |
| 480 | Stab | 768 | 48 |
| 512 | Grab Gun | 256 | 16 |
| 544 | Gun Idle | 384 | 24 |
| 576 | Shoot | 192 | 12 |
| 608 | Hurt | 208 | 13 |

### Sleep row note

The `Sleep` export region is 13 cells wide and contains bed/prop artwork as
well as sleeping character poses. Its first six cells form the sleeping
character sequence.

## Where this information came from

The local `.ase` document has 20 whole-sheet frames and no Aseprite animation
tags. The generator stored the layout metadata separately. The findings above
were read from the following files at commit
[`3503160c442b24fb55dc90a9f04bf17fb0afcbb0`](https://github.com/stas-bool/Character-Generator-2.0/tree/3503160c442b24fb55dc90a9f04bf17fb0afcbb0):

- [`AnimationSO.cs`](https://github.com/stas-bool/Character-Generator-2.0/blob/3503160c442b24fb55dc90a9f04bf17fb0afcbb0/Assets/Create%20Character%20Menu/Save%20Character%20Popup/Scripts/AnimationSO.cs) defines an export strip's name, start position, and size.
- [Animation Data assets](https://github.com/stas-bool/Character-Generator-2.0/tree/3503160c442b24fb55dc90a9f04bf17fb0afcbb0/Assets/Create%20Character%20Menu/Save%20Character%20Popup/Animation%20Data) provide the 19 named rows and crop widths.
- [`Adult Character Preview.png.meta`](https://github.com/stas-bool/Character-Generator-2.0/blob/3503160c442b24fb55dc90a9f04bf17fb0afcbb0/Assets/Create%20Character%20Menu/Character%20Preview/Adult/Adult%20Character%20Preview.png.meta) assigns named 16×32 rectangles to the ten preview actions.
- [Adult preview `.anim` clips](https://github.com/stas-bool/Character-Generator-2.0/tree/3503160c442b24fb55dc90a9f04bf17fb0afcbb0/Assets/Create%20Character%20Menu/Character%20Preview/Adult) provide the six/12 FPS playback and looping settings.
