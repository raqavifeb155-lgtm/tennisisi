extends RefCounted
## The bot's chance to win a tournament match, measured with real autoplay runs
## (--autoplay --tournament --format=1 --bot-sd=0.07 --xp=N, 6 runs per row, 08.10, code of
## main 866cce0) and smoothed to be monotonic. Used by tools/drop_sim.gd and
## tools/economy_sim.gd so their numbers rest on how the bot really plays.
##   xp  = experience in every skill (--xp): 280 ~ level 5, 580 ~ 7, 1000 ~ 9, 1930 ~ 12
##   row = win chance per round: first, second, quarter, semi, final (the boss)

const XP := [0.0, 100.0, 280.0, 580.0, 1000.0, 1500.0, 1930.0, 4000.0]
const WIN := [
	[0.17, 0.05, 0.02, 0.01, 0.00],
	[0.20, 0.08, 0.03, 0.01, 0.00],
	[0.67, 0.29, 0.20, 0.05, 0.01],
	[0.83, 0.43, 0.25, 0.08, 0.01],
	[0.95, 0.80, 0.62, 0.50, 0.03],
	[0.97, 0.86, 0.80, 0.70, 0.10],
	[0.99, 0.92, 0.88, 0.82, 0.12],
	[0.99, 0.96, 0.94, 0.90, 0.30],
]
## Experience a skill gains in one match of "Сет до 6" (measured: one lost first-round set
## takes a beginner from levels 1/1/1/0/0/0/0 to about 2/2/2/0/2/3/4).
const XP_PER_MATCH := 70.0
const STYLE_GOLD := 13.6          # the bot's average style gold per match (161 matches)


## Win chance in round `stage` with `xp` in every skill; `edge` shifts it (gear, islands):
## +0.1 = ten points of win chance more against an even opponent.
static func win_chance(xp: float, stage: int, edge := 0.0) -> float:
	var i := 0
	while i < XP.size() - 2 and xp > XP[i + 1]:
		i += 1
	var k := clampf((xp - XP[i]) / (XP[i + 1] - XP[i]), 0.0, 1.0)
	var p := lerpf(WIN[i][stage], WIN[i + 1][stage], k)
	# The edge in log-odds, so it never pushes past 0 or 1.
	if edge != 0.0 and p > 0.0 and p < 1.0:
		var lo := log(p / (1.0 - p)) + edge * 4.0
		p = 1.0 / (1.0 + exp(-lo))
	return p
