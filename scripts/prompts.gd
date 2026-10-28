class_name RushPrompts
extends RefCounted
# Resolution-independent button artwork. Semantic names remain in RushControls for
# descriptions; visible prompts use these vector shapes rather than font glyphs.
const INK:=Color("edf4ff")
const FILL:=Color("18263d")

static func width(family: String, action: String, height: float) -> float:
	if action=="navigate": return height if family=="keyboard" else height*2.3
	if action=="adjust": return height*1.5
	if family=="keyboard":
		if action=="confirm": return height*2.1
		if action=="steer": return height*2.0
		if action=="drift": return height*1.6
		if action in ["back","pause"]: return height*1.35
	if action in ["accelerate","brake","capacitor"]: return height*1.4
	return height

static func line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, thickness: float) -> void:
	canvas.draw_line(a,b,color,thickness,true)

static func ring(canvas: CanvasItem, center: Vector2, radius: float, color: Color, thickness: float) -> void:
	canvas.draw_arc(center,radius,0,TAU,48,color,thickness,true)

static func keycap(canvas: CanvasItem, rect: Rect2, color: Color=INK) -> void:
	var style:=StyleBoxFlat.new()
	style.bg_color=FILL
	style.border_color=color
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	canvas.draw_style_box(style,rect)

static func centered(canvas: CanvasItem, font: Font, text: String, center: Vector2, size: int, color: Color=INK) -> void:
	var dimensions:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size)
	canvas.draw_string(font,center+Vector2(-dimensions.x*0.5,(font.get_ascent(size)-font.get_descent(size))*0.5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

static func arrows(canvas: CanvasItem, center: Vector2, size: float, color: Color, horizontal_only: bool=false) -> void:
	var stroke:=maxf(1.5,size*0.075)
	for direction in [Vector2.LEFT,Vector2.RIGHT] if horizontal_only else [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		var tip: Vector2=center+direction*size*0.4
		var base: Vector2=center+direction*size*0.12
		var lateral:=Vector2(-direction.y,direction.x)*size*0.15
		line(canvas,base,tip,color,stroke)
		line(canvas,tip,base+lateral,color,stroke)
		line(canvas,tip,base-lateral,color,stroke)

static func stick(canvas: CanvasItem, center: Vector2, size: float) -> void:
	ring(canvas,center+Vector2(0,size*0.12),size*0.35,INK,1.5)
	canvas.draw_circle(center+Vector2(size*0.1,-size*0.13),size*0.22,FILL)
	ring(canvas,center+Vector2(size*0.1,-size*0.13),size*0.22,INK,1.7)
	line(canvas,center+Vector2(0,size*0.16),center+Vector2(size*0.1,-size*0.13),INK,2)

static func dpad(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var points:=PackedVector2Array()
	for p in [Vector2(-1,-3),Vector2(1,-3),Vector2(1,-1),Vector2(3,-1),Vector2(3,1),Vector2(1,1),Vector2(1,3),Vector2(-1,3),Vector2(-1,1),Vector2(-3,1),Vector2(-3,-1),Vector2(-1,-1),Vector2(-1,-3)]:
		points.append(center+p*size*0.125)
	canvas.draw_colored_polygon(points,FILL)
	canvas.draw_polyline(points,INK,1.5,true)
	canvas.draw_circle(center,size*0.06,INK)

static func draw_action(canvas: CanvasItem, font: Font, controls: RushControls, action: String, pos: Vector2, height: float=26) -> float:
	var family:=controls.family
	var w:=width(family,action,height)
	var center:=pos+Vector2(w*0.5,height*0.5)
	var stroke:=maxf(1.7,height*0.075)
	if action=="navigate":
		if family=="keyboard":
			keycap(canvas,Rect2(pos,Vector2(height,height)))
			centered(canvas,font,"Tab",pos+Vector2.ONE*height*0.5,int(height*0.4))
		else:
			stick(canvas,pos+Vector2.ONE*height*0.5,height)
			dpad(canvas,pos+Vector2(height*1.7,height*0.5),height)
		return w
	if action=="adjust":
		keycap(canvas,Rect2(pos,Vector2(w,height)))
		arrows(canvas,center,height*0.9,INK,true)
		return w
	if action=="steer" and family!="keyboard":
		stick(canvas,center,height)
		return w
	if family=="keyboard":
		if action=="steer":
			for i in range(2):
				var rect:=Rect2(pos+Vector2(i*height,0),Vector2(height*0.9,height))
				keycap(canvas,rect)
				centered(canvas,font,"A" if i==0 else "D",rect.get_center(),int(height*0.5))
		elif action=="confirm":
			keycap(canvas,Rect2(pos,Vector2(height,height)))
			var c:=pos+Vector2.ONE*height*0.5
			line(canvas,c+Vector2(5,-5),c+Vector2(5,2),INK,stroke)
			line(canvas,c+Vector2(5,2),c+Vector2(-5,2),INK,stroke)
			line(canvas,c+Vector2(-5,2),c+Vector2(-1,-2),INK,stroke)
			line(canvas,c+Vector2(-5,2),c+Vector2(-1,6),INK,stroke)
			var mouse:=Rect2(pos+Vector2(height*1.2,0),Vector2(height*0.75,height))
			keycap(canvas,mouse)
			canvas.draw_rect(Rect2(mouse.position+Vector2(3,3),Vector2(mouse.size.x*0.4,mouse.size.y*0.35)),INK)
			line(canvas,mouse.position+Vector2(mouse.size.x*0.5,2),mouse.position+Vector2(mouse.size.x*0.5,mouse.size.y*0.5),INK,1)
		else:
			keycap(canvas,Rect2(pos,Vector2(w,height)))
			if action=="drift":
				line(canvas,center+Vector2(-w*0.28,2),center+Vector2(w*0.28,2),INK,stroke)
				for side in [-1,1]: line(canvas,center+Vector2(side*w*0.28,2),center+Vector2(side*w*0.28,-3),INK,stroke)
			elif action=="capacitor":
				var points:=PackedVector2Array([center+Vector2(-7,0),center+Vector2(0,-7),center+Vector2(7,0),center+Vector2(3,0),center+Vector2(3,7),center+Vector2(-3,7),center+Vector2(-3,0),center+Vector2(-7,0)])
				canvas.draw_polyline(points,INK,1.5,true)
			else:
				var text: String={"accelerate":"W","brake":"S","item":"E","recover":"R","back":"Esc","pause":"Esc"}.get(action,action)
				centered(canvas,font,text,center,int(height*(0.42 if text=="Esc" else 0.5)))
		return w
	if action in ["accelerate","brake","capacitor"]:
		keycap(canvas,Rect2(pos,Vector2(w,height)))
		if family=="generic":
			# Highlight the physical top-button position instead of borrowing Xbox labels.
			for right in [false,true]:
				var left:=pos.x+w*(0.56 if right else 0.12)
				var selected: bool=right if action!="brake" else not right
				var color:=INK if selected else Color("576981")
				if action=="capacitor":
					canvas.draw_rect(Rect2(Vector2(left,pos.y+height*0.52),Vector2(w*0.3,height*0.18)),color)
				else:
					canvas.draw_rect(Rect2(Vector2(left,pos.y+height*0.18),Vector2(w*0.3,height*0.34)),color)
		else:
			centered(canvas,font,controls.prompt(action),center,int(height*0.48))
		return w
	if action=="pause":
		if family=="playstation":
			keycap(canvas,Rect2(pos+Vector2(w*0.18,0),Vector2(w*0.64,height)))
		else:
			canvas.draw_circle(center,height*0.46,FILL)
			ring(canvas,center,height*0.46,INK,1.2)
		if family=="nintendo":
			line(canvas,center+Vector2(-6,0),center+Vector2(6,0),INK,stroke)
			line(canvas,center+Vector2(0,-6),center+Vector2(0,6),INK,stroke)
		else:
			for y in [-4,0,4]: line(canvas,center+Vector2(-5,y),center+Vector2(5,y),INK,stroke)
		return w
	var button: String=controls.prompt(action)
	canvas.draw_circle(center,height*0.46,FILL)
	ring(canvas,center,height*0.46,INK,1.2)
	if family=="playstation":
		var colors:={"Cross":Color("7abaff"),"Circle":Color("ff929f"),"Square":Color("ef9cdd"),"Triangle":Color("7be0bd")}
		var color: Color=colors.get(button,INK)
		var r:=height*0.23
		match button:
			"Cross":
				line(canvas,center+Vector2(-r,-r),center+Vector2(r,r),color,stroke)
				line(canvas,center+Vector2(-r,r),center+Vector2(r,-r),color,stroke)
			"Circle": ring(canvas,center,r,color,stroke)
			"Square": canvas.draw_polyline(PackedVector2Array([center+Vector2(-r,-r),center+Vector2(r,-r),center+Vector2(r,r),center+Vector2(-r,r),center+Vector2(-r,-r)]),color,stroke,true)
			"Triangle": canvas.draw_polyline(PackedVector2Array([center+Vector2(0,-r*1.2),center+Vector2(r,r),center+Vector2(-r,r),center+Vector2(0,-r*1.2)]),color,stroke,true)
	elif family=="generic":
		var positions:={"South":Vector2(0,1),"East":Vector2(1,0),"West":Vector2(-1,0),"North":Vector2(0,-1)}
		for name in positions:
			canvas.draw_circle(center+positions[name]*height*0.23,height*0.09,INK if name==button else Color("576981"))
	else:
		var color: Color={"A":Color("99df85"),"B":Color("ff919a"),"X":Color("7bbcff"),"Y":Color("ffe28b")}.get(button,INK) if family=="xbox" else INK
		centered(canvas,font,button,center,int(height*0.58),color)
	return w

static func phrase(canvas: CanvasItem, font: Font, controls: RushControls, action: String, description: String, pos: Vector2, height: float=26, size: int=16, color: Color=INK) -> float:
	var w:=draw_action(canvas,font,controls,action,pos,height)
	canvas.draw_string(font,pos+Vector2(w+8,height*0.5+(font.get_ascent(size)-font.get_descent(size))*0.5),description,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	return w+8+font.get_string_size(description,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
