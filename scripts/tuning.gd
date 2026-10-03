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

# Swipe mapping
var swipe_deep_len := 0.30     # swipe length (fraction of screen height) that aims at the baseline
var swipe_side_angle := 38.0   # swipe angle (deg from vertical) that aims at the sideline

# Player
var player_speed := 6.2
var assist := 0.35             # auto-positioning help, 0 = none

# Opponent
var ai_skill := 0.5

# Feedback / debug
var hitstop := true
var show_path := false
var show_landing := true
var show_debug_text := false


func notify_changed() -> void:
	changed.emit()
