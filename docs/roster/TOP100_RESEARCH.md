# Топ-100 теннисистов для TENNISISI — ресерч

Состояние на 05.10.2026, рейтинг ATP от **28.09.2026**. Это только ресерч: код игры не менялся.

Файлы рядом:
- `top100_players.json` / `top100_players.csv` — все 100 игроков со всеми полями (для будущего ростера и редактора);
- этот отчёт.

## 1. Главное

1. **Список и рейтинг** — реальный топ-100 ATP (одиночный разряд, мужчины). Он сохранён как есть: `rank` = место в рейтинге.
2. **Данные по каждому игроку** (рабочая рука, бэкхенд, рост, дата рождения) взяты из источников и сверены между собой (см. раздел 2). Внешность (кожа, причёска, борода, кепка/повязка) я смотрел **по фото** на 9 контактных листах, а не вспоминал из головы. Для 5 игроков фото найти не удалось, их внешность взята **из вашего описания** (`photo_confidence = user`).
3. **Важная находка по коду:** сейчас внешность соперника в игре **не применяется вообще**. Соперник создаётся один раз с фиксированным цветом (`main.gd:191`), а поле `shirt` из `opponents.gd` нигде не читается. Всё, что связано с редактором персонажей, придётся делать с нуля (раздел 3).
4. **Реальный топ-100 довольно однообразен** по внешности (раздел 5): 96 из 100 с тоном кожи 1–3, почти две трети с одинаковой «короткой аккуратной» причёской. Чтобы выборка выглядела разнообразной, одних реальных прототипов мало. Решение ниже.

## 2. Откуда данные и что проверено

| Что | Источник | Проверка |
|---|---|---|
| Список топ-100, возраст | [ATP Tour — рейтинг](https://www.atptour.com/en/rankings/singles?rankRange=1-100) | топ-20 совпадает с [Wikipedia — Current tennis rankings](https://en.wikipedia.org/wiki/Current_tennis_rankings) на 28.09.2026 |
| Левши | [Tennis Abstract — Lefthander rankings](https://tennisabstract.com/reports/leftyRankings.html) | 14 человек, **полностью совпадает** с полем `Plays` в Википедии |
| Одноручный бэкхенд | [Tennis Abstract — One-hand backhand](https://tennisabstract.com/reports/oneHandBackhandRankings.html) | 5 человек в топ-100, совпадает с Википедией и с [Baseline Rank](https://baselinerank.com/blog/atp-top-100-two-handed-backhand/) |
| Рост, дата рождения, рука, бэкхенд (все 100) | инфобокс статьи в Википедии (через API) | **возраст из Википедии сверен с возрастом ATP у всех 100**: расхождение нашлось у одного (Ковачевич, подтянулась статья однофамильца), исправлено |
| Рост топ-10 | [Baseline Rank — рост](https://baselinerank.com/blog/atp-top-100-height-analysis/) | совпал с Википедией; у Синнера в старой таблице [Tenniscompanion](https://tenniscompanion.org/players/male/height-and-weight/) 188, в актуальных источниках 191, взял 191 |
| Внешность | фото из статей Википедии | 95 из 100 есть (ещё 5 — со слов заказчика); **фото снимали в разные годы**, причёска и борода могут отличаться от сегодняшних |

Одну мою ошибку проверка поймала: я считал, что у Берреттини и Ханфмана одноручный бэкхенд, а по источникам (и по вашей поправке) у обоих **двуручный**. Одноручный сегодня у пятерых: Музетти (25), Циципас (44), Шаповалов (46), Альтмайер (67), Ковачевич (79).

Рост: у 14 игроков автоматический разбор не нашёл часть полей (другой формат записи в инфобоксе), я дозаполнил их по тем же статьям. У Фонсеки в Википедии 188 см (по ATP может быть чуть меньше), на классе роста это не скажется.

## 3. Что в игре сейчас (как устроен персонаж)

Смотрел `scripts/athlete.gd`, `opponents.gd`, `main.gd`.

- **Модель — процедурный риг** из капсул и сфер (`_build(shirt)`, `athlete.gd:1102`). Цвета кожи, шорт и волос вписаны константами (`skin`, `shorts`, `hair`), в `_build` передаётся только цвет майки. Голова: череп-сфера, «затылочные волосы», кепка с козырьком, глаза, нос.
- **Только правша.** Весь риг и все ключевые позы считаются «вправо» (в шапке файла: `Right-handed. Local space: forward = -Z, right = +X`). Левши нет вообще: нужна зеркальная модель либо переделка позиций ударов. Левшей в топ-100 — **14**, среди них Шелтон (4-й), Тьен (15-й), Шаповалов (46-й).
- **Бэкхенд — глобальная настройка игрока** (`Tuning.one_handed_bh`), у соперника `one_handed_backhand` не задаётся, то есть он всегда двуручный. Одноручников в топ-100 — **5**.
- **Внешность соперника не применяется:** `cpu.setup(1.0, Color(0.22, 0.28, 0.42), …)` вызывается один раз при старте (`main.gd:191`), а в `_play_match` (`main.gd:1653`) меняются только сила ИИ, подпись и ракетка. Поле `shirt` в `opponents.gd` пока мёртвое.
- **Сила соперника** — одно число `skill` 0..1 (сейчас от 0.0 у Джумхура до 0.85 у босса Джоковича).

Что из этого следует для работ:
1. Перестроить `_build` так, чтобы он принимал **словарь внешности** (это и есть «модерация/редактор»).
2. Сделать «перекрашиваемую» модель: менять материалы и сменные части (волосы, борода, кепка/повязка) без пересоздания всего узла.
3. Левша: зеркалить модель по X (`scale.x = -1` на корне `_model`) и отзеркалить логику «правой руки» в ИИ и в ударах. Это самое рискованное место: проверять тестами и покадровыми снимками `tools/pose_shots.gd`.
4. Одноручный бэкхенд: `one_handed_backhand` на Athlete уже есть, достаточно выставлять его из данных игрока.

## 4. Тиры

Вы писали «тир С, А, Б, Д, Е». Я понял это как **S, A, B, C, D, E** (S — топ, как Алькарас, Синнер, Джокович), а пропущенную букву C считаю опечаткой. Если нужны другие тиры, поменять легко: правило лежит в одной функции.

Предложенное распределение (ровно 100 игроков):

| Тир | Кто | Игроков | Предлагаемый `skill` ИИ |
|---|---|---|---|
| **S** | Синнер, Зверев, Алькарас + Джокович (11-й по рейтингу, но по классу S, как вы сказали) | 4 | 0.80–0.95 |
| **A** | места 4–15 без Джоковича | 11 | 0.65–0.80 |
| **B** | места 16–35 | 20 | 0.50–0.65 |
| **C** | места 36–60 | 25 | 0.35–0.50 |
| **D** | места 61–80 | 20 | 0.20–0.35 |
| **E** | места 81–100 | 20 | 0.00–0.20 |

Внутри тира `skill` растёт линейно от худшего места к лучшему. Проверьте два решения:
- **Зверев (2-й в рейтинге) в S.** Вы назвали в пример троих; по очкам он второй, поэтому я поставил его в S. Сейчас в игре у него 0.62 (это уровень A).
- **Старые значения `skill` придётся пересчитать.** Рублёв (24-й, тир B) стоит на 0.45. Джумхур и Басилашвили в топ-100 не входят (их можно оставить как «тир E−» для обучения).

Турнир из 5 матчей удобно собирать по тирам: матч 1 — E/D, матч 2 — D/C, матч 3 — C/B, матч 4 — B/A, босс — S. Тогда следующие уровни турниров (Клубный → Шлем) просто сдвигают окно.

## 5. Что есть в топ-100 (для настроек редактора)

| Параметр | Значения и сколько игроков |
|---|---|
| Рука | правая 86, **левая 14** |
| Бэкхенд | двуручный 95, **одноручный 5** |
| Рост | малый (<178) 6, средний (178–187) 44, высокий (188–195) 37, очень высокий (≥196) 13; диапазон 170–198 см |
| Кожа (1 очень светлая … 6 тёмная) | 1: 27, 2: 37, 3: 32, 4: 1, 5: 1, 6: 2 |
| Волосы: цвет | тёмно-каштановые 43, каштановые 15, светло-каштановые 14, чёрные 11, русые 7, рыжие 5, светлые 4, лысый 1 |
| Волосы: форма | короткая аккуратная 63, короткая растрёпанная 6, средняя волнистая 6, кудри крупные 5, кудри короткие 5, средняя зачёсанная 4, бритая 3, длинные распущенные 3, длинные собранные 2, «кроп» 2, лысый 1 |
| Борода | нет 53, щетина 23, короткая борода 13, полная борода 6, усы 5 |
| Головной убор | нет 45, кепка козырьком вперёд 27, кепка задом наперёд 15, повязка 13 |

**Вывод:** если делать строго по реальным прототипам, на корте всегда будет очень похожая публика (кожа 1–3, аккуратные короткие волосы). Чтобы получить разнообразие, о котором вы просили, предлагаю:
1. 100 персонажей — реальные прототипы (как в таблице ниже): это «лицо» каждого игрока, узнаваемое по приметам (повязка Рублёва, пучок Зверева, борода Берреттини, кепка Синнера).
2. Редактор шире реальности: 6 тонов кожи, 11–14 причёсок, 8 цветов волос, 5 видов бороды, 4 вида головных уборов, цвета формы. Он нужен и для вашего героя, и для генерации «любителей» (тир E и фоновые персонажи) с настоящим разнообразием.

## 6. Схема внешности для редактора (предложение)

Один словарь на игрока (так он уже лежит в JSON):

```
{ "hand": "R|L", "backhand": "1H|2H",
  "height_class": "small|medium|tall|very_tall", "body": "slim|regular|strong",
  "skin": 1..6,
  "hair_style": "bald|buzz|short_crop|short_neat|short_messy|medium_swept|medium_wavy|curls_short|curls_big|long_loose|long_tied",
  "hair_color": "black|dark_brown|brown|light_brown|dirty_blond|blond|ginger|none",
  "facial_hair": "none|stubble|moustache|short_beard|full_beard",
  "headwear": "none|cap_fwd:<цвет>|cap_back:<цвет>|headband:<цвет>",
  "kit": { "shirt": Color, "shorts": Color, "accent": Color } }
```

Цвет формы (`kit`) в данных пока **не заполнен**: в таблице есть только заметные детали с фото (цвет повязки и кепки). Палитру формы лучше назначить отдельным шагом (по флагу страны и фирменным цветам), чтобы 100 игроков не слились в белый.

## 7. Риски и вопросы

- **Узнаваемость и права.** Вы просили чуть изменить имена, я предложил черновые «пародийные» (колонка «В игре»). Но сама внешность (повязка, борода, причёска) тоже приближает персонажа к реальному человеку. Для коммерческого релиза в Telegram имеет смысл дополнительно «сместить» приметы (цвет формы, форма повязки) или проконсультироваться; это одна правка в данных. Реальные имена в игровые файлы я класть не собираюсь: они лежат только в этом ресерче (`real_name`).
- **5 игроков без фото** описаны вами: Блокс (28), Бузе (35), Мерида (42), Фариа (61), Ландалусе (73). У Блокса известны только рост и сильная подача, кожа и волосы стоят по умолчанию.
- **Фото из Википедии разных лет:** у молодых игроков (Jódar, Фонсека, Меншик, Ландалусе) причёска может уже отличаться.
- **Левши и одноручники влияют на баланс:** левша меняет привычные углы подачи и розыгрыша для игрока, это стоит учесть в ИИ.
- **Это только ростер.** Стили игры («стена», «подача 220», «тяжёлый форхенд») я здесь не размечал: из открытых источников надёжно берутся только рука и бэкхенд. Стили лучше задать вручную по 15–20 топ-игрокам, остальным — по тирам.

## 8. Следующие шаги («подготовка почвы»)

1. Вынести ростер в данные: `data/roster.json` (из `top100_players.json`, без реальных имён) и загрузчик вместо констант в `opponents.gd`.
2. Переделать `Athlete._build` под словарь внешности + метод `apply_look()` (перекраска и смена частей без пересоздания).
3. Сделать левшу (зеркало) и подключить `one_handed_backhand` к данным игрока; проверить `tools/pose_shots.gd` для всех ударов.
4. Сделать экран редактора персонажа и заполнить цвета формы.
5. Перестроить турнир на выбор соперников по тирам; пересчитать `skill`.
6. Прогнать `tests/run_tests.gd` и бот-матчи на нескольких внешностях.

## 9. Все 100 игроков

`В игре` — черновое имя. `Р/Б` — рука и бэкхенд (Л — левша, П — правша, 1H — одноручный). `Рост` в см. `Кожа` 1–6. `Фото`: есть, далеко (мелко на снимке) или «со слов» (описал заказчик).

| № | Тир | Реальное имя | В игре | Страна | Р/Б | Рост | Кожа | Волосы | Борода | Убор | Заметно | Фото |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | S | Jannik Sinner | Яник Сенер | ITA | П | 191 | 1 | short_neat/ginger | none | cap_fwd:white | orange-red polo; the red-haired Italian | есть |
| 2 | S | Alexander Zverev | Саша Зверов | GER | П | 198 | 2 | long_tied/dirty_blond | short_beard | headband:black | hair in a bun under a black headband | есть |
| 3 | S | Carlos Alcaraz | Карлито Алькораз | ESP | П | 183 | 3 | short_crop/dark_brown | none | none | textured quiff, muscular arms | есть |
| 4 | A | Ben Shelton | Бен Шелдон | USA | Л | 193 | 4 | curls_big/black | none | none | big curly hair, lefty, huge smile | есть |
| 5 | A | Felix Auger-Aliassime | Феликс Оже-Алиас | CAN | П | 193 | 6 | curls_short/black | none | none | tight short curls, tall and lean | есть |
| 6 | A | Daniil Medvedev | Данил Медведов | RUS | П | 198 | 1 | medium_swept/light_brown | stubble | none | swept-back hair, receding hairline, lanky | есть |
| 7 | A | Flavio Cobolli | Фабио Каболли | ITA | П | 183 | 3 | short_messy/brown | none | none | textured short hair, red-orange shirt | есть |
| 8 | A | Frances Tiafoe | Фрэнки Тиафу | USA | П | 188 | 6 | buzz/black | short_beard | headband:white | white headband, wristbands, necklace | есть |
| 9 | A | Arthur Fils | Артюр Филь | FRA | П | 185 | 5 | short_crop/black | stubble | none | black wristband/sleeve, colourful kit | есть |
| 10 | A | Alex de Minaur | Алекс де Минаро | AUS | П | 183 | 2 | short_neat/brown | none | none | side-swept brown hair, wiry | есть |
| 11 | S | Novak Djokovic | Новик Джокорич | SRB | П | 188 | 3 | short_neat/dark_brown | short_beard | none | swept short hair, trimmed greying beard | есть |
| 12 | A | Taylor Fritz | Тайлер Фрайц | USA | П | 196 | 2 | medium_swept/dirty_blond | stubble | headband:white | white headband, hair parted in the middle | есть |
| 13 | A | Rafael Jodar | Рафа Хордан | ESP | П | 191 | 3 | short_neat/brown | none | cap_fwd:navy | navy cap, slim | есть |
| 14 | A | Jakub Mensik | Якоб Мениш | CZE | П | 196 | 1 | short_neat/light_brown | none | cap_back:black | backwards black cap, very tall | есть |
| 15 | A | Learner Tien | Лерой Тайн | USA | Л | 180 | 3 | short_neat/black | none | cap_fwd:black | black cap, lefty | есть |
| 16 | B | Tommy Paul | Томми Полл | USA | П | 185 | 2 | short_neat/light_brown | none | none | neutral look (photo is far away) | далеко |
| 17 | B | Brandon Nakashima | Брэн Накасами | USA | П | 188 | 3 | short_messy/black | none | none | spiky black hair | есть |
| 18 | B | Valentin Vacherot | Валентен Вашерон | MON | П | 193 | 3 | medium_wavy/dark_brown | stubble | cap_fwd:white | white cap, dark wavy hair at the back | есть |
| 19 | B | Luciano Darderi | Лучиано Дардеро | ITA | П | 183 | 3 | short_neat/dark_brown | none | cap_fwd:white | white cap, orange-red shirt | есть |
| 20 | B | Alexander Bublik | Алекс Бубликс | KAZ | П | 196 | 1 | short_messy/light_brown | stubble | none | messy hair, lanky, chequered shirt | есть |
| 21 | B | Casper Ruud | Кас Руде | NOR | П | 183 | 2 | short_neat/light_brown | stubble | headband:white | white headband, green kit | есть |
| 22 | B | Francisco Cerundolo | Франко Серундо | ARG | П | 185 | 3 | short_neat/dark_brown | stubble | cap_back:black | backwards black cap, yellow wristband | есть |
| 23 | B | Jiri Lehecka | Иржи Лешека | CZE | П | 185 | 1 | short_neat/light_brown | none | none | pink shirt, clean look | есть |
| 24 | B | Andrey Rublev | Андрей Ребилёв | RUS | П | 188 | 1 | medium_wavy/ginger | stubble | headband:orange | orange headband, wavy strawberry-blond hair | есть |
| 25 | B | Lorenzo Musetti | Лоренцо Мазетти | ITA | П/1H | 185 | 2 | long_loose/dark_brown | none | cap_fwd:turquoise | ONE-HANDED backhand, long curls out of the cap | есть |
| 26 | B | Alejandro Davidovich Fokina | Алехандро Давидов Фокин | ESP | П | 180 | 2 | short_neat/blond | none | headband:white | white headband, yellow-green shirt | есть |
| 27 | B | Karen Khachanov | Карен Хачаров | RUS | П | 198 | 2 | short_messy/dark_brown | full_beard | none | dark full beard, broad and tall | есть |
| 28 | B | Alexander Blockx | Алекс Бокс | BEL | П | 193 | 2 | short_neat/brown | none | none | FROM USER: very tall, big serve; hair/skin not specified (defaults) | со слов |
| 29 | B | Joao Fonseca | Жуан Фонтека | BRA | П | 188 | 3 | medium_wavy/dark_brown | none | cap_fwd:white | white cap, dark wavy hair | есть |
| 30 | B | Tomas Martin Etcheverry | Томас Этчеверро | ARG | П | 196 | 3 | short_neat/brown | stubble | headband:white | white headband, light-blue shirt, tall | есть |
| 31 | B | Alejandro Tabilo | Алехо Табело | CHI | Л | 188 | 3 | short_neat/dark_brown | none | cap_fwd:white | white cap, lefty, tattoo on forearm | есть |
| 32 | B | Ugo Humbert | Юго Хумбер | FRA | Л | 188 | 2 | curls_short/dark_brown | none | none | short dark curls, lefty | есть |
| 33 | B | Arthur Rinderknech | Артюр Ринделькнеш | FRA | П | 196 | 2 | short_neat/dark_brown | moustache | headband:black | black headband, green shirt, very tall | есть |
| 34 | B | Alex Michelsen | Алекс Микельсен | USA | П | 193 | 1 | curls_big/ginger | none | none | big messy ginger-blond curls | есть |
| 35 | B | Ignacio Buse | Игнасио Буссе | PER | П | 183 | 2 | long_loose/ginger | none | none | FROM USER: red-haired, long hair | со слов |
| 36 | C | Arthur Fery | Артюр Ферри | GBR | П | 175 | 1 | short_neat/dark_brown | none | cap_back:white | backwards white cap, small | есть |
| 37 | C | Matteo Arnaldi | Маттео Арнальдо | ITA | П | 185 | 2 | short_neat/dark_brown | stubble | cap_fwd:white | white cap, blue shirt | есть |
| 38 | C | Zizou Bergs | Зизу Берг | BEL | П | 185 | 1 | short_neat/dirty_blond | none | cap_back:white | pale, light cap on backwards, floral shirt | есть |
| 39 | C | Hubert Hurkacz | Хуберт Гуркош | POL | П | 196 | 1 | short_neat/brown | none | none | black arm sleeve, wristbands, tall and slim | есть |
| 40 | C | Cameron Norrie | Кэмерон Норрис | GBR | Л | 188 | 1 | short_messy/brown | short_beard | none | lefty, short brown beard, grey shirt | есть |
| 41 | C | Botic van de Zandschulp | Ботик ван дер Зандшульп | NED | П | 191 | 1 | short_neat/light_brown | none | cap_fwd:white | white cap, light-blue shirt | есть |
| 42 | C | Daniel Merida | Даниэль Мариде | ESP | П | 188 | 3 | short_neat/black | none | none | FROM USER: Spaniard, dark (black hair, tan skin) | со слов |
| 43 | C | Luca Van Assche | Люк Ван Аш | FRA | П | 178 | 1 | curls_big/ginger | none | none | curly ginger-brown mop, small | есть |
| 44 | C | Stefanos Tsitsipas | Стефанос Цицинас | GRE | П/1H | 193 | 2 | long_loose/brown | short_beard | headband:black | ONE-HANDED backhand, long wavy hair, black headband | есть |
| 45 | C | Mariano Navone | Мариано Новоне | ARG | П | 178 | 3 | short_neat/dark_brown | short_beard | none | short beard, compact | далеко |
| 46 | C | Denis Shapovalov | Денис Шаповалин | CAN | Л/1H | 185 | 2 | short_messy/dirty_blond | stubble | headband:white | ONE-HANDED backhand, lefty, white headband | есть |
| 47 | C | Matteo Berrettini | Маттео Бернеттини | ITA | П | 196 | 3 | short_neat/dark_brown | full_beard | cap_back:black | big thick dark beard, backwards black cap, broad | есть |
| 48 | C | Raphael Collignon | Рафаэль Колиньи | BEL | П | 191 | 2 | short_neat/brown | none | cap_back:white | backwards white cap, all-white kit | есть |
| 49 | C | Nuno Borges | Нуно Борхес | POR | П | 185 | 3 | short_neat/dark_brown | stubble | cap_fwd:white | white cap, dark shirt | есть |
| 50 | C | Quentin Halys | Кентен Элис | FRA | П | 191 | 2 | short_neat/dark_brown | short_beard | cap_fwd:white | white cap, orange shirt | есть |
| 51 | C | Sebastian Baez | Себастьян Бааз | ARG | П | 170 | 3 | short_neat/black | none | cap_back:black | backwards black cap, blue shirt, very small | есть |
| 52 | C | Thiago Agustin Tirante | Тьяго Тиранто | ARG | П | 185 | 3 | short_neat/dark_brown | moustache | cap_back:black | backwards black cap, dark shirt | есть |
| 53 | C | Juan Manuel Cerundolo | Хуан Мануэль Сурундо | ARG | Л | 183 | 3 | curls_short/dark_brown | none | none | lefty, short dark curls, pink shirt | есть |
| 54 | C | Yannick Hanfmann | Яннис Ханфельд | GER | П | 193 | 1 | short_neat/light_brown | none | none | yellow-white shirt, tall | есть |
| 55 | C | Tallon Griekspoor | Таллон Грейкспур | NED | П | 188 | 1 | short_neat/light_brown | stubble | cap_back:white | backwards white cap, white arm sleeve, light-blue shirt | есть |
| 56 | C | Adolfo Daniel Vallejo | Адольфо Вальехос | PAR | П | 185 | 3 | curls_big/black | none | none | thick black curls | есть |
| 57 | C | Miomir Kecmanovic | Миомир Кецманов | SRB | П | 183 | 2 | short_neat/brown | moustache | none | navy shirt, light moustache | есть |
| 58 | C | Arthur Gea | Артур Жеан | FRA | П | 180 | 2 | buzz/dark_brown | short_beard | none | short beard, white polo | есть |
| 59 | C | Jan-Lennard Struff | Ян-Ленни Штруфф | GER | П | 193 | 1 | short_neat/dirty_blond | stubble | cap_fwd:white | white cap, green-teal shirt, tall | есть |
| 60 | C | Roman Andres Burruchaga | Роман Бурручета | ARG | П | 183 | 3 | curls_short/dark_brown | stubble | none | short curls, red Yonex bag | есть |
| 61 | D | Jaime Faria | Жайме Фарьо | POR | П | 188 | 3 | short_neat/black | short_beard | none | FROM USER: Portuguese, dark, with a beard | со слов |
| 62 | D | Fabian Marozsan | Фабиан Марошан | HUN | П | 193 | 2 | short_neat/dark_brown | none | none | slicked-back wet-look hair, maroon shirt, tall | есть |
| 63 | D | James Duckworth | Джеймс Дакворс | AUS | П | 183 | 1 | short_neat/brown | none | cap_fwd:white | white cap, grey shirt | есть |
| 64 | D | Jaume Munar | Жауме Мунер | ESP | П | 183 | 3 | short_neat/dark_brown | none | cap_fwd:white | white cap, blue shirt | есть |
| 65 | D | Ethan Quinn | Итан Квин | USA | П | 190 | 1 | short_neat/blond | none | cap_fwd:white | white cap, lilac shirt, red wristband | есть |
| 66 | D | Pablo Carreno Busta | Пабло Карреньо Бустос | ESP | П | 188 | 3 | curls_short/dark_brown | stubble | none | short curls, blue-navy shirt | есть |
| 67 | D | Daniel Altmaier | Даниэль Альтмейр | GER | П/1H | 188 | 2 | short_neat/dark_brown | none | cap_fwd:white | ONE-HANDED backhand, white cap, green shirt | есть |
| 68 | D | Vit Kopriva | Вит Копршива | CZE | П | 178 | 2 | short_neat/light_brown | stubble | none | all-white kit | есть |
| 69 | D | Facundo Diaz Acosta | Факундо Диас Акосто | ARG | Л | 183 | 3 | short_neat/dark_brown | short_beard | cap_fwd:dark | lefty, dark cap, short beard | далеко |
| 70 | D | Corentin Moutet | Корентен Мутен | FRA | Л | 180 | 2 | short_neat/light_brown | full_beard | cap_fwd:white | lefty, full ginger-brown beard, white cap | есть |
| 71 | D | Kamil Majchrzak | Камиль Майхржак | POL | П | 183 | 2 | short_neat/dark_brown | none | cap_fwd:black | black cap, white-black shirt | есть |
| 72 | D | Titouan Droguet | Титуан Дроге | FRA | П | 191 | 3 | medium_wavy/dark_brown | full_beard | cap_back:white | white cap backwards, full dark beard | есть |
| 73 | D | Martin Landaluce | Мартин Ландалуз | ESP | П | 193 | 1 | short_neat/blond | none | none | FROM USER: fair-skinned Spaniard, white-blond hair | со слов |
| 74 | D | Sebastian Korda | Себастьян Кордо | USA | П | 196 | 1 | medium_wavy/dirty_blond | none | none | wavy blond hair, gold chain, very tall | есть |
| 75 | D | Tomas Machac | Томаш Мохач | CZE | П | 183 | 2 | short_neat/dark_brown | full_beard | cap_back:white | white cap backwards, thick beard, white towel | есть |
| 76 | D | Camilo Ugo Carabelli | Камило Уго Карабеллис | ARG | П | 185 | 3 | buzz/dark_brown | none | none | arm tattoos, dark navy shirt | есть |
| 77 | D | Hamad Medjedovic | Хамад Медждович | SRB | П | 188 | 2 | short_neat/dark_brown | none | none | white polo, black shorts | есть |
| 78 | D | Marin Cilic | Марин Чилан | CRO | П | 198 | 3 | short_neat/dark_brown | stubble | none | dark stubble, blue head kit, tall | есть |
| 79 | D | Aleksandar Kovacevic | Александар Коваль | USA | П/1H | 183 | 1 | medium_swept/light_brown | none | cap_back:white | ONE-HANDED backhand, white cap backwards, red shirt | есть |
| 80 | D | Zachary Svajda | Закари Свейда | USA | П | 175 | 1 | short_neat/light_brown | moustache | none | thin moustache, small, black-white shirt | есть |
| 81 | E | Adrian Mannarino | Адриан Манарино | FRA | Л | 180 | 1 | bald/none | short_beard | none | lefty, bald, short grey-blond beard | есть |
| 82 | E | Rinky Hijikata | Ринки Хиджиката | AUS | П | 178 | 3 | short_neat/black | none | none | red-navy shirt, towel | есть |
| 83 | E | Lorenzo Sonego | Лоренцо Соньего | ITA | П | 191 | 2 | short_neat/dark_brown | stubble | headband:lime | lime-yellow headband, turquoise shirt | есть |
| 84 | E | Roman Safiullin | Роман Сафиулов | RUS | П | 185 | 2 | short_neat/dark_brown | short_beard | none | short beard, white shirt | есть |
| 85 | E | Marcos Giron | Маркос Гирон | USA | П | 180 | 3 | short_neat/dark_brown | stubble | cap_fwd:white | white cap, navy shirt | есть |
| 86 | E | Kyrian Jacquet | Кирьян Жаке | FRA | П | 175 | 2 | short_neat/light_brown | stubble | cap_fwd:white | white cap, light-blue shirt, arm tattoos | есть |
| 87 | E | Hugo Gaston | Юг Гастен | FRA | Л | 173 | 2 | short_neat/brown | short_beard | none | lefty, small, black patterned shirt | есть |
| 88 | E | Marco Trungelliti | Марко Трунгелли | ARG | П | 178 | 2 | long_loose/dark_brown | full_beard | cap_fwd:white | long wavy hair out of a white cap, full beard | есть |
| 89 | E | Jan Choinski | Ян Хойнцки | GBR | П | 196 | 1 | short_neat/blond | none | cap_fwd:blue | blue cap, very tall | есть |
| 90 | E | Benjamin Bonzi | Бенжамен Бонци | FRA | П | 183 | 2 | short_neat/dark_brown | stubble | cap_fwd:white | white cap, lime-yellow shirt | есть |
| 91 | E | Mattia Bellucci | Маттиа Белуччо | ITA | Л | 175 | 3 | long_tied/dark_brown | none | headband:blue | lefty, long hair tied back, blue headband | есть |
| 92 | E | Michael Zheng | Майкл Джен | USA | П | 188 | 3 | short_neat/black | none | none | black hair, floral shirt | есть |
| 93 | E | Jesper de Jong | Йеспер де Йонк | NED | П | 180 | 1 | short_neat/blond | none | cap_fwd:white | white cap, all-white kit | есть |
| 94 | E | Jacob Fearnley | Джейкоб Фирнли | GBR | П | 183 | 2 | short_neat/dark_brown | short_beard | cap_fwd:white | white cap, dark short beard, all-white kit | есть |
| 95 | E | Dino Prizmic | Дино Прижмич | CRO | П | 188 | 2 | short_neat/brown | none | none | blue-grey shirt, navy shorts | далеко |
| 96 | E | Alex Molcan | Алекс Мольчан | SVK | Л | 178 | 2 | short_neat/dark_brown | stubble | headband:black | lefty, black headband, arm tattoos, speckled shirt | есть |
| 97 | E | Adam Walton | Адам Уолтен | AUS | П | 183 | 1 | medium_swept/dirty_blond | none | cap_back:white | white cap backwards, blond hair out of it | есть |
| 98 | E | Toby Samuel | Тоби Самуэль | GBR | П | 191 | 1 | medium_wavy/ginger | none | cap_back:white | white cap backwards, wavy ginger-brown hair, tall | есть |
| 99 | E | Terence Atmane | Теранс Атман | FRA | Л | 193 | 1 | short_neat/brown | moustache | cap_back:blue | lefty, blue cap backwards, light moustache, tall | есть |
| 100 | E | Coleman Wong | Колман Ванг | HKG | П | 191 | 3 | curls_big/black | none | none | curly dark messy hair, black Nike kit, tall | есть |

## 8. Ростер в игре (D-8, 08.10.2026)

- `tools/gen_roster_data.py` читает `top100_players.json` и пишет `scripts/roster_data.gd`: **только игровые
  имена** (`game_name`), страна, тир, рука (метка: риг праворукий), бэкхенд, класс роста и внешность уже в
  индексах `Looks`. Реальные имена в игру не попадают. Правишь JSON, запускаешь скрипт.
- `Opponents.roster()` — пятеро именных (Джумхур, Басилашвили, Рублёв, Зверев, Джокович: обучение и босс) и
  100 игроков `p001…p100`. Навык (`skill`) идёт по полосам тиров из раздела 4 (лучшее место тира сильнее
  всех в нём), статы 1–10 и стиль придуманы по рангу один раз и всегда те же. Двойники именных (места 2, 11,
  24: «Зверов», «Джокорич», «Ребилёв») помечены `alias_of` и в жеребьёвку не попадают.
- `Opponents.random(seed, tier, opts)` — случайный теннисист (имя из пулов стран, статы по тиру с разбросом,
  стиль, внешность); 3 % «монстров»; `opts.weakness` — явная слабина для карточки.
- `Opponents.draw(остров, seed)` — сетка: Нью-Йорк E/D, Испания D/C, Англия C/B/A, Париж B/A/S, финал —
  именной Джокович; около 30 % мест у случайных.
