extends Node3D

const VERSION := "1.0"
const Kart = preload("res://scripts/kart.gd")
var track: RushTrack
var racers: Array[RushKart] = []
var player: RushKart
var camera: Camera3D
var ui: RushUI
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var mode := "Grand Prix"
var difficulty := 1
var volume := 0.7
var sensitivity := 1.0
var fullscreen := false
var quality := true
var resolution_index := 4
var controls: RushControls
var display_system: RushDisplay
var records: Dictionary = {}
var profile_prefix := ""
var racing := false
var paused := false
var countdown := 0.0
var race_time := 0.0
var finishers: Array[RushKart] = []
var shake := 0.0
var menu_time := 0.0
var last_count := 4
var in_menu := true
var force_render := false
var test_mode := false
var test_frames := 0
var test_suite := 0
var test_results: Array[Dictionary] = []
var test_success := true
var effects: Array[Dictionary] = []

func _ready() -> void:
	# Scenery/effects animate per rendered frame. Only physical karts opt in.
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	seed(42)
	var args := OS.get_cmdline_user_args()
	setup_inputs()
	test_mode="--autotest" in args
	if test_mode:
		profile_prefix="validation_autotest_"
	load_settings()
	if test_mode:
		difficulty=1
		records={"lap":0.0,"total":0.0}
	if "--windowed" in args:
		fullscreen=false
	if test_mode or "--mute" in args:
		volume=0
	display_system=RushDisplay.new()
	add_child(display_system)
	build_world()
	controls=RushControls.new()
	controls.game=self
	add_child(controls)
	ui=RushUI.new()
	ui.game=self
	add_child(ui)
	apply_settings(true)
	music=AudioStreamPlayer.new()
	music.stream=load("res://assets/music.wav")
	music.volume_db=3
	add_child(music)
	play_audio(music)
	sfx=AudioStreamPlayer.new()
	sfx.volume_db=3
	add_child(sfx)
	return_to_menu()
	force_render="--force-render" in args
	if test_mode:
		volume=0
		apply_settings()
		start_race("Grand Prix")
		player.autopilot=true
		countdown=0.05
		print("TEST_BEGIN Grand Prix / Normal / Six Racers")
	elif "--show-race" in args:
		start_race("Grand Prix")
	elif "--demo" in args:
		start_race("Grand Prix")
		player.autopilot=true
	if "--mute" in args:
		volume=0
		apply_settings()

func setup_inputs() -> void:
	var keys := {"accelerate":[KEY_W,KEY_UP],"brake":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"drift":[KEY_SPACE],"capacitor":[KEY_SHIFT],"item":[KEY_E],"pause":[KEY_ESCAPE],"recover":[KEY_R]}
	for action in keys:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action,0.15)
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode=code
			InputMap.action_add_event(action,event)
	var axes := {"accelerate":[JOY_AXIS_TRIGGER_RIGHT,1.0],"brake":[JOY_AXIS_TRIGGER_LEFT,1.0],"left":[JOY_AXIS_LEFT_X,-1.0],"right":[JOY_AXIS_LEFT_X,1.0]}
	for action in axes:
		var event := InputEventJoypadMotion.new()
		event.device=-1
		event.axis=axes[action][0]
		event.axis_value=axes[action][1]
		InputMap.action_add_event(action,event)
	var buttons := {"drift":JOY_BUTTON_A,"item":JOY_BUTTON_X,"capacitor":JOY_BUTTON_RIGHT_SHOULDER,"pause":JOY_BUTTON_START,"recover":JOY_BUTTON_Y}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.device=-1
		event.button_index=buttons[action]
		InputMap.action_add_event(action,event)

func build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_SKY
	var sky_material:=ShaderMaterial.new()
	sky_material.shader=load("res://assets/shaders/sky.gdshader")
	var sky:=Sky.new()
	sky.radiance_size=Sky.RADIANCE_SIZE_1024
	sky.sky_material=sky_material
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("b8c5ff")
	env.ambient_light_energy=0.35
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure=0.95
	env.fog_enabled=true
	env.fog_light_color=Color("8276aa")
	env.fog_density=0.0013
	env.fog_sky_affect=0.0
	world.environment=env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-35,0)
	sun.light_color=Color("fff2df")
	sun.light_energy=0.70
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=90
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-25,145,0)
	fill.light_color=Color("b3a4ff")
	fill.light_energy=0.20
	add_child(fill)
	track=RushTrack.new()
	add_child(track)
	camera=Camera3D.new()
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.near=0.5
	camera.far=450
	camera.fov=67
	display_system.viewport.add_child(camera)
	camera.current=true

func clear_race_effects() -> void:
	for effect in effects:
		if is_instance_valid(effect.node):
			effect.node.hide()
			effect.node.queue_free()
	effects.clear()
	if is_instance_valid(ui):
		ui.toast=""
		ui.toast_time=0

func clear_racers() -> void:
	clear_race_effects()
	for racer in racers:
		remove_child(racer)
		racer.queue_free()
	racers.clear()
	finishers.clear()

func make_racer(i: int, menu: bool = false) -> RushKart:
	var racer: RushKart=Kart.new()
	racer.game=self
	racer.track=track
	racer.is_player=i==0
	racer.style=i
	racer.driver_name=["You","Glitch","Pixel","Flux","Nova","Cache"][i]
	racer.tint=[Color("b5ff66"),Color("f088c7"),Color("54e7ef"),Color("ffc369"),Color("a897ff"),Color("ff786b")][i]
	add_child(racer)
	racers.append(racer)
	racer.spawn_at(22 if menu else -2-int(i/2)*2,(-1 if i%2==0 else 1)*3)
	return racer

func start_race(race_mode: String) -> void:
	paused=false
	in_menu=false
	racing=false
	mode=race_mode
	clear_racers()
	for pickup in track.pickups:
		pickup.timer=0
	for i in range(6 if mode=="Grand Prix" else 1):
		var racer := make_racer(i)
		if i==0:
			player=racer
	race_time=0
	countdown=3.7
	last_count=4
	shake=0
	ui.race_hud()
	camera.position=player.global_position-player.forward()*10+Vector3.UP*5.5
	camera.look_at(player.global_position+player.forward()*6+Vector3.UP)

func return_to_menu() -> void:
	paused=false
	racing=false
	in_menu=true
	clear_racers()
	player=make_racer(0,true)
	ui.main_menu()

func toggle_pause() -> void:
	if in_menu or player.finish_time>=0:
		return
	paused=not paused
	for racer in racers:
		racer.set_audio_paused(paused)
	if paused:
		ui.pause_menu()
	else:
		ui.race_hud()

func _unhandled_input(event: InputEvent) -> void:
	var pause_pressed:=event.is_action_pressed("pause")
	var back_pressed:=ui.screen!="race" and event.is_action_pressed("ui_cancel")
	if pause_pressed or back_pressed:
		if ui.screen=="settings":
			ui.main_menu() if in_menu else ui.pause_menu()
		elif ui.screen=="results":
			start_race(mode) if pause_pressed and event is InputEventJoypadButton else return_to_menu()
		elif in_menu:
			if pause_pressed and event is InputEventJoypadButton:
				start_race("Grand Prix")
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("recover") and racing and not paused and player.finish_time<0:
		player.recover()

func _physics_process(delta: float) -> void:
	if not paused and not in_menu:
		if countdown>0:
			countdown-=delta
			var count := ceili(countdown)
			if count!=last_count:
				last_count=count
				sfx.stream=load("res://assets/go.wav" if count==0 else "res://assets/countdown.wav")
				play_audio(sfx)
			if countdown<=0:
				racing=true
		elif racing:
			race_time+=delta
	if test_mode:
		run_test_step()

func _process(delta: float) -> void:
	if force_render:
		RenderingServer.force_draw(false)
	if paused:
		return
	if not is_instance_valid(player):
		return
	# Match the camera's target to the same interpolated pose used to render the kart.
	var pose:=player.get_global_transform_interpolated()
	var pivot:=pose.origin
	var facing: Vector3=-pose.basis.z.normalized()
	if in_menu:
		menu_time+=delta
		var right:=track.right_at(player.nearest_index)
		camera.position=pivot-facing*(8+sin(menu_time*0.15)*1.5)+right*7+Vector3.UP*5.5
		camera.look_at(pivot+facing*3-right*4+Vector3.UP)
		camera.fov=57
	else:
		var desired:=pivot-facing*(10.0+absf(player.speed)*0.06)+Vector3.UP*5.4
		camera.position=camera.position.lerp(desired,1-exp(-delta*6))
		var aim:=pivot+facing*7+Vector3.UP*1.4
		if shake>0:
			shake=maxf(0,shake-delta)
			aim+=Vector3(randf_range(-shake,shake),randf_range(-shake,shake),0)*3
		camera.look_at(aim)
		camera.fov=lerpf(camera.fov,68+absf(player.speed)*0.24+(7 if player.boost_time>0 else 0),1-exp(-delta*4))
	for effect in effects.duplicate():
		effect.time+=delta
		effect.node.scale=Vector3.ONE*(1+effect.time*12)
		effect.node.material_override.albedo_color.a=maxf(0.0,1-effect.time/0.6)*0.65
		if effect.time>0.6:
			effect.node.queue_free()
			effects.erase(effect)

func sorted_racers() -> Array:
	var result: Array=racers.duplicate()
	result.sort_custom(func(a,b):
		if a.finish_time>=0 and b.finish_time>=0:
			return a.finish_rank<b.finish_rank
		if a.finish_time>=0:
			return true
		if b.finish_time>=0:
			return false
		# Checkpoint count determines standing before local distance does.
		if a.gate_count!=b.gate_count:
			return a.gate_count>b.gate_count
		return remaining_to_checkpoint(a)<remaining_to_checkpoint(b))
	return result

func remaining_to_checkpoint(racer: RushKart) -> float:
	var gate: int=track.checkpoints[racer.next_checkpoint]
	return fposmod(track.distances[gate]-racer.progress,track.total_length)

func position_of(racer: RushKart) -> int:
	return sorted_racers().find(racer)+1

func racer_finished(racer: RushKart) -> void:
	if not racers.has(racer) or finishers.has(racer) or racer.finish_time<0:
		return
	racer.clear_driving_effects()
	racer.collision_layer=0
	racer.collision_mask=1
	finishers.append(racer)
	racer.finish_rank=finishers.size()
	if finishers.size()==racers.size():
		racing=false
	if racer.is_player:
		if mode=="Time Trial":
			if records.get("total",0.0)==0 or racer.finish_time<float(records.total):
				records.total=racer.finish_time
				save_records()
		if not test_mode:
			ui.results()
	# Opponents continue racing so their final times update on the results screen.
	elif player.finish_time>=0 and not test_mode and ui.screen=="results":
		ui.update_results_standings()

func record_lap(time: float) -> void:
	if mode!="Time Trial":
		return
	if records.get("lap",0.0)==0 or time<float(records.lap):
		records.lap=time
		save_records()

func announce(text: String, color: Color) -> void:
	ui.toast=text
	ui.toast_color=color
	ui.toast_time=2.0

func emp_effect(pos: Vector3) -> void:
	var ring := RushArt.ring(self,pos+Vector3.UP,1.2,Color("54e7ef"))
	effects.append({"node":ring,"time":0.0})

func ui_sound() -> void:
	sfx.stream=load("res://assets/ui.wav")
	play_audio(sfx)

func read_number(file: ConfigFile, section: String, key: String, fallback: float, minimum: float, maximum: float) -> float:
	var value: Variant=file.get_value(section,key,fallback)
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampf(float(value),minimum,maximum)

func read_bool(file: ConfigFile, key: String, fallback: bool) -> bool:
	var value: Variant=file.get_value("game",key,fallback)
	return value if value is bool else fallback

func read_record(file: ConfigFile, key: String) -> float:
	var value: Variant=file.get_value("records",key,0.0)
	if not (value is int or value is float):
		return 0.0
	var time:=float(value)
	return time if is_finite(time) and time>0 and time<1.0e9 else 0.0

func load_settings() -> void:
	var file:=ConfigFile.new()
	file.load("user://"+profile_prefix+"settings.cfg")
	difficulty=int(read_number(file,"game","difficulty",1,0,2))
	volume=read_number(file,"game","volume",0.7,0,1)
	sensitivity=read_number(file,"game","sensitivity",1.0,0.65,1.4)
	fullscreen=read_bool(file,"fullscreen",false)
	quality=read_bool(file,"quality",true)
	resolution_index=int(read_number(file,"game","resolution_index",4,0,RushDisplay.RESOLUTIONS.size()-1))
	var saved:=ConfigFile.new()
	saved.load("user://"+profile_prefix+"records.cfg")
	records={"lap":read_record(saved,"lap"),"total":read_record(saved,"total")}

func save_settings() -> void:
	if test_mode:
		return
	var file := ConfigFile.new()
	for key in ["difficulty","volume","sensitivity","fullscreen","quality","resolution_index"]:
		file.set_value("game",key,get(key))
	file.save("user://"+profile_prefix+"settings.cfg")

func save_records() -> void:
	if test_mode:
		return
	var file := ConfigFile.new()
	for key in records:
		file.set_value("records",key,records[key])
	file.save("user://"+profile_prefix+"records.cfg")

func apply_settings(resize_window: bool = false) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.0001)))
	AudioServer.set_bus_mute(0,volume<=0)
	if is_instance_valid(display_system):
		display_system.apply(resolution_index,fullscreen,quality,resize_window)

func set_resolution(index: int) -> void:
	resolution_index=clampi(index,0,RushDisplay.RESOLUTIONS.size()-1)
	apply_settings(true)
	save_settings()

func test_assert(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:
		test_success=false

func run_test_step() -> void:
	test_frames+=1
	if test_frames==60:
		test_assert(track.points.size()==240,"Closed track has 240 samples")
		test_assert(racers.size()==(6 if mode=="Grand Prix" else 1),"Correct racer count for "+mode)
		test_assert(track.total_length>600,"Full-length circuit")
		var old_gate := player.gate_count
		var pos := player.global_position
		player.global_position=track.sample(0)+Vector3.UP
		player.check_gates()
		test_assert(player.gate_count==old_gate,"Start line cannot skip ordered checkpoints")
		player.global_position=pos
		player.item="Hardlight Shield"
		player.item_delay=0
		player.use_item()
		player.attack(1.0)
		test_assert(not player.shield and player.slow_time<=0,"Shield absorbs an attack")
		player.item="Turbo Cell"
		player.use_item()
		test_assert(player.boost_time>1,"Turbo Cell grants real boost")
		if racers.size()>1:
			var other := racers[1]
			var other_pos := other.global_position
			other.global_position=player.global_position+Vector3.RIGHT*3
			player.item="EMP Burst"
			player.use_item()
			test_assert(other.slow_time>0,"EMP slows opponent in range")
			other.global_position=other_pos
		for charge in [0.8,1.8,2.8]:
			player.boost_time=0
			player.drift_time=charge
			player.release_drift()
			test_assert(player.boost_power==[8,10,12][[0.8,1.8,2.8].find(charge)],"Drift tier at %.1f seconds"%charge)
		player.boost_time=0
		player.boost_power=0
		var gate_before := player.gate_count
		player.global_position.y=-15
		player.recover()
		test_assert(player.global_position.y>0 and player.gate_count==gate_before,"Fall recovery preserves gate order")
	if test_frames%1800==0:
		print("TEST_PROGRESS t=%.1f laps=%s gates=%s recoveries=%s"%[race_time,str(racers.map(func(r):return r.lap)),str(racers.map(func(r):return r.gate_count)),str(racers.map(func(r):return r.recoveries))])
	if finishers.size()==racers.size() or test_frames>16000:
		var summary := {"mode":mode,"difficulty":difficulty,"time":race_time,"frames":test_frames,"racers":[]}
		for r in racers:
			var result := {"driver":r.driver_name,"laps":r.lap,"gates":r.gate_count,"time":r.finish_time,"recoveries":r.recoveries,"drift_boosts":r.drift_boosts,"jumps":r.jumps,"items":r.item_uses}
			summary.racers.append(result)
			test_assert(r.lap==3 and r.gate_count==36,"%s completes 3 legitimate laps"%r.driver_name)
			test_assert(r.recoveries<12,"%s navigates reliably"%r.driver_name)
		test_results.append(summary)
		if test_suite<3:
			test_suite+=1
			test_frames=0
			difficulty=[1,0,2,1][test_suite]
			start_race("Time Trial" if test_suite==3 else "Grand Prix")
			player.autopilot=true
			countdown=0.05
			print("TEST_BEGIN %s / difficulty %d"%[mode,difficulty])
		else:
			test_assert(records.get("lap",0)>0 and records.get("total",0)>0,"Time Trial records computed")
			var file := FileAccess.open("user://test_results.json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"passed":test_success,"suites":test_results},"  "))
			print("TEST_REPORT "+ProjectSettings.globalize_path("user://test_results.json"))
			get_tree().quit(0 if test_success else 1)

func _exit_tree() -> void:
	for audio in [music,sfx]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream=null
	RushArt.materials.clear()
	RushArt.fonts.clear()

func pickup_effect(pos: Vector3) -> void:
	var ring := RushArt.ring(self,pos,0.4,Color("b5ff66"))
	effects.append({"node":ring,"time":0.0})

func play_audio(player_node: AudioStreamPlayer) -> void:
	# The dummy headless audio driver does not drain playback references on fast shutdown.
	if DisplayServer.get_name()!="headless":
		player_node.play()
