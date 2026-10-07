---
name: roguelike-vision-docs
description: "Where the roguelike-RPG vision and the menu redesign spec live, and which design decisions the user approved on 2026-10-06"
metadata:
  node_type: memory
  type: project
  originSessionId: 74babe32-4a18-415f-a94b-cb932c21e40a
  modified: 2026-10-07T03:24:32.562Z
---

Vision doc: `work/tennis/docs/ROGUELIKE_DESIGN.md`. Menu/UI spec for a separate chat: `work/tennis/docs/UI_MENU_TZ.md`. Both were written 2026-10-06; no code was changed.

User-approved decisions (section 16 of the vision doc):
- Two modes: «Рогалик» (main) and «Классика» (plain tennis, minimal on-screen effects).
- 3 gear slots shared with opponents (racket, shoes, wristband) plus a bag.
- 5 rarities: gray, blue, purple, orange legendary, red mythic.
- Rarity is revealed on court with light and pattern, not in the bracket.
- Items drop from opponents and from «Выбей приз» events.
- Opponent stamina works as HP, with damage numbers and bar shards.
- Every run must carry something into the next one (locker item, workshop, unlocks); retirement to the Academy is voluntary.
- Run format: one set to 4 games, tiebreak at 3:3.

Still open: deciding point at 40:40, shared skills across both modes.

Menu direction, answered 2026-10-06 (overrides UI_MENU_TZ section 4's proposal):
- ONE brand color everywhere (dark base + gold, as now), NOT the surface color of the location. Only rarities and win/lose states are saturated.
- Club = the live 3D court behind the menu, with room tiles at the bottom (not a 2D illustration).
- Main visual reference: Balatro. Items are physical cards that tilt under the finger, have a shine sweep and flip over.
- Work order: menu → ball-machine tutorial (replaces the popup tutorial) → gear slots and bag → New York sounds → How to Fish research and a first-person camera prototype.
- Check every screen at phone size, not desktop. The reliable way is `tools/menu_shots.gd`, which renders all menu screens at 720×1564 (= iPhone 17 Pro Max 440×956 in the 720-wide stretch canvas) and `-- --size=1480` (360×740 Android) into user://menu_*.png. The browser pane (root `.claude/launch.json` "web-build", :8765) runs the real web build, but its canvas screenshots come out cropped or shifted, so use it for interaction only.
- 2026-10-07: How to Fish breakdown in `docs/HOW_TO_FISH_TAKEAWAYS.md`. Hooks we take: «Очки стиля» (stacking style multipliers per point, with hidden tricks), the Тотализатор room in the Club (roulette ×2/×35 and a bet on your own match, in-game gold only, never Stars), rare variants of opponents, sharing the best point to Telegram. First-person camera only for replays and a challenge, not as the main mode. Online spec in `docs/ONLINE_PVP_TZ.md`, path A→B→C→D: friend challenge, 1v1 by invite link, pair vs AI, 2v2. It has no career: equal stats at level 12, event-based netcode, a headless Godot server on fi, and doubles zones with a «Мой!» rule. The user moved online ahead of patch 4. Next design stage: gear interplay, progression, balance.
- 2026-10-07: the club hub spec is `docs/CLUB_HUB_TZ.md` (v2). It is a walkable 3D tennis club you upgrade: the hero walks with the match controls, and each place has one context button plus quick travel. Models come from CC0 packs (KayKit, Quaternius, Kenney) unified by our toon material; courts and buildings stay procedural. It includes an indoor arena for hosting your own and online matches. Upgrades are about 70% flex and 30% small capped utility (off online), and they replace the Мастерская. Stages H0–H4. H0 (design) is delegated to the session «Хаб: свой теннисный клуб (дизайн и код)».
- Done 2026-10-06 and deployed: UiTheme (`scripts/ui/ui_theme.gd`), GameCard (`scripts/ui/game_card.gd`), and a new TournamentUI frame (back button at top, scrolling middle, pinned actions). The Club has Раздевалка, Тренерская and «Как играть». PRODUCT.md is at the project root.

**Why:** these were decided in conversation, not in code; later patches must follow them.
**How to apply:** before planning patch 2a/2b or any UI work, read these docs. The user wants deep replayability psychology and a premium-looking loot/rarity presentation.
