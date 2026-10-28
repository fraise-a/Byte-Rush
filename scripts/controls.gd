class_name RushControls
extends Node

signal prompts_changed
var game: Node3D
var family:="keyboard"
var active_device:=-1
var devices: Dictionary={}
var notice:=""
var repeat_action:=""
var repeat_time:=0.0

func _ready() -> void:
	Input.joy_connection_changed.connect(connection_changed)
	for id in Input.get_connected_joypads():
		remember_device(id,Input.get_joy_name(id),Input.get_joy_info(id))
	rebuild_menu_bindings()
	if not devices.is_empty():
		select_device(devices.keys()[0])

static func detect_family(device_name: String, info: Dictionary={}) -> String:
	var text:=(device_name+" "+str(info.get("raw_name",""))).to_lower()
	var vendor:=int(info.get("vendor_id",0))
	if vendor==0x054c or "dualsense" in text or "dualshock" in text or "playstation" in text or "ps4" in text or "ps5" in text or "sony" in text:
		return "playstation"
	if vendor==0x057e or "nintendo" in text or "switch" in text or "joy-con" in text or "joycon" in text:
		return "nintendo"
	if vendor==0x045e or "xbox" in text or "xinput" in text or "microsoft" in text:
		return "xbox"
	return "generic"

func remember_device(id: int, device_name: String, info: Dictionary={}) -> void:
	devices[id]={"name":device_name,"family":detect_family(device_name,info)}

func rebuild_menu_bindings() -> void:
	# macOS defaults omit joypad Confirm/Back. Keep keyboard bindings and explicitly
	# install each connected pad's convention, including Nintendo's east-button A.
	for action in ["ui_accept","ui_cancel"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				InputMap.action_erase_event(action,event)
	for id in devices:
		var nintendo: bool=devices[id].family=="nintendo"
		for pair in [["ui_accept",JOY_BUTTON_B if nintendo else JOY_BUTTON_A],["ui_cancel",JOY_BUTTON_A if nintendo else JOY_BUTTON_B]]:
			var event:=InputEventJoypadButton.new()
			event.device=id
			event.button_index=pair[1]
			InputMap.action_add_event(pair[0],event)
	var directions:={"ui_up":[JOY_BUTTON_DPAD_UP,JOY_AXIS_LEFT_Y,-1.0],"ui_down":[JOY_BUTTON_DPAD_DOWN,JOY_AXIS_LEFT_Y,1.0],"ui_left":[JOY_BUTTON_DPAD_LEFT,JOY_AXIS_LEFT_X,-1.0],"ui_right":[JOY_BUTTON_DPAD_RIGHT,JOY_AXIS_LEFT_X,1.0]}
	for action in directions:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action,event)
		InputMap.action_set_deadzone(action,0.5)
		var button:=InputEventJoypadButton.new()
		button.device=-1
		button.button_index=directions[action][0]
		InputMap.action_add_event(action,button)
		var stick:=InputEventJoypadMotion.new()
		stick.device=-1
		stick.axis=directions[action][1]
		stick.axis_value=directions[action][2]
		InputMap.action_add_event(action,stick)

func select_device(id: int) -> void:
	if not devices.has(id):
		remember_device(id,Input.get_joy_name(id),Input.get_joy_info(id))
		rebuild_menu_bindings()
	var had_notice:=not notice.is_empty()
	var changed: bool=family!=devices[id].family or active_device!=id
	notice=""
	set_active(devices[id].family,id)
	if had_notice and not changed:
		prompts_changed.emit()

func set_active(next_family: String, id: int = -1) -> void:
	if family==next_family and active_device==id:
		return
	family=next_family
	active_device=id
	repeat_action=""
	update_cursor()
	prompts_changed.emit()

func update_cursor() -> void:
	var driving: bool=is_instance_valid(game.ui) and game.ui.screen=="race"
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN if driving or family!="keyboard" else Input.MOUSE_MODE_VISIBLE

func connection_changed(id: int, connected: bool) -> void:
	if connected:
		notice=""
		remember_device(id,Input.get_joy_name(id),Input.get_joy_info(id))
		rebuild_menu_bindings()
		select_device(id)
	else:
		devices.erase(id)
		rebuild_menu_bindings()
		if id==active_device:
			notice="Controller disconnected. Reconnect or switch input devices."
			for action in ["accelerate","brake","left","right","drift","capacitor","item"]:
				Input.action_release(action)
			set_active("keyboard")
			if not game.in_menu and not game.paused and game.player.finish_time<0:
				game.toggle_pause()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		select_device(event.device)
	elif event is InputEventJoypadMotion:
		var meaningful: bool=absf(event.axis_value)>0.35 if event.axis<=JOY_AXIS_RIGHT_Y else event.axis_value>0.2
		if meaningful:
			select_device(event.device)
	elif event is InputEventKey and event.pressed and not event.echo:
		set_active("keyboard")
	elif event is InputEventMouseButton and event.pressed:
		set_active("keyboard")
	elif event is InputEventMouseMotion and maxf(event.relative.length(),event.screen_relative.length())>2:
		set_active("keyboard")
	if family!="keyboard" and is_instance_valid(game.ui) and game.ui.screen!="race":
		game.ui.ensure_focus()

func _process(delta: float) -> void:
	if family=="keyboard" or not is_instance_valid(game.ui) or game.ui.screen=="race":
		repeat_action=""
		return
	var direction:=Input.get_vector("ui_left","ui_right","ui_up","ui_down",0.5)
	var action:=""
	if direction.length()>0.1:
		action=("ui_right" if direction.x>0 else "ui_left") if absf(direction.x)>absf(direction.y) else ("ui_down" if direction.y>0 else "ui_up")
	if action!=repeat_action:
		repeat_action=action
		repeat_time=0.38
	elif action!="":
		repeat_time-=delta
		if repeat_time<=0:
			repeat_time=0.12
			var event:=InputEventAction.new()
			event.action=action
			event.pressed=true
			get_viewport().push_input(event)
			event=event.duplicate()
			event.pressed=false
			get_viewport().push_input(event)

func title() -> String:
	return {"keyboard":"Keyboard & Mouse","playstation":"PlayStation","xbox":"Xbox","nintendo":"Nintendo","generic":"Gamepad"}[family]

func prompt(action: String) -> String:
	var keys:={"confirm":"Enter","back":"Esc","navigate":"Arrows / Tab","adjust":"Left / Right","accelerate":"W / Up","brake":"S / Down","steer":"A / D","drift":"Space","capacitor":"Shift","item":"E","recover":"R","pause":"Esc"}
	if family=="keyboard":
		return keys.get(action,action)
	var shared:={"navigate":"Stick / D-pad","adjust":"Left / Right","steer":"Left Stick"}
	if shared.has(action):
		return shared[action]
	var pads:={
		"playstation":{"confirm":"Cross","back":"Circle","accelerate":"R2","brake":"L2","drift":"Cross","capacitor":"R1","item":"Square","recover":"Triangle","pause":"Options"},
		"xbox":{"confirm":"A","back":"B","accelerate":"RT","brake":"LT","drift":"A","capacitor":"RB","item":"X","recover":"Y","pause":"Menu"},
		"nintendo":{"confirm":"A","back":"B","accelerate":"ZR","brake":"ZL","drift":"B","capacitor":"R","item":"Y","recover":"X","pause":"+"},
		"generic":{"confirm":"South","back":"East","accelerate":"Right Trigger","brake":"Left Trigger","drift":"South","capacitor":"Right Shoulder","item":"West","recover":"North","pause":"Start"}}
	return pads[family].get(action,action)

func drift_tip_description() -> String:
	return "Hold %s through a corner. Release at amber, cyan or violet for a stronger turbo."%prompt("drift")

func driving_help() -> String:
	return "%s / %s  Drive · %s  Steer\n%s  Drift · %s  Boost · %s  Item · %s  Recover"%[prompt("accelerate"),prompt("brake"),prompt("steer"),prompt("drift"),prompt("capacitor"),prompt("item"),prompt("recover")]

func _exit_tree() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
