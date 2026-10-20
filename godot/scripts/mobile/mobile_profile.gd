class_name MobileProfile
extends RefCounted
## Android profile; SERA_TOUCH=1 enables the same layout for desktop QA.

const TEXTURE_CACHE_LIMIT := 24
const RAIN_DROPS := 180
const PARTICLES := 20


static func enabled() -> bool:
	return OS.has_feature("android") or OS.get_environment("SERA_TOUCH") == "1"


static func safe_margins(screen: Vector2, safe: Rect2, viewport: Vector2) -> Vector4:
	if screen.x <= 0.0 or screen.y <= 0.0 or not safe.has_area():
		return Vector4.ZERO
	var scale := viewport / screen
	return Vector4(
		maxf(0.0, safe.position.x) * scale.x,
		maxf(0.0, safe.position.y) * scale.y,
		maxf(0.0, screen.x - safe.end.x) * scale.x,
		maxf(0.0, screen.y - safe.end.y) * scale.y
	)
