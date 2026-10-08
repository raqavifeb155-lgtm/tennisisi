extends Node
## Global tweakable parameters, edited live from the debug panel.
## Everything that affects "feel" should live here so it can be tuned on device.

signal changed

# Slow-motion window
var slowmo_enabled := true
var slowmo_scale := 0.33       # time scale inside the window
var slowmo_lead := 0.40        # game seconds before contact when slow-mo starts

# Timing windows (game seconds, relative to the ideal contact moment)
var perfect_window := 0.035
var good_window := 0.09
var early_limit := 0.30        # swing released earlier than this = whiff
var late_limit := 0.12         # how long after the ideal moment a swing still connects

# Swipe shape -> stroke (see ShotGesture)
var curl_min := 0.12          # the turn of the wrist after an upward stroke (of its length) for a TOPSPIN
var curl_turn := 45.0         # how sharply (degrees) the finger must turn away to count as that turn
var lob_speed := 1.4          # an upward arc slower than this (screen heights per second) is a LOB
var drop_len := 0.11           # a downward stroke shorter than this (of screen height) is a drop shot

# Player
var player_speed := 6.2
var one_handed_bh := false     # backhand style: one-handed (Wawrinka) or two-handed
var tap_controls := false      # true: tap / hold the court to run; false: thumb joystick under the player
var assist := 0.6              # auto-positioning help, 0 = none (a tap overrides it for that ball)
var tv_camera := false         # the broadcast camera: high behind the baseline, the whole court (GameCamera)

# Opponent
var ai_skill := 0.5

# Feedback / debug
var hitstop := true
var vibration := true
var ambience := true            # the sound of the location (sea, city, birds)
var music := true               # menu music
var graphics := 0               # GraphicsQuality preset: 0 auto, 1 low .. 4 max, 5 custom
var gfx_res := 0.75             # graphics parts (GraphicsQuality): share of the screen resolution
var gfx_aa := 1                 # smooth edges: 0 off, 1 2x, 2 4x
var gfx_shadows := 2            # 0 off, 1 hard, 2 soft, 3 the softest
var gfx_reach := 1.0            # how far shadows are drawn, x the scenery's own
var gfx_details := true         # scenery extras
var show_fps := false           # the frame rate in a corner
var opp_bar_style := 1          # the opponent's stamina bar (OppStaminaView): 1 thin over his head, 2 half ring under the score, 3 line in the score plate
var show_path := false
var show_landing := true
var hawkeye_range := 0.15      # show the line-call replay when the mark is this close to a line (m)
var show_aim := true           # aim marker while swiping + where the shot landed
var show_debug_text := false


func notify_changed() -> void:
	changed.emit()
