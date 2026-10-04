extends "res://scripts/world_simulation.gd"

# Small real-ENet application adapter. No views, profile writes or platform input
# are needed to exercise the production session and its unmodified wire codec.
class TestSession extends "res://scripts/network_session.gd":
	var transform_packet: Callable
	var sent: Array[Dictionary]=[]
	func _send(packet: Dictionary, reliable: bool, channel: int) -> void:
		var wire:=packet.duplicate(true)
		if transform_packet.is_valid(): wire=transform_packet.call(wire)
		if wire.is_empty(): return
		sent.append(wire.duplicate(true))
		super._send(wire,reliable,channel)

var network: TestSession
var rounds_started := 0
var results_presented := 0

func _init() -> void:
	super._init()
	network=TestSession.new()
	network.game=self
	add_child(network)

func start_shared_session(_role: String, config: Dictionary) -> void:
	if reset_world(config): rounds_started+=1

func _present_result(_winner: String, _cause: String) -> void:
	results_presented+=1
