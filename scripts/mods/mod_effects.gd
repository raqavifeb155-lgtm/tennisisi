class_name ModEffects
## The primitives every modifier is made of (v0.2 stream G; ROGUELIKE_DESIGN 14.2). Each
## one changes something for the match through the knobs the game already has (Skills,
## Tuning, BallPhysics, Court, the ball and the light of the location, ModsHub's own
## switches that Main reads) and pushes onto hub.undo how to put it back. ModsHub runs
## the undo list backwards when the match ends or is left.
##
##   ["stat", key, v]            the player's Skills mods (all_window / all_pace / all expand)
##   ["stamina_start", f]        the player starts the match with this much stamina
##   ["no_ring"]                 no timing ring
##   ["ring_late", s]            the ring shows only this many seconds before the contact
##   ["mirror"]                  swipes and the stick mirrored left-right
##   ["tuning", prop, value]     a Tuning property set for the match
##   ["tuning_x", prop, k]       ... multiplied
##   ["gravity", k]              BallPhysics gravity x k
##   ["wind", a]                 sideways wind (m/s^2), its side drawn per match
##   ["rubber_net"]              a ball into the net hops over it
##   ["surface", friction, pace_k, bounce_add, tint]   the bounce of the court
##   ["narrow", m]               the singles lines move in m a side
##   ["ball_scale", k]           the ball drawn k times bigger
##   ["fog", density]            fog over the court, the ball fades away from the player
##   ["night"]                   a dark court, the ball glows
##   ["shot_pace", who, k]       rally shots of who (0 player, 1 CPU, -1 both) x k
##   ["serve_pace", who, k]      serves x k
##   ["echo", n]                 every n-th rally shot of the CPU is a drop shot
##   ["opp", key, v]             the opponent's skill / speed / serve (Tournament.modifier_value)
##   ["opp_stamina", k]          the opponent's stamina x k (MatchEffects: damage / k)
##   ["reaction", s]             the AI reads the player's shot s later (- = earlier)
##   ["cpu_scale", k]            the opponent drawn k times taller
##   ["drain_on_loss", f]        his winner or ace takes f of the player's stamina
##   ["heal_on_win", f]          the player's winner or ace gives f back
##   ["aura_rate", k]            (out of a match: auras k times likelier, see Modifiers)
##   ["style_hole"]              his weak backhand: a winner to it is a style trick (Traits.hole_hit)
##   ["twins"]                   a second opponent on his half
##
## Stream A can run any of these from an item's trigger: ModEffects.apply(main.mods_hub, fx)
## (it lasts the match, like everything here).


## The opponent's stamina, scaled: what costs him d costs this one d / k.
class ScaledStamina extends OppStamina:
	var k := 1.0

	func damage(n: float) -> float:
		return super.damage(n / maxf(k, 0.05))


static func apply(hub: Node, f: Array) -> void:
	var main: Node = hub.main
	match String(f[0]):
		"stat":
			var m := Items.expand({f[1]: f[2]})
			for key in m:
				Skills.mods_layer[key] = float(Skills.mods_layer.get(key, 0.0)) + float(m[key])
			hub.undo.append(func() -> void:
				for key in m:
					Skills.mods_layer[key] = float(Skills.mods_layer.get(key, 0.0)) - float(m[key])
					if absf(float(Skills.mods_layer[key])) < 0.00001:
						Skills.mods_layer.erase(key))
		"stamina_start":
			var old: float = hub.start_stamina
			hub.start_stamina = minf(old, float(f[1]))
			hub.undo.append(func() -> void: hub.start_stamina = old)
		"no_ring":
			hub.no_ring = true
			hub.undo.append(func() -> void: hub.no_ring = false)
		"ring_late":
			var old: float = hub.ring_late
			hub.ring_late = minf(old, float(f[1]))
			hub.undo.append(func() -> void: hub.ring_late = old)
		"mirror":
			hub.mirror = true
			hub.undo.append(func() -> void: hub.mirror = false)
		"tuning":
			var t: Node = hub.get_node("/root/Tuning")
			var old = t.get(f[1])
			t.set(f[1], f[2])
			hub.undo.append(func() -> void: t.set(f[1], old))
		"tuning_x":
			var t: Node = hub.get_node("/root/Tuning")
			var old = t.get(f[1])
			t.set(f[1], float(old) * float(f[2]))
			hub.undo.append(func() -> void: t.set(f[1], old))
		"gravity":
			var old := BallPhysics.gravity_scale
			BallPhysics.gravity_scale = old * float(f[1])
			hub.undo.append(func() -> void: BallPhysics.gravity_scale = old)
		"wind":
			var old := BallPhysics.wind
			var side := 1.0 if hub.rng.randf() < 0.5 else -1.0
			hub.wind_side = side
			BallPhysics.wind = Vector3(side * float(f[1]), 0.0, 0.0)
			hub.undo.append(func() -> void:
				BallPhysics.wind = old
				hub.wind_side = 0.0)
		"rubber_net":
			var old := BallPhysics.rubber_net
			BallPhysics.rubber_net = true
			hub.undo.append(func() -> void: BallPhysics.rubber_net = old)
		"surface":
			var old := [BallPhysics.friction, BallPhysics.pace, BallPhysics.bounce_offset]
			BallPhysics.friction = old[0] * float(f[1])
			BallPhysics.pace = old[1] * float(f[2])
			BallPhysics.bounce_offset = old[2] + float(f[3])
			var mat: StandardMaterial3D = main.court._court_mat if main.court != null else null
			var tint: Color = f[4] if f.size() > 4 else Color.WHITE
			var old_c := mat.albedo_color if mat else Color.WHITE
			if mat:
				mat.albedo_color = old_c * tint
			hub.undo.append(func() -> void:
				BallPhysics.friction = old[0]
				BallPhysics.pace = old[1]
				BallPhysics.bounce_offset = old[2]
				if mat:
					mat.albedo_color = old_c)
		"narrow":
			var old := Court.inset
			Court.inset = float(f[1])
			var lines: Node3D = hub.narrow_lines(Court.half_width())
			hub.undo.append(func() -> void:
				Court.inset = old
				if is_instance_valid(lines):
					if lines.get_parent():
						lines.get_parent().remove_child(lines)
					lines.queue_free())
		"ball_scale":
			var ball: Node3D = main.ball
			var k := float(f[1])
			var mesh: Node3D = ball._mesh
			var shadow: Node3D = ball._shadow
			var old_m := mesh.scale
			var old_s := shadow.scale
			mesh.scale = old_m * k
			shadow.scale = Vector3(old_s.x * k, old_s.y, old_s.z * k)
			hub.undo.append(func() -> void:
				mesh.scale = old_m
				shadow.scale = old_s)
		"fog":
			var env: Environment = hub.environment()
			hub.fog = true
			if env:
				var old := [env.fog_enabled, env.fog_density, env.fog_light_color, env.fog_light_energy, env.fog_sky_affect]
				env.fog_enabled = true
				env.fog_density = float(f[1])
				env.fog_light_color = Color(0.78, 0.8, 0.83)
				env.fog_light_energy = 1.0
				env.fog_sky_affect = 1.0
				hub.undo.append(func() -> void:
					env.fog_enabled = old[0]
					env.fog_density = old[1]
					env.fog_light_color = old[2]
					env.fog_light_energy = old[3]
					env.fog_sky_affect = old[4])
			hub.undo.append(func() -> void: hub.fog = false)
		"night":
			var env: Environment = hub.environment()
			hub.night = true
			if env:
				var old := [env.tonemap_exposure, env.ambient_light_energy, env.adjustment_saturation, env.fog_light_energy]
				env.tonemap_exposure = old[0] * 0.34
				env.ambient_light_energy = old[1] * 0.45
				env.adjustment_saturation = old[2] * 0.6
				env.fog_light_energy = old[3] * 0.3
				hub.undo.append(func() -> void:
					env.tonemap_exposure = old[0]
					env.ambient_light_energy = old[1]
					env.adjustment_saturation = old[2]
					env.fog_light_energy = old[3])
			hub.undo.append(func() -> void: hub.night = false)
		"shot_pace", "serve_pace":
			var arr: Array = hub.pace if f[0] == "shot_pace" else hub.serve_pace
			var who := int(f[1])
			var old := arr.duplicate()
			for w in [0, 1]:
				if who < 0 or who == w:
					arr[w] = float(arr[w]) * float(f[2])
			hub.undo.append(func() -> void:
				for w in [0, 1]:
					arr[w] = old[w])
		"echo":
			var old: int = hub.echo_every
			hub.echo_every = int(f[1])
			hub.undo.append(func() -> void: hub.echo_every = old)
		"opp":
			# Through Tournament.modifier_value, read when the match starts. A practice
			# match (the bot's --mods runs) has no tournament: set straight on Main.
			if not main.tournament_mode or main.tournament == null:
				var t: Node = hub.get_node("/root/Tuning")
				match String(f[1]):
					"skill":
						t.ai_skill = clampf(t.ai_skill + float(f[2]), 0.0, 1.0)
						var d := float(f[2])
						hub.undo.append(func() -> void: t.ai_skill = clampf(t.ai_skill - d, 0.0, 1.0))
					"speed":
						var old: float = main.ai.speed_mult
						main.ai.speed_mult = old * float(f[2])
						hub.undo.append(func() -> void: main.ai.speed_mult = old)
					"serve":
						var old: float = main._cpu_serve_mult
						main._cpu_serve_mult = old * float(f[2])
						hub.undo.append(func() -> void: main._cpu_serve_mult = old)
		"opp_stamina":
			var fx = main.run_hub.match_fx if main.run_hub != null else null
			if fx != null:
				var old = fx.opp
				var s := ScaledStamina.new()
				s.value = old.value
				s.k = float(f[1]) * (old.k if old is ScaledStamina else 1.0)
				fx.opp = s
				hub.undo.append(func() -> void:
					old.value = s.value
					fx.opp = old)
		"reaction":
			var old: float = hub.reaction_add
			hub.reaction_add = old + float(f[1])
			hub.undo.append(func() -> void: hub.reaction_add = old)
		"cpu_scale":
			var cpu: Node3D = main.cpu
			var old := cpu.scale
			cpu.scale = old * float(f[1])
			hub.undo.append(func() -> void: cpu.scale = old)
		"style_hole":
			hub.hole = true
			hub.undo.append(func() -> void:
				hub.hole = false
				Traits.hole_hit = false)
		"drain_on_loss":
			var old: float = hub.drain_on_loss
			hub.drain_on_loss = old + float(f[1])
			hub.undo.append(func() -> void: hub.drain_on_loss = old)
		"heal_on_win":
			var old: float = hub.heal_on_win
			hub.heal_on_win = old + float(f[1])
			hub.undo.append(func() -> void: hub.heal_on_win = old)
		"aura_rate":
			pass  # decided when the lineup is rolled (Modifiers.add_auras)
		"twins":
			hub.start_twins()
			hub.undo.append(func() -> void: hub.stop_twins())
		_:
			push_warning("ModEffects: unknown primitive %s" % str(f))
