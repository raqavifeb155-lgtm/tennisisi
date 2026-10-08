class_name ClubApi
## The club's newer perks, read through the script so this stream works before and after
## stream B adds them (ClubBuilds.shop_free_rerolls, restring_discount, insurance_discount):
## a missing function gives the default. Discounts come as a share (0.1) or percent (10).


static func call_or(method: String, default: Variant) -> Variant:
	var scr: GDScript = load("res://scripts/club/club_builds.gd")
	for m in scr.get_script_method_list():
		if m["name"] == method:
			return scr.call(method)
	return default


static func free_rerolls() -> int:
	return int(call_or("shop_free_rerolls", 0))


static func _share(v: Variant) -> float:
	var f := float(v)
	return clampf(f / 100.0 if f > 1.0 else f, 0.0, 0.9)


static func restring_discount() -> float:
	return _share(call_or("restring_discount", 0.0))


static func insurance_discount() -> float:
	return _share(call_or("insurance_discount", 0.0))
