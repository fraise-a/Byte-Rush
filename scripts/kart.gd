class_name RushKart
extends CharacterBody3D

var game: Node3D
var track: RushTrack
var driver_name := "You"
var tint := Color("b5ff66")
var is_player := false
var autopilot := false
var style := 0
var heading := 0.0
var speed := 0.0
var steering := 0.0
var drift_time := 0.0
var drift_side := 0.0
var was_drifting := false
var capacitor := 20.0
var boost_time := 0.0
var boost_power := 0.0
var slow_time := 0.0
var shield := false
var item := ""
var item_delay := 0.0
var hurt_cooldown := 0.0
var ramp_cooldown := 0.0
var recovery_time := 0.0
var stuck_time := 0.0
var last_progress := 0.0
var nearest_index := 0
var safe_index := 0
var progress := 0.0
var next_checkpoint := 1
var lap := 0
var lap_start := 0.0
var lap_times: Array[float] = []
var finish_time := -1.0
var finish_rank := 0
var recoveries := 0
var gate_count := 0
var drift_boosts := 0
var item_uses := 0
var jumps := 0
var visual: Node3D
var wheels: Array[MeshInstance3D] = []
var sparks: CPUParticles3D
var exhaust: CPUParticles3D
var tyre_smoke: CPUParticles3D
var shield_mesh: MeshInstance3D
var engine: AudioStreamPlayer
var drift_audio: AudioStreamPlayer
var effects: AudioStreamPlayer
var ai_item_clock := 0.0

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	collision_layer=2
	collision_mask=3
	floor_snap_length=1.1
	floor_max_angle=deg_to_rad(50)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(1.7,1.0,2.7)
	collision.shape=shape
	collision.position.y=0.5
	add_child(collision)
	build_model()
	engine=AudioStreamPlayer.new()
	engine.stream=load("res://assets/engine.wav")
	engine.volume_db=-12 if is_player else -80
	add_child(engine)
	if is_player:
		game.play_audio(engine)
	drift_audio=AudioStreamPlayer.new()
	drift_audio.stream=load("res://assets/drift.wav")
	drift_audio.volume_db=0
	add_child(drift_audio)
	effects=AudioStreamPlayer.new()
	effects.volume_db=2
	add_child(effects)

func build_model() -> void:
	visual=Node3D.new()
	add_child(visual)
	RushArt.box(visual,Vector3(0,0.55,0),Vector3(1.9,0.45,3.0),Color("111c31"))
	RushArt.ellipsoid(visual,Vector3(0,0.76,-0.1),Vector3(0.94,0.36,1.45),tint)
	var nose := RushArt.box(visual,Vector3(0,0.78,-1.25),Vector3(1.5,0.3,0.8),tint)
	nose.rotation.x=0.15
	RushArt.ellipsoid(visual,Vector3(0,1.04,0.24),Vector3(0.61,0.31,0.68),Color("193b63"))
	RushArt.ellipsoid(visual,Vector3(0,1.36,0.38),Vector3(0.38,0.37,0.38),tint.darkened(0.12))
	RushArt.ellipsoid(visual,Vector3(0,1.39,0.12),Vector3(0.33,0.18,0.18),Color("344e82"))
	RushArt.box(visual,Vector3(0,1.70,0.38),Vector3(0.14,0.035,0.35),Color("e7f7ff"))
	RushArt.box(visual,Vector3(0,1.4,-0.055),Vector3(0.38,0.055,0.03),Color("67edff"),0.35)
	for side in [-1,1]:
		RushArt.box(visual,Vector3(side*0.82,0.75,-0.1),Vector3(0.1,0.13,2.1),tint.lightened(0.3),0.35)
		RushArt.box(visual,Vector3(side*0.67,0.82,-1.65),Vector3(0.4,0.13,0.12),Color("acffff"),1.7)
		RushArt.box(visual,Vector3(side*0.65,0.65,1.57),Vector3(0.34,0.12,0.12),Color("ff7aab"),1.5)
		RushArt.box(visual,Vector3(side*0.68,1.0,1.15),Vector3(0.12,0.8,0.12),Color("334963"))
		for z in [-0.94,0.95]:
			var wheel := RushArt.cylinder(visual,Vector3(side*1.0,0.4,z),0.43,0.38,Color("0b1120"))
			wheel.rotation.z=PI/2
			wheels.append(wheel)
			RushArt.box(wheel,Vector3(0,side*0.205,0),Vector3(0.65,0.035,0.08),tint,0.3)
			var hub := RushArt.cylinder(visual,Vector3(side*1.21,0.4,z),0.22,0.03,tint,0.6)
			hub.rotation.z=PI/2
	RushArt.box(visual,Vector3(0,1.42,1.25),Vector3(2.2,0.16,0.5),tint)
	shield_mesh=MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius=1.8
	sphere.height=3.6
	shield_mesh.mesh=sphere
	var material := RushArt.mat(Color("61d9ff"),0.4).duplicate()
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled=false
	material.albedo_color=Color(0.22,0.72,1,0.12)
	shield_mesh.material_override=material
	visual.add_child(shield_mesh)
	shield_mesh.position.y=0.85
	shield_mesh.visible=false
	sparks=particle(Color("ffc369"),30,0.25,Vector3(0,0.3,1.1),Vector3(0,1,2),0.12)
	exhaust=particle(Color("64eaff"),35,0.28,Vector3(0,0.5,1.6),Vector3(0,0,1),0.28)
	tyre_smoke=particle(Color(0.40,0.49,0.61,0.3),16,0.45,Vector3(0,0.1,1.0),Vector3(0,0.2,1),0.5)

func particle(color: Color, amount: int, lifetime: float, pos: Vector3, direction: Vector3, scale_size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount=amount
	p.lifetime=lifetime
	p.local_coords=false
	p.direction=direction
	p.spread=32
	p.initial_velocity_min=3
	p.initial_velocity_max=7
	p.gravity=Vector3(0,-4,0)
	p.scale_amount_min=scale_size*0.5
	p.scale_amount_max=scale_size
	var mesh := SphereMesh.new()
	mesh.radius=0.25
	mesh.height=0.5
	mesh.radial_segments=6
	mesh.rings=3
	p.mesh=mesh
	var particle_mat := RushArt.mat(Color.WHITE,0.5).duplicate()
	particle_mat.vertex_color_use_as_albedo=true
	particle_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override=particle_mat
	p.color=color
	visual.add_child(p)
	p.position=pos
	p.emitting=false
	return p

func spawn_at(index: int, lane: float = 0.0) -> void:
	global_position=track.sample(index)+track.right_at(index)*lane+Vector3.UP*0.3
	var dir := track.tangent(index)
	heading=atan2(-dir.x,-dir.z)
	rotation.y=heading
	velocity=Vector3.ZERO
	nearest_index=posmod(index,track.points.size())
	safe_index=nearest_index
	progress=track.distances[nearest_index]
	last_progress=progress
	# Spawn/recovery is a teleport: never blend from the previous world position.
	reset_physics_interpolation()

func forward() -> Vector3:
	return Vector3(-sin(heading),0,-cos(heading))

func _physics_process(delta: float) -> void:
	if game == null or game.paused:
		return
	var info := refresh_progress()
	if is_on_floor() and info.distance<11 and forward().dot(track.tangent(nearest_index))>0.4:
		safe_index=nearest_index
	recovery_time=maxf(0,recovery_time-delta)
	boost_time=maxf(0,boost_time-delta)
	if boost_time==0:
		boost_power=0
	slow_time=maxf(0,slow_time-delta)
	hurt_cooldown=maxf(0,hurt_cooldown-delta)
	ramp_cooldown=maxf(0,ramp_cooldown-delta)
	item_delay=maxf(0,item_delay-delta)
	if global_position.y < -3 or info.distance > 38:
		recover()
	if not game.racing or finish_time>=0:
		speed=move_toward(speed,0,delta*18)
		velocity=Vector3(0,-8,0)
		move_and_slide()
		update_visuals(delta)
		return
	var control := ai_control(delta) if not is_player or autopilot else player_control()
	var throttle: float=control.throttle
	var brake: float=control.brake
	steering=move_toward(steering,clampf(control.steer*(game.sensitivity if is_player and not autopilot else 1.0),-1,1),delta*5.5)
	var drifting: bool=control.drift and absf(speed)>10 and absf(steering)>0.12 and (is_on_floor() or was_drifting)
	if drifting:
		if not was_drifting:
			drift_side=signf(steering)
			velocity.y=3.2
		drift_time+=delta
		capacitor=minf(100,capacitor+delta*12)
	elif was_drifting:
		release_drift()
	was_drifting=drifting
	if control.cap and capacitor>=30 and boost_time<0.15:
		capacitor-=30
		boost(1.5,12)
		if is_player:
			game.announce("Capacitor Discharge",Color("b5ff66"))
	if control.use:
		use_item()
	var limit := 33.0
	if not is_player or autopilot:
		limit=control.target_speed
	if boost_time>0:
		limit+=boost_power
	if slow_time>0:
		limit*=0.48
	if throttle>0:
		speed=move_toward(speed,limit,delta*(17+boost_power if boost_time>0 else 13)*throttle)
	elif brake>0:
		speed=move_toward(speed,-10,delta*24*brake)
	else:
		speed=move_toward(speed,0,delta*4)
	if speed>limit:
		speed=move_toward(speed,limit,delta*10)
	var turn_factor := clampf(absf(speed)/12,0.0,1.0)
	var steer_rate := 1.8 if absf(speed)<30 else 1.52
	if drifting:
		steer_rate*=1.12
	heading-=steering*steer_rate*turn_factor*delta*signf(speed)
	rotation.y=heading
	var desired := forward()*speed
	var grip := 3.5 if drifting else 10.0
	velocity.x=lerpf(velocity.x,desired.x,minf(delta*grip,1))
	velocity.z=lerpf(velocity.z,desired.z,minf(delta*grip,1))
	if nearest_index>=170 and nearest_index<=205:
		velocity+=track.right_at(nearest_index)*sin(game.race_time*1.4)*delta*2.0
	if is_on_floor() and velocity.y<0:
		velocity.y=-1
	else:
		velocity.y-=25*delta
	var before := velocity
	move_and_slide()
	for c in range(get_slide_collision_count()):
		var hit := get_slide_collision(c)
		if absf(hit.get_normal().y)<0.4 and before.length()>12 and hurt_cooldown<=0:
			speed*=0.68
			velocity+=hit.get_normal()*5
			hurt_cooldown=0.5
			if is_player:
				play_effect("collision")
				game.shake=0.2
	interact_with_track(delta)
	check_gates()
	if absf(progress-last_progress)<delta*1.4 and speed>2:
		stuck_time+=delta
	else:
		stuck_time=0
	last_progress=progress
	if stuck_time>3.0:
		recover()
	# Drafting rewards following another vehicle without forcing a scripted racing line.
	for other in game.racers:
		if other==self or other.finish_time>=0:
			continue
		var offset: Vector3=other.global_position-global_position
		if offset.length()>3 and offset.length()<14 and forward().dot(offset.normalized())>0.96:
			capacitor=minf(100,capacitor+delta*7)
			break
	update_visuals(delta)

func player_control() -> Dictionary:
	return {"throttle":Input.get_action_strength("accelerate"),"brake":Input.get_action_strength("brake"),"steer":Input.get_axis("left","right"),"drift":Input.is_action_pressed("drift"),"cap":Input.is_action_just_pressed("capacitor"),"use":Input.is_action_just_pressed("item")}

func ai_control(delta: float) -> Dictionary:
	var lookahead := 4+int(absf(speed)*0.10)
	var lane := sin(game.race_time*0.45+style*1.7)*2.8
	var target := track.sample(nearest_index+lookahead)+track.right_at(nearest_index+lookahead)*lane
	# Choose one bounded passing offset; crowded packs must not sum steering offsets.
	for other in game.racers:
		if other==self or other.finish_time>=0:
			continue
		var offset: Vector3=other.global_position-global_position
		if offset.length()<8 and offset.dot(forward())>0:
			lane=clampf(lane+(-2.0 if style%2==0 else 2.0),-4.0,4.0)
			break
	for hazard in track.hazards:
		if posmod(hazard.index-nearest_index,track.points.size())<9:
			lane=-3.0
	target=track.sample(nearest_index+lookahead)+track.right_at(nearest_index+lookahead)*lane
	var delta_pos := target-global_position
	var target_heading := atan2(-delta_pos.x,-delta_pos.z)
	var error := wrapf(target_heading-heading,-PI,PI)
	var steer := clampf(-error*2.4,-1,1)
	var curvature := track.tangent(nearest_index+3).angle_to(track.tangent(nearest_index+10))
	var base: float = [25.0,29.0,33.0][game.difficulty]+style*0.30
	var target_speed := clampf(base-curvature*15,16,base)
	var do_drift := absf(error)>0.17 and absf(error)<0.7 and drift_time<1.6
	ai_item_clock+=delta
	if curvature>0.35 and boost_time>0:
		target_speed=maxf(10,target_speed-boost_power*0.85)
	var do_item := item!="" and ai_item_clock>2.5+style*0.25 and (item!="Turbo Cell" or absf(error)<0.2)
	if do_item:
		ai_item_clock=0
	return {"throttle":1.0,"brake":0.0,"steer":steer,"drift":do_drift,"cap":capacitor>65 and absf(error)<0.2,"use":do_item,"target_speed":target_speed}

func interact_with_track(_delta: float) -> void:
	for p in track.pickups:
		if p.timer<=0 and item=="" and p.node.position.distance_to(global_position+Vector3.UP)<3.2:
			item=["Turbo Cell","EMP Burst","Hardlight Shield"][randi()%3]
			p.timer=5.0
			game.pickup_effect(global_position+Vector3.UP)
			item_delay=0.4
			if is_player:
				play_effect("pickup")
				game.announce(item,Color("54e7ef"))
	for pad in track.pads:
		if global_position.distance_to(pad.pos)<5.0 and boost_time<0.3:
			boost(1.1,9)
	for ramp in track.ramps:
		if global_position.distance_to(ramp.pos)<6.5 and absf((global_position-ramp.pos).dot(track.right_at(ramp.index)))<ramp.width*0.5+0.7 and speed>13 and ramp_cooldown<=0:
			velocity.y=11.5
			capacitor=minf(100,capacitor+13)
			ramp_cooldown=2
			jumps+=1
	for hazard in track.hazards:
		if global_position.distance_to(hazard.node.position)<2.4 and hurt_cooldown<=0:
			attack(1.1)

func refresh_progress() -> Dictionary:
	var info:=track.nearest(global_position)
	nearest_index=info.index
	progress=info.progress
	return info

func check_gates() -> void:
	if not game.racing or game.paused or finish_time>=0:
		return
	refresh_progress()
	var idx := track.checkpoints[next_checkpoint]
	var p := track.sample(idx)
	# Local projection and a spatial gate prevent laps from being earned by teleporting or reversing.
	var index_delta := posmod(nearest_index-idx,track.points.size())
	if index_delta>4 or global_position.distance_to(p)>19:
		return
	if forward().dot(track.tangent(idx))<0.15 or speed<1:
		return
	gate_count+=1
	if next_checkpoint==0:
		lap+=1
		var elapsed: float=game.race_time-lap_start
		lap_times.append(elapsed)
		lap_start=game.race_time
		if is_player:
			game.record_lap(elapsed)
			game.announce("Final Lap" if lap==2 else "Lap %d Complete"%lap,Color("b5ff66"))
		if lap>=3:
			finish_time=game.race_time
			game.racer_finished(self)
	next_checkpoint=(next_checkpoint+1)%track.checkpoints.size()

func release_drift() -> void:
	if drift_time>0.45:
		var tier := 3 if drift_time>2.4 else 2 if drift_time>1.3 else 1
		boost(0.55+tier*0.35,6+tier*2)
		drift_boosts+=1
		if is_player:
			game.announce(["","Mini Turbo","Super Turbo","Ultra Turbo"][tier],Color("ffc369"))
	drift_time=0

func boost(duration: float, power: float) -> void:
	boost_power=maxf(boost_power,power) if boost_time>0 else power
	boost_time=maxf(boost_time,duration)
	if is_player:
		play_effect("boost")

func use_item() -> void:
	if item=="" or item_delay>0 or not game.racing or game.paused or finish_time>=0:
		return
	item_uses+=1
	match item:
		"Turbo Cell":
			boost(2.2,14)
		"EMP Burst":
			for other in game.racers:
				if other!=self and other.finish_time<0 and global_position.distance_to(other.global_position)<24:
					other.attack(2.5)
			game.emp_effect(global_position)
		"Hardlight Shield":
			shield=true
	if is_player:
		play_effect("item")
		game.announce(item+" Activated",tint)
	item=""

func attack(duration: float) -> void:
	if finish_time>=0 or game.paused or not game.racing:
		return
	if shield:
		shield=false
		game.pickup_effect(global_position+Vector3.UP)
		if is_player:
			game.announce("Shield Absorbed Impact",Color("54e7ef"))
	else:
		slow_time=duration
		speed*=0.5
		if is_player:
			game.shake=0.3
			play_effect("collision")
	hurt_cooldown=1.5

func clear_driving_effects() -> void:
	was_drifting=false
	drift_time=0
	drift_side=0
	boost_time=0
	boost_power=0
	drift_audio.stop()
	sparks.emitting=false
	tyre_smoke.emitting=false
	exhaust.emitting=false

func recover() -> void:
	if finish_time>=0:
		return
	clear_driving_effects()
	# Return to the last grounded racing position; recovery never grants progress.
	var idx := posmod(safe_index-2,track.points.size())
	spawn_at(idx,0 if is_player else (style%3-1)*3)
	speed=8
	recovery_time=1.5
	hurt_cooldown=2
	stuck_time=0
	recoveries+=1
	if is_player:
		game.announce("Back on Track",Color("54e7ef"))

func update_visuals(delta: float) -> void:
	for wheel in wheels:
		wheel.rotate_object_local(Vector3.UP,speed*delta*2.2)
	visual.rotation.z=lerpf(visual.rotation.z,-steering*clampf(absf(speed)/30,0,1)*0.10,1-exp(-delta*7))
	visual.rotation.y=lerpf(visual.rotation.y,-drift_side*0.24 if was_drifting else 0.0,1-exp(-delta*6))
	var slope := asin(clampf(track.tangent(nearest_index).y,-1,1))
	visual.rotation.x=lerpf(visual.rotation.x,-slope if is_on_floor() else -0.10,1-exp(-delta*5))
	visual.position.y=sin(game.race_time*20)*0.012*absf(speed)/30
	shield_mesh.visible=shield
	sparks.emitting=was_drifting
	tyre_smoke.emitting=was_drifting
	sparks.color=Color("ffc369") if drift_time<1.3 else Color("54e7ef") if drift_time<2.4 else Color("dc91ff")
	exhaust.emitting=boost_time>0 and game.racing
	if is_player:
		engine.pitch_scale=0.65+absf(speed)/35
		engine.volume_db=-3 if game.racing and finish_time<0 else -12
		if was_drifting and not drift_audio.playing:
			game.play_audio(drift_audio)
		elif not was_drifting:
			drift_audio.stop()

func play_effect(name: String) -> void:
	effects.stream=load("res://assets/"+name+".wav")
	game.play_audio(effects)

func _exit_tree() -> void:
	for audio in [engine,drift_audio,effects]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream=null

func set_audio_paused(value: bool) -> void:
	visual.process_mode=Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	for audio in [engine,drift_audio,effects]:
		audio.stream_paused=value
