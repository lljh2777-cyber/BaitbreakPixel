extends RefCounted

# Existing survival opponent: its actuator regulates tension and schedules the net.
# These commands use the same simulation entry point as a human angler.
func command(world: Node2D, _delta: float) -> Dictionary:
	return {"auto_reel":true,"auto_net":true,"qte":world.effort_ai_press("angler")}
