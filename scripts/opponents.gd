class_name Opponents
## Tournament roster: one tennis player per level, the boss in the final. Each one
## teaches a lesson. For now a profile sets the AI skill (the format is chosen per run); play
## styles (heavy forehands, 220 km/h serves, the wall that returns everything) and the
## boss phases come with the opponent profiles step of the roadmap.
## Names live only here, so they are easy to swap. "look" dresses them (see Looks).

const ROSTER := [
	{
		"id": "dzumhur", "name": "Дамир Джумхур", "short": "ДЖУМХУР", "title": "Уровень 1",
		"lesson": "Мягкий темп, прощает ошибки. Обучение", "skill": 0.0,
		"shirt": Color(0.2, 0.45, 0.8),
		"look": {"skin": 3, "hair": Looks.Hair.SHORT, "hair_color": 1, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.NONE, "shirt": 5, "shorts": 3, "accent": 5},
	},
	{
		"id": "basilashvili", "name": "Николоз Басилашвили", "short": "БАСИЛАШВИЛИ", "title": "Уровень 2",
		"lesson": "Лупит всё подряд и ошибается. Урок обороны", "skill": 0.25,
		"shirt": Color(0.85, 0.85, 0.88),
		"look": {"skin": 3, "hair": Looks.Hair.SHORT, "hair_color": 0, "beard": Looks.Beard.SHORT, "head": Looks.Head.NONE, "shirt": 0, "shorts": 3, "accent": 0},
	},
	{
		"id": "rublev", "name": "Андрей Рублёв", "short": "РУБЛЁВ", "title": "Уровень 3",
		"lesson": "Тяжёлый форхенд. Урок терпения", "skill": 0.45,
		"shirt": Color(0.75, 0.2, 0.18),
		"look": {"skin": 1, "hair": Looks.Hair.MESSY, "hair_color": 8, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.HEADBAND, "shirt": 13, "shorts": 3, "accent": 11},
	},
	{
		"id": "zverev", "name": "Саша Зверев", "short": "ЗВЕРЕВ", "title": "Уровень 4",
		"lesson": "Подача за 220 км/ч. Урок приёма", "skill": 0.62,
		"shirt": Color(0.12, 0.12, 0.16),
		"look": {"skin": 1, "hair": Looks.Hair.BUN, "hair_color": 5, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.HEADBAND, "shirt": 3, "shorts": 3, "accent": 3},
	},
	{
		"id": "djokovic", "name": "Новак Джокович", "short": "ДЖОКОВИЧ", "title": "Босс · Король Корта",
		"lesson": "Возвращает всё. Финал турнира", "skill": 0.85, "boss": true,
		"shirt": Color(0.95, 0.75, 0.2),
		"look": {"skin": 3, "hair": Looks.Hair.SHORT, "hair_color": 1, "beard": Looks.Beard.STUBBLE, "head": Looks.Head.NONE, "shirt": 10, "shorts": 3, "accent": 10},
	},
]

const ROUND_NAMES := ["Первый круг", "Второй круг", "Четвертьфинал", "Полуфинал", "Финал"]
