extends Node
## Read-only review scene. Freeze the simulation and compare identical snapshots.
const Main=preload("res://scenes/main.tscn")
const View=preload("res://tools/watergen/composition_view.gd")
const Resolver=preload("res://scripts/maps/map_resolver.gd")
var game: Node2D
var viewport: SubViewport
var display: TextureRect
var caption: Label
var baseline:=false
var selected:="A"
var map_seed:=42
var full_world:=true

func _ready() -> void:
	get_window().size=Vector2i(1440,810)
	get_window().content_scale_size=Vector2i(960,540)
	get_window().title="水下构图重做 · 静态草案 A / B / C"
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,480)
	viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	game=Main.instantiate(); viewport.add_child(game)
	game.capture_mode="composition-review"; game.menu.close(); freeze(game)
	game.set_process_input(false); game.set_process_unhandled_input(false)
	var old: Node=game.view; game.remove_child(old); old.free()
	game.view=View.new(); game.view.game=game; game.add_child(game.view)
	var background:=ColorRect.new(); background.color=Color("102c36"); background.size=Vector2(960,540); add_child(background)
	display=TextureRect.new(); display.texture=viewport.get_texture(); display.position=Vector2(0,116); display.size=Vector2(960,360)
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; add_child(display)
	var title:=Label.new(); title.text="第一轮重做 · 只看坡面与大形体"; title.position=Vector2(22,10); title.add_theme_font_size_override("font_size",23); add_child(title)
	caption=Label.new(); caption.position=Vector2(22,79); caption.add_theme_font_size_override("font_size",15); add_child(caption)
	var actions: Array=[
		["A 斜木宽谷",func(): choose("A")],["B 双岸跨谷",func(): choose("B")],["C 石坡浅湾",func(): choose("C")],
		["原版 / 方案",func(): baseline=not baseline; refresh()],
		["全景 / 游戏 HUD",func(): full_world=not full_world; refresh()],
		["地图 42 / 1346",func(): map_seed=1346 if map_seed==42 else 42; load_map()]]
	for i in actions.size():
		var button:=Button.new(); button.text=actions[i][0]; button.position=Vector2(22+i*155,45); button.size=Vector2(146,29); button.pressed.connect(actions[i][1]); add_child(button)
	var note:=Label.new(); note.text="静态美术草案，地形不参与碰撞；左右键移镜头。原植物与杂物暂隐，未增加生态细节。"; note.position=Vector2(22,506); note.add_theme_font_size_override("font_size",15); add_child(note)
	load_map()

static func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func choose(id: String) -> void:
	selected=id; baseline=false; refresh()

func load_map() -> void:
	game.reset_world({"map_source":Resolver.generated(map_seed,3),"seed":64317,"challenge":false})
	game.fish=Vector2(620,286); game.fish_before=game.fish; game.elapsed=2.0; game.player_role="fish"
	refresh()

func refresh() -> void:
	game.view.choice=selected; game.view.overview=full_world
	game.view.show_baseline=baseline
	viewport.size=Vector2i(1280,480) if full_world else Vector2i(640,360)
	display.position=Vector2(0,116) if full_world else Vector2(170,111)
	display.size=Vector2(960,360) if full_world else Vector2(620,349)
	caption.text="Seed %d · %s · %s" % [map_seed,"原版" if baseline else selected+" 构图草案","1280 × 480 全景" if full_world else "HUD / 可读性叠加"]
	game.view.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	if event.keycode in [KEY_LEFT,KEY_RIGHT]:
		game.fish.x=clampf(game.fish.x+(-80 if event.keycode==KEY_LEFT else 80),40,1240)
		game.fish=game.map_context.constrain_to_bed(game.fish,12); game.fish_before=game.fish
		refresh()
