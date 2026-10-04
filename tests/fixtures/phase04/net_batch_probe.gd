extends SceneTree

# Independent inherited-edge diagnostic, not a green acceptance test.
# Captures unmodified authority/wire behavior for same-tick versus staged input.
# Run the identical external file against immutable baseline and current source.
const World=preload("res://scripts/world_simulation.gd")
const FishWire=preload("res://scripts/fish_network_observation.gd")
const AnglerWire=preload("res://scripts/angler_network_observation.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
func sample(world: Node2D, tick: int) -> Dictionary:
 var peer:=World.new(); peer.reset_world({"seed":1})
 var fish: Dictionary=Protocol.unpack_state(Protocol.pack_state(FishWire.capture(world)))
 var result: Dictionary={"tick":tick,"net_state":world.net_state,"observing":world.net_action.observing,
  "net_age_variant_type":type_string(typeof(world.net_action.age)),"net_age":world.net_action.age,
  "authority_restore":peer.restore_snapshot(world.capture_snapshot()),
  "fish_wire_valid":FishWire.valid(peer,fish),"fish_wire_apply":FishWire.apply(peer,fish),
  "angler_wire_valid":AnglerWire.valid(peer,AnglerWire.capture(world))}
 peer.free(); return result
func _initialize() -> void:
 var results: Array=[]
 var events: Array=[{"kind":"toggle"},{"kind":"point","point":Vector2(210,140)},{"kind":"point","point":Vector2(310,140)}]
 for batching: bool in [true,false]:
  var world:=World.new()
  world.reset_world({"seed":75401,"ruleset":"duel","challenge":true,"npc_count":3,"rules":{"hunger_enabled":false,"water_strength":0.0,"instinct_max_strength":0.0}})
  world.angler.x=234.0; world.angler.previous_anchor=world.angler.anchor(); world.angler.auto_net=false
  world.fish=Vector2(1000,320); world.fish_before=world.fish
  for bait: Dictionary in world.baits: bait.active=false
  var checkpoints: Array=[sample(world,-1)]
  for tick in 120:
   var command: Dictionary={"auto_net":false}
   if batching and tick==0: command.net_events=events
   if not batching and tick<3: command.net_events=[events[tick]]
   world.advance_tick({},command)
   if tick in [0,1,2,30,60,119]: checkpoints.append(sample(world,tick))
  results.append({"input":"same-tick batch" if batching else "separate authority ticks","checkpoints":checkpoints})
  world.free()
 var report: Dictionary={"engine":Engine.get_version_info().string,"cases":results,
  "scope":"Direct actual authority/wire capture/compression/apply reproduction; no actual ENet or frequency claim"}
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="):
   var f:=FileAccess.open(argument.trim_prefix("--output="),FileAccess.WRITE)
   f.store_string(JSON.stringify(report,"\t")+"\n"); f.close()
 print("P40_NET_BATCH_PROBE_COMPLETE")
 quit()
