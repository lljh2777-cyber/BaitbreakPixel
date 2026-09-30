extends RefCounted

# Existing survival opponent: its actuator regulates tension and schedules the net.
# These commands use the same simulation entry point as a human angler.
func command(world: Node2D, _delta: float) -> Dictionary:
	var patrol: float=180.0+(world.Layout.SIZE.x-360)*(0.5+0.5*sin(world.elapsed*0.06))
	return {"walk":clampf((patrol-world.angler.x)/80,-1,1),"auto_reel":true,"auto_net":world.untangle_phase.is_empty(),"untangle":world.can_untangle(),"qte":world.effort_ai_press("angler")}
