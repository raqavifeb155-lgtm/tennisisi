# Credits

## Sounds

- `assets/sfx/hit_real_1.wav`, `hit_real_2.wav`, `hit_real_3.wav` — three racket hits cut from
  "Tennis ball being hit" by freesound_community (Pixabay, sound 72611), used under the
  [Pixabay Content License](https://pixabay.com/service/license-summary/) (free for commercial
  use, no attribution required; credited here anyway).
- `assets/sfx/bounce_real_1.wav` … `bounce_real_4.wav` — four bounces cut from
  "Tennis ball bounce" by freesound_community (Pixabay, sound 39028), same license.
- `assets/sfx/birds.ogg` — a seamless one-minute loop from "Birds chirping calm" by
  zehendrew (Pixabay, sound 173695), same license.
- `assets/sfx/amb_clay.ogg` — a seamless one-minute loop from "Pea Point, New Brunswick seaside
  ambience" by freesound_community (Pixabay, sound 17262), same license.
- `assets/sfx/amb_grass.ogg` — a seamless one-minute loop from "City above far ambience car" by
  cliffordjohnson (Pixabay, sound 479129), same license.
- `assets/sfx/amb_grass_bell.ogg` — "The chimes of Big Ben" by scottishperson (Pixabay,
  sound 203986), same license.
- From Pixabay, same license (author, Pixabay sound id): `amb_park.ogg` — "City Traffic (Outdoor)"
  (freesound_community, 6414); `amb_park_horn.ogg` — "Car Horn 02" (153260); `amb_park_ship.ogg` —
  "Cargo Ship Horn" (352063); `amb_clay_gull.ogg` — "Seagull Calls" (339723); `amb_clay_bell.ogg` —
  "Church bell" (5993); `applause.ogg` — "Applause, cheer" (236786); `crowd_ooh.ogg` — "Crowd
  Shocked Reaction" (352766); `coin.ogg` — "coin recieved" (230517); `reward.ogg` — "Game Bonus"
  (144751); `click.ogg` — "Click Button" (140881); `victory.ogg` — "Success Fanfare Trumpets"
  (6185); `defeat.ogg` — "Sad Trumpet" (278822); `music_menu.ogg` — "Lofi Sunny Cafe"
  (alex-morgan, 568156); `amb_park_plane.ogg` — "Airplane, aircraft take off" (freesound_community,
  121949). Sources and the prep commands: `tools/prep_audio.py`. `amb_park.ogg` was then
  repaired (a helicopter in the recording: its blade wobble levelled out), see `tools/dechop_bed.py`.
- All other sounds in `assets/sfx/` are generated procedurally by `tools/gen_sfx.py`.

## 3D models (the club's props)

All CC0 1.0 (public domain, no attribution required; credited here anyway). Brought to one
look - colours baked into the vertices and pulled toward the club's palette, scaled to the
hero (1.85 m), no textures - and packed into one file, `assets/club/models/club_props.glb`,
by `tools/club_models.py` (which also lists what is taken from where). The web build serves
it as `models/club_props.<version>.glb` and the game downloads it after the start.

- KayKit by Kay Lousberg (kaylousberg.itch.io, github.com/KayKit-Game-Assets), CC0:
  City Builder Bits 1.0 (bench, street light, dumpster, hydrant, boxes, three cars,
  water tower, two buildings), Furniture Bits 1.0 (armchair, wooden chair, low table),
  Restaurant Bits 1.0 (round table, chair, stool, crate, menu board).
- Kenney (kenney.nl), CC0: Nature Kit 2.1 (trees, pines, bushes, flowers, rocks, logs, stump,
  pot, sign, planks fence, broken column), Car Kit (cone, tyre, bumper), City Kit Commercial 2.1
  (parasol, awning, five low-detail shop fronts), City Kit Suburban 2.0 (two fences).
- Quaternius is not used (kept in reserve).
