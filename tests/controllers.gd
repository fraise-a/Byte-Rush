extends SceneTree
# Parsed standard SDL/Godot events exercise the same GUI path as real pads.
var game
var failures:=0
var checks: Array[String]=[]
var elapsed:=0.0
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")
func _process(delta: float) -> bool:
	elapsed+=delta
	if elapsed>120:
		print("FAIL Controller regression timed out")
		quit(2)
	return false
func check(ok: bool, description: String) -> void:
	var message:=("PASS " if ok else "FAIL ")+description
	checks.append(message)
	print(message)
	if not ok:
		failures+=1
func frames(count: int=3) -> void:
	for i in range(count):
		await process_frame
func button(id: int, index: int) -> void:
	var event:=InputEventJoypadButton.new()
	event.device=id
	event.button_index=index
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await frames(2)
func axis(id: int, which: int, value: float) -> void:
	var event:=InputEventJoypadMotion.new()
	event.device=id
	event.axis=which
	event.axis_value=value
	Input.parse_input_event(event)
	await frames(2)
func run() -> void:
	await frames()
	game.profile_prefix="validation_controllers_"
	game.volume=0
	game.apply_settings()
	var controls: RushControls=game.controls
	for entry in [[8,"DualSense Wireless Controller","playstation"],[9,"Xbox Wireless Controller","xbox"],[10,"Nintendo Switch Pro Controller","nintendo"],[11,"USB Gamepad","generic"]]:
		controls.remember_device(entry[0],entry[1])
	controls.rebuild_menu_bindings()
	check(RushControls.detect_family("Wireless Controller",{"vendor_id":0x054c})=="playstation","Sony vendor ID identifies ambiguous wireless-controller names")
	check(RushControls.detect_family("Unknown",{"vendor_id":0x057e})=="nintendo","Nintendo vendor ID identifies Nintendo layout")
	for entry in [[8,"playstation",JOY_BUTTON_A],[9,"xbox",JOY_BUTTON_A],[10,"nintendo",JOY_BUTTON_B],[11,"generic",JOY_BUTTON_A]]:
		game.return_to_menu()
		await frames()
		controls.select_device(entry[0])
		root.gui_release_focus()
		await button(entry[0],entry[2])
		check(not game.in_menu and game.mode=="Grand Prix",entry[1]+" Confirm starts the focused Grand Prix from lost focus")
		check(controls.family==entry[1],entry[1]+" input selects the correct prompt family")
		game.start_race("Time Trial")
		game.countdown=0
		game.racing=true
		var p: RushKart=game.player
		p.spawn_at(1)
		var origin: Vector3=p.global_position
		await axis(entry[0],JOY_AXIS_TRIGGER_RIGHT,0.8)
		for i in range(60):
			await physics_frame
		check(p.speed>4 and p.global_position.distance_to(origin)>2,entry[1]+" trigger input accelerates the physical kart on a nonzero device ID")
		await axis(entry[0],JOY_AXIS_TRIGGER_RIGHT,0)
		await axis(entry[0],JOY_AXIS_LEFT_X,0.6)
		for i in range(10):
			await physics_frame
		check(p.steering>0.2,entry[1]+" analogue stick steers the physical kart")
		await axis(entry[0],JOY_AXIS_LEFT_X,0)
		p.spawn_at(1,-4)
		p.speed=24
		await axis(entry[0],JOY_AXIS_LEFT_X,0.4)
		var drift:=InputEventJoypadButton.new()
		drift.device=entry[0]
		drift.button_index=JOY_BUTTON_A
		drift.pressed=true
		Input.parse_input_event(drift)
		for i in range(20):
			await physics_frame
		check(not game.paused and p.drift_time>0.1,entry[1]+" south button drifts during gameplay without triggering menu Back")
		drift=drift.duplicate()
		drift.pressed=false
		Input.parse_input_event(drift)
		await axis(entry[0],JOY_AXIS_LEFT_X,0)
		p.item="Turbo Cell"
		p.item_delay=0
		await button(entry[0],JOY_BUTTON_X)
		check(p.item=="" and p.boost_time>1,entry[1]+" west face button activates the held item")
	game.return_to_menu()
	await frames()
	await button(9,JOY_BUTTON_DPAD_DOWN)
	await button(9,JOY_BUTTON_A)
	check(not game.in_menu and game.mode=="Time Trial","Xbox D-pad navigates to Time Trial and A activates it")
	game.return_to_menu()
	await frames()
	await button(8,JOY_BUTTON_START)
	check(not game.in_menu and game.mode=="Grand Prix","PlayStation Options starts a quick race from the main menu")
	await button(8,JOY_BUTTON_START)
	check(game.paused and game.ui.screen=="pause","PlayStation Options pauses the race")
	await button(8,JOY_BUTTON_B)
	check(not game.paused and game.ui.screen=="race","PlayStation Circle resumes from pause")
	game.toggle_pause()
	game.ui.settings("pause")
	await frames()
	await button(10,JOY_BUTTON_A)
	check(game.paused and game.ui.screen=="pause","Nintendo B backs out of Settings while preserving pause")
	game.return_to_menu()
	game.ui.settings("main")
	await frames()
	controls.select_device(8)
	var items: Array[Control]=game.ui.menu_controls()
	check(items.size()==7 and items.all(func(item):return item.focus_mode==Control.FOCUS_ALL and not item.focus_next.is_empty() and not item.focus_previous.is_empty()),"All seven Settings controls have explicit cyclic focus navigation")
	var resolution: OptionButton=items[0]
	await button(8,JOY_BUTTON_A)
	check(resolution.get_popup().visible,"PlayStation Cross opens the resolution dropdown")
	await button(8,JOY_BUTTON_B)
	check(not resolution.get_popup().visible and game.ui.screen=="settings","Circle closes a dropdown without leaving Settings")
	var volume: HSlider=items[2]
	volume.grab_focus()
	var prior: float=volume.value
	await button(8,JOY_BUTTON_DPAD_RIGHT)
	check(volume.value>prior,"Controller D-pad adjusts the focused volume slider")
	var quality: CheckButton=items[5]
	quality.grab_focus()
	var was_on:=quality.button_pressed
	await button(8,JOY_BUTTON_A)
	check(quality.button_pressed!=was_on,"PlayStation Cross toggles focused Settings checkbuttons")
	game.return_to_menu()
	await frames()
	await axis(8,JOY_AXIS_LEFT_Y,0.8)
	var initial: Control=root.gui_get_focus_owner()
	check(initial==game.ui.menu_controls()[1],"Left stick moves menu focus once immediately")
	await frames(28)
	check(root.gui_get_focus_owner()!=initial,"Holding the stick repeats navigation after a deliberate delay")
	await axis(8,JOY_AXIS_LEFT_Y,0)
	var resting: Control=root.gui_get_focus_owner()
	await frames(30)
	check(root.gui_get_focus_owner()==resting,"Releasing the stick stops navigation repeat")
	await axis(8,JOY_AXIS_LEFT_Y,0.1)
	check(controls.family=="playstation" and root.gui_get_focus_owner()==resting,"Small stick drift neither moves focus nor changes prompts")
	await axis(8,JOY_AXIS_LEFT_Y,0)
	var keyboard:=InputEventKey.new()
	keyboard.physical_keycode=KEY_TAB
	keyboard.pressed=true
	Input.parse_input_event(keyboard)
	await frames()
	check(controls.family=="keyboard" and controls.prompt("item")=="E","Keyboard input restores keyboard prompts")
	keyboard.pressed=false
	Input.parse_input_event(keyboard)
	controls.select_device(8)
	var mouse:=InputEventMouseMotion.new()
	mouse.relative=Vector2(10,0)
	Input.parse_input_event(mouse)
	await frames()
	check(controls.family=="keyboard" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Mouse movement restores mouse navigation and visible cursor")
	controls.select_device(10)
	check(controls.prompt("confirm")=="A" and controls.prompt("back")=="B" and controls.prompt("drift")=="B" and controls.prompt("item")=="Y" and controls.prompt("accelerate")=="ZR","Nintendo labels match physical button positions and menu convention")
	controls.select_device(8)
	check(controls.prompt("item")=="Square" and controls.prompt("recover")=="Triangle" and controls.prompt("pause")=="Options" and controls.prompt("accelerate")=="R2","PlayStation labels cover driving, items, recovery and pause")
	game.start_race("Grand Prix")
	game.countdown=0
	game.racing=true
	controls.connection_changed(8,false)
	check(game.paused and controls.family=="keyboard" and game.ui.screen=="pause","Disconnecting the active pad pauses safely and falls back to keyboard")
	game.return_to_menu()
	await frames()
	var key:=InputEventKey.new()
	key.keycode=KEY_ENTER
	key.physical_keycode=KEY_ENTER
	key.pressed=true
	Input.parse_input_event(key)
	await frames(2)
	key=key.duplicate()
	key.pressed=false
	Input.parse_input_event(key)
	await frames()
	check(not game.in_menu,"Keyboard Enter still activates the focused race button")
	game.volume=0
	game.apply_settings()
	check(AudioServer.is_bus_mute(0),"Master volume zero truly mutes output")
	game.volume=1
	game.apply_settings()
	check(not AudioServer.is_bus_mute(0) and is_zero_approx(AudioServer.get_bus_volume_db(0)),"Master volume maximum restores full mix gain")
	var limiter:=AudioServer.get_bus_effect(0,0) as AudioEffectHardLimiter
	check(limiter!=null and limiter.ceiling_db<=-1.0,"Master mix has a -1 dB ceiling to protect louder simultaneous effects")
	check(game.music.volume_db==3 and game.sfx.volume_db==3 and game.player.drift_audio.volume_db==0 and game.player.effects.volume_db==2,"Music, menu and kart effects use the revised audible mix levels")
	game.volume=0
	game.apply_settings()
	var file:=FileAccess.open("user://controllers_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":game.VERSION,"passed":failures==0,"headless":DisplayServer.get_name()=="headless","checks":checks},"  "))
	print("CONTROLLERS_REPORT "+ProjectSettings.globalize_path("user://controllers_results.json"))
	game.free()
	quit(0 if failures==0 else 1)
