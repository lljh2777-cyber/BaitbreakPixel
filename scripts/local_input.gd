extends RefCounted

# The only gameplay component that reads the keyboard/mouse. No world-state writes.
var net_events: Array[Dictionary]=[]
var power_steps := 0
var needs_neutral := false

func reset() -> void:
	net_events.clear()
	power_steps=0
	needs_neutral=false

func suspend() -> void:
	net_events.clear()
	net_events.append({"kind":"suspend"})
	power_steps=0
	needs_neutral=true

func handle(event: InputEvent, role: String, point: Vector2) -> void:
	if needs_neutral: return
	if role=="angler":
		if event.is_action_released("use") or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed):
			net_events.append({"kind":"cancel"})
		elif event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed):
			if Input.is_action_pressed("use") and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				net_events.append({"kind":"point","point":point})
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: power_steps+=1
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: power_steps-=1

func fish_command(world: Node2D, pointer: Vector2) -> Dictionary:
	var direction: Vector2=pointer-world.fish
	var result := {
		"move":Input.get_vector("left","right","up","down"),
		"aim":direction.normalized() if direction.length()>4 else world.aim,
		"power":clampf(world.power+power_steps*0.1,0.1,1),
		"suck":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"dash":Input.is_action_pressed("dash"),
		"slow":Input.is_action_pressed("slow"),"qte":Input.is_action_just_pressed("qte"),"home":Input.is_action_just_pressed("use")
	}
	power_steps=0
	return result

func angler_command(_world: Node2D, pointer: Vector2) -> Dictionary:
	var held := Input.is_action_pressed("use")
	var drag := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if needs_neutral and not held and not drag: needs_neutral=false
	var result := {
		"target":pointer,"walk":Input.get_axis("left","right"),
		"deploy":Input.is_action_just_pressed("slow"),"reel":Input.is_action_pressed("up"),"release":Input.is_action_pressed("down"),
		"net_hold":held and not needs_neutral,"drag":drag and not needs_neutral,
		"net_events":net_events.duplicate(true)
	}
	net_events.clear()
	return result
