extends SceneTree
# Display integration checks run with either the headless driver or real GPU rendering.
var game
var failures:=0
var checks: Array[String]=[]
var rendered:=false

func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func check(ok: bool, description: String) -> void:
	var message:=("PASS " if ok else "FAIL ")+description
	checks.append(message)
	print(message)
	if not ok:
		failures+=1

func run() -> void:
	await frames(3)
	game.volume=0
	game.profile_prefix="validation_display_"
	game.apply_settings()
	game.ui.settings("main")
	var choice: OptionButton=game.ui.overlay.get_node("ResolutionChoice")
	check(choice.item_count==RushDisplay.RESOLUTIONS.size(),"Settings exposes every supported resolution")
	check(RushDisplay.RESOLUTIONS[-1]==Vector2i(3840,2160),"Highest offered resolution is 4K UHD")
	for i in range(choice.item_count):
		choice.select(i)
		choice.item_selected.emit(i)
		await frames(2)
		var actual: Vector2i=game.display_system.viewport.size
		var bounds: Vector2i=RushDisplay.RESOLUTIONS[i]
		check(game.resolution_index==i and actual.x<=bounds.x and actual.y<=bounds.y,"Resolution %s applies within its render limit"%RushDisplay.resolution_label(i))
	game.save_settings()
	game.resolution_index=0
	game.load_settings()
	check(game.resolution_index==8,"Chosen 4K resolution survives save/load")
	game.set_resolution(999)
	check(game.resolution_index==8,"Out-of-range selection clamps to 4K")
	check(root.max_size==RushDisplay.MAX_RESOLUTION,"Resizable window is capped at 4K")
	check(game.camera.get_viewport()==game.display_system.viewport,"Race camera uses bounded render viewport")
	game.fullscreen=true
	game.apply_settings(true)
	await frames(3)
	var actual: Vector2i=game.display_system.viewport.size
	check(actual.x<=3840 and actual.y<=2160,"Fullscreen rendering respects the 4K cap")
	if DisplayServer.get_name()!="headless":
		rendered=true
		game.fullscreen=false
		game.apply_settings(true)
		game.start_race("Grand Prix")
		game.player.autopilot=true
		game.countdown=0.01
		await frames(90)
		# Exact offscreen 4K readback checks the GPU target independent of desktop dimensions.
		game.display_system.viewport.size=RushDisplay.MAX_RESOLUTION
		RenderingServer.force_draw(false)
		var image: Image=game.display_system.viewport.get_texture().get_image()
		check(image.get_size()==RushDisplay.MAX_RESOLUTION,"GPU renders and reads back an exact 3840 × 2160 frame")
		image.save_png("res://tests/gameplay-4k.png")
		game.ui.settings("pause")
		await frames(2)
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://tests/settings.png")
		print("CAPTURE settings and gameplay-4k")
	game.fullscreen=false
	game.apply_settings()
	var report:={"passed":failures==0,"rendered":rendered,"checks":checks}
	var file:=FileAccess.open("user://display_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("DISPLAY_REPORT "+ProjectSettings.globalize_path("user://display_results.json"))
	game.free()
	quit(0 if failures==0 else 1)
