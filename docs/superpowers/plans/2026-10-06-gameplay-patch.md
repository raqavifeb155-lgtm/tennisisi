# Патч геймплея — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Шаги — чекбоксы.

**Goal:** удары по задуманному жесту (топспин = вверх + выкрут, слайс = вниз), короткий бак
выносливости с седьмым навыком, прокачка с заметной разницей между уровнями.

**Architecture:** классификатор жеста остаётся чистой статической функцией
(`ShotGesture.classify`) и тестируется в `tests/run_tests.gd`. Вся математика навыков и
выносливости — статические функции `Skills` (тестируемые без сцены); `main.gd` только
хранит `stamina` и вызывает их. Новый узел `BallTrail` рисует след мяча.

**Tech Stack:** Godot 4.4.1 (GDScript), headless-тесты.

## Global Constraints
- Godot только 4.4.1: `C:\Users\pipij\.cache\godot-4.4.1\Godot_v4.4.1-stable_win64_console.exe` (`$G` ниже).
- Нет git в `work/tennis` — бэкап до патча: `work/backup-tennis-2026-10-06-gameplay/`.
- Направление удара: «куда уходит палец, туда мяч, по линии от игрока» — не менять.
- Потолок навыка 25; перки на 5/10/15/20/25.
- Тексты для игрока — по-русски, как в остальном коде.

Команды проверки:
```bash
"$G" --headless --path . -s tests/run_tests.gd
"$G" --headless --path . --fixed-fps 60 -s tests/input_test.gd
"$G" --headless --path . --fixed-fps 60 -s tests/anim_test.gd
"$G" --headless --path . --fixed-fps 60 -- --autoplay --tournament --format=1
```

---

### Task 1: Классификатор жестов

**Files:** Modify `scripts/shot_gesture.gd`, `scripts/tuning.gd:19-21`, `scripts/hud.gd:446-447`,
`scripts/main.gd:681`; Test `tests/run_tests.gd::test_gestures`.

**Interfaces — Produces:**
`ShotGesture.classify(points: PackedVector2Array, times: PackedInt32Array, screen_h: float, curl_min := 0.12, turn_min_deg := 45.0, drop_len := 0.11, dead_deg := 12.0, side_gain := 0.6) -> Result`;
`Result.curl_k: float` (1.0 вне топспина, 0.6–1.4 у топспина); `Result.apex` — точка
прицела (для штриха вниз уже с мёртвой зоной и коэффициентом). Поля `curve`/`hook` удаляются.
`Tuning.curl_min`, `Tuning.curl_turn` вместо `curve_min`/`hook_min`.

- [ ] Переписать `test_gestures` под новые правила (кейсы из спеки, раздел 4): прямо вверх → FLAT;
  вверх + выкрут вправо/влево → TOPSPIN, прицел прямо (|apex.x − start.x| < 0.1 × forward);
  больший выкрут → больший `curl_k`; C с загибом назад → TOPSPIN; длинный ↘ → SLICE, apex
  правее старта; ↙ → левее; вниз с дрейфом 10° → SLICE, apex.x == start.x; ↘ под 60° → SLICE;
  короткий вниз → DROP; почти горизонтальный → FLAT.
- [ ] Запустить — новые проверки падают.
- [ ] Реализовать: направление по первому вертикальному сдвигу ≥ 3% высоты; вверх — точка
  поворота (первая, где локальное направление отклоняется от хорды ≥ `turn_min_deg`, при
  хорде ≥ 5% высоты), иначе самая верхняя; выкрут = путь после точки поворота, TOPSPIN при
  `curl ≥ curl_min × forward` и `curl ≥ 2%` высоты; `curl_k` по формуле спеки; вниз — хорда
  старт→конец, мёртвая зона/коэффициент, зеркально вверх; DROP по `drop_len`.
- [ ] Tuning/hud-слайдеры: «Выкрут для крутки» (`curl_min` 0.05–0.4), «Поворот выкрута, °»
  (`curl_turn` 25–80). main: передать новые параметры.
- [ ] run_tests зелёный.

### Task 2: Топспин ощущается

**Files:** Modify `scripts/main.gd` (`_on_swipe`, `_swing_input`, `pending_swing`, `_player_hit`,
`_player_serve`), Create `scripts/ball_trail.gd`; Test `tests/run_tests.gd::test_topspin_curl`.

**Interfaces:** Consumes `Result.curl_k`. Produces `var _curl_k := 1.0` в main (последний жест),
`BallTrail.new()` с `set_color(c: Color, bright: bool)` и `follow(ball: Node3D)`.

- [ ] Тест: решатель + физика, та же скорость; отскок топспина с вращением
  `lerpf(300,470,0.75) × 1.4` выше плоского (top 40) минимум в 1.3 раза.
- [ ] main: `_curl_k` из жеста, в топспине `top *= _curl_k` (и в кик-подаче); подпись
  `TOPSPIN ×1.3`; при `_curl_k ≥ 1.2` — `sfx.play("swing", -3.0, 0.8)` и `_haptic("heavy")`.
- [ ] BallTrail: лента из последних ~0.25 с позиций мяча, ImmediateMesh, unshaded, alpha
  к хвосту; цвет по типу последнего удара (топспин оранжевый, слайс/укороченный голубой,
  плоский/подача белый), ярче при PERFECT; гаснет, когда мяч припаркован.
- [ ] run_tests + input_test зелёные.

### Task 2a: Свеча (LOB) — добавлено по ходу

`ShotGesture.Type.LOB` (медленная дуга вверх), `main.lob_target`, `ShotType.LOB` через
`solve_lob`; тесты: жест (медленная дуга / быстрая дуга / медленная прямая) и физика
свечи над игроком у сетки. ✅

### Task 3: Навыки — кривая, статы, потолок 25, миграция

**Files:** Modify `scripts/skills.gd`, `scripts/save_data.gd` (после загрузки —
`Skills.rebuild_pending()`); Test `tests/run_tests.gd::test_skills`.

**Interfaces — Produces:** `Skills.MAX_LEVEL = 25`; `Skills.cost(n) = 12 × n^1.35`;
`Skills.k(lv: int) -> float = 1 − (1 − lv/25)^1.6`; `Skills.stroke(id, lv := -1)`;
`Skills.rebuild_pending()`; `Skills.headline(id, lv) -> String` (например «104 км/ч»).

- [ ] Тесты: cost(1)==12; сумма до 8 ≈ 780; потолок 25 и ~10 тыс. опыта; новичок: pace 0.70,
  scatter 1.8, window 0.55; k(25)==1; ранние уровни дают больше (k(5) > 0.3); перки 5 штук на
  пути к 25; `rebuild_pending` при xp с уровнем 25 и 1 взятым перком → 4 в очереди.
- [ ] Реализовать, существующие проверки на 30/100 обновить.

### Task 4: Выносливость

**Files:** Modify `scripts/skills.gd` (навык `stamina`, 6 перков, функции бака),
`scripts/main.gd` (константы, `_tired`, `_update_stamina`, `_spend_stroke`, отдых, опыт),
`scripts/hud.gd` (порог красных краёв, если зашит), `scripts/tournament_ui.gd` (7 навыков
в списке, если сетка на 6); Test `tests/run_tests.gd::test_stamina_tank`.

**Interfaces — Produces:** `Skills.stamina_drain() -> float` (множитель расхода / запас:
новичок 2.0, потолок 0.5); `Skills.stamina_rest(kind: String) -> float` (`"point"` 0.10→0.20,
`"change"` 0.30→0.45, `"set"` 0.50→0.70); `Skills.tired_below() -> float` (0.4, перк → 0.3).

- [ ] Тесты: спринт до нуля 15±1 с на уровне 0 и 60±3 с на 25 (интеграция
  `STAMINA_SPRINT × drain`); отдых между очками 0.10/0.20; перк «Холодный пот» → 0.3.
- [ ] main: `STAMINA_SPRINT 0.0333`, удар `0.003 + 0.003·pace`, прыжок 0.03 — всё × drain;
  «Ноги» больше не влияют на расход; отдых между очками разово в `_setup_serve`, без
  посекундного отдыха вне розыгрыша; усталость ниже порога: бег до −30%, окно до ×0.7,
  разброс до ×1.8, сила до ×0.85; на нуле бег ≤ 60%; опыт «Выносливости» 25 × потраченное
  (в конце очка, как «Ноги»).
- [ ] run_tests, input_test зелёные.

### Task 5: Ап виден числом

**Files:** Modify `scripts/main.gd::_gain_xp`.
- [ ] `«ФОРХЕНД 7 · 104 → 109 км/ч»` через `Skills.headline(id, lv-1)` и `(id, lv)`.
- [ ] Ручная проверка в автоплее (печать в лог).

### Task 6: Поза усталости

**Files:** Modify `scripts/athlete.gd` (`var tired := false`, вариант `_mode 0`), `scripts/main.gd`
(выставлять между очками при stamina < `tired_below()`); Test `tests/anim_test.gd`.
- [ ] Кисти у коленей, `_pitch` ≈ 0.5, в пределах `_human_hand/_human_elbow`.
- [ ] anim_test (55 проверок) зелёный.

### Task 7: Баланс, тексты, сборка

**Files:** `scripts/main.gd` (аргумент `--xp=N` для автоплея), `scripts/opponents.gd` (если
нужно), `scripts/tutorial.gd`, `README.md`, `docs/ROADMAP.md`, `build/web`.
- [ ] Бот-прогоны: новичок вылетает в 1–2 круге; `--xp=` трёх турниров — Джумхур ≥ 80%.
- [ ] Тексты обучения и README: новые жесты, выносливость, 7 навыков, потолок 25.
- [ ] Пересобрать `build/web`.

---

## Статус (2026-10-06): выполнено

Задачи 1–7 и 2a (свеча) сделаны; run_tests, input_test, anim_test (+ поза усталости на
трёх телах), audio_test зелёные. Баланс ботом (`--bot-sd=0.07`, формат «сет до 6»):
новичок 0/3 против Джумхура (вылет в 1-м круге); `--xp=800` (8-й уровень) — Джумхур 3/4,
доходит до 1/4–финала; `--xp=2000` (~12-й) — выигрывает турнир. Соперников не меняли.
Попутно: кружок-тень под игроками виден только при выключенных тенях графики.
Сборка: `build/web` (index.9fd5c3b028.pck), архив для сервера `dist/tennis-hostkey.zip`.
