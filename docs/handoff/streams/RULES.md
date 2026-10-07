# Правила для потоков v0.2 (Mac, 08.10.2026)

Ты — отдельный поток (субагент) проекта TENNISISI. Сборщик (главная сессия) сливает,
проверяет и выкладывает. Ты **не** сливаешь в `main`, **не** пушишь, **не** выкладываешь.

## Среда
- Godot 4.4.1 (строго): `G=/Applications/Godot441.app/Contents/MacOS/Godot`.
- Работай **только в своём worktree** (путь в брифе), не трогай другие папки.
- Перед началом: `$G --headless --path . --import`. Прочитай `docs/HANDOFF.md`
  (разделы 4, 5, 7, 8, 9, 10), план `docs/superpowers/plans/2026-10-07-v0.2-pre-online.md`
  (владение файлами, крючки), свой раздел и документы из брифа.
- Экраны — только в разрешении телефона (720×1564 и `--size=1480`), см. `tools/menu_shots.gd`.

## Владение файлами
- `scripts/main.gd`, `scripts/hud.gd`, `scripts/tournament_ui.gd` — файлы сборщика. Правь их
  только маленькими отдельными коммитами-«крючками» (одна строка `emit`, тонкий вызов
  `show_*`, ветка в `_on_ui`), в сообщении коммита — что и зачем.
- Логика слушает `GameEvents` (`scripts/game_events.gd`), не встраивается в `main.gd`.
- `scripts/save_data.gd` — только новые секции и функции, старые не менять.
- Остальное владение — таблица в плане v0.2, раздел 2.

## Процесс
1. Спецификация (коротко, в `docs/superpowers/specs/`) → план (`docs/superpowers/plans/`) →
   TDD (тест сначала) → реализация → проверки → отчёт «готов к слиянию».
2. Коммиты маленькие, по делу, с трейлером `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
   Переносы строк LF (в репозитории `.gitattributes`).
3. Проверки перед «готов к слиянию» (все должны быть зелёными, кроме 4 известных
   провалов `overlay_probe` до C-2):
   ```bash
   $G --headless --path . -s tests/run_tests.gd
   $G --headless --path . -s tests/roguelike_test.gd
   $G --headless --path . -s tests/ui_test.gd
   $G --headless --path . -s tests/audio_test.gd
   $G --headless --path . --fixed-fps 60 -s tests/input_test.gd
   $G --headless --path . --fixed-fps 60 -s tests/anim_test.gd -- --body=0   # и 1, 2
   $G --headless --path . --fixed-fps 60 -- --autoplay --tournament --format=1 --bot-sd=0.07
   $G --path . --rendering-driver opengl3 -s tools/menu_shots.gd
   $G --path . --rendering-driver opengl3 -s tools/menu_shots.gd -- --size=1480
   ```
   Снимки лежат в user data Godot (`~/Library/Application Support/Godot/app_userdata/...`,
   путь печатается). Смотри их сам (Read на png) — на телефонном размере.
4. Балансировать ботом: `--bot-sd=0.07` (новичок), `--xp=N` (опыт навыков). Метрики
   «до/после» — в отчёт таблицей.
5. Не задавай вопросов владельцу по мелочам: принимай решение, записывай его в спеку.
   Если решение меняет видимое поведение — отметь в отчёте в разделе «Решения, которые
   стоит подтвердить».

## Отчёт сборщику (финальное сообщение, ≤ 40 строк)
- Ветка и диапазон коммитов, список затронутых файлов (отдельно — крючки в файлах сборщика).
- Что сделано (по пунктам ТЗ), что не сделано и почему.
- Таблица проверок: команда → результат. Метрики бота до/после.
- Пути к 3–6 ключевым снимкам.
- «Решения, которые стоит подтвердить» и известные проблемы.
