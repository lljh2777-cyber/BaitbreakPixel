extends RefCounted
## Each named object owns one local stream. Never use global RNG or a world seed.
static func valid(value: Variant) -> bool:
	return value is int and value >= 0 and value <= 2147483647

static func stream(visual_seed: int, layer: String, kind: String, index: int = 0) -> RandomNumberGenerator:
	var label := "wg-p5-1|%d|%s|%s|%d" % [visual_seed, layer, kind, index]
	# Explicit integer mixing: one isolated stream per named visual object.
	# No cryptographic work per decoration and no global/Authority RNG.
	var value:int=2166136261 & 0x7fffffff
	for byte in label.to_utf8_buffer(): value=((value ^ byte)*16777619) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng
