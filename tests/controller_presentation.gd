extends SceneTree
var game
func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")
func frames(count: int=4) -> void:
	for i in range(count):
		await process_frame
func capture(name: String) -> void:
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://tests/"+name+".png")
	print("CAPTURE "+name)
func run() -> void:
	await frames()
	game.volume=0
	game.fullscreen=false
	game.resolution_index=4
	game.apply_settings(true)
	game.controls.remember_device(8,"DualSense Wireless Controller")
	game.controls.remember_device(9,"Nintendo Switch Pro Controller")
	game.controls.remember_device(10,"Xbox Wireless Controller")
	game.controls.rebuild_menu_bindings()
	game.controls.select_device(8)
	await frames(30)
	capture("playstation-menu")
	game.ui.settings("main")
	await frames()
	capture("playstation-settings")
	game.start_race("Grand Prix")
	game.player.autopilot=true
	game.countdown=0.01
	await frames(170)
	capture("playstation-driving")
	game.toggle_pause()
	await frames()
	capture("playstation-pause")
	game.return_to_menu()
	game.controls.select_device(9)
	await frames()
	capture("nintendo-menu")
	game.controls.select_device(10)
	await frames()
	capture("xbox-menu")
	game.controls.set_active("keyboard")
	await frames()
	capture("keyboard-menu")
	game.free()
	quit()
