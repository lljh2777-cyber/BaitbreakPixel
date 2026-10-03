extends RefCounted

# Keep the established angler protocol for pre-Phase-3 systems, but carry no NPC
# brain/replay data. Authority snapshots remain a separate, exact replay contract.
const World=preload("res://scripts/world_simulation.gd")
const Snapshot=preload("res://scripts/world_snapshot.gd")
const NPCPublic=preload("res://scripts/npc_fish_public_state.gd")
const Protocol=preload("res://scripts/network_protocol.gd")
const FORMAT := "angler-presentation"
const NPC_PROFILE_VERSION := 4
const PRIVATE_WORLD_FIELDS := ["next_fish_id","npc_foraging_enabled","npc_social_enabled","public_hook_cue","npc_hook_enabled"]
const FIELDS := ["format","role","npc_profile_version","schema","bait_profile_version","map_id","state","rig","rng_seed","rng_state"]

static func capture(world: Node2D) -> Dictionary:
	var snapshot: Dictionary=world.capture_snapshot()
	snapshot.format=FORMAT
	snapshot.role="angler"
	snapshot.npc_profile_version=NPC_PROFILE_VERSION
	snapshot.state.npc_fishes=NPCPublic.capture(world.npc_fishes,world.hook_target_fish_id,world.npc_hook)
	snapshot.state.npc_hook=NPCPublic.capture_hook(world.npc_hook)
	snapshot.state.public_npc_hook_result=NPCPublic.capture_result(world.public_npc_hook_result)
	for key: String in PRIVATE_WORLD_FIELDS: snapshot.state.erase(key)
	for key: String in World.Stats.NPC_FIELDS: snapshot.state.round_stats.erase(key)
	return snapshot

static func _authority(snapshot: Dictionary) -> Dictionary:
	if snapshot.size()!=FIELDS.size(): return {}
	for key: String in FIELDS:
		if not snapshot.has(key): return {}
	if snapshot.format!=FORMAT or snapshot.role!="angler" or not snapshot.npc_profile_version is int or snapshot.npc_profile_version!=NPC_PROFILE_VERSION: return {}
	if not snapshot.schema is int or not snapshot.state is Dictionary or not Protocol.safe_values(snapshot): return {}
	if not snapshot.state.get("fish_id") is int or not NPCPublic.valid(snapshot.state.get("npc_fishes"),snapshot.state.fish_id): return {}
	if snapshot.state.size()!=Snapshot.WORLD_FIELDS.size()-PRIVATE_WORLD_FIELDS.size(): return {}
	for key: String in Snapshot.WORLD_FIELDS:
		if key not in PRIVATE_WORLD_FIELDS and not snapshot.state.has(key): return {}
	for key: String in PRIVATE_WORLD_FIELDS:
		if snapshot.state.has(key): return {}
	if not snapshot.state.get("round_stats") is Dictionary: return {}
	for key: String in World.Stats.NPC_FIELDS:
		if snapshot.state.round_stats.has(key): return {}
	# Validate the unchanged existing authority fields using their established
	# schema. Do not fabricate private NPC state or retain locally generated AI.
	var result: Dictionary=bytes_to_var(var_to_bytes(snapshot))
	result.erase("format"); result.erase("role"); result.erase("npc_profile_version")
	result.state.next_fish_id=2
	result.state.npc_hook_enabled=false
	result.state.npc_foraging_enabled=false
	result.state.npc_social_enabled=false
	result.state.public_hook_cue={"tick":-1,"position":Vector2.ZERO}
	var defaults: Dictionary=World.Stats.fresh()
	for key: String in World.Stats.NPC_FIELDS: result.state.round_stats[key]=defaults[key]
	return result

static func valid(_world: Node2D, snapshot: Dictionary) -> bool:
	var authority:=_authority(snapshot)
	if authority.is_empty(): return false
	var probe:=World.new()
	var accepted: bool=Snapshot.restore_angler_presentation(probe,authority)
	probe.free()
	return accepted

static func apply(world: Node2D, snapshot: Dictionary) -> bool:
	var authority:=_authority(snapshot)
	if authority.is_empty() or not Snapshot.restore_angler_presentation(world,authority): return false
	world.npc_fishes.assign(NPCPublic.capture(snapshot.state.npc_fishes))
	return true
