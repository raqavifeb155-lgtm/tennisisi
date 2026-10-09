extends SceneTree
## How much rare loot drops in 10 runs (v0.2 A-1, spec 3): the real Tournament code, the
## bot's measured win chances (tools/bot_model.gd), many repeats.
##   godot --headless --path . -s tools/drop_sim.gd
## Rows: a beginner who levels up over the 10 runs (starts at 0 experience, ~70 a match)
## and a player already at level 12. Counts what dropped (before the «Трофей» game).

const Model := preload("res://tools/bot_model.gd")
const REPEATS := 3000


func _initialize() -> void:
	SaveData.enabled = false
	for row in [["новичок, 10 забегов", 0.0, true], ["уровень 12, 10 забегов", 1930.0, false]]:
		var c := _sim(float(row[1]), bool(row[2]))
		print("DROPS %s: epic %.2f  legendary %.2f  mythic %.3f  (rare %.2f, matches %.1f, wins %.1f)" % [row[0],
			c[2], c[3], c[4], c[1], c[5], c[6]])
		print("   of which from chests: %.2f items (epic %.2f, legendary %.2f)" % [c[7], c[10], c[11]])
	quit()


## Average per 10 runs: [common, rare, epic, legendary, mythic, matches, wins].
func _sim(xp0: float, grows: bool) -> Array:
	var total := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]  # [8 + rarity]: from chests
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for rep in REPEATS:
		var xp := xp0
		for run in 10:
			var t := Tournament.new(1, rng.randi() | 1)
			var guard := 0
			while t.state != Tournament.State.OVER and guard < 30:
				guard += 1
				var won := rng.randf() < Model.win_chance(xp, t.stage)
				if grows:
					xp += Model.XP_PER_MATCH
				t.record_match(won, "", rng)
				total[5] += 1
				if won:
					total[6] += 1
				for it in t.new_items:
					total[int(it["rarity"])] += 1
				if not t.pending_loot.is_empty():
					total[int(t.pending_loot["rarity"])] += 1
					t.take_loot(true)
				if not t.chest.is_empty():  # v0.2 A-7: a chest by the net (counted with the drops)
					if not t.chest["item"].is_empty():
						total[int(t.chest["item"]["rarity"])] += 1
						total[7] += 1
						total[8 + int(t.chest["item"]["rarity"])] += 1
					t.take_chest()
				match t.state:
					Tournament.State.REWARD:
						t.take_chest()
					Tournament.State.LOST:
						t.use_wildcard()
	return total.map(func(v): return v / REPEATS)
