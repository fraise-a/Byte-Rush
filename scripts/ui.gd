class_name RushUI
extends CanvasLayer

var game: Node3D
var root: Control
var overlay: Control
var screen := ""
var accent := Color("b5ff66")
var white := Color("edf4ff")
var muted := Color("99abc4")
var font: Font = RushArt.font(600)
var toast := ""
var toast_color := Color.WHITE
var toast_time := 0.0
var hud: Control
var focus_target: Control
var result_rows: Array[Label]=[]
var hints: Control
var help_labels: Array[Control]=[]
var connection_label: Label

func _ready() -> void:
	root=Control.new()
	root.size=Vector2(1440,900)
	add_child(root)
	hud=Control.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(draw_hud)
	hints=Control.new()
	root.add_child(hints)
	hints.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hints.draw.connect(draw_hints)
	game.controls.prompts_changed.connect(refresh_prompts)
	build_theme()

func build_theme() -> void:
	var theme := Theme.new()
	theme.default_font=font
	theme.default_font_size=22
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color=Color("b5ff66") if state in ["hover","pressed"] else Color("19263c")
		style.border_color=Color("b5ff66") if state in ["hover","focus"] else Color("34425b")
		style.set_border_width_all(2 if state=="focus" else 1)
		style.corner_radius_top_left=8
		style.corner_radius_bottom_right=8
		style.content_margin_left=23
		style.content_margin_right=23
		style.content_margin_top=15
		style.content_margin_bottom=15
		theme.set_stylebox(state,"Button",style)
		theme.set_stylebox(state,"OptionButton",style)
		theme.set_color("font_"+state+"_color","Button",Color("101d2b") if state in ["hover","pressed"] else white)
	theme.set_color("font_color","Label",white)
	for state in ["normal","hover","pressed","focus"]:
		var toggle_style:=StyleBoxFlat.new()
		toggle_style.bg_color=Color(0.12,0.18,0.32,0.45 if state=="hover" else 0)
		toggle_style.set_content_margin_all(6)
		theme.set_stylebox(state,"CheckButton",toggle_style)
		theme.set_color("font_"+state+"_color","CheckButton",white)
	root.theme=theme

func clear_menu() -> void:
	help_labels.clear()
	result_rows.clear()
	focus_target=null
	if is_instance_valid(overlay):
		root.remove_child(overlay)
		overlay.queue_free()
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	screen=""
	call_deferred("wire_navigation")
	root.move_child(hints,-1)

func set_screen(next_screen: String) -> void:
	screen=next_screen
	game.controls.update_cursor()

func shade(alpha: float = 0.65) -> void:
	var color := ColorRect.new()
	color.name="Backdrop"
	color.mouse_filter=Control.MOUSE_FILTER_IGNORE
	color.color=Color(0.018,0.03,0.065,alpha)
	color.position=-root.position
	color.size=get_viewport().get_visible_rect().size
	overlay.add_child(color)

func label(text: String, pos: Vector2, size: int, color: Color = Color.WHITE, parent: Node = null) -> Label:
	var l := Label.new()
	l.text=text
	l.position=pos
	l.add_theme_font_size_override("font_size",size)
	if size>=40:
		l.add_theme_font_override("font",RushArt.font(700))
	l.add_theme_color_override("font_color",color)
	(parent if parent else overlay).add_child(l)
	return l

func panel(pos: Vector2, size: Vector2, color: Color = Color("101b30")) -> Panel:
	var p := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=Color("344059")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel",style)
	p.position=pos
	p.size=size
	overlay.add_child(p)
	return p

func button(text: String, pos: Vector2, width: float, callback: Callable, focus: bool = false) -> Button:
	var b := Button.new()
	b.text=text
	b.position=pos
	b.custom_minimum_size=Vector2(width,62)
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	overlay.add_child(b)
	b.pressed.connect(func(): game.ui_sound(); callback.call())
	if focus:
		focus_target=b
	return b

func main_menu() -> void:
	clear_menu()
	set_screen("main")
	shade(0.14)
	panel(Vector2(0,0),Vector2(610,900),Color(0.035,0.05,0.13,0.93))
	label("TINY KARTS. MASSIVE ENERGY.",Vector2(65,66),17,accent)
	label("BYTE",Vector2(58,104),116,white)
	label("RUSH",Vector2(58,208),116,accent)
	label("NEON CIRCUIT 01  /  KEYBOARD KINGDOM",Vector2(66,358),17,muted)
	button("01    Grand Prix       →",Vector2(66,422),470,func():game.start_race("Grand Prix"),true)
	button("02    Time Trial        →",Vector2(66,498),470,func():game.start_race("Time Trial"))
	button("03    Settings",Vector2(66,574),470,func():settings("main"))
	button("04    Quit",Vector2(66,650),470,func():game.get_tree().quit())
	add_driving_guide(Vector2(66,745))
	label("Byte Rush "+game.VERSION,Vector2(66,820),15,Color("647f99"))
	panel(Vector2(1030,650),Vector2(350,175),Color(0.035,0.07,0.12,0.9))
	label("THE KEYBOARD KINGDOM",Vector2(1052,672),21,white)
	label("DRIFT  /  CHARGE  /  RUSH",Vector2(1052,711),17,accent)
	label("Drift to charge. Release to surge.\nFind the service bridge shortcut.",Vector2(1052,750),17,muted)

func settings(origin: String) -> void:
	clear_menu()
	set_screen("settings")
	shade(0.90)
	panel(Vector2(300,55),Vector2(840,790),Color("182448"))
	label("TUNE YOUR RIDE",Vector2(350,90),42,accent)
	label("Your setup. Your speed. Saved automatically.",Vector2(352,150),20,muted)
	label("Resolution",Vector2(352,226),23,white)
	var resolution:=OptionButton.new()
	resolution.name="ResolutionChoice"
	for i in range(RushDisplay.RESOLUTIONS.size()):
		resolution.add_item(RushDisplay.resolution_label(i))
	resolution.selected=game.resolution_index
	resolution.position=Vector2(750,210)
	resolution.size=Vector2(350,54)
	overlay.add_child(resolution)
	resolution.item_selected.connect(func(index):game.set_resolution(index))
	focus_target=resolution
	label("3D rendering up to 4K. Window fits your desktop.",Vector2(352,278),16,muted)
	label("Difficulty",Vector2(352,338),23,white)
	var difficulty:=OptionButton.new()
	for name in ["Easy","Normal","Hard"]:
		difficulty.add_item(name)
	difficulty.selected=game.difficulty
	difficulty.position=Vector2(750,322)
	difficulty.size=Vector2(350,54)
	overlay.add_child(difficulty)
	difficulty.item_selected.connect(func(index):game.difficulty=index; game.save_settings())
	label("Master Volume",Vector2(352,422),23,white)
	var volume_value:=label("%d%%"%roundi(game.volume*100),Vector2(650,422),22,accent)
	var volume:=HSlider.new()
	volume.position=Vector2(750,425)
	volume.size=Vector2(350,36)
	volume.min_value=0
	volume.max_value=1
	volume.step=0.01
	volume.value=game.volume
	overlay.add_child(volume)
	volume.value_changed.connect(func(value):game.volume=value; volume_value.text="%d%%"%roundi(value*100); game.apply_settings(); game.save_settings())
	label("Steering Sensitivity",Vector2(352,500),23,white)
	var sensitivity:=HSlider.new()
	sensitivity.position=Vector2(750,503)
	sensitivity.size=Vector2(350,36)
	sensitivity.min_value=0.65
	sensitivity.max_value=1.4
	sensitivity.step=0.05
	sensitivity.value=game.sensitivity
	overlay.add_child(sensitivity)
	sensitivity.value_changed.connect(func(value):game.sensitivity=value; game.save_settings())
	var fullscreen:=CheckButton.new()
	fullscreen.text="Fullscreen"
	fullscreen.position=Vector2(350,578)
	fullscreen.button_pressed=game.fullscreen
	overlay.add_child(fullscreen)
	fullscreen.toggled.connect(func(value):game.fullscreen=value; game.apply_settings(true); game.save_settings())
	var quality:=CheckButton.new()
	quality.text="4× Antialiasing"
	quality.position=Vector2(750,578)
	quality.button_pressed=game.quality
	overlay.add_child(quality)
	quality.toggled.connect(func(value):game.quality=value; game.apply_settings(); game.save_settings())
	add_driving_guide(Vector2(352,642))
	button("←   Back to "+("Race" if origin=="pause" else "Main Menu"),Vector2(352,750),748,func():pause_menu() if origin=="pause" else main_menu())

func pause_menu() -> void:
	clear_menu()
	set_screen("pause")
	shade(0.80)
	label("TAKE A BREATHER",Vector2(470,170),46,accent)
	label("Race Paused",Vector2(473,237),22,muted)
	button("Resume Race   →",Vector2(470,320),500,func():game.toggle_pause(),true)
	button("Restart Race",Vector2(470,397),500,func():game.start_race(game.mode))
	button("Settings",Vector2(470,474),500,func():settings("pause"))
	button("Return to Main Menu",Vector2(470,551),500,func():game.return_to_menu())
	connection_label=label(game.controls.notice,Vector2(470,643),18,muted)

func results() -> void:
	clear_menu()
	set_screen("results")
	shade(0.86)
	var p: RushKart=game.player
	label("RUN COMPLETE",Vector2(180,90),62,accent)
	label(game.mode+"  /  The Keyboard Kingdom",Vector2(184,170),22,muted)
	panel(Vector2(180,238),Vector2(440,390))
	label("YOUR TIME",Vector2(210,266),20,muted)
	label(time_string(p.finish_time),Vector2(205,305),62,white)
	label("BEST LAP",Vector2(210,416),18,muted)
	label(time_string(p.lap_times.min() if p.lap_times.size()>0 else 0),Vector2(210,452),35,accent)
	var record: float=game.records.get("total",0.0)
	label("Personal Best   "+time_string(record) if game.mode=="Time Trial" else "Finish Position   %d / 6"%p.finish_rank,Vector2(210,548),23,white)
	label("FINISHING ORDER" if game.mode=="Grand Prix" else "LAP BREAKDOWN",Vector2(705,250),20,muted)
	if game.mode=="Grand Prix":
		var order: Array=game.sorted_racers()
		for i in range(order.size()):
			var racer: RushKart=order[i]
			var timing := time_string(racer.finish_time) if racer.finish_time>=0 else "Racing · Lap %d"%mini(3,racer.lap+1)
			result_rows.append(label("%02d   %-12s   %s"%[i+1,racer.driver_name,timing],Vector2(705,300+i*49),23,accent if racer.is_player else white))
	else:
		for i in range(p.lap_times.size()):
			label("Lap %d                 %s"%[i+1,time_string(p.lap_times[i])],Vector2(705,310+i*72),28,white)
		label("Best Lap Record   "+time_string(game.records.get("lap",0)),Vector2(705,553),22,accent)
	button("Race Again    →",Vector2(180,710),500,func():game.start_race(game.mode),true)
	button("Main Menu",Vector2(715,710),500,func():game.return_to_menu())
	add_drift_tip()

func update_results_standings() -> void:
	if screen!="results" or game.mode!="Grand Prix":
		return
	var order: Array=game.sorted_racers()
	for i in range(mini(order.size(),result_rows.size())):
		var racer: RushKart=order[i]
		var timing:=time_string(racer.finish_time) if racer.finish_time>=0 else "Racing · Lap %d"%mini(3,racer.lap+1)
		result_rows[i].text="%02d   %-12s   %s"%[i+1,racer.driver_name,timing]
		result_rows[i].add_theme_color_override("font_color",accent if racer.is_player else white)

func race_hud() -> void:
	clear_menu()
	set_screen("race")
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	root.position=(get_viewport().get_visible_rect().size-root.size)*0.5
	if is_instance_valid(overlay):
		var backdrop:=overlay.get_node_or_null("Backdrop") as ColorRect
		if backdrop:
			backdrop.position=-root.position
			backdrop.size=get_viewport().get_visible_rect().size
	if is_instance_valid(focus_target) and focus_target.is_inside_tree():
		focus_target.grab_focus()
		focus_target=null
	if not game.paused:
		toast_time=maxf(0,toast_time-delta)
	hud.queue_redraw()
	hints.queue_redraw()

func text_at(text: String, pos: Vector2, size: int, color: Color = Color.WHITE) -> void:
	hud.draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func rect(pos: Vector2, size: Vector2, color: Color) -> void:
	hud.draw_style_box(make_style(color),Rect2(pos,size))

func make_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(12)
	s.border_color=Color(0.38,0.54,0.82,0.20)
	s.set_border_width_all(1)
	return s

func draw_hud() -> void:
	if screen!="race" or not is_instance_valid(game.player):
		return
	var p: RushKart=game.player
	draw_speed_lines(p)
	var dark := Color(0.045,0.075,0.17,0.88)
	rect(Vector2(35,30),Vector2(290,118),dark)
	text_at("%02d"%game.position_of(p),Vector2(54,120),82,accent)
	text_at("/ 06" if game.mode=="Grand Prix" else "/ TT",Vector2(180,83),23,muted)
	text_at("POSITION" if game.mode=="Grand Prix" else "SOLO RUN",Vector2(179,118),16,white)
	rect(Vector2(345,30),Vector2(235,118),dark)
	text_at("LAP",Vector2(365,66),17,muted)
	text_at("%d / 3"%mini(3,p.lap+1),Vector2(365,120),38,white)
	rect(Vector2(600,30),Vector2(255,118),dark)
	text_at("RACE TIME",Vector2(622,66),17,muted)
	text_at(time_string(game.race_time),Vector2(622,119),34,white)
	draw_minimap()
	if game.mode=="Grand Prix":
		rect(Vector2(35,184),Vector2(225,250),dark)
		var order: Array=game.sorted_racers()
		for i in range(order.size()):
			var racer: RushKart=order[i]
			hud.draw_circle(Vector2(58,211+i*38),4,racer.tint)
			text_at("%d  %s"%[i+1,racer.driver_name],Vector2(73,219+i*38),19,accent if racer.is_player else muted)
	var zone := "Mechanical Keyboard" if p.nearest_index<80 else "Motherboard Motorway" if p.nearest_index<160 else "Cooling Chamber"
	text_at(zone.to_upper(),Vector2(37,860),18,muted)
	rect(Vector2(1120,713),Vector2(280,147),dark)
	text_at("%03d"%int(absf(p.speed)*5.0),Vector2(1142,811),74,accent if p.boost_time>0 else white)
	text_at("KM/H",Vector2(1305,808),19,muted)
	text_at("CAPACITOR ACTIVE" if p.boost_time>0 else "ELECTRIC DRIVE",Vector2(1145,843),15,accent if p.boost_time>0 else muted)
	rect(Vector2(465,752),Vector2(510,110),dark)
	text_at("CAPACITOR",Vector2(490,784),17,muted)
	RushPrompts.draw_action(hud,font,game.controls,"capacitor",Vector2(747,762),26)
	text_at("%d%%"%p.capacitor,Vector2(797,784),17,accent)
	rect(Vector2(490,805),Vector2(460,20),Color("29394e"))
	rect(Vector2(490,805),Vector2(maxf(1,460*p.capacitor/100),20),accent if p.capacitor>=30 else Color("527477"))
	text_at("Drift · Draft · Jump to recharge",Vector2(490,848),15,muted)
	rect(Vector2(35,657),Vector2(278,145),dark)
	RushPrompts.phrase(hud,font,game.controls,"item","ITEM",Vector2(57,665),26,17,muted)
	text_at(p.item if p.item!="" else "Empty Slot",Vector2(57,733),24,white if p.item!="" else muted)
	text_at("Shield Online" if p.shield else "Collect a glowing cube",Vector2(57,775),16,Color("54e7ef") if p.shield else muted)
	if p.drift_time>0:
		var c := Color("ffc369") if p.drift_time<1.3 else Color("54e7ef") if p.drift_time<2.4 else Color("dc91ff")
		text_at("DRIFT CHARGE",Vector2(606,674),22,c)
		rect(Vector2(555,692),Vector2(330,7),Color("29394e"))
		rect(Vector2(555,692),Vector2(330*minf(p.drift_time/2.4,1),7),c)
	if game.countdown>0:
		rect(Vector2(548,280),Vector2(344,220),dark)
		text_at(str(ceili(game.countdown)),Vector2(665,445),126,accent)
		text_at("GET READY",Vector2(647,320),23,white)
	elif game.race_time<1.0:
		text_at("GO!",Vector2(625,430),110,accent)
	if toast_time>0 and game.racing:
		rect(Vector2(470,184),Vector2(500,56),dark)
		text_at(toast,Vector2(494,222),25,toast_color)
	rect(Vector2(1060,865),Vector2(340,28),dark)
	var pause_width:=RushPrompts.phrase(hud,font,game.controls,"pause","Pause",Vector2(1070,866),25,14)
	RushPrompts.phrase(hud,font,game.controls,"recover","Recover",Vector2(1090+pause_width,866),25,14)
	rect(Vector2(1090,660),Vector2(310,40),dark)
	var drive_width:=RushPrompts.phrase(hud,font,game.controls,"accelerate","Accelerate",Vector2(1100,668),25,15)
	RushPrompts.phrase(hud,font,game.controls,"brake","Brake",Vector2(1112+drive_width,668),25,15)
	rect(Vector2(465,706),Vector2(510,38),dark)
	text_at("Hold",Vector2(480,732),17,white)
	var drift_width:=RushPrompts.draw_action(hud,font,game.controls,"drift",Vector2(526,712),26)
	text_at("in a turn · Release to boost",Vector2(535+drift_width,732),17,white)
	if game.racing and p.speed>5 and p.forward().dot(game.track.tangent(p.nearest_index))< -0.3:
		text_at("WRONG WAY  ↶",Vector2(580,310),32,Color("ff799d"))

func draw_minimap() -> void:
	var origin := Vector2(1255,172)
	rect(Vector2(1100,30),Vector2(300,268),Color(0.035,0.06,0.115,0.88))
	text_at("CIRCUIT 01",Vector2(1120,60),16,muted)
	var path := PackedVector2Array()
	for p in game.track.points:
		path.append(origin+Vector2(p.x,p.z)*0.94)
	path.append(path[0])
	hud.draw_polyline(path,Color("52627c"),5,true)
	var sp: Vector3=game.track.sample(0)
	hud.draw_circle(origin+Vector2(sp.x,sp.z)*0.94,4,accent)
	for racer in game.racers:
		var pos: Vector3=racer.get_global_transform_interpolated().origin
		hud.draw_circle(origin+Vector2(pos.x,pos.z)*0.94,5 if racer.is_player else 3,racer.tint)

static func time_string(value: float) -> String:
	if value<0:
		return "--:--.---"
	var ms := int(value*1000)
	return "%02d:%02d.%03d"%[ms/60000,(ms/1000)%60,ms%1000]

func draw_speed_lines(p: RushKart) -> void:
	if p.boost_time<=0 or not game.racing or game.paused:
		return
	var center:=Vector2(720,450)
	var clock:=Time.get_ticks_msec()/1000.0
	for i in range(22):
		var angle:=i*TAU/22.0+0.10
		var direction:=Vector2(cos(angle)*850,sin(angle)*560)
		var phase:=fmod(clock*1.5+i*0.137,1.0)
		var begin:=0.68+phase*0.2
		var end:=begin+0.08
		var color:=Color(0.3,0.95,1.0,0.16*(1-phase))
		hud.draw_line(center+direction*begin,center+direction*end,color,1.5,true)

func refresh_prompts() -> void:
	if is_instance_valid(connection_label):
		connection_label.text=game.controls.notice
	for help in help_labels:
		if is_instance_valid(help):
			help.tooltip_text=game.controls.drift_tip_description() if help.get_meta("prompt_context","")=="drift_tip" else game.controls.driving_help()
			help.queue_redraw()
	hints.queue_redraw()
	hud.queue_redraw()

func menu_controls() -> Array[Control]:
	var result: Array[Control]=[]
	if is_instance_valid(overlay):
		for child in overlay.get_children():
			if child is BaseButton or child is Range:
				if child.visible:
					result.append(child)
	return result

func wire_navigation() -> void:
	if not is_instance_valid(overlay) or overlay.has_meta("navigation_wired"):
		return
	overlay.set_meta("navigation_wired",true)
	var items:=menu_controls()
	for i in range(items.size()):
		var item:=items[i]
		item.focus_mode=Control.FOCUS_ALL
		var previous:=item.get_path_to(items[posmod(i-1,items.size())])
		var following:=item.get_path_to(items[(i+1)%items.size()])
		item.focus_previous=previous
		item.focus_next=following
		item.focus_neighbor_top=previous
		item.focus_neighbor_bottom=following
		item.mouse_entered.connect(item.grab_focus)
		if item is Range:
			item.draw.connect(func():
				if item.has_focus():
					var focus:=StyleBoxFlat.new()
					focus.bg_color=Color.TRANSPARENT
					focus.border_color=accent
					focus.set_border_width_all(2)
					focus.set_corner_radius_all(6)
					item.draw_style_box(focus,Rect2(Vector2(-9,-8),item.size+Vector2(18,16))))
			item.focus_entered.connect(item.queue_redraw)
			item.focus_exited.connect(item.queue_redraw)
	# Checkbuttons share a row: horizontal navigation moves between them.
	for i in range(items.size()-1):
		if items[i] is CheckButton and items[i+1] is CheckButton:
			items[i].focus_neighbor_right=items[i].get_path_to(items[i+1])
			items[i+1].focus_neighbor_left=items[i+1].get_path_to(items[i])

func ensure_focus() -> void:
	var current:=get_viewport().gui_get_focus_owner()
	if is_instance_valid(current) and is_instance_valid(overlay) and overlay.is_ancestor_of(current):
		return
	if is_instance_valid(focus_target) and focus_target.is_inside_tree():
		focus_target.grab_focus()
		focus_target=null
	else:
		var items:=menu_controls()
		if not items.is_empty():
			items[0].grab_focus()

func hint_chip(x: float, action: String, description: String) -> float:
	return x+RushPrompts.phrase(hints,font,game.controls,action,description,Vector2(x,858),28,16)+28

func add_driving_guide(pos: Vector2) -> void:
	var guide:=Control.new()
	guide.position=pos
	guide.size=Vector2(740,68)
	guide.mouse_filter=Control.MOUSE_FILTER_IGNORE
	guide.tooltip_text=game.controls.driving_help()
	overlay.add_child(guide)
	help_labels.append(guide)
	guide.draw.connect(func():
		var x:=RushPrompts.draw_action(guide,font,game.controls,"accelerate",Vector2.ZERO,25)+6
		guide.draw_string(font,Vector2(x,18),"/",HORIZONTAL_ALIGNMENT_LEFT,-1,16,muted)
		x+=14
		x+=RushPrompts.phrase(guide,font,game.controls,"brake","Drive",Vector2(x,0),25,15,muted)+22
		RushPrompts.phrase(guide,font,game.controls,"steer","Steer",Vector2(x,0),25,15,muted)
		x=0
		for pair in [["drift","Drift"],["capacitor","Boost"],["item","Item"],["recover","Recover"]]:
			x+=RushPrompts.phrase(guide,font,game.controls,pair[0],pair[1],Vector2(x,34),25,15,muted)+18)

func draw_hints() -> void:
	if screen=="race" or screen=="":
		return
	hints.draw_style_box(make_style(Color(0.025,0.045,0.10,0.94)),Rect2(30,853,1380,39))
	var x:=48.0
	if game.controls.family=="keyboard":
		x=hint_chip(x,"navigate","Navigate")
	if screen=="settings":
		x=hint_chip(x,"adjust","Adjust")
	x=hint_chip(x,"confirm","Select")
	if screen!="main":
		x=hint_chip(x,"back","Resume" if screen=="pause" else "Main Menu" if screen=="results" else "Back")
	elif game.controls.family!="keyboard":
		hint_chip(x,"pause","Quick Race")

func add_drift_tip() -> void:
	var tip:=Control.new()
	tip.name="ResultsDriftTip"
	tip.set_meta("prompt_context","drift_tip")
	tip.position=Vector2(182,810)
	tip.size=Vector2(1080,34)
	tip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	tip.tooltip_text=game.controls.drift_tip_description()
	overlay.add_child(tip)
	help_labels.append(tip)
	tip.draw.connect(func():
		tip.draw_string(font,Vector2(0,24),"Hold",HORIZONTAL_ALIGNMENT_LEFT,-1,18,muted)
		var width:=RushPrompts.draw_action(tip,font,game.controls,"drift",Vector2(49,1),29)
		tip.draw_string(font,Vector2(58+width,24),"through a corner. Release at amber, cyan or violet for a stronger turbo.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,muted))
