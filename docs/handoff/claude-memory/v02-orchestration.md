---
name: v02-orchestration
description: "How the v0.2 «до онлайна» patch is built — local git in work/tennis, three stream sessions, one integrator"
metadata:
  node_type: memory
  type: project
  originSessionId: 748f86a6-6de7-4b8b-8566-b0dc163b09e9
  modified: 2026-10-07T03:48:41.723Z
---

Since 2026-10-07, `work/tennis` is a local git repo (no remote, never push). It continues the old history from `tennis-full-history.bundle`: main = 55b5bcc snapshot, then 455decf GameEvents bus + plan. `build/` is untracked because the server builds from source, and `core.autocrlf=false` keeps the `.sh` scripts LF.

v0.2 plan: `docs/superpowers/plans/2026-10-07-v0.2-pre-online.md`. Streams:
- A «v0.2 A: логика рогалика»: branch v02-roguelike (worktree). Style points, gear and the effect bus, opponent STA as HP, Тотализатор, golden opponents.
- B «Хаб: свой теннисный клуб (дизайн и код)»: branch v02-club (worktree ../tennis-club). The walkable 3D club H0–H4 per CLUB_HUB_TZ v2.
- C «v0.2 C: интерфейс и флоу — аудит и ТЗ»: branch v02-ui-flow. Audits the UI and writes `docs/UI_FLOW_TZ.md`, no code until the owner approves.
- The integrator is the session «Roguelike прокачка и механика ударов». It owns main.gd, hud.gd and tournament_ui.gd, merges per plan section 5, and is the only one who deploys to fi, and only with the owner's ok.

Deploy goes from committed main only: `git archive --format=tar HEAD | gzip | ssh fi '...'`, then the same build, update and compose steps as in docs/TZ.md. Performance numbers and the optimisation plan are in `docs/PERFORMANCE.md`. The telemetry beat now carries fps, low, worst, cpu, draws, tris and px. A match draws about 450 calls; the next optimisation step is merging the near props.

**Why:** the owner wants one tested build with no stream overwriting another. Streams listen on GameEvents instead of editing main.gd.
**How to apply:** check the plan's ownership table before editing shared files. Run every check in plan section 6 after each merge. Related: [[roguelike-vision-docs]], [[godot-441-path]].
