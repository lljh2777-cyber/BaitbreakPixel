extends RefCounted
## Each named object owns one local stream. Never use global RNG or a world seed.
static func valid(value: Variant) -> bool:
	return value is int and value >= 0 and value <= 2147483647

static func stream(visual_seed: int, layer: String, kind: String, index: int = 0) -> RandomNumberGenerator:
	var label := "wg-1.0|%d|%s|%s|%d" % [visual_seed, layer, kind, index]
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(label.to_utf8_buffer())
	var bytes := hash.finish()
	var first: int = (int(bytes[0]) << 24) | (int(bytes[1]) << 16) | (int(bytes[2]) << 8) | int(bytes[3])
	var rng := RandomNumberGenerator.new()
	rng.seed = first >> 1
	return rng
