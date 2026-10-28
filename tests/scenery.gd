extends SceneTree
# Focused GPU captures of areas implicated in scenery artefacts.
var game
var captures: Array[Dictionary]=[]
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")
func frames(count: int) -> void:
	for i in range(count):
		await process_frame
func capture(name: String, position: Vector3, target: Vector3, fov: float = 60) -> void:
	game.camera.position=position
	game.camera.look_at(target)
	game.camera.fov=fov
	await frames(3)
	RenderingServer.force_draw(false)
	var image: Image=game.display_system.viewport.get_texture().get_image()
	image.save_png("res://tests/"+name+".png")
	captures.append({"name":name,"pixels":[image.get_width(),image.get_height()]})
	print("CAPTURE ",name," ",image.get_size())
func run() -> void:
	await frames(3)
	game.volume=0
	game.fullscreen=false
	game.resolution_index=4
	game.apply_settings(true)
	game.set_process(false)
	game.ui.hide()
	var track: RushTrack=game.track
	var p: Vector3=track.sample(128)
	await capture("scenery-hairpin",p+Vector3(0,22,25),p+Vector3(0,0,-6),61)
	p=track.sample(40)
	await capture("scenery-boost",p-track.tangent(40)*12+Vector3.UP*8,p+track.tangent(40)*3,58)
	p=track.sample(80)
	await capture("scenery-sign",p-track.tangent(80)*25+Vector3.UP*7,p+Vector3.UP*7,52)
	var mount: Node3D=track.fans[1].get_parent()
	var toward_track: Vector3=(track.sample(181)+Vector3.UP*4-mount.global_position).normalized()
	for i in range(4):
		await frames(12)
		await capture("scenery-fan-%d"%i,mount.global_position+toward_track*30+Vector3.UP*2,mount.global_position,53)
	game.resolution_index=8
	game.apply_settings(true)
	await frames(3)
	p=track.sample(128)
	await capture("scenery-hairpin-4k",p+Vector3(0,18,22),p+Vector3(0,0,-6),61)
	var result:={"captures":captures,"device":RenderingServer.get_video_adapter_name(),"all_saved":captures.size()==8}
	var report:=FileAccess.open("user://scenery_results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(result,"  "))
	print("SCENERY_REPORT ",result)
	game.free()
	quit()
