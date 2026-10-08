class_name Items
## The unique items of a run (v0.2): 25 rackets, shoes and wristbands described as data,
## see ROGUELIKE_DESIGN 6 and the v0.2 spec 3.3. Commons and rares also come from the
## affix generator (Gear); epic and up are always one of these, and always do something
## besides stats. No ball tags yet (fire, ice, weight come with patch 2a).
##
## An entry: id, slot, rarity, name, desc (the effect in words) and any of
##   mods       stat mods while worn (Skills keys; "all_window" / "all_pace" expand)
##   style      StyleRules boosts {trick: x, "all": x}
##   rules      {"cannon_kmh": 190, "dive_free": 1, "run_dmg": 1.3, "second_wind": 1}
##   cond_mods  [{"if": {"tiebreak": true}, "mods": {...}}]
##   triggers   [{"on": event, "if": {...}, "do": [[primitive, args...]]}]  (RunEffects)
##   skin       how it looks on the player (AthleteGear, spec 2026-10-08-v02-gear-skins):
##              racket {frame, tube, color, accent, grip, wrap, strings, pattern, halo},
##              shoes {body, sole, stripe, pattern}, band {color, second, pattern}
## A saved item keeps id, slot, rarity, name, mods and lines; the rest is read from here.
##
## Economy (v0.2 A, spec 2026-10-08-v02-A-economy): every item has a buy price by rarity
## and level, and sells for a third of it. The level (field "level", none = 1) makes the
## stats stronger: mods = (base + strings) x (1 + LEVEL_POWER x (level - 1)), where "base"
## are the item's own stats and "strings" the extra line the shop's restringing rolls.

const BUY := [15, 45, 120, 360, 1200]   # buy price by rarity, level 1 (mythic: only for selling and insurance)
static var PRICE_SCALE := 2.4                # one knob to rebalance every price (items, strings, insurance, rerolls); 2.4 with income x0.5
const LEVEL_PRICE := 0.15               # +15% price a level
const LEVEL_POWER := 0.10               # +10% stats a level
const SELL_SHARE := 1.0 / 3.0

const STROKES := ["forehand", "backhand", "serve", "net", "touch"]

const LIST := [
	# --- Rackets
	{"id": "heavy_frame", "slot": "racket", "rarity": 1, "name": "Тяжёлая рама",
		"skin": {"frame": "wide", "tube": 1.4, "color": "#4a5160", "accent": "#2f6fe0", "grip": "#16161a", "wrap": "#3b3f48", "strings": "#e6eaf0"},
		"desc": "+10% силы справа и слева, −10% окна PERFECT",
		"mods": {"forehand_pace": 0.10, "backhand_pace": 0.10, "forehand_window": -0.10, "backhand_window": -0.10}},
	{"id": "knife_string", "slot": "racket", "rarity": 1, "name": "Струна-нож",
		"skin": {"frame": "slim", "tube": 0.8, "color": "#c9d1db", "accent": "#3fd0ff", "grip": "#f4f6f8", "wrap": "#3fa0ff", "strings": "#bfe8ff", "pattern": "stripe"},
		"desc": "Вращение резаного +20%. «Слайс-нож» ×1.5",
		"mods": {"touch_spin": 0.20}, "style": {"knife": 1.5}},
	{"id": "cannon_frame", "slot": "racket", "rarity": 1, "name": "Пушечная рама",
		"skin": {"frame": "round", "tube": 1.35, "color": "#7a6038", "accent": "#e0a83a", "grip": "#5a3a22", "wrap": "#3a2414", "strings": "#f0e6cc", "pattern": "twotone"},
		"desc": "Подача +8%. «Пушка» уже с 190 км/ч",
		"mods": {"serve_pace": 0.08}, "rules": {"cannon_kmh": 190.0}},
	{"id": "twister", "slot": "racket", "rarity": 2, "name": "Выкрутас",
		"skin": {"frame": "teardrop", "color": "#7b3fd1", "accent": "#a6e22e", "grip": "#a6e22e", "wrap": "#5a2a9a", "strings": "#e8ffc0", "pattern": "spiral"},
		"desc": "Вращение справа и слева +15%. «Выкрут» ×2",
		"mods": {"forehand_spin": 0.15, "backhand_spin": 0.15}, "style": {"curl": 2.0}},
	{"id": "sledgehammer", "slot": "racket", "rarity": 2, "name": "Кувалда",
		"skin": {"frame": "square", "tube": 1.45, "color": "#3b3f47", "accent": "#b5562a", "grip": "#141414", "wrap": "#c0302a", "strings": "#d8d8d0", "pattern": "twotone"},
		"desc": "Каждый 4-й удар розыгрыша: −8 выносливости соперника",
		"triggers": [{"on": "on_hit", "if": {"every_n": 4}, "do": [["opp_stamina", 8.0]]}]},
	{"id": "lightning_rod", "slot": "racket", "rarity": 2, "name": "Громоотвод",
		"skin": {"frame": "slim", "color": "#1b2a5c", "accent": "#ffe14a", "grip": "#ffe14a", "wrap": "#141414", "strings": "#fff6c0", "pattern": "segments"},
		"desc": "Эйс: −20 выносливости соперника",
		"triggers": [{"on": "on_ace", "do": [["opp_stamina", 20.0]]}]},
	{"id": "feather", "slot": "racket", "rarity": 2, "name": "Перо",
		"skin": {"frame": "round", "tube": 0.8, "color": "#f2f0ea", "accent": "#cbb6ff", "grip": "#bfe0ff", "wrap": "#ffffff", "strings": "#ffffff"},
		"desc": "Окно PERFECT на касании +15%. «Мёртвый мяч» ×2",
		"mods": {"touch_window": 0.15}, "style": {"dead_ball": 2.0}},
	{"id": "cutter", "slot": "racket", "rarity": 3, "name": "Резак",
		"skin": {"frame": "slim", "color": "#2e8f8a", "accent": "#ff8a2a", "grip": "#16403e", "wrap": "#ff8a2a", "strings": "#e0fff8", "pattern": "edge", "halo": "flames"},
		"desc": "Вращение резаного +40%. Победный слайс: −25 выносливости соперника",
		"mods": {"touch_spin": 0.40},
		"triggers": [{"on": "on_point_won", "if": {"type": "SLICE", "reason": "WINNER"}, "do": [["opp_stamina", 25.0]]}]},
	{"id": "thunderer", "slot": "racket", "rarity": 3, "name": "Громовержец",
		"skin": {"frame": "wide", "tube": 1.2, "color": "#1a1a1f", "accent": "#f2b632", "grip": "#1a1a1f", "wrap": "#f2b632", "strings": "#fff0c0", "pattern": "veins", "halo": "bolts"},
		"desc": "Смэш: −30 выносливости соперника. «Молот» ×2",
		"style": {"smash": 2.0},
		"triggers": [{"on": "on_hit", "if": {"type": "SMASH"}, "do": [["opp_stamina", 30.0]]}]},
	{"id": "sun", "slot": "racket", "rarity": 4, "name": "Солнце",
		"skin": {"frame": "round", "tube": 1.15, "color": "#2a0b08", "accent": "#ff3a1a", "grip": "#ffb020", "wrap": "#c01810", "strings": "#ffd8b0", "pattern": "core", "halo": "rays"},
		"desc": "Каждый PERFECT: −6 выносливости соперника. Третий PERFECT подряд — «Метеор»: −30 и стиль очка ×2",
		"triggers": [
			{"on": "on_perfect", "do": [["opp_stamina", 6.0]]},
			{"on": "on_perfect", "if": {"streak": 3}, "do": [["opp_stamina", 30.0], ["point_style", 2.0]]},
		]},
	# --- Shoes
	{"id": "runners", "slot": "shoes", "rarity": 0, "name": "Беговые",
		"skin": {"body": "#d9dce1", "sole": "#ffffff", "stripe": "#8b9099", "pattern": "stripe"},
		"desc": "+4% к скорости бега", "mods": {"run_speed": 0.04}},
	{"id": "spikes", "slot": "shoes", "rarity": 1, "name": "Шипы",
		"skin": {"body": "#1a1a1e", "sole": "#ff8a2a", "stripe": "#2f6fe0", "pattern": "toe"},
		"desc": "+4% к скорости бега, штраф за удар на бегу −20%",
		"mods": {"run_speed": 0.04, "move_penalty": -0.20}},
	{"id": "marathoners", "slot": "shoes", "rarity": 1, "name": "Марафонки",
		"skin": {"body": "#1b2a5c", "sole": "#ffffff", "stripe": "#3fa0ff", "pattern": "two"},
		"desc": "Расход выносливости −15%", "mods": {"stamina_drain": -0.15}},
	{"id": "springs", "slot": "shoes", "rarity": 2, "name": "Пружины",
		"skin": {"body": "#a6e22e", "sole": "#7b3fd1", "stripe": "#7b3fd1", "pattern": "zigzag"},
		"desc": "Прыжок за мячом не тратит выносливость. «В прыжке» ×2.5",
		"rules": {"dive_free": 1.0}, "style": {"dive": 2.5}},
	{"id": "heavy_steps", "slot": "shoes", "rarity": 2, "name": "Тяжёлые шаги",
		"skin": {"body": "#6b5f55", "sole": "#141414", "stripe": "#b5562a", "pattern": "heel"},
		"desc": "Соперник теряет на 30% больше выносливости от бега",
		"rules": {"run_dmg": 1.3}},
	{"id": "ghost_sneakers", "slot": "shoes", "rarity": 3, "name": "Кеды Призрака",
		"skin": {"body": "#e6f4ff", "sole": "#7ccfff", "stripe": "#ffffff", "pattern": "gradient"},
		"desc": "PERFECT возвращает 4% твоей выносливости",
		"triggers": [{"on": "on_perfect", "do": [["self_stamina", 0.04]]}]},
	{"id": "second_wind", "slot": "shoes", "rarity": 4, "name": "Второе дыхание",
		"skin": {"body": "#ffffff", "sole": "#ff2a1a", "stripe": "#ff2a1a", "pattern": "wind"},
		"desc": "На смене сторон твоя выносливость — 100%, а соперник не отдыхает",
		"rules": {"second_wind": 1.0}},
	# --- Wristbands
	{"id": "terry_band", "slot": "band", "rarity": 0, "name": "Махровый",
		"skin": {"color": "#ffffff"},
		"desc": "+6% к окну PERFECT всех ударов", "mods": {"all_window": 0.06}},
	{"id": "server_band", "slot": "band", "rarity": 1, "name": "Подающий",
		"skin": {"color": "#2f6fe0", "second": "#ffffff", "pattern": "stripe"},
		"desc": "Подача +5%, окно PERFECT на подаче +15%",
		"mods": {"serve_pace": 0.05, "serve_window": 0.15}},
	{"id": "ace_counter", "slot": "band", "rarity": 1, "name": "Счётчик эйсов",
		"skin": {"color": "#ffd23a", "second": "#141414", "pattern": "dots"},
		"desc": "Эйс: +5 золота забега",
		"triggers": [{"on": "on_ace", "do": [["money", 5]]}]},
	{"id": "lucky_coin", "slot": "band", "rarity": 1, "name": "Счастливая монетка",
		"skin": {"color": "#2ea84a", "second": "#f2c04a", "pattern": "edges"},
		"desc": "Очко с трюком: +1 золото забега",
		"triggers": [{"on": "on_point_won", "if": {"tricks": true}, "do": [["money", 1]]}]},
	{"id": "cold_pack", "slot": "band", "rarity": 2, "name": "Холодный компресс",
		"skin": {"color": "#9fe0ff", "second": "#ffffff", "pattern": "stripes"},
		"desc": "На тай-брейке окно PERFECT +25%",
		"cond_mods": [{"if": {"tiebreak": true}, "mods": {"all_window": 0.25}}]},
	{"id": "berserk", "slot": "band", "rarity": 3, "name": "Берсерк",
		"skin": {"color": "#b0121a", "second": "#141414", "pattern": "zigzag"},
		"desc": "Каждый удар розыгрыша +3% силы (до конца очка)",
		"triggers": [{"on": "on_hit", "do": [["temp_mod", "all_pace", 0.03]]}]},
	{"id": "crown", "slot": "band", "rarity": 3, "name": "Корона",
		"skin": {"color": "#f2c04a", "second": "#7b3fd1", "pattern": "crown"},
		"desc": "Каждый твой брейк: +2% ко всем ударам и бегу до конца турнира",
		"triggers": [{"on": "on_break", "do": [["run_mod", "all", 0.02]]}]},
	{"id": "golden_hand", "slot": "band", "rarity": 4, "name": "Золотая рука",
		"skin": {"color": "#f2b632", "second": "#e02a1a", "pattern": "stripe"},
		"desc": "Все множители стиля ×1.5", "style": {"all": 1.5}},
]


static func find(id: String) -> Dictionary:
	for e in LIST:
		if e["id"] == id:
			return e
	return {}


static func pool(slot: String, rarity: int) -> Array:
	return LIST.filter(func(e): return e["slot"] == slot and int(e["rarity"]) == rarity)


## A random catalog item of this slot and rarity ({} if there is none).
static func roll(slot: String, rarity: int, rng: RandomNumberGenerator) -> Dictionary:
	var p := pool(slot, rarity)
	if p.is_empty():
		return {}
	return instance(p[rng.randi_range(0, p.size() - 1)])


## The item as the run keeps it (and saves it). An epic or better also carries its slot's
## plain stat package (PACKAGE) next to its own effect.
static func instance(e: Dictionary) -> Dictionary:
	var mods := expand(e.get("mods", {}))
	var lines: Array = [String(e["desc"])]
	var pk := package(String(e["slot"]), int(e["rarity"]))
	for k in pk["mods"]:
		mods[k] = float(mods.get(k, 0.0)) + float(pk["mods"][k])
	if pk["line"] != "":
		lines.append(pk["line"])
	return {"id": e["id"], "slot": e["slot"], "rarity": int(e["rarity"]), "name": e["name"],
		"mods": mods, "lines": lines}


## v0.2 A-6: the direct stats every epic+ item has (the unique effect stays on top): a
## racket hits harder and truer, shoes run faster and spare breath, a wristband widens the
## PERFECT windows. Base values of an epic; a legendary and a mythic get PACKAGE_RARITY x.
## PACKAGE_SCALE is the tuning knob (tools/power_bot.sh measures what it does).
const PACKAGE := {
	"racket": {"all_pace": 0.06, "serve_pace": 0.05, "all_scatter": -0.12},
	"shoes": {"run_speed": 0.04, "stamina_drain": -0.10, "move_penalty": -0.15},
	"band": {"all_window": 0.12},
}
const PACKAGE_RARITY := [0.0, 0.0, 1.0, 1.7, 2.3]
static var PACKAGE_SCALE := 1.45


static func package(slot: String, rarity: int) -> Dictionary:
	var k: float = float(PACKAGE_RARITY[clampi(rarity, 0, 4)]) * PACKAGE_SCALE
	if k <= 0.0 or not PACKAGE.has(slot):
		return {"mods": {}, "line": ""}
	var raw: Dictionary = PACKAGE[slot]
	var scaled := {}
	for key in raw:
		scaled[key] = snappedf(float(raw[key]) * k, 0.01)
	var text := ""
	match slot:
		"racket":
			text = "Класс: +%d%% силы, −%d%% разброса" % [roundi(float(scaled["all_pace"]) * 100.0), roundi(-float(scaled["all_scatter"]) * 100.0)]
		"shoes":
			text = "Класс: +%d%% бега, −%d%% расхода выносливости" % [roundi(float(scaled["run_speed"]) * 100.0), roundi(-float(scaled["stamina_drain"]) * 100.0)]
		"band":
			text = "Класс: +%d%% к окну PERFECT" % roundi(float(scaled["all_window"]) * 100.0)
	return {"mods": expand(scaled), "line": text}


## "all_window" / "all_pace" / "all" -> the keys of every stroke (and running for "all").
static func expand(mods: Dictionary) -> Dictionary:
	var out := {}
	for k in mods:
		var keys: Array = [k]
		match k:
			"all_window":
				keys = STROKES.map(func(s): return s + "_window")
			"all_pace":
				keys = STROKES.filter(func(s): return s != "serve").map(func(s): return s + "_pace")
			"all_scatter":
				keys = STROKES.map(func(s): return s + "_scatter")
			"all":
				keys = STROKES.map(func(s): return s + "_window") + STROKES.map(func(s): return s + "_pace") + ["run_speed"]
		for key in keys:
			out[key] = float(out.get(key, 0.0)) + float(mods[k])
	return out


## The card's text: the item's own lines, its strings, its level.
static func describe(item: Dictionary) -> String:
	var out: Array = item.get("lines", []).duplicate()
	for l in item.get("strings", {}).get("lines", []):
		out.append("Струны: " + String(l))
	if level(item) > 1:
		out.append("Уровень %d: статы +%d%%" % [level(item), roundi(LEVEL_POWER * (level(item) - 1) * 100.0)])
	return "\n".join(out)


# --- Economy ------------------------------------------------------------------------

static func level(item: Dictionary) -> int:
	return maxi(1, int(item.get("level", 1)))


## What the item costs in the shop (and what selling and the locker's insurance count from).
static func price(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	var r := clampi(int(item.get("rarity", 0)), 0, BUY.size() - 1)
	return roundi(BUY[r] * (1.0 + LEVEL_PRICE * (level(item) - 1)) * PRICE_SCALE)


static func sell_price(item: Dictionary) -> int:
	return roundi(price(item) * SELL_SHARE)


## The item at this level: its stats recounted from the base (levels never stack).
static func set_level(item: Dictionary, lv: int) -> Dictionary:
	if not item.has("base"):
		item["base"] = item.get("mods", {}).duplicate()
	if lv > 1:
		item["level"] = lv
	else:
		item.erase("level")
	refresh(item)
	return item


## mods = (base + strings) x the level's power.
static func refresh(item: Dictionary) -> void:
	if not item.has("base"):
		item["base"] = item.get("mods", {}).duplicate()
	var k := 1.0 + LEVEL_POWER * (level(item) - 1)
	var mods := {}
	for src in [item["base"], item.get("strings", {}).get("mods", {})]:
		for key in src:
			mods[key] = float(mods.get(key, 0.0)) + float(src[key])
	for key in mods:
		mods[key] = float(mods[key]) * k
	item["mods"] = mods
