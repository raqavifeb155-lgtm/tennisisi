# План P: тренировка с пушкой

Спека: `docs/superpowers/specs/2026-10-08-p-ball-machine.md`. Ветка `v02-practice`.

1. `scripts/run/ball_machine.gd` + `ball_machine_hud.gd`; `Tutorial.mark_done()` — готово.
2. Крючки `main.gd` (одним коммитом): `Phase.DRILL`, создание `BallMachine`, `tick`, `stop`,
   `holds_xp`/`xp_mult` в опыте, простой AI, `_on_ui("drill")`, `on_club_opened` — готово.
3. Клуб: кнопка «Пушка» (+ тихая «Свободная игра»), реплики тренера, пульс «Новая игра»,
   `Club.stand_at`, шаблон задания `drill` — готово.
4. Тесты: `tests/drill_test.gd`, правка `club_test`, `overlay_probe` (+17), `hud_shots` (--tag=p).
5. Не сделано: звуки пушки (используется «hit» тише и ниже), модель пушки не поворачивает ствол
   по вертикали (только по горизонтали и отдача).
