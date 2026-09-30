extends "res://tests/net_v020.gd"

# The old suite activates a hook without casting it. Give that fixture a real tethered pose.
func fresh(extra: Dictionary={}) -> void:
	super.fresh(extra)
	w.baits[0].pos=w.angler.anchor()+Vector2(0,132)
	w.baits[0].home=w.baits[0].pos
	w.baits[0].tip_before=w._tip(0)
