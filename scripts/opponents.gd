class_name Opponents
## Tournament roster: one tennis player per level, the boss in the final. Each one
## teaches a lesson. For now a profile sets the AI skill (the format is chosen per run); play
## styles (heavy forehands, 220 km/h serves, the wall that returns everything) and the
## boss phases come with the opponent profiles step of the roadmap.
## Names live only here, so they are easy to swap.

const ROSTER := [
	{
		"id": "dzumhur", "name": "Дамир Джумхур", "short": "ДЖУМХУР", "title": "Уровень 1",
		"lesson": "Мягкий темп, прощает ошибки. Обучение", "skill": 0.0,
		"shirt": Color(0.2, 0.45, 0.8),
	},
	{
		"id": "basilashvili", "name": "Николоз Басилашвили", "short": "БАСИЛАШВИЛИ", "title": "Уровень 2",
		"lesson": "Лупит всё подряд и ошибается. Урок обороны", "skill": 0.25,
		"shirt": Color(0.85, 0.85, 0.88),
	},
	{
		"id": "rublev", "name": "Андрей Рублёв", "short": "РУБЛЁВ", "title": "Уровень 3",
		"lesson": "Тяжёлый форхенд. Урок терпения", "skill": 0.45,
		"shirt": Color(0.75, 0.2, 0.18),
	},
	{
		"id": "zverev", "name": "Саша Зверев", "short": "ЗВЕРЕВ", "title": "Уровень 4",
		"lesson": "Подача за 220 км/ч. Урок приёма", "skill": 0.62,
		"shirt": Color(0.12, 0.12, 0.16),
	},
	{
		"id": "djokovic", "name": "Новак Джокович", "short": "ДЖОКОВИЧ", "title": "Босс · Король Корта",
		"lesson": "Возвращает всё. Финал турнира", "skill": 0.85, "boss": true,
		"shirt": Color(0.95, 0.75, 0.2),
	},
]

const ROUND_NAMES := ["Первый круг", "Второй круг", "Четвертьфинал", "Полуфинал", "Финал"]
