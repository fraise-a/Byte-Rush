extends SceneTree
var game
var failed:=false
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	print(("PASS " if ok else "FAIL ")+description)
	failed=failed or not ok
func mouse() -> void:
	var event:=InputEventMouseMotion.new()
	event.relative=Vector2(20,0)
	event.screen_relative=Vector2(20,0)
	Input.parse_input_event(event)
func run() -> void:
	await process_frame
	game.profile_prefix="validation_cursor_"
	game.controls.set_active("keyboard")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Mouse cursor is available in main menu")
	var text:=""
	for child in game.ui.overlay.get_children():
		if child is Label: text+=child.text
	check(not text.contains("4K") and not text.contains("UHD"),"Main menu has no 4K promotion")
	game.start_race("Grand Prix")
	check(Input.mouse_mode==Input.MOUSE_MODE_HIDDEN,"Cursor hides immediately for countdown")
	mouse()
	await process_frame
	await process_frame
	check(Input.mouse_mode==Input.MOUSE_MODE_HIDDEN,"Mouse motion cannot reveal the racing cursor")
	game.countdown=0;game.racing=true
	game.controls.remember_device(9,"Xbox Wireless Controller")
	game.controls.select_device(9)
	mouse()
	await process_frame
	await process_frame
	check(game.controls.family=="keyboard" and Input.mouse_mode==Input.MOUSE_MODE_HIDDEN,"Switching from controller to keyboard while racing keeps cursor hidden")
	game.toggle_pause()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Mouse cursor returns for pause menu")
	game.ui.settings("pause")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Mouse cursor remains available in paused Settings")
	game.ui.pause_menu();game.toggle_pause()
	check(Input.mouse_mode==Input.MOUSE_MODE_HIDDEN,"Resuming hides cursor again")
	game.player.lap_times.assign([30.0,30.0,30.0])
	game.player.finish_time=90
	game.racer_finished(game.player)
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Results restore the mouse cursor")
	game.return_to_menu()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Returning to main menu restores the mouse cursor")
	await process_frame
	game.free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
