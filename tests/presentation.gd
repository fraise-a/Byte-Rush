extends SceneTree
# Rendered performance smoke test, including PNG captures from Godot's own viewport.
var game
var elapsed := 0.0
var started := false
var samples: Array[float] = []
var frame_times: Array[float] = []
var last_second := -1
var captured := {}
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("start")
func start() -> void:
	await process_frame
	game.volume=0
	game.fullscreen=false
	game.resolution_index=4
	game.apply_settings(true)
	started=true
func capture(name: String) -> void:
	RenderingServer.force_draw(false)
	var image: Image=root.get_texture().get_image()
	image.save_png("res://tests/"+name+".png")
	print("CAPTURE "+name)
func _process(delta: float) -> bool:
	if not started:
		return false
	elapsed+=delta
	RenderingServer.force_draw(false)
	if elapsed>1 and not captured.has("menu"):
		captured["menu"]=true
		capture("menu")
	if elapsed>2 and not captured.has("race"):
		captured["race"]=true
		print("STARTING RENDERED RACE at ",elapsed)
		game.start_race("Grand Prix")
		game.player.autopilot=true
	if elapsed>8:
		frame_times.append(delta*1000)
		var second:=int(elapsed)
		if second!=last_second:
			last_second=second
			samples.append(Engine.get_frames_per_second())
			print("PERF fps=",Engine.get_frames_per_second()," process_ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if elapsed>11 and not captured.has("driving"):
		captured["driving"]=true
		capture("driving")
	if elapsed>19 and not captured.has("cooling") and game.player.nearest_index>=160:
		captured["cooling"]=true
		capture("cooling")
	if elapsed>35:
		frame_times.sort()
		var sum:=0.0
		for value in samples:
			sum+=value
		var report:={"device":RenderingServer.get_video_adapter_name(),"window_pixels":str(root.size),"render_pixels":str(game.display_system.viewport.size),"selected_resolution":RushDisplay.resolution_label(game.resolution_index),"mean_sampled_fps":sum/maxi(1,samples.size()),"minimum_sampled_fps":samples.min(),"p95_frame_ms":frame_times[int(frame_times.size()*0.95)],"sample_seconds":samples.size(),"forced_render":true,"racing_seconds":game.race_time,"player_progress_index":game.player.nearest_index}
		var file:=FileAccess.open("res://tests/performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
		print("PERF_REPORT ",report)
		game.free()
		quit()
	return false
