class_name RunShare
## "Поделиться" for the best point: a picture of the replay with the style plate, a short
## caption and the game's link. No server: inside Telegram the phone's share sheet takes
## the picture when the WebView can share files (Web Share API); otherwise Telegram's own
## "share to chat" opens with the caption and the link (the bot's card shows as the
## preview). In a desktop browser the picture is downloaded; outside the web it is saved.

const LINK := "https://t.me/TennisisiBot?startapp=style"
const WIDTH := 540                # the picture is scaled down to this width

const _JS := """
(function (b64, text, url, path) {
  function post(type, data) {
    try {
      if (window.TelegramWebviewProxy) window.TelegramWebviewProxy.postEvent(type, JSON.stringify(data));
      else if (window.external && 'notify' in window.external) window.external.notify(JSON.stringify({eventType: type, eventData: data}));
      else if (window.parent !== window) window.parent.postMessage(JSON.stringify({eventType: type, eventData: data}), 'https://web.telegram.org');
    } catch (e) {}
  }
  var inTG = !!(window.tennisTG && window.tennisTG.inTelegram);
  try {
    var bin = atob(b64), arr = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
    var file = new File([arr], 'tennisisi.png', {type: 'image/png'});
    if (navigator.canShare && navigator.canShare({files: [file]})) {
      navigator.share({files: [file], text: text + ' ' + url}).catch(function () {});
      return 'web_share';
    }
  } catch (e) {}
  if (inTG) { post('web_app_open_tg_link', {path_full: path}); return 'tg_link'; }
  var a = document.createElement('a');
  a.href = 'data:image/png;base64,' + b64; a.download = 'tennisisi.png';
  document.body.appendChild(a); a.click(); a.remove();
  return 'download';
})(%s, %s, %s, %s)
"""


## "СТИЛЬ ×5.2 · Эйс · Пушка — TENNISISI"
static func caption(best: Dictionary) -> String:
	var parts: Array[String] = ["СТИЛЬ ×" + StylePlate._x(float(best.get("mult", 1.0)))]
	for t in best.get("tricks", []):
		parts.append(String(t["name"]))
	return " · ".join(parts) + " — TENNISISI"


## Telegram's "share to chat" (t.me/share/url) as a path for web_app_open_tg_link.
static func tg_share_path(best: Dictionary) -> String:
	return "/share/url?url=%s&text=%s" % [LINK.uri_encode(), caption(best).uri_encode()]


## Shares the picture (or just the caption and link when there is none). Returns how:
## "web_share", "tg_link", "download" (web) or "file" (a PNG in user://, desktop).
static func share(img: Image, best: Dictionary) -> String:
	var png := PackedByteArray()
	if img != null:
		var small := img.duplicate() as Image
		if small.get_width() > WIDTH:
			small.resize(WIDTH, roundi(small.get_height() * float(WIDTH) / small.get_width()), Image.INTERPOLATE_BILINEAR)
		png = small.save_png_to_buffer()
	if OS.has_feature("web"):
		var js := _JS % [JSON.stringify(Marshalls.raw_to_base64(png)), JSON.stringify(caption(best)),
			JSON.stringify(LINK), JSON.stringify(tg_share_path(best))]
		return String(JavaScriptBridge.eval(js, true))
	var path := "user://share_%d.png" % int(Time.get_unix_time_from_system())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(png)
		f.close()
	print("share: %s  ->  %s" % [caption(best), ProjectSettings.globalize_path(path)])
	return "file"
