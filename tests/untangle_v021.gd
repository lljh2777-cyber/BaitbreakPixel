extends "res://tests/untangle_v020.gd"

# Contact the main trunk itself; the new branch layout has a nearer twig at the old point.
func fresh() -> Node2D:
	var w=World.new()
	w.reset_world({"ruleset":"duel","challenge":false,"water_strength":0,"line_force":0,"seed":2649})
	w.fish=Vector2(346,340); w.baits[0].active=true; w._enter_hook(0); w._attach_hook()
	w._update_contacts(0); w._begin_wrap(); w._commit_wrap()
	for frame in 90: w.advance_tick({}, {})
	w.fish+=Vector2(48,0)
	set_tension(w,0.4)
	return w
