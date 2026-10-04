class_name TelegramApp
## Telegram Mini App integration for the web build, without Telegram's SDK script:
## the page talks to the Telegram client through its documented postEvent bridge.
##
##  - tells Telegram the game is ready, opens it full height, and turns off
##    "swipe down to close" so swipes are always shots
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
  if (inTG) {
    post('web_app_ready');
    post('web_app_expand');
    post('web_app_setup_swipe_behavior', {allow_vertical_swipe: false});
    post('web_app_setup_closing_behavior', {need_confirmation: true});
  }
})();
"""


static func init() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(_SHIM, true)


## kind: "light", "medium", "heavy" or "perfect" (a light tick, then a firm thump).
static func haptic(kind: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.tennisTG && window.tennisTG.haptic('%s')" % kind, true)
	else:
		Input.vibrate_handheld({"light": 14, "medium": 26, "heavy": 60, "perfect": 45}.get(kind, 20))
