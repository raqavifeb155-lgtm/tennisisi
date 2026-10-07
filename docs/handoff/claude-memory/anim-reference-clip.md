---
name: anim-reference-clip
description: Reference tennis clip (Alcaraz–Sinner RG) the user wants animations/dynamics to match; where the frame analysis lives and what it found
metadata:
  node_type: memory
  type: project
  originSessionId: b54cd8e5-f7b8-4419-8136-84ae20feccb7
  modified: 2026-10-05T23:35:43.639Z
---

User's goal (2026-10-06): make the game's player animations/rally dynamics resemble a real top match; wants clay slides, wide-court running strokes, and a right-hander retreating to hit diagonally.

Reference clip: `C:\Users\pipij\OneDrive\Рабочий стол\IMG_5044.MP4` (Alcaraz near/white, Sinner far/green, RG clay, fixed rear camera, 343 real frames at ~25 fps inside a 30 fps container). Full analysis, trajectories and per-frame crops: `C:\Users\pipij\Downloads\TENNISISI\research\clip-IMG_5044\CLIP_ANALYSIS.md`.

Key findings: lean into runs is driven by acceleration (peaks 14–17°, game uses ~3.5° from speed); recovery step starts ~0.3 s after contact; racket goes back 0.5–0.7 s before contact while still running; split-step is a low wide load, not a hop; clip has no retreat-and-hit shot (needs another clip).

Second batch (2026-10-06): IMG_5045, IMG_5045 (2), IMG_5046 from `C:\Users\pipij\Downloads\Telegram Desktop\` — same broadcast camera; analysis in `research\CLIPS_5045_5046.md`. Measured clay slides: 5.1 m/s -> 0 in 0.63 s over ~1.6 m, stance 1.5–1.8 m, decel ~6–8 m/s² (game uses 30). Serve: touchdown ~0.3 s after contact, rear leg kicks up to horizontal. Still no retreat-and-hit shot. Proposed next step: pose estimation (MediaPipe/ViTPose) for joint tracks — needs a pip install, waiting for user's OK.

Implemented 2026-10-06 in work/tennis (athlete.gd, opponent_ai.gd, tools/pose_shots.gd, new tests/anim_test.gd, docs/ANIMATION_REALISM.md); pre-change backup in work/backup-tennis-2026-10-06-anim. Not built/deployed: build needs Godot 4.4.1 + web templates (only Godot 4.7.1 is on this PC, at OneDrive\Рабочий стол\Проекты\PROJECT_RELIQUARY), deploy = push build/web to GitHub main. Lesson: a physical clay slide must not apply while steering in to the ball — it cost the hitter quality via movement_quality and skewed bot-vs-AI balance.

User review workflow (agreed 2026-10-06): comparison boards in research/compare (real frame on top, game at the same phase below, event codes like FH-5 listed in EVENTS.md); the user sends corrections by code. User caught a broken arm I missed in my own visual check — hand keys are absolute in model space, so anything that moves the chest (lunge drop, trunk pitch) must carry the arm targets along. Godot 4.4.1 is now in C:\Users\pipij\.cache\godot-4.4.1 (all tests pass on it).

Round 2 (2026-10-06, user notes by board code) done: wider stances everywhere, ~90° shoulder turn on forehand, two-hander right foot to the right, serve kick/arm extension, slide body turn + reaching arm, stretch tilt, no crossed feet; RF board = Sinner's run to the net (IMG_5044 10.5–13.1 s), side burst moved to RS. User's standing rule: feet wider, body turned to the stroke side, mostly left-right movement. Web build rebuilt with 4.4.1 into work/tennis/build/web (old build in backup-tennis-2026-10-06-anim/build-web-old); not pushed — no git repo locally.

Body model (2026-10-06): user chose the TOON body (`Athlete.Body.TOON`, now the default `Athlete.body_style`): lathe limbs with sleeves/shorts/socks/sneakers, bigger head/hands/feet, cel shading + outline; CLASSIC and ATHLETE kept switchable. All Looks keys work on it. Next asked-about option was a real rigged model (not started).

**Why:** the user wants "ровнее" animations before implementing; analysis was research only, no game code changed.
**How to apply:** when implementing, start from section 5 (P1–P6) of the analysis; the open question was whether to keep the arcade accel/decel (22/30 m/s²) or add animation-only smoothing. The clip itself has no retreat shot, so ask for a new clip before building that stroke. Related: [[top100-roster-research]].
