extends SceneTree
# Edge cases beyond a clean autonomous race. Fixtures use their own save-file prefix.
var game
var failures:=0
var checks: Array[String]=[]
var watchdog:=0
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")
func _physics_process(_delta: float) -> bool:
	watchdog+=1
	if watchdog>3000:
		print("FAIL Correctness test aborted before completing")
		quit(2)
	return false
func check(ok: bool, description: String) -> void:
	var message:=("PASS " if ok else "FAIL ")+description
	checks.append(message)
	print(message)
	if not ok:
		failures+=1
func race() -> RushKart:
	game.start_race("Grand Prix")
	game.set_physics_process(false)
	game.racing=true
	game.countdown=0
	for r in game.racers:
		r.set_physics_process(false)
	return game.player
func run() -> void:
	await process_frame
	await process_frame
	game.profile_prefix="validation_correctness_"
	var p:=race()
	for i in range(game.racers.size()):
		game.racers[i].progress=game.track.total_length-5-i*3
		game.racers[i].gate_count=0
		game.racers[i].next_checkpoint=1
	p.progress=10
	check(game.position_of(p)==1,"Standings remain correct as the leader crosses the starting line")
	for r in game.racers:
		r.gate_count=12
		r.next_checkpoint=1
	check(game.position_of(p)==1,"Standings handle a racer recovered just behind a lap boundary")
	p.boost_time=0
	p.boost(2.2,14)
	p.boost(0.9,8)
	check(p.boost_power==14 and p.boost_time>=2.2,"A weaker drift turbo cannot downgrade an active Turbo Cell")
	p.drift_time=2.8
	p.was_drifting=true
	p.recover()
	check(p.drift_time==0 and not p.was_drifting and p.boost_time==0,"Recovery clears pending drift charge and temporary boosts")
	p.finish_time=30
	var position:=p.global_position
	var recover:=InputEventAction.new()
	recover.action="recover"
	recover.pressed=true
	game._unhandled_input(recover)
	check(p.global_position==position,"Recovery input cannot move a finished racer")
	p=race()
	var opponent: RushKart=game.racers[1]
	opponent.global_position=p.global_position+Vector3.RIGHT*2
	opponent.finish_time=20
	opponent.slow_time=0
	p.item="EMP Burst"
	p.item_delay=0
	p.use_item()
	check(opponent.slow_time==0,"EMP cannot attack a finished racer")
	p.item="Turbo Cell"
	p.item_delay=0
	game.toggle_pause()
	p.use_item()
	check(p.item=="Turbo Cell" and p.boost_time==0,"Item use is blocked while paused")
	game.toggle_pause()
	game.emp_effect(p.global_position)
	var effect_time: float=game.effects[-1].time
	game.paused=true
	game._process(0.2)
	check(game.effects[-1].time==effect_time,"Pause freezes transient race effects")
	game.paused=false
	p=race()
	check(game.effects.is_empty(),"Restart clears effects from the previous race")
	game.announce("Previous Race",Color.WHITE)
	game.return_to_menu()
	p=race()
	check(game.ui.toast_time==0,"Race announcements do not leak into a new race")
	if DisplayServer.get_name()!="headless":
		await process_frame
		await process_frame
		check(p.engine.playing,"Native engine playback is active before the pause check")
	game.toggle_pause()
	check((not p.engine.playing or p.engine.stream_paused) and p.visual.process_mode==Node.PROCESS_MODE_DISABLED,"Pause suspends kart effects and any active engine playback")
	game.toggle_pause()
	p.finish_time=30
	p.lap=3
	p.lap_times.assign([10.0,10.0,10.0])
	game.racer_finished(p)
	var overlay: Control=game.ui.overlay
	var buttons:=overlay.get_children().filter(func(n):return n is Button)
	buttons[-1].grab_focus()
	var focused: Control=root.gui_get_focus_owner()
	var next: RushKart=game.racers[1]
	next.finish_time=31
	game.racer_finished(next)
	check(game.ui.overlay==overlay and root.gui_get_focus_owner()==focused,"AI finishing updates results without replacing the menu or stealing focus")
	game.racer_finished(p)
	check(game.finishers.count(p)==1 and p.finish_rank==1,"Finisher registration is idempotent")
	for r in game.racers:
		if r.finish_time<0:
			r.finish_time=32+r.style
			game.racer_finished(r)
	check(not game.racing and game.finishers.size()==6,"Race clock stops when the whole field has finished")
	# Deliberately valid ConfigFile syntax containing invalid value types and records.
	var config:=ConfigFile.new()
	config.set_value("game","difficulty","invalid")
	config.set_value("game","volume","loud")
	config.set_value("game","sensitivity",-5.0)
	config.set_value("game","fullscreen","yes")
	config.set_value("game","quality",123)
	config.set_value("game","resolution_index",999)
	config.save("user://validation_correctness_settings.cfg")
	var records:=ConfigFile.new()
	records.set_value("records","lap",-22.0)
	records.set_value("records","total",NAN)
	records.save("user://validation_correctness_records.cfg")
	game.load_settings()
	check(game.difficulty==1 and is_equal_approx(game.volume,0.7) and game.sensitivity==0.65 and not game.fullscreen and game.quality and game.resolution_index==8,"Malformed preference values fall back or clamp safely")
	check(game.records.get("lap",0)==0 and game.records.get("total",0)==0,"Invalid personal-record times cannot poison Time Trial records")
	var file:=FileAccess.open("user://correctness_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"version":game.VERSION,"headless":DisplayServer.get_name()=="headless","checks":checks},"  "))
	print("CORRECTNESS_REPORT "+ProjectSettings.globalize_path("user://correctness_results.json"))
	game.free()
	quit(0 if failures==0 else 1)
