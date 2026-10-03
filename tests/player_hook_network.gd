extends SceneTree

const Main=preload("res://scenes/main.tscn")
const World=preload("res://scripts/world_simulation.gd")
const Session=preload("res://scripts/network_session.gd")
const DT=1.0/60.0
var passed:=0
var failed:=0
var host: Node2D
var client: Node2D

func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PLAYER_HOOK_NET_PASS | ",label)
	else: failed+=1; push_error("PLAYER_HOOK_NET_FAIL | "+label)

func packet(session: Node, seq: int, identity: int, tick: int, kind: String="regular") -> Dictionary:
	return {"session":session.session_id,"round":session.round_id,"seq":seq,"command":{"qte":true,"qte_at_age":9.0},"seen_tick":tick,"qte_id":identity,"check_kind":kind,"events":[],"gesture":0}

func queue_checks() -> void:
	var world:=World.new()
	world.reset_world({"npc_count":0,"rules":{"line_force":0.0,"water_strength":0.0,"timer_enabled":false,"instinct_max_strength":0.0}})
	world._enter_hook(0); world.simulation_tick=100; world.qte_age=0.3
	var session:=Session.new(); session.game=world; session.remote_role="fish"; session.session_id="player-hook-preparation"; session.round_id=1
	session._remember_qte()
	world.simulation_tick=108; world.qte_age=0.45
	session.receive_input(packet(session,1,world.qte_id,100))
	var command: Dictionary=session._take_remote()
	check(command.qte and is_equal_approx(command.qte_at_age,0.3),"authority replaces forged client age with its own observed preparation age")
	world.advance_tick(command,{})
	check(world.qte=="entry" and world.round_stats.fish_total==0,"late-arriving preparation press cannot judge a now-visible QTE")
	check(not session._take_remote().qte,"held remote command cannot replay the consumed preparation edge")
	session.receive_input(packet(session,1,world.qte_id,100))
	check(not session._take_remote().qte and session.rejected_inputs==1,"duplicate input sequence cannot replay an ignored edge")
	session.receive_input(packet(session,2,world.qte_id+1,100))
	check(not session._take_remote().qte,"foreign QTE identity is still rejected")
	session.receive_input(packet(session,3,world.qte_id,100,"unknown"))
	check(not session._take_remote().qte,"unknown judgment kind remains rejected")
	world.simulation_tick=120
	session.receive_input(packet(session,4,world.qte_id,100))
	check(not session._take_remote().qte,"preparation guard does not weaken the 15-tick history bound")
	world.qte_age=world.qte_timing.lead+world.qte_timing.sweep*(world.qte_zone+world.qte_width*0.5)
	session._remember_qte(); var valid_tick: int=world.simulation_tick
	world.simulation_tick+=5; world.qte_age+=5*DT
	session.receive_input(packet(session,5,world.qte_id,valid_tick))
	world.advance_tick(session._take_remote(),{})
	check(world.hooked==world.HookState.FREE and world.round_stats.fish_good==1,"verified green history still succeeds after ordinary transport delay")
	session.presentation.dispose(); session.free(); world.free()

# Transport drains up to eight packets together. A warning edge is not a
# judgment and cannot consume a later fresh visible edge in that same batch.
func batch_checks() -> void:
	for kind: String in ["regular","fish_effort","angler_effort","untangle"]:
		for mode: String in ["warning_green","visible_miss_green","wrong_identity","expired_history"]:
			var values: Dictionary={"line_force":0.0,"water_strength":0.0,"timer_enabled":false,"hunger_enabled":false,"instinct_max_strength":0.0}
			for prefix: String in ["qte_entry_","qte_fish_effort_","qte_angler_effort_","qte_untangle_"]:
				values[prefix+"lead"]=0.4; values[prefix+"sweep"]=0.5; values[prefix+"window"]=0.04
				values[prefix+"random"]=false; values[prefix+"zone"]=0.1
			var world:=World.new()
			world.reset_world({"npc_count":0,"rules":values})
			world.fish=Vector2(100,380); world.fish_before=world.fish; world.aim=Vector2.RIGHT
			for bait: Dictionary in world.baits: bait.active=false
			world._enter_hook(0)
			var role: String="fish" if kind in ["regular","fish_effort"] else "angler"
			var wire_kind: String="regular" if kind=="regular" else "effort"
			if kind!="regular": world._attach_hook()
			if kind=="untangle":
				world._update_contacts(0); world._begin_wrap(); world._commit_wrap()
				world.wraps[0].progress=1.0; world.untangle_cooldown=0.0
				world.fish+=Vector2(48,0); world.fish_before=world.fish
				world.fish_line_length=world.mouth().distance_to(world.wraps[0].entry)-(0.4-0.18)*world.rule("line_elastic"); world.tension=0.4
				world._begin_untangle()
			elif kind!="regular": world.Effort.open(world.effort_checks[role],world.rng,world.effort_tuning(role))
			var identity: int=world.qte_id if kind=="regular" else world.effort_checks[role].id
			var session:=Session.new(); session.game=world; session.remote_role=role; session.session_id="batch-"+kind; session.round_id=1
			var first_tick: int=102 if mode=="visible_miss_green" else 100
			var first_age: float=0.4+DT if mode=="visible_miss_green" else 0.4-DT
			world.simulation_tick=first_tick
			if kind=="regular": world.qte_age=first_age
			else: world.effort_checks[role].age=first_age
			if kind=="untangle": world.tension=0.1 # Invalid warning-era tension must not taint the later valid press.
			session._remember_qte()
			if kind=="untangle": world.tension=0.4
			world.simulation_tick=106
			if kind=="regular": world.qte_age=0.4+5*DT
			else: world.effort_checks[role].age=0.4+5*DT
			session._remember_qte()
			world.simulation_tick=108
			if kind=="regular": world.qte_age=0.4+7*DT
			else: world.effort_checks[role].age=0.4+7*DT
			session.receive_input(packet(session,1,identity,first_tick,wire_kind))
			var seq:=2
			for seen_tick in range(first_tick+1,106):
				var neutral: Dictionary=packet(session,seq,identity,seen_tick,wire_kind)
				neutral.command={}; session.receive_input(neutral); seq+=1
			session.receive_input(packet(session,seq,identity+(1 if mode=="wrong_identity" else 0),90 if mode=="expired_history" else 106,wire_kind))
			var command: Dictionary=session._take_remote()
			var expected_age: float=0.4+5*DT if mode=="warning_green" else first_age
			check(command.qte and is_equal_approx(command.qte_at_age,expected_age) and session.remote_queue.is_empty() and (kind!="untangle" or command.qte_condition_valid==(mode=="warning_green")),kind+" batch "+mode+": selects only the first valid visible history age, never client-forged age")
			var total_before: int=world.round_stats[role+"_total"]
			var good_before: int=world.round_stats[role+"_good"]
			world.advance_tick(command if role=="fish" else {},command if role=="angler" else {})
			var expected_total: int=total_before+(1 if mode in ["warning_green","visible_miss_green"] else 0)
			var expected_good: int=good_before+(1 if mode=="warning_green" else 0)
			check(world.round_stats[role+"_total"]==expected_total and world.round_stats[role+"_good"]==expected_good,kind+" batch "+mode+": fresh green succeeds, first visible miss is final, invalid candidate cannot judge")
			check(session.qte_accepted==(2 if mode=="warning_green" else 1) and not session._take_remote().qte,kind+" batch "+mode+": accepted candidates are bounded and cannot replay as held input")
			session.presentation.dispose(); session.free(); world.free()

func frame(command: Dictionary={}) -> void:
	host.network.poll(); client.network.poll()
	client.network.tick(DT,command); host.network.tick(DT,{})
	await create_timer(0.017).timeout

func phase(wanted: String) -> bool:
	for tick in 340:
		await frame()
		if host.network.status==wanted and client.network.status==wanted: return true
		if host.network.status=="failed" or client.network.status=="failed": return false
	return false

func begin_pair(local_role: String, port: int) -> bool:
	host=Main.instantiate(); client=Main.instantiate(); root.add_child(host); root.add_child(client)
	for game: Node2D in [host,client]:
		game.capture_mode="player-hook-network"; game.set_process(false); game.set_physics_process(false)
		game.save_path="user://player-hook-network-"+str(game.get_instance_id())+".cfg"
	var values: Dictionary={"water_strength":0.0,"line_force":0.0,"timer_enabled":false,"hunger_enabled":false,"instinct_max_strength":0.0,
		"qte_entry_lead":0.8,"qte_entry_random":false,"qte_entry_zone":0.4,
		"qte_angler_effort_lead":0.8,"qte_angler_effort_random":false,"qte_angler_effort_zone":0.4,
		"qte_untangle_lead":0.8,"qte_untangle_random":false,"qte_untangle_zone":0.4}
	var connected: bool=host.network.host_game(local_role,port,{"rules":values})==OK and client.network.join_game("127.0.0.1",port)==OK
	check(connected,"actual ENet connects with host role "+local_role)
	if not connected or not await phase("waiting"): check(false,"actual ENet handshake: "+local_role); return false
	host.network.set_ready(true); client.network.set_ready(true)
	if not await phase("playing"): check(false,"actual ENet countdown: "+local_role); return false
	for bait: Dictionary in host.baits:
		bait.active=false
		for grain: Dictionary in bait.grains: grain.eaten=true
	host.fish=Vector2(250,200); host.fish_before=host.fish; host.aim=Vector2.RIGHT; host.velocity=Vector2.ZERO
	return true

func end_pair() -> void:
	if is_instance_valid(host): host.network.close(); host.queue_free()
	if is_instance_valid(client): client.network.close(); client.queue_free()
	await process_frame

func press_cycle(role: String, kind: String) -> void:
	var early_sent:=false
	var early_seen:=false
	var green_sent:=false
	var visible_without_buffer:=false
	var starting_total: int=host.round_stats[role+"_total"]
	var starting_good: int=host.round_stats[role+"_good"]
	var accepted_before: int=host.network.qte_accepted
	for tick in 210:
		var view: Node2D=client.network.display_world()
		var state: Dictionary=view.skill_check(role)
		var command: Dictionary={}
		if state.active and state.kind==kind:
			if not early_sent and state.age<state.lead*0.5:
				command={"qte":true,"qte_at_age":9.0}; early_sent=true
			if early_sent and state.age>=state.lead+0.05 and not green_sent:
				early_seen=host.network.qte_accepted>accepted_before
				visible_without_buffer=host.round_stats[role+"_total"]==starting_total
			if not green_sent and state.progress>=state.zone+state.width*0.35 and state.progress<=state.zone+state.width*0.8:
				command={"qte":true}; green_sent=true
		await frame(command)
		if host.round_stats[role+"_total"]>starting_total:
			for wait_tick in 8: await frame()
			break
	check(early_sent and early_seen,role+" "+kind+": actual remote preparation edge reaches authority")
	check(visible_without_buffer,role+" "+kind+": ignored edge is neither failed nor buffered into sweep")
	check(green_sent and host.round_stats[role+"_total"]==starting_total+1 and host.round_stats[role+"_good"]==starting_good+1,role+" "+kind+": fresh displayed-green press resolves exactly once")
	check(host.network.qte_accepted==accepted_before+2,role+" "+kind+": transport accepts exactly two fresh edges, without held replays")
	check(client.round_stats[role+"_total"]==host.round_stats[role+"_total"] and client.round_stats[role+"_good"]==host.round_stats[role+"_good"],role+" "+kind+": public result converges across actual ENet")

func live_checks() -> void:
	if await begin_pair("angler",24931):
		host._enter_hook(0); host.network._remember_qte(); host.network._send_state(true)
		await press_cycle("fish","entry")
		check(host.hooked==host.HookState.FREE and client.hooked==client.HookState.FREE,"remote fish entry success releases the hook on both peers")
	await end_pair()
	if await begin_pair("fish",24932):
		host._enter_hook(0); host._attach_hook()
		host.Effort.open(host.effort_checks.angler,host.rng,host.effort_tuning("angler"))
		host.network._remember_qte(); host.network._send_state(true)
		await press_cycle("angler","effort")
		check(host.effort_checks.angler.good and host.effort_multiplier("angler")>1,"remote angler effort retains its configured successful boost")
		host._clear_hook(); host.fish=Vector2(100,380); host.fish_before=host.fish; host.velocity=Vector2.ZERO
		host._enter_hook(0); host._attach_hook(); host._update_contacts(0); host._begin_wrap(); host._commit_wrap()
		host.wraps[0].progress=1.0; host.untangle_cooldown=0.0; host.fish+=Vector2(48,0); host.fish_before=host.fish
		host.fish_line_length=host.mouth().distance_to(host.wraps[0].entry)-(0.4-0.18)*host.rule("line_elastic"); host.tension=0.4
		host.network._remember_qte(); host.network._send_state(true)
		for tick in 8: await frame()
		await frame({"untangle":true})
		await press_cycle("angler","untangle")
		check(host.untangle_phase=="unwind" and host.effort_checks.angler.good,"remote angler can still begin actual coil removal with valid tension")
	await end_pair()

func run() -> void:
	queue_checks(); batch_checks(); await live_checks()
	print("PLAYER_HOOK_NETWORK | passed=",passed," | failed=",failed)
	quit(1 if failed else 0)

func _initialize() -> void: call_deferred("run")
