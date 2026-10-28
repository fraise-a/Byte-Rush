extends SceneTree
# Integration checks use actual input actions, physics frames and application save code.
var game
var failures := 0
var messages: Array[String] = []

func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	var message := ("PASS " if condition else "FAIL ")+description
	messages.append(message)
	print(message)
	if not condition:
		failures+=1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	await frames(3)
	game.start_race("Time Trial")
	game.countdown=0
	game.racing=true
	var p=game.player
	p.spawn_at(1,0)
	var origin: Vector3=p.global_position
	Input.action_press("accelerate")
	await frames(100)
	Input.action_release("accelerate")
	check(p.speed>18 and p.global_position.distance_to(origin)>10,"Keyboard action accelerates and moves physical kart")
	check(p.is_on_floor() or absf(p.global_position.y-game.track.sample(p.nearest_index).y)<2,"Kart remains supported by road collision")
	Input.action_press("brake")
	await frames(150)
	check(p.speed< -8,"Brake transitions into reverse")
	Input.action_release("brake")
	p.spawn_at(1,-4)
	p.speed=24
	p.capacitor=0
	p.boost_time=0
	Input.action_press("accelerate")
	Input.action_press("right",0.24)
	Input.action_press("drift")
	await frames(52)
	check(p.drift_time>0.55 and p.capacitor>5,"Held drift accumulates charge and capacitor through physics")
	Input.action_release("drift")
	Input.action_release("right")
	await frames(2)
	check(p.boost_time>0.4 and p.drift_boosts>0,"Releasing drift activates a real temporary boost")
	Input.action_release("accelerate")
	p.spawn_at(2,0)
	p.boost_time=0
	p.capacitor=40
	Input.action_press("capacitor")
	await frames(2)
	Input.action_release("capacitor")
	check(p.capacitor<15 and p.boost_time>1,"Capacitor input spends energy and boosts")
	await frames(2)
	p.boost_time=0
	Input.action_press("capacitor")
	await frames(2)
	Input.action_release("capacitor")
	check(p.boost_time==0,"Insufficient capacitor cannot create a boost")
	var t: float=game.race_time
	var pos: Vector3=p.global_position
	game.toggle_pause()
	await frames(30)
	check(game.race_time==t and p.global_position==pos and game.ui.screen=="pause","Pause freezes race timer and movement")
	game.toggle_pause()
	await frames(3)
	check(game.race_time>t and game.ui.screen=="race","Resume restores gameplay")
	p.item=""
	var pickup: Dictionary=game.track.pickups[0]
	pickup.timer=0
	p.global_position=pickup.node.global_position-Vector3.UP
	p.interact_with_track(0)
	check(p.item!="" and pickup.timer>4,"Pickup fills inventory and enters respawn cooldown")
	p.next_checkpoint=1
	p.gate_count=0
	p.nearest_index=game.track.checkpoints[1]
	p.global_position=game.track.sample(p.nearest_index)+Vector3.UP
	var dir: Vector3=game.track.tangent(p.nearest_index)
	p.heading=atan2(-dir.x,-dir.z)+PI
	p.speed=10
	p.check_gates()
	check(p.gate_count==0,"Wrong-way crossing cannot validate a checkpoint")
	p.heading-=PI
	p.check_gates()
	p.check_gates()
	check(p.gate_count==1,"Valid checkpoint advances exactly once")
	p.nearest_index=100
	p.global_position=game.track.sample(100)
	p.check_gates()
	check(p.gate_count==1 and p.lap==0,"Skipping forward cannot earn a lap")
	var road_pos: Vector3=game.track.sample(25)
	var ray:=PhysicsRayQueryParameters3D.create(road_pos+Vector3.UP*10,road_pos-Vector3.UP*5,1)
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.normal.y>0.8,"Road has solid upward-facing physical surface")
	var right: Vector3=game.track.right_at(25)
	ray=PhysicsRayQueryParameters3D.create(road_pos+Vector3.UP*0.7,road_pos+right*13+Vector3.UP*0.7,1)
	hit=game.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty(),"Track barriers have physical collision")
	check(InputMap.action_get_events("accelerate").size()==3 and InputMap.action_get_events("drift").size()==2,"Keyboard and controller bindings are installed")
	game.profile_prefix="validation_"
	game.difficulty=2
	game.sensitivity=1.15
	game.records={"lap":22.3,"total":70.4}
	game.save_settings()
	game.save_records()
	game.records={}
	game.difficulty=0
	game.sensitivity=0.7
	game.load_settings()
	check(game.difficulty==2 and is_equal_approx(game.sensitivity,1.15),"Settings survive a save/load round trip")
	check(is_equal_approx(game.records.lap,22.3) and is_equal_approx(game.records.total,70.4),"Personal records survive a save/load round trip")
	game.ui.settings("pause")
	check(game.ui.screen=="settings","Settings screen can open from paused race")
	p.lap_times.assign([22.3,23.0,25.1])
	p.finish_time=70.4
	p.finish_rank=1
	game.ui.results()
	check(game.ui.screen=="results","Results screen renders computed race data")
	game.return_to_menu()
	await frames(2)
	check(game.in_menu and game.ui.screen=="main","Return to menu clears race and restores functional menu")
	var menu_button: Button=game.ui.overlay.get_children().filter(func(n):return n is Button)[0]
	var click_pos: Vector2=menu_button.get_global_transform_with_canvas()*(menu_button.size*0.5)
	print("MENU INPUT rect=",menu_button.get_global_rect()," transform=",root.get_final_transform()," mode_before=",game.mode)
	click_pos=root.get_final_transform()*click_pos
	var motion:=InputEventMouseMotion.new()
	motion.position=click_pos
	motion.global_position=click_pos
	Input.parse_input_event(motion)
	await frames(2)
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=click_pos
	event.global_position=click_pos
	event.pressed=true
	Input.parse_input_event(event)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await frames(2)
	print("MENU INPUT after menu=",game.in_menu," mode=",game.mode)
	check(not game.in_menu and game.mode=="Grand Prix","Menu mouse event activates connected Grand Prix button")
	var report:=FileAccess.open("user://systems_results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures==0,"checks":messages},"  "))
	print("SYSTEMS_REPORT "+ProjectSettings.globalize_path("user://systems_results.json"))
	game.free()
	quit(0 if failures==0 else 1)
