class_name ClubLots
extends RefCounted
## The club as a tycoon (docs/superpowers/specs/2026-10-09-tycoon.md 1): empty LOTS on the
## map where the player chooses what to build. A lot holds any one of seven TYPES of
## building and every type is built once, on one lot; the court, the shop and the gate
## do not stand on lots. Data only (like ClubPlaces): move a lot, change when it opens or
## what a type gives here.
##
## Saved in SaveData.club["lots"] = {lot id: type id}. A save without the key is either
## new (an empty club: the court and the shop) or old (it has progress: every building
## that was open stands on its home lot, as it always did) - see is_legacy / map.
##
## A building keeps being drawn around its HOME (the place it had before lots, in
## ClubPlaces.LIST); on a lot it is moved there by one transform, xf(): the offset from home
## to the lot, and - for the stands - a quarter turn so they face the court.

## Lots. unlock: "" (from the start), "played:N" (N finished runs), "titles:N".
## The centre is the lot's circle; the site is HALF x 2 around it, kept free of trees.
const LOTS := [
	{"id": "n1", "name": "Юго-запад", "title": "Южный двор, запад", "pos": Vector3(-14, 0, 26), "unlock": ""},
	{"id": "n2", "name": "Юго-восток", "title": "Южный двор, восток", "pos": Vector3(16, 0, 26), "unlock": ""},
	{"id": "n3", "name": "Запад", "title": "Западная аллея", "pos": Vector3(-22, 0, 0), "unlock": "played:1"},
	{"id": "n4", "name": "Восток", "title": "Восточный двор", "pos": Vector3(28, 0, -9), "unlock": "played:3"},
	{"id": "n5", "name": "Северо-запад", "title": "Набережная, запад", "pos": Vector3(-18, 0, -26), "unlock": "titles:1"},
	{"id": "n6", "name": "Северо-восток", "title": "Набережная, восток", "pos": Vector3(20, 0, -30), "unlock": "played:6"},
	{"id": "n7", "name": "Лужайка", "title": "Восточная лужайка", "pos": Vector3(32, 0, 14), "unlock": "titles:2"},
]
const HALF := Vector2(8.0, 6.0)         # half the lot's site (x, z)
const R := 2.2                          # the circle of an empty lot

## The seven buildings. "home": where it stood before lots (a lot id: its default lot in an old
## save). "soon": no construction yet (the arena, H-3): a card, no button. "late": not on the
## sheet before its own condition is met (a newcomer is not shown what is far away). The
## academy (T-3) has its own levels (Academy.LEVELS), not ClubBuilds'.
## "faces_court": turned toward the court wherever it stands. "price"/"unlock": for the ones
## ClubBuilds does not know yet.
const TYPES := {
	"coach": {"name": "Тренерская", "home": "n2", "gives": "Навыки и задания тренера, отдых между очками"},
	"stands": {"name": "Трибуны", "home": "n4", "faces_court": true, "gives": "Болельщики и до +10% золота за победы"},
	"locker": {"name": "Раздевалка", "home": "n1", "gives": "Шкафчик для вещей, внешность, страховка вещей"},
	"trophy": {"name": "Трофейная", "home": "n5", "gives": "Кубки за титулы и твоя статуя. Для красоты: силы не даёт"},
	"bar": {"name": "Бар", "home": "n6", "gives": "Тотализатор и блэкджек: ставки золотом"},
	"academy": {"name": "Академия", "home": "n7", "late": true, "price": 150, "unlock": "played:4",
		"gives": "Места для учеников, рост быстрее и выше, сборы, скаут"},
	"arena": {"name": "Крытая арена", "home": "n3", "soon": true, "late": true, "price": 250, "unlock": "played:5",
		"gives": "Свои матчи, покрытие на выбор"},
}
const ORDER := ["coach", "stands", "locker", "trophy", "bar", "academy", "arena"]


# --- Data lookups ---------------------------------------------------------------------

static func lot(id: String) -> Dictionary:
	for l in LOTS:
		if l["id"] == id:
			return l
	return {}


static func is_type(id: String) -> bool:
	return TYPES.has(id)


## The type a place belongs to: itself ("locker"), or the building it grows with ("blackjack"
## -> "bar"); "" for the places that do not stand on lots (the court, the shop, the gate...).
static func owner_type(place_id: String) -> String:
	var b: String = ClubPlaces.base(place_id).get("build", place_id)
	return b if TYPES.has(b) else ""


static func lot_rect(lot_id: String) -> Rect2:
	var l := lot(lot_id)
	if l.is_empty():
		return Rect2()
	var c: Vector3 = l["pos"]
	return Rect2(c.x - HALF.x, c.z - HALF.y, HALF.x * 2.0, HALF.y * 2.0)


# --- What stands where ------------------------------------------------------------------

## A save from before lots: it has progress but no "lots" key. A new one is empty.
static func is_legacy() -> bool:
	var c: Dictionary = SaveData.club
	if SaveData.played > 0 or SaveData.titles > 0:
		return true
	var lv = c.get("levels", {})
	if lv is Dictionary:
		for k in lv:
			if int(lv[k]) > 0:
				return true
	var b = c.get("building", {})
	return int(c.get("spent", 0)) > 0 or (b is Dictionary and not (b as Dictionary).is_empty())


## What an old save gets: every building that is open stands on its home lot.
static func legacy_layout() -> Dictionary:
	var out := {}
	for t in ["locker", "coach", "trophy", "bar", "stands"]:
		if ClubBuilds.is_open(t):
			out[String(TYPES[t]["home"])] = t
	return out


## {lot id: type id} now: the save's, or - before the first visit writes it - what the save
## would get (so a world built in a test or a shot sees the same club).
static func map() -> Dictionary:
	var m = SaveData.club.get("lots")
	if m is Dictionary:
		return m
	return legacy_layout() if is_legacy() else {}


## Writes the layout into the save once (the first visit to the club after this update).
static func ensure() -> void:
	if SaveData.club.get("lots") is Dictionary:
		return
	SaveData.club["lots"] = legacy_layout() if is_legacy() else {}
	SaveData.save()


static func type_at(lot_id: String) -> String:
	return String(map().get(lot_id, ""))


static func lot_of(type: String) -> String:
	var m := map()
	for k in m:
		if m[k] == type:
			return k
	return ""


## Does the type stand on a lot? Everything that is not a lot type (the court...) always does.
static func is_placed(id: String) -> bool:
	return not TYPES.has(id) or lot_of(id) != ""


# --- When a lot / a type opens -----------------------------------------------------------

static func cond_met(cond: String) -> bool:
	if cond == "":
		return true
	var n := int(cond.get_slice(":", 1))
	match cond.get_slice(":", 0):
		"played":
			return SaveData.played >= n
		"titles":
			return SaveData.titles >= n
	return false


static func cond_text(cond: String) -> String:
	if cond == "":
		return ""
	var n := int(cond.get_slice(":", 1))
	var one := n % 10 == 1 and n % 100 != 11   # «после 21 забега», «после 4 забегов»: the genitive
	if cond.begins_with("titles"):
		return "после первого титула" if n == 1 else "после %d %s" % [n, "титула" if one else "титулов"]
	return "после первого забега" if n == 1 else "после %d %s" % [n, "забега" if one else "забегов"]


static func _word(n: int, few: String, many: String) -> String:
	return few if n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20) else many


## A lot can be built on once its condition is met (a placed one always counts open).
static func lot_open(lot_id: String) -> bool:
	if type_at(lot_id) != "":
		return true
	var l := lot(lot_id)
	return not l.is_empty() and cond_met(String(l["unlock"]))


static func free_lots() -> Array:
	return LOTS.filter(func(l: Dictionary) -> bool: return type_at(l["id"]) == "" and lot_open(l["id"]))


static func is_soon(type: String) -> bool:
	return bool(TYPES.get(type, {}).get("soon", false))


## Whether the type's own condition is met (the academy and the arena: their own; the others
## are ClubBuilds' unlock: first run / first title).
static func type_open(type: String) -> bool:
	if ClubBuilds.TABLE.has(type):
		return ClubBuilds.is_open(type)
	return cond_met(String(TYPES.get(type, {}).get("unlock", "never")))


static func type_cond_text(type: String) -> String:
	if ClubBuilds.TABLE.has(type):
		return "после первого титула" if String(ClubBuilds.TABLE[type].get("unlock", "")) == "title" else "после первого забега"
	return cond_text(String(TYPES.get(type, {}).get("unlock", "")))


## The price of the first level, which is what a lot costs (the scale applies).
static func price(type: String) -> int:
	if ClubBuilds.TABLE.has(type):
		return roundi(float(ClubBuilds.TABLE[type]["levels"][0]["price"]) * ClubBuilds.CLUB_PRICE_SCALE)
	return roundi(float(TYPES.get(type, {}).get("price", 0)) * ClubBuilds.CLUB_PRICE_SCALE)


## "": the type can be built on the lot (gold apart). Else why not, short, for the card.
static func why_not(lot_id: String, type: String) -> String:
	var l := lot(lot_id)
	if l.is_empty() or not TYPES.has(type):
		return "Нет такого"
	if type_at(lot_id) != "":
		return "Участок занят"
	if not lot_open(lot_id):
		return "Участок откроется %s" % cond_text(String(l["unlock"]))
	if is_soon(type):
		return "Скоро"
	if lot_of(type) != "":
		return "Уже построено"
	if not type_open(type):
		return "Откроется %s" % type_cond_text(type)
	return ""


static func can_build(lot_id: String, type: String) -> bool:
	return why_not(lot_id, type) == "" and SaveData.gold >= price(type)


## Builds the type on the lot: the first level is bought (gold goes, the save is written).
static func build(lot_id: String, type: String) -> bool:
	if not can_build(lot_id, type):
		return false
	var lots: Dictionary = map().duplicate()
	lots[lot_id] = type
	SaveData.club["lots"] = lots
	if not ClubBuilds.TABLE.has(type):
		# A building with its own levels (the academy): the first one is bought here.
		var pr := price(type)
		SaveData.gold -= pr
		SaveData.club["spent"] = int(SaveData.club.get("spent", 0)) + pr
		var levels: Dictionary = SaveData.club.get("levels", {}).duplicate()
		levels[type] = 1
		SaveData.club["levels"] = levels
		SaveData.save()
		return true
	if not ClubBuilds.buy(type):
		lots.erase(lot_id)
		SaveData.club["lots"] = lots
		return false
	return true


## The coach's line for a level of a type just built (the academy's own, or ClubBuilds').
static func line(type: String, lv: int) -> String:
	if type == "academy":
		return Academy.level_line(lv)
	return ClubBuilds.line(type, lv)


## Types worth showing on a lot's sheet, in the order the sheet pages them.
## (The academy and the arena are not in the game yet: a newcomer is not shown them as «Скоро»
## cards between the things he can build; they join the sheet when their own run count is met.)
static func sheet_types() -> Array:
	return ORDER.filter(func(t: String) -> bool: return not (is_soon(t) or bool(TYPES[t].get("late", false))) or cond_met(String(TYPES[t].get("unlock", "never"))))


## What can be built now on some free lot, cheapest first (types not built, open, buildable).
static func buildable_types() -> Array:
	var out: Array = []
	for t in ORDER:
		if lot_of(t) == "" and not is_soon(t) and type_open(t):
			out.append(t)
	out.sort_custom(func(a: String, b: String) -> bool: return price(a) < price(b))
	return out


static func cheapest_price() -> int:
	var t := buildable_types()
	return price(t[0]) if not t.is_empty() else 0


static func affordable_count() -> int:
	var n := 0
	for t in buildable_types():
		if price(t) <= SaveData.gold:
			n += 1
	return n


## The constructions the foreman lists: the ones that stand.
static func foreman_ids() -> Array:
	return ClubBuilds.ORDER.filter(func(id: String) -> bool: return is_placed(id))


# --- Where a building stands -------------------------------------------------------------

static func home(type: String) -> Vector3:
	return ClubPlaces.base(type).get("pos", Vector3.ZERO)


## A quarter turn (0, 90, 180, 270 degrees) so that the type's front (-x at home) looks
## toward the court from `at`; 0 for the others.
static func rotation_for(type: String, at: Vector3) -> float:
	if not bool(TYPES.get(type, {}).get("faces_court", false)):
		return 0.0
	var want := Vector3(-at.x, 0, -at.z).normalized()
	var best := 0.0
	var best_dot := -2.0
	for k in 4:
		var a := k * PI * 0.5
		var d := (Basis(Vector3.UP, a) * Vector3(-1, 0, 0)).dot(want)
		if d > best_dot + 0.001:
			best_dot = d
			best = a
	return best


## world = xf * (point drawn around home). Identity for what does not stand on a lot.
static func xf_for(type: String, lot_id: String) -> Transform3D:
	var l := lot(lot_id)
	if l.is_empty() or not TYPES.has(type):
		return Transform3D.IDENTITY
	var at: Vector3 = l["pos"]
	var b := Basis(Vector3.UP, rotation_for(type, at))
	return Transform3D(b, at - b * home(type))


static func xf(type: String) -> Transform3D:
	var l := lot_of(type)
	return xf_for(type, l) if l != "" else Transform3D.IDENTITY


## Where home goes: the lot's centre minus home (zero for a building on its home lot).
static func offset(type: String) -> Vector3:
	return (xf(type) * home(type)) - home(type)


## A rectangle (x, z) drawn around home, in the world.
static func rect_in_world(t: Transform3D, r: Rect2) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var q := t * Vector3(c.x, 0, c.y)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.z))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.z))
	return Rect2(lo, hi - lo)


# --- Places made of lots -------------------------------------------------------------------

## A built type's place, moved to its lot (its camera too).
static func moved(p: Dictionary, type: String) -> Dictionary:
	var t := xf(type)
	var out: Dictionary = p.duplicate()
	out["pos"] = t * (p["pos"] as Vector3)
	if p.has("cam"):
		var c: Dictionary = p["cam"]
		out["cam"] = {"pos": t * (c["pos"] as Vector3), "look": t * (c["look"] as Vector3)}
	return out


## "Участок · построить / от 96 ●", or why it is shut.
static func sign_text(lot_id: String) -> String:
	var l := lot(lot_id)
	if not lot_open(lot_id):
		return "Участок\n%s" % cond_text(String(l["unlock"]))
	var p := cheapest_price()
	if p <= 0:
		return "Участок\nпока нечего строить"
	return "Участок · построить\nот %d ●" % p


## An empty lot as a place of the club: a circle, the button «Построить», a sign.
static func lot_place(l: Dictionary) -> Dictionary:
	var open := lot_open(String(l["id"]))
	return {
		"id": "lot_" + String(l["id"]), "name": "Участок · %s" % String(l["name"]).to_lower(),
		"pos": l["pos"], "r": R, "unlock": "" if open else "never", "sign": sign_text(String(l["id"])),
		"keep_sign": true, "lot": l["id"],
		"levels": [{"label": "Построить", "action": "club_lot", "note": "Пустой участок: выбери, что здесь построить"}],
	}


## Red counts over the lots where something can be bought now (lot place id -> count).
static func lot_badges() -> Dictionary:
	var out := {}
	var n := affordable_count()
	if n > 0:
		for l in free_lots():
			out["lot_" + String(l["id"])] = n
	return out


# --- For the ruins of stream H ---------------------------------------------------------------------

## The level a RUIN prop of a building's home site should see (ClubScenery.level_of for
## `owner`): the ruins belong to the SITE, not to the type that used to stand there. -1: not a
## lot type (use the construction's own level); else 0 while whatever lot is that building's
## home is empty, and the level of whatever was built on it once something is (>= 1: the ruin
## goes). So a bar built on the western lot clears the western junk, not the bar's old corner.
static func ruin_level(owner: String) -> int:
	if not TYPES.has(owner):
		return -1
	var t := type_at(String(TYPES[owner]["home"]))
	return 0 if t == "" else maxi(1, ClubBuilds.level(t))


# --- The sheet ---------------------------------------------------------------------------------

## The card and the button of the sheet for a type on a lot:
## {card: {tag, title, desc, locked}, build: {text, can}}.
static func sheet(lot_id: String, type: String) -> Dictionary:
	var t: Dictionary = TYPES[type]
	var l := lot(lot_id)
	var card := {"tag": "Участок · %s" % String(l.get("name", "")).to_lower(), "title": t["name"], "locked": false}
	var desc := "Что даёт: %s" % t["gives"]
	if ClubBuilds.TABLE.has(type):
		var lv: Dictionary = ClubBuilds.TABLE[type]["levels"][0]
		desc += "\nПервый уровень: %s" % lv["now"]
		if String(lv.get("perk", "")) != "":
			desc += "\nПольза: %s" % lv["perk"]
	elif type == "academy":
		var lv: Dictionary = Academy.LEVELS[0]
		desc += "\nПервый уровень: %s\nПольза: %s" % [lv["now"], lv["perk"]]
	else:
		desc += "\nПервый уровень будет позже"
	card["desc"] = desc
	var why := why_not(lot_id, type)
	var build := {}
	var pr := price(type)
	if why == "":
		if SaveData.gold >= pr:
			build = {"text": "ПОСТРОИТЬ  ·  %d ●" % pr, "can": true}
		else:
			build = {"text": "Нужно ещё %d" % (pr - SaveData.gold), "can": false}
	else:
		build = {"text": why, "can": false}
		card["locked"] = why != "Уже построено"
	return {"card": card, "build": build}
