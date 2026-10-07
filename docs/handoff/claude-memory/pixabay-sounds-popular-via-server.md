---
name: pixabay-sounds-popular-via-server
description: "How to pick and fetch game sounds — only popular Pixabay sounds, downloaded through the fi server"
metadata:
  node_type: memory
  type: feedback
  originSessionId: f168eeed-930e-4f8a-afbe-a21906a30138
  modified: 2026-10-05T17:34:48.107Z
---

When picking sounds for TENNISISI, take only Pixabay sounds with lots of likes and downloads. If a sound has few likes, don't download it at all.

**Why:** the user said so directly (2026-10-05). Popularity is their quality filter.

**How to apply:** use the browser pane to read likes, downloads and plays from each sound's Pixabay page. The page HTML has "Plays" and "Downloads", and the like count sits between "Free download" and "Save"; the mp3 is at cdn.pixabay.com/download/audio/...mp3. cdn.pixabay.com does not resolve from the user's PC, so download with `ssh fi 'curl ...'` and then `scp` the file back into `sources/`. Add a line for each source to sources2.txt and to CREDITS.md. Prepare the file with tools/prep_audio.py. Related: [[web-audio-stream-not-samples]].
