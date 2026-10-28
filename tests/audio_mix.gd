extends SceneTree
# Native audio sample capture; output is routed through a muted master for this test.
var game
var failures:=0
var checks: Array[String]=[]
var capture: AudioEffectCapture
var monitor: int
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	var message:=("PASS " if ok else "FAIL ")+description
	print(message)
	checks.append(message)
	if not ok:
		failures+=1
func level(samples: PackedVector2Array) -> Dictionary:
	var squared:=0.0
	var peak:=0.0
	for frame in samples:
		squared+=frame.length_squared()
		peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	var rms:=sqrt(squared/maxi(1,samples.size()*2))
	return {"frames":samples.size(),"rms_db":linear_to_db(maxf(0.000001,rms)),"peak_db":linear_to_db(maxf(0.000001,peak))}
func record(seconds: float) -> PackedVector2Array:
	capture.clear_buffer()
	await create_timer(seconds).timeout
	return capture.get_buffer(capture.get_frames_available())
func run() -> void:
	await process_frame
	game.profile_prefix="validation_audio_"
	game.start_race("Grand Prix")
	game.countdown=0
	game.racing=true
	game.set_physics_process(false)
	for racer in game.racers:
		racer.set_physics_process(false)
	game.player.speed=28
	game.player.update_visuals(0.1)
	# Use the actual release limiter and capture after it, while keeping speakers silent.
	AudioServer.add_bus()
	monitor=AudioServer.bus_count-1
	AudioServer.set_bus_name(monitor,"ValidationCapture")
	AudioServer.set_bus_send(monitor,"Master")
	var limiter: AudioEffectHardLimiter=AudioServer.get_bus_effect(0,0).duplicate()
	AudioServer.add_bus_effect(monitor,limiter)
	capture=AudioEffectCapture.new()
	capture.buffer_length=3
	AudioServer.add_bus_effect(monitor,capture)
	for player in [game.music,game.sfx,game.player.engine,game.player.drift_audio,game.player.effects]:
		player.bus="ValidationCapture"
	game.volume=1
	game.apply_settings()
	AudioServer.set_bus_mute(0,true)
	var new_music_gain: float=game.music.volume_db
	var new_engine_gain: float=game.player.engine.volume_db
	game.music.volume_db=-16
	game.player.engine.volume_db=-29
	var before:=level(await record(1.25))
	game.music.volume_db=new_music_gain
	game.player.engine.volume_db=new_engine_gain
	var after:=level(await record(1.25))
	check(before.frames>10000 and after.frames>10000,"Native audio capture contains real mixed PCM frames")
	check(after.rms_db-before.rms_db>15,"Revised race mix is at least 15 dB stronger than the previous mix at identical master gain")
	check(after.rms_db> -24 and after.rms_db< -10,"Normal race mix has an audible level with dynamic headroom")
	game.player.was_drifting=true
	game.player.update_visuals(0.1)
	game.player.play_effect("collision")
	game.sfx.stream=load("res://assets/go.wav")
	game.play_audio(game.sfx)
	var busy_samples:=await record(0.8)
	var busy:=level(busy_samples)
	check(busy.peak_db<=-0.9,"Simultaneous engine, drift, collision, countdown and music stay under the -1 dB ceiling")
	var report:={"version":game.VERSION,"passed":failures==0,"headless":DisplayServer.get_name()=="headless","old_mix":before,"new_mix":after,"busy_mix":busy,"gain_difference_db":after.rms_db-before.rms_db,"checks":checks}
	var file:=FileAccess.open("user://audio_mix_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("AUDIO_MIX_REPORT "+ProjectSettings.globalize_path("user://audio_mix_results.json"))
	print("LEVELS ",report)
	game.free()
	AudioServer.remove_bus(monitor)
	quit(0 if failures==0 else 1)
