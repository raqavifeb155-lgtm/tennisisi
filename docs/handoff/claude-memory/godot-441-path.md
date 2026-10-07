---
name: godot-441-path
description: "Which Godot binary to use for work/tennis (4.4.1, not 4.7) and where it lives"
metadata:
  node_type: memory
  type: reference
  originSessionId: 748f86a6-6de7-4b8b-8566-b0dc163b09e9
  modified: 2026-10-06T04:17:44.363Z
---

Use the project's Godot 4.4.1: `C:\Users\pipij\.cache\godot-4.4.1\Godot_v4.4.1-stable_win64_console.exe`; web export templates in `%APPDATA%\Godot\export_templates\4.4.1.stable`. Godot 4.7.1 is also on the machine but rewrites project files and rejects some untyped `:=` inferences in main.gd.

**Why:** the animation session (2026-10-06) set this up after 4.7 broke things.
**How to apply:** run tests/autoplay/export with this exe; rebuild `work/tennis/build/web` after gameplay changes. Animation regression test: `tests/anim_test.gd` (55 checks). See [[looks-and-paris-court]].
