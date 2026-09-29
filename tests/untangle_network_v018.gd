extends SceneTree
const Main=preload("res://scenes/main.tscn")
var host:Node2D
var client:Node2D
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok: passed+=1; print("UNTANGLE_UDP_PASS | ",label)
	else: failed+=1; push_error("UNTANGLE_UDP_FAIL | "+label)
func frame(command:Dictionary={}) -> void:
	host.network.poll(); client.network.poll()
	host.network.tick(1.0/60,{}); client.network.tick(1.0/60,command)
	await create_timer(0.017).timeout
func phase(wanted:String) -> bool:
	for i in 300:
		await frame()
		if host.network.status==wanted and client.network.status==wanted: return true
	return false
func run() -> void:
	host=Main.instantiate(); client=Main.instantiate(); root.add_child(host); root.add_child(client)
	for game in [host,client]:
		game.capture_mode="untangle-network"; game.save_path="user://untangle-net-"+str(game.get_instance_id())+".cfg"
		game.set_process(false); game.set_physics_process(false)
	check(host.network.host_game("fish",24758,{"water_strength":0.0})==OK and client.network.join_game("127.0.0.1",24758)==OK,"host fish and remote angler connect through real ENet")
	if not await phase("waiting"): check(false,"handshake"); await cleanup(); return
	host.network.set_ready(true); client.network.set_ready(true)
	if not await phase("playing"): check(false,"countdown"); await cleanup(); return
	host.fish=Vector2(332,245); host.baits[0].active=true; host._enter_hook(0); host._attach_hook()
	host._update_contacts(0); host._begin_wrap(); host._commit_wrap()
	host.wraps[0].progress=1.0; host.untangle_cooldown=0.0; host.fish=Vector2(382,245)
	host.fish_line_length=host.mouth().distance_to(host.wraps[0].entry)-(0.4-0.18)*32
	host.tension=0.4; host._rebuild_rope(); host.effort_checks.angler.wait=12.0
	host.network._remember_qte(); host.network._send_state(true)
	for i in 10: await frame()
	var seen:=false; var pressed:=false; var unwinding:=false; var min_progress:=1.0
	for i in 260:
		var view:Node2D=client.network.display_world(); var state:Dictionary=view.skill_check("angler")
		var command:Dictionary={"untangle":i==0,"reel":view.tension<0.41,"release":view.tension>0.50}
		if state.active and state.kind=="untangle":
			seen=true
			if not pressed and state.progress>=state.zone+state.width*0.35:
				command.qte=true; pressed=true
		if view.untangle_phase=="unwind" and not view.wraps.is_empty():
			unwinding=true; min_progress=minf(min_progress,view.wraps[-1].progress)
		await frame(command)
		if host.round_stats.unwrap_good==1 and client.round_stats.unwrap_good==1: break
	check(seen,"remote F opens a human QTE displayed on the client")
	check(pressed and host.network.qte_accepted==1,"remote Space judges exactly once using server history")
	check(unwinding and min_progress<0.8,"remote view receives interpolated reverse winding")
	check(host.wraps.is_empty() and client.wraps.is_empty() and host.round_stats.unwrap_good==1 and client.round_stats.unwrap_good==1,"one coil removal and statistics converge on both peers")
	check(host.hooked==host.HookState.HOOKED and not host.movement_locked(),"shared fish stays hooked and movable after the counter")
	await cleanup()
func cleanup() -> void:
	host.queue_free(); client.queue_free(); await process_frame
	print("UNTANGLE_NETWORK_V018 | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)
