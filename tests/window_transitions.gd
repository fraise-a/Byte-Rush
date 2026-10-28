extends SceneTree
var game
var failures:=0
var checks: Array[String]=[]
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks.append(("PASS " if ok else "FAIL ")+message)
	print(checks[-1])
	if not ok: failures+=1
func desired_size() -> Vector2i:
	var available:=DisplayServer.screen_get_usable_rect()
	var target:=RushDisplay.RESOLUTIONS[game.resolution_index]
	var fit:=minf(1.0,minf((available.size.x-40.0)/target.x,(available.size.y-90.0)/target.y))
	return Vector2i(Vector2(target)*fit)
func run() -> void:
	game.volume=0
	game.fullscreen=false
	game.resolution_index=4
	game.apply_settings(true)
	await create_timer(1.0).timeout
	check(root.size.distance_to(desired_size())<=2,"Initial window fits selected resolution")
	game.fullscreen=true
	game.apply_settings(true)
	await process_frame
	game.fullscreen=false
	game.apply_settings(true)
	await create_timer(1.8).timeout
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"Rapid fullscreen toggle settles in the requested mode")
	check(root.size.distance_to(desired_size())<=2,"Window resolution is reapplied after fullscreen animation")
	game.fullscreen=true
	game.apply_settings(true)
	await create_timer(1.1).timeout
	game.fullscreen=false
	game.resolution_index=2
	game.apply_settings(true)
	await create_timer(1.8).timeout
	check(root.size.distance_to(desired_size())<=2,"Changing resolution while leaving fullscreen sets the requested window size")
	var file:=FileAccess.open("user://window_transition_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks},"  "))
	print("WINDOW_REPORT ",root.size)
	game.free()
	quit(0 if failures==0 else 1)
