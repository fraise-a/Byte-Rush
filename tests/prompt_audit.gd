extends SceneTree
# Screen/profile matrix, using real input events to change device while screens stay open.
class AuditInputGate extends Node:
	func _input(event: InputEvent) -> void:
		# Keep incidental real mouse/controller activity out of this synthetic matrix.
		if event.device<8 and (event is InputEventMouse or event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
			get_viewport().set_input_as_handled()

var game
var checks: Array[String]=[]
var failures:=0
var elapsed:=0.0
const PROFILES:=["keyboard","playstation","xbox","nintendo","generic"]
const EXPECTED:={
	"keyboard":["Enter","Esc","Space","Shift","E","R","Esc","W / Up","S / Down"],
	"playstation":["Cross","Circle","Cross","R1","Square","Triangle","Options","R2","L2"],
	"xbox":["A","B","A","RB","X","Y","Menu","RT","LT"],
	"nintendo":["A","B","B","R","Y","X","+","ZR","ZL"],
	"generic":["South","East","South","Right Shoulder","West","North","Start","Right Trigger","Left Trigger"]}
const ACTIONS:=["confirm","back","drift","capacitor","item","recover","pause","accelerate","brake"]
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")
func _process(delta: float) -> bool:
	elapsed+=delta
	if elapsed>120:
		print("FAIL Prompt audit timed out")
		quit(2)
	return false
func check(ok: bool, description: String) -> void:
	var message:=("PASS " if ok else "FAIL ")+description
	print(message)
	checks.append(message)
	if not ok: failures+=1
func frames(count: int=3) -> void:
	for i in range(count): await process_frame
func freeze() -> void:
	for racer in game.racers: racer.set_physics_process(false)
func switch_to(family: String) -> void:
	var event: InputEvent
	if family=="keyboard":
		event=InputEventKey.new()
		event.device=64
		event.physical_keycode=KEY_F10
	else:
		event=InputEventJoypadButton.new()
		event.device=8+PROFILES.find(family)
		event.button_index=JOY_BUTTON_MISC1
	event.pressed=true
	Input.parse_input_event(event)
	await frames()
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await frames()
func texts(node: Node) -> Array[String]:
	var result: Array[String]=[]
	if node is Label or node is BaseButton: result.append(node.text)
	if node is Control and not node.tooltip_text.is_empty(): result.append(node.tooltip_text)
	for child in node.get_children(): result.append_array(texts(child))
	return result
func foreign_terms(family: String) -> Array[String]:
	var forbidden: Array[String]=[]
	if family!="keyboard": forbidden.append_array(["Space","Shift","Enter","Tab","Esc","Escape","WASD"])
	if family!="playstation": forbidden.append_array(["Cross","Circle","Square","Triangle","R1","R2","L1","L2","Options"])
	if family!="xbox": forbidden.append_array(["RT","LT","RB","LB"])
	if family!="nintendo": forbidden.append_array(["ZR","ZL"])
	return forbidden
func audit(context: String) -> void:
	await frames()
	var overlay: Control=game.ui.overlay
	var focus: Control=root.gui_get_focus_owner()
	for family in PROFILES+["keyboard"]:
		await switch_to(family)
		if DisplayServer.get_name()!="headless": RenderingServer.force_draw(false)
		var leaked: Array[String]=[]
		for text in texts(game.ui.root):
			for term in foreign_terms(family):
				var regex:=RegEx.new()
				regex.compile("\\b"+term+"\\b")
				if regex.search(text): leaked.append(text)
		var matched: bool=game.controls.family==family
		var intact: bool=game.ui.overlay==overlay and root.gui_get_focus_owner()==focus
		if not leaked.is_empty(): print("LEAK ",context," / ",family," ",leaked)
		check(matched and intact and leaked.is_empty(),context+" / "+family+": input prompts match and live switching preserves screen/focus")
		if context.begins_with("results"):
			var tip: Control=game.ui.overlay.get_node_or_null("ResultsDriftTip")
			check(tip!=null and tip.tooltip_text.contains(EXPECTED[family][2]),context+" / "+family+": drift tip follows the active drift binding")
func capture(name: String) -> void:
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false)
		var error:=root.get_texture().get_image().save_png("user://prompt_audit_"+name+".png")
		if error!=OK: check(false,"Could not save "+name+" capture")
func run() -> void:
	await frames()
	game.add_child(AuditInputGate.new())
	game.profile_prefix="validation_prompt_audit_"
	game.volume=0
	game.apply_settings()
	game.set_physics_process(false)
	game.set_process(false)
	for entry in [[9,"DualSense Wireless Controller"],[10,"Xbox Wireless Controller"],[11,"Nintendo Switch Pro Controller"],[12,"USB Gamepad"]]:
		game.controls.remember_device(entry[0],entry[1])
	game.controls.rebuild_menu_bindings()
	for family in PROFILES:
		await switch_to(family)
		var actual: Array[String]=[]
		for action in ACTIONS: actual.append(game.controls.prompt(action))
		check(actual==EXPECTED[family],family+": independent binding expectations match the prompt profile")
	game.return_to_menu(); freeze()
	await audit("main menu")
	game.ui.settings("main")
	await audit("main settings")
	game.start_race("Grand Prix"); freeze()
	await audit("countdown")
	game.countdown=0; game.racing=true
	await audit("driving HUD")
	game.toggle_pause()
	await audit("pause menu")
	game.ui.settings("pause")
	await audit("paused settings")
	game.toggle_pause()
	for mode in ["Grand Prix","Time Trial"]:
		game.start_race(mode); freeze()
		game.countdown=0; game.racing=true; game.race_time=90
		game.player.lap=3
		game.player.lap_times.assign([30.0,30.0,30.0])
		game.player.finish_time=90
		game.racer_finished(game.player)
		await audit("results "+mode)
		for family in PROFILES:
			await switch_to(family)
			capture(family+"-results"+("-tt" if mode=="Time Trial" else ""))
	game.start_race("Grand Prix"); freeze()
	game.countdown=0; game.racing=true
	await switch_to("playstation")
	game.controls.connection_changed(9,false)
	check(game.paused and game.controls.family=="keyboard","Active-controller disconnect selects a safe keyboard fallback")
	await switch_to("xbox")
	check(game.controls.notice.is_empty() and game.ui.connection_label.text.is_empty(),"Switching to another controller clears stale disconnect instructions")
	var report:={"version":game.VERSION,"passed":failures==0,"headless":DisplayServer.get_name()=="headless","contexts":8,"profiles":PROFILES,"checks":checks}
	var file:=FileAccess.open("user://prompt_audit_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("PROMPT_AUDIT_REPORT "+ProjectSettings.globalize_path("user://prompt_audit_results.json"))
	game.free()
	quit(0 if failures==0 else 1)
