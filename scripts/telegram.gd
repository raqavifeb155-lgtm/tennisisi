class_name TelegramApp
## Telegram Mini App integration for the web build, without Telegram's SDK script:
## the page talks to the Telegram client through its documented postEvent bridge.
##
##  - tells Telegram the game is ready, opens it full height (true full screen on
##    phones, Bot API 8.0+), locks portrait, and turns off "swipe down to close" so
##    swipes are always shots
##  - reports the safe area: in full screen Telegram draws its close / menu buttons
##    over the top of the page (and the phone has a notch), so the HUD moves below
##  - haptics through the Telegram app (works on iPhone too, unlike the browser
##    Vibration API); outside Telegram it falls back to navigator.vibrate (Android)

const _SHIM := """
(function () {
  if (window.tennisTG) return;
  var hash = location.hash || '';
  var proxy = window.TelegramWebviewProxy;
  var inTG = !!proxy || /tgWebApp(Data|Version|Platform)=/.test(hash) ||
             /tgWebApp(Data|Version|Platform)=/.test(location.search);
  function post(type, data) {
    data = data || {};
    try {
      if (window.TelegramWebviewProxy) {
        window.TelegramWebviewProxy.postEvent(type, JSON.stringify(data));
      } else if (window.external && 'notify' in window.external) {
        window.external.notify(JSON.stringify({eventType: type, eventData: data}));
      } else if (window.parent !== window) {
        window.parent.postMessage(JSON.stringify({eventType: type, eventData: data}), 'https://web.telegram.org');
      }
    } catch (e) {}
  }
  function impact(style) { post('web_app_trigger_haptic_feedback', {type: 'impact', impact_style: style}); }
  var patterns = {light: 14, medium: 26, heavy: 60, perfect: [12, 55, 38]};
  window.tennisTG = {
    inTelegram: inTG,
    haptic: function (kind) {
      if (inTG) {
        if (kind === 'perfect') { impact('light'); setTimeout(function () { impact('heavy'); }, 70); }
        else impact(kind);
      } else if (navigator.vibrate) {
        navigator.vibrate(patterns[kind] || 20);
      }
    }
  };
  var plat = (/tgWebAppPlatform=([a-z_]+)/.exec(hash + location.search) || [])[1] || '';
  window.tennisTG.insets = function () {
    var t = window.Telegram && window.Telegram.WebApp;
    var a = (t && t.safeAreaInset) || {}, c = (t && t.contentSafeAreaInset) || {};
    return [(a.top || 0) + (c.top || 0), (a.bottom || 0) + (c.bottom || 0), window.innerHeight].join(',');
  };
  if (inTG) {
    post('web_app_ready');
    post('web_app_expand');
    if (plat === 'ios' || plat === 'android') {
      post('web_app_request_fullscreen');
      post('web_app_toggle_orientation_lock', {locked: true});
    }
    post('web_app_request_safe_area');
    post('web_app_request_content_safe_area');
    post('web_app_setup_swipe_behavior', {allow_vertical_swipe: false});
    post('web_app_setup_closing_behavior', {need_confirmation: true});
  }
})();
"""


static func init() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(_SHIM, true)


## Top and bottom of the screen covered by Telegram's buttons and the phone itself,
## in canvas units of a viewport `canvas_h` tall. Zero outside Telegram.
static func safe_insets(canvas_h: float) -> Vector2:
	if not OS.has_feature("web"):
		return Vector2.ZERO
	var r = JavaScriptBridge.eval("window.tennisTG && window.tennisTG.insets ? window.tennisTG.insets() : ''", true)
	var parts := String(r).split(",")
	if parts.size() < 3 or float(parts[2]) <= 0.0:
		return Vector2.ZERO
	var k := canvas_h / float(parts[2])
	return Vector2(float(parts[0]) * k, float(parts[1]) * k)


## An event to the server's log (see the page's tennisLog): for diagnosing crashes on
## players' phones. Values are plain numbers and short words.
static func log_event(event: String, data: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.tennisLog && window.tennisLog(%s, %s)" % [JSON.stringify(event), JSON.stringify(data)], true)


## kind: "light", "medium", "heavy" or "perfect" (a light tick, then a firm thump).
static func haptic(kind: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.tennisTG && window.tennisTG.haptic('%s')" % kind, true)
	else:
		Input.vibrate_handheld({"light": 14, "medium": 26, "heavy": 60, "perfect": 45}.get(kind, 20))
