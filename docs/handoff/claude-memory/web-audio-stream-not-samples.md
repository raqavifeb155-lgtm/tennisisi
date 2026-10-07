---
name: web-audio-stream-not-samples
description: Godot 4.4 web — sounds must play as streams; the Web Audio sample path silenced SFX and got the page killed on iPhone/Telegram
metadata:
  node_type: memory
  type: project
  originSessionId: f168eeed-930e-4f8a-afbe-a21906a30138
  modified: 2026-10-05T16:59:55.017Z
---

TENNISISI (work/tennis, Godot 4.4.1 web, Telegram Mini App on fi server): since 2026-10-05 every sound plays with PLAYBACK_TYPE_STREAM (`audio/general/default_playback_type.web=0`, `Sfx._voice()`).

**Why:** Godot 4.4's web sample path duplicates the AudioBuffer, builds ~10 nodes plus an AudioWorklet on every play. On the user's iPhone in Telegram only the music played (it already streamed), and iOS killed the page after 1.5–3 min. Server telemetry (`docker logs tennis-web-1 | grep /log?`) showed sessions ending with no pagehide around points 4–7.

**How to apply:** don't switch back to samples, and don't re-add sample "warming". For crash questions, read the `/log` telemetry on the server first (`ssh fi`). Deploy steps are in docs/TZ.md.
