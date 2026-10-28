extends SceneTree
# Regression checks for race transitions and the generated service-bridge route.
var game
var failures:=0
var checks: Array[String]=[]

func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	var message:=("PASS " if ok else "FAIL ")+description
	checks.append(message)
	print(message)
	if not ok:
		failures+=1

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func run() -> void:
	await frames(3)
	game.profile_prefix="validation_lifecycle_"
	game.start_race("Grand Prix")
	game.set_physics_process(false)
	game.racing=true
	game.countdown=0
	for r in game.racers:
		r.set_physics_process(false)
	var p: RushKart=game.player
	p.was_drifting=true
	p.drift_time=2.7
	p.drift_side=1
	p.boost_time=2.2
	p.boost_power=14
	p.update_visuals(0.1)
	if DisplayServer.get_name()!="headless":
		await frames(2)
		check(p.drift_audio.playing,"Native drift audio is playing before finishing")
	p.lap=3
	p.lap_times.assign([30.0,30.0,30.0])
	p.finish_time=90
	game.racer_finished(p)
	p.update_visuals(0.1)
	check(not p.was_drifting and p.drift_time==0 and p.boost_time==0,"Finishing clears drift charge and temporary propulsion")
	check(not p.sparks.emitting and not p.tyre_smoke.emitting and not p.exhaust.emitting and not p.drift_audio.playing,"Finished karts stop driving particles and drift audio")
	# Sample the real bridge route in order using its own tangent and the normal gate validator.
	var bridge: PackedVector3Array=game.track.shortcut_points
	var rival: RushKart=game.racers[1]
	rival.gate_count=5
	rival.next_checkpoint=6
	for i in range(bridge.size()-1):
		rival.global_position=bridge[i]+Vector3.UP*0.3
		var direction: Vector3=(bridge[i+1]-bridge[i]).normalized()
		rival.heading=atan2(-direction.x,-direction.z)
		rival.speed=20
		rival.check_gates()
	check(rival.gate_count==7 and rival.next_checkpoint==8,"Service bridge validates both required checkpoints before rejoining")
	# Exercise transitions repeatedly, including a paused restart and settings-back path.
	for i in range(10):
		game.start_race("Time Trial" if i%2==0 else "Grand Prix")
		game.countdown=0
		game.racing=true
		game.toggle_pause()
		game.ui.settings("pause")
		var escape:=InputEventAction.new()
		escape.action="pause"
		escape.pressed=true
		game._unhandled_input(escape)
		check(game.paused and game.ui.screen=="pause","Settings escape preserves pause on transition %d"%i)
		game.start_race(game.mode)
		check(not game.paused and not game.racing and game.countdown>0 and game.finishers.is_empty() and game.effects.is_empty(),"Paused restart resets lifecycle state on transition %d"%i)
		game.return_to_menu()
		await frames(1)
		var active: Array=game.get_children().filter(func(n):return n is RushKart)
		check(game.racers.size()==1 and active.size()==1 and game.player==game.racers[0] and game.ui.screen=="main","Menu has exactly one active kart after transition %d"%i)
	var file:=FileAccess.open("user://lifecycle_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":game.VERSION,"passed":failures==0,"headless":DisplayServer.get_name()=="headless","checks":checks},"  "))
	print("LIFECYCLE_REPORT "+ProjectSettings.globalize_path("user://lifecycle_results.json"))
	game.free()
	quit(0 if failures==0 else 1)
