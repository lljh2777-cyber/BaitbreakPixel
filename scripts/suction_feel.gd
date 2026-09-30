extends RefCounted

# One profile for both bait identities, shared by simulation and presentation.
static func body_gain(power: float) -> float:
	return power*(0.55+0.45*power)

static func body_speed(power: float) -> float:
	return 18+46*power*power

static func peel_gain(power: float, layer: int) -> float:
	return pow(power,0.8 if layer==0 else (1.6 if layer==1 else 2.2))

static func pellet_gain(power: float) -> float:
	return 0.4+0.6*power

static func mode_name(power: float) -> String:
	return "轻吸" if power<=0.4 else ("稳吸" if power<=0.7 else "猛吸")

static func deform(offset: Vector2, direction: Vector2, gain: float) -> Vector2:
	var side:=direction.orthogonal()
	return offset+direction*offset.dot(direction)*gain*0.32-side*offset.dot(side)*gain*0.18
