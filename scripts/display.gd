class_name RushDisplay
extends Node

# Resolution is a bounded 3D render budget, independent of macOS Retina/fullscreen size.
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280,720), Vector2i(1280,800), Vector2i(1440,900), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(1920,1200), Vector2i(2560,1440), Vector2i(2560,1600), Vector2i(3840,2160)]
const MAX_RESOLUTION := Vector2i(3840,2160)
var viewport: SubViewport
var image: TextureRect
var selected := 4
var requested_fullscreen:=false
var mode_initialized:=false
var reconcile_until:=0
var next_mode_attempt:=0
var next_fit_attempt:=0
var resize_pending:=false

func _ready() -> void:
	viewport=SubViewport.new()
	viewport.name="RaceRender"
	viewport.world_3d=get_viewport().find_world_3d()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input=true
	add_child(viewport)
	var canvas:=CanvasLayer.new()
	canvas.layer=-10
	add_child(canvas)
	image=TextureRect.new()
	image.texture=viewport.get_texture()
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_SCALE
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_window().max_size=MAX_RESOLUTION
	get_window().min_size=Vector2i(960,600)
	get_window().size_changed.connect(update_render_size)

func apply(index: int, fullscreen: bool, antialiasing: bool, resize_window: bool = true) -> void:
	selected=clampi(index,0,RESOLUTIONS.size()-1)
	viewport.msaa_3d=Viewport.MSAA_4X if antialiasing else Viewport.MSAA_DISABLED
	var now:=Time.get_ticks_msec()
	var mode_changed:=not mode_initialized or requested_fullscreen!=fullscreen
	requested_fullscreen=fullscreen
	mode_initialized=true
	if mode_changed or resize_window:
		# AppKit can ignore a second toggle while its first animation is in flight.
		# Reconcile only for this bounded request, never continuously fight OS controls.
		reconcile_until=now+3500
		next_mode_attempt=0
		next_fit_attempt=0
		resize_pending=not fullscreen and resize_window
	if DisplayServer.get_name()!="headless":
		reconcile_window()
	update_render_size()

func fitted_window_size() -> Vector2i:
	var available:=DisplayServer.screen_get_usable_rect()
	var target:=RESOLUTIONS[selected]
	var fit:=minf(1.0,minf(maxf(1,available.size.x-40.0)/target.x,maxf(1,available.size.y-90.0)/target.y))
	return Vector2i(Vector2(target)*fit)

func reconcile_window() -> void:
	var now:=Time.get_ticks_msec()
	if now>reconcile_until:
		resize_pending=false
		return
	var target_mode:=DisplayServer.WINDOW_MODE_FULLSCREEN if requested_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode()!=target_mode and now>=next_mode_attempt:
		DisplayServer.window_set_mode(target_mode)
		next_mode_attempt=now+450
		if not requested_fullscreen:
			resize_pending=true
	if resize_pending and not requested_fullscreen and DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED and now>=next_fit_attempt:
		var size:=fitted_window_size()
		if get_window().size==size:
			resize_pending=false
		else:
			var available:=DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(available.position+(available.size-size)/2)
			next_fit_attempt=now+200

func _process(_delta: float) -> void:
	if DisplayServer.get_name()!="headless" and Time.get_ticks_msec()<=reconcile_until:
		reconcile_window()

func update_render_size() -> void:
	if not is_instance_valid(viewport):
		return
	var bounds:=RESOLUTIONS[selected]
	var window_size:=get_window().size
	if window_size.x<100 or window_size.y<100:
		window_size=bounds # Headless driver uses a tiny dummy window.
	var factor:=minf(float(bounds.x)/window_size.x,float(bounds.y)/window_size.y)
	viewport.size=Vector2i(maxi(1,roundi(window_size.x*factor)),maxi(1,roundi(window_size.y*factor)))
	viewport.size=viewport.size.clamp(Vector2i.ONE,MAX_RESOLUTION)

static func resolution_label(index: int) -> String:
	var value:=RESOLUTIONS[clampi(index,0,RESOLUTIONS.size()-1)]
	return "%d × %d%s"%[value.x,value.y,"  ·  4K UHD" if value==MAX_RESOLUTION else ""]
