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
var curve_min := 0.14          # sideways bulge / length above which a swipe is a topspin "C"
var drop_len := 0.11           # a slice hook shorter than this (of screen height) is a drop shot
var hook_min := 0.15           # how far the finger must come back (of the forward length) for a slice

# Player
var player_speed := 6.2
var assist := 0.6              # auto-positioning help, 0 = none (a tap overrides it for that ball)

# Opponent
var ai_skill := 0.5

# Feedback / debug
var hitstop := true
var vibration := true
var show_path := false
var show_landing := true
var hawkeye_range := 0.15      # show the line-call replay when the mark is this close to a line (m)
var show_aim := true           # aim marker while swiping + where the shot landed
var show_debug_text := false


func notify_changed() -> void:
	changed.emit()
