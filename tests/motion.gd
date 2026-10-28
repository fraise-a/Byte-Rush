extends SceneTree
# Render-frame regression using six co-moving real kart models at a controlled render/physics cadence.
class MotionDriver extends Node:
	var racers: Array=[]
	var active:=false
	var direction:=Vector3(10,0,0)
	func _physics_process(delta: float) -> void:
		if active:
			for racer in racers:
				racer.global_position+=direction*delta
var game
var driver: MotionDriver
var active:=false
var elapsed:=0.0
var frame_count:=0
var render_hz:=144
var last_physics:=-1
var previous_world:=Vector3.ZERO
var same_tick_frames:=0
var moving_between_ticks:=0
var samples: Array[Vector2]=[]
var raw_samples: Array[Vector3]=[]
var captures:=0
var failures:=0
var checks: Array[String]=[]
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	var message:=("PASS " if ok else "FAIL ")+description
	checks.append(message); print(message)
	if not ok: failures+=1
func run() -> void:
	await process_frame
	game.profile_prefix="validation_motion_"
	game.volume=0; game.fullscreen=false; game.resolution_index=4
	game.apply_settings(true)
	game.start_race("Grand Prix")
	game.countdown=0; game.racing=true
	game.set_physics_process(false)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	for i in range(game.racers.size()):
		var racer: RushKart=game.racers[i]
		racer.set_physics_process(false)
		racer.global_position=Vector3((i%2)*4-2,100,-int(i/2)*6)
		racer.heading=0; racer.rotation=Vector3.ZERO
		racer.speed=10
		racer.reset_physics_interpolation()
	game.camera.global_position=game.player.global_position+Vector3(0,5.4,10.6)
	game.camera.look_at(game.player.global_position+Vector3(0,1.4,-7))
	driver=MotionDriver.new()
	driver.racers=game.racers
	game.add_child(driver)
	# Allow the real macOS window-size animation to settle before measuring pixels.
	var until:=Time.get_ticks_msec()+3700
	while Time.get_ticks_msec()<until: await process_frame
	check(Engine.physics_ticks_per_second==60,"Simulation remains at 60 physics ticks per second")
	driver.active=true; active=true
func _process(delta: float) -> bool:
	if not active: return false
	elapsed+=delta
	render_hz=roundi(1.0/delta)
	game._process(delta)
	var pose: Transform3D=game.racers[2].get_global_transform_interpolated()
	if elapsed>1.5:
		var tick:=Engine.get_physics_frames()
		if tick==last_physics:
			same_tick_frames+=1
			if pose.origin.distance_to(previous_world)>0.005: moving_between_ticks+=1
		last_physics=tick; previous_world=pose.origin
		samples.append(game.camera.unproject_position(pose.origin+Vector3.UP))
		raw_samples.append(game.racers[2].global_position)
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false)
		if elapsed>2 and captures<3:
			game.display_system.viewport.get_texture().get_image().save_png("user://motion_frame_%d.png"%captures)
			captures+=1
	frame_count+=1
	if elapsed>=4:
		active=false; driver.active=false
		call_deferred("finish")
	return false
func finish() -> void:
	var squared:=0.0
	var peak:=0.0
	var reversals:=0
	for i in range(2,samples.size()):
		var second_difference:=samples[i]-samples[i-1]*2+samples[i-2]
		squared+=second_difference.length_squared()
		peak=maxf(peak,second_difference.length())
		if (samples[i]-samples[i-1]).dot(samples[i-1]-samples[i-2])<0: reversals+=1
	var jitter:=sqrt(squared/maxi(1,samples.size()-2))
	check(same_tick_frames>50 if render_hz>60 else same_tick_frames==0,"Render samples have the expected cadence relative to physics")
	check(moving_between_ticks>=same_tick_frames*0.95,"Kart presentation advances smoothly between physics ticks")
	check(jitter<0.12,"Co-moving kart has no alternating camera-relative position jump")
	var p: RushKart=game.player
	# Inspect the next rendered pose, not the cached pose already drawn this frame.
	# Choose a phase where no new physics tick can hide a missing reset.
	while Engine.get_physics_interpolation_fraction()>0.3: await process_frame
	var spawn_tick:=Engine.get_physics_frames()
	p.spawn_at(90)
	await process_frame
	var spawn_error: float=p.get_global_transform_interpolated().origin.distance_to(p.global_position)
	var model: Node3D=p.visual.get_child(0)
	var spawn_model_error: float=model.get_global_transform_interpolated().origin.distance_to(model.global_position)
	check(spawn_error<0.001 and spawn_model_error<0.001 and (render_hz<=60 or Engine.get_physics_frames()==spawn_tick),"Spawn placement resets presentation history by the next rendered frame")
	while Engine.get_physics_interpolation_fraction()>0.3: await process_frame
	var recovery_tick:=Engine.get_physics_frames()
	var gate_count: int=p.gate_count
	p.safe_index=100
	p.global_position+=Vector3(80,10,0)
	p.recover()
	await process_frame
	var recovery_error: float=p.get_global_transform_interpolated().origin.distance_to(p.global_position)
	var recovery_model_error: float=model.get_global_transform_interpolated().origin.distance_to(model.global_position)
	check(recovery_error<0.001 and recovery_model_error<0.001 and p.gate_count==gate_count and (render_hz<=60 or Engine.get_physics_frames()==recovery_tick),"Recovery snaps cleanly without a streak or checkpoint credit")
	var report:={"version":game.VERSION,"passed":failures==0,"headless":DisplayServer.get_name()=="headless","render_frames":frame_count,"physics_hz":Engine.physics_ticks_per_second,"fixed_render_hz":render_hz,"same_tick_frames":same_tick_frames,"moving_between_ticks":moving_between_ticks,"screen_second_difference_rms_px":jitter,"screen_second_difference_peak_px":peak,"screen_direction_reversals":reversals,"sample_count":samples.size(),"spawn_history_error":spawn_error,"spawn_model_history_error":spawn_model_error,"recovery_history_error":recovery_error,"recovery_model_history_error":recovery_model_error,"checks":checks}
	var file:=FileAccess.open("user://motion_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	var per_rate:=FileAccess.open("user://motion_results_%d.json"%render_hz,FileAccess.WRITE)
	per_rate.store_string(JSON.stringify(report,"  "))
	print("MOTION_REPORT ",report)
	game.free()
	quit(0 if failures==0 else 1)
