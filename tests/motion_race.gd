extends SceneTree
# A rendered, six-kart race with physics-step diagnostics. This is not a human playtest.
var game
var elapsed:=0.0
var started:=false
var last_positions: Dictionary={}
var last_recoveries: Dictionary={}
var largest_normal_step:=0.0
var unannounced_jumps: Array[Dictionary]=[]
var fps_samples: Array[float]=[]
var last_second:=-1
var captures: Dictionary={}
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")
func run() -> void:
	await process_frame
	game.profile_prefix="validation_motion_race_"
	game.volume=0; game.resolution_index=4; game.fullscreen=false; game.difficulty=1
	game.apply_settings(true)
	game.set_process_unhandled_input(false)
	game.start_race("Grand Prix")
	game.player.autopilot=true
	started=true
func _physics_process(_delta: float) -> bool:
	if started and game.racing:
		for racer in game.racers:
			var id: int=racer.get_instance_id()
			if last_positions.has(id) and last_recoveries[id]==racer.recoveries:
				var distance: float=racer.global_position.distance_to(last_positions[id])
				largest_normal_step=maxf(largest_normal_step,distance)
				if distance>2.0: unannounced_jumps.append({"driver":racer.driver_name,"distance":distance,"race_time":game.race_time})
			last_positions[id]=racer.global_position
			last_recoveries[id]=racer.recoveries
	return false
func capture(name: String) -> void:
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("user://motion_race_"+name+".png")
	print("CAPTURE "+name)
func _process(delta: float) -> bool:
	if not started: return false
	elapsed+=delta
	RenderingServer.force_draw(false)
	if elapsed>6:
		var second:=int(elapsed)
		if second!=last_second:
			last_second=second
			fps_samples.append(Engine.get_frames_per_second())
	if elapsed>10 and not captures.has("pack"):
		captures.pack=true;capture("pack")
	if elapsed>15 and game.player.nearest_index>=80 and not captures.has("motherboard"):
		captures.motherboard=true;capture("motherboard")
	if elapsed>20 and game.player.nearest_index>=160 and not captures.has("cooling"):
		captures.cooling=true;capture("cooling")
	if elapsed>=35:
		var count: int=game.get_children().filter(func(n):return n is RushKart).size()
		var passed: bool=unannounced_jumps.is_empty() and count==6 and game.race_time>25
		var mean_fps:=0.0
		for value in fps_samples: mean_fps+=value
		mean_fps/=maxi(1,fps_samples.size())
		var states: Array[Dictionary]=[]
		for racer in game.racers: states.append({"driver":racer.driver_name,"index":racer.nearest_index,"recoveries":racer.recoveries,"gates":racer.gate_count})
		var report:={"version":game.VERSION,"passed":passed,"rendered":DisplayServer.get_name()!="headless","elapsed":elapsed,"race_time":game.race_time,"active_karts":count,"largest_non_recovery_step_m":largest_normal_step,"unexpected_teleports":unannounced_jumps,"racers":states,"mean_sampled_fps":mean_fps,"minimum_sampled_fps":fps_samples.min(),"render_pixels":str(game.display_system.viewport.size),"captures":captures.keys()}
		var file:=FileAccess.open("user://motion_race_results.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
		print(("PASS " if passed else "FAIL ")+"Six-kart rendered race has no unexplained physics teleports")
		print("MOTION_RACE_REPORT ",report)
		game.free();quit(0 if passed else 1)
	return false
