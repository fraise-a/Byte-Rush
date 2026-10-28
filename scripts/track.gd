class_name RushTrack
extends Node3D

const WIDTH := 17.0
const CYAN := Color("54e7ef")
const LIME := Color("b5ff66")
const PURPLE := Color("b28aff")
var points: PackedVector3Array = []
var distances: PackedFloat32Array = []
var total_length := 0.0
var checkpoints: Array[int] = []
var pickups: Array[Dictionary] = []
var pads: Array[Dictionary] = []
var ramps: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var fans: Array[Node3D] = []
var clock := 0.0
var winds: Array[Dictionary] = []
var shortcut_points: PackedVector3Array = []
var floating_bits: MultiMeshInstance3D
var bit_origins: Array[Vector3] = []
var main_sections: Array[Dictionary] = []
var main_faces:=PackedVector3Array()
var main_uvs:=PackedVector2Array()
var decal_materials: Dictionary = {}


func _ready() -> void:
	var controls := [Vector3(-55,4,76), Vector3(0,4,76), Vector3(52,6,68), Vector3(80,10,36), Vector3(69,12,0), Vector3(94,9,-34), Vector3(63,6,-66), Vector3(18,6,-68), Vector3(-9,6,-39), Vector3(-40,6,-65), Vector3(-88,11,-56), Vector3(-109,8,-17), Vector3(-86,5,23), Vector3(-104,4,59), Vector3(-85,4,81)]
	for i in range(controls.size()):
		for j in range(16):
			var t := j / 16.0
			points.append(controls[i].cubic_interpolate(controls[(i + 1) % controls.size()], controls[posmod(i - 1, controls.size())], controls[(i + 2) % controls.size()], t))
	# The service bridge and main hairpin share a coplanar deck at their overlaps.
	for i in range(96,145):
		points[i].y=6.0
	distances.append(0.0)
	for i in range(1, points.size()):
		total_length += points[i].distance_to(points[i-1])
		distances.append(total_length)
	total_length += points[-1].distance_to(points[0])
	for i in range(12):
		checkpoints.append(i * points.size() / 12)
	main_sections=road_sections(points,WIDTH,true)
	road(points, WIDTH, Color("252d48"), true)
	build_details()
	build_scenery()

func sample(index: int) -> Vector3:
	return points[posmod(index, points.size())]

func tangent(index: int) -> Vector3:
	return (sample(index + 1) - sample(index - 1)).normalized()

func right_at(index: int) -> Vector3:
	return tangent(index).cross(Vector3.UP).normalized()

func nearest(pos: Vector3) -> Dictionary:
	var best := INF
	var idx := 0
	var fraction := 0.0
	for i in range(points.size()):
		var a := sample(i)
		var delta := sample(i+1) - a
		var t := clampf((pos - a).dot(delta) / delta.length_squared(), 0.0, 1.0)
		var d := pos.distance_squared_to(a + delta * t)
		if d < best:
			best = d
			idx = i
			fraction = t
	return {"index": idx, "distance": sqrt(best), "progress": distances[idx] + sample(idx).distance_to(sample(idx+1)) * fraction}

func road_sections(path: PackedVector3Array, width: float, closed: bool) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for i in range(path.size()):
		var p:=path[i]
		var prev:=path[posmod(i-1,path.size())] if closed or i>0 else p-(path[i+1]-p)
		var nxt:=path[(i+1)%path.size()] if closed or i+1<path.size() else p+(p-prev)
		var incoming:=Vector3(p.x-prev.x,0,p.z-prev.z)
		var outgoing:=Vector3(nxt.x-p.x,0,nxt.z-p.z)
		var turn:=atan2(incoming.cross(outgoing).y,incoming.dot(outgoing))
		var left:=width*0.5
		var right:=width*0.5
		if absf(turn)>0.00001:
			var radius: float=(incoming.length()+outgoing.length())*0.5/absf(turn)
			# An offset wider than the bend radius folds back across itself.
			if turn>0:
				left=minf(left,radius*0.65)
			else:
				right=minf(right,radius*0.65)
		var lateral: Vector3=(nxt-prev).cross(Vector3.UP).normalized()
		result.append({"pos":p,"right":lateral,"left_width":left,"right_width":right})
	# Apply the bend limit to its approaches as well as its apex. Otherwise
	# the inside edges of two non-neighbouring approach segments can intersect.
	var original: Array[Dictionary]=result.duplicate(true)
	for i in range(result.size()):
		for offset in range(-3,4):
			var neighbour:=posmod(i+offset,result.size()) if closed else clampi(i+offset,0,result.size()-1)
			result[i].left_width=minf(result[i].left_width,original[neighbour].left_width)
			result[i].right_width=minf(result[i].right_width,original[neighbour].right_width)
	return result

func section_point(section: Dictionary, fraction: float) -> Vector3:
	return section.pos+section.right*fraction*(section.left_width if fraction<0 else section.right_width)

func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, normal: Vector3) -> void:
	var verts: Array[Vector3]=[a,b,c,d]
	if (c-a).cross(b-a).dot(normal)<0:
		verts=[a,d,c,b]
	for face in [[0,1,2],[0,2,3]]:
		var face_normal: Vector3=(verts[face[2]]-verts[face[0]]).cross(verts[face[1]]-verts[face[0]]).normalized()
		for index in face:
			st.set_normal(face_normal)
			st.set_color(color)
			st.add_vertex(verts[index])

func build_barriers() -> void:
	for side in [-1,1]:
		for trim in [false,true]:
			var st:=SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(points.size()):
				if side==1 and i>=114 and i<=145:
					continue
				var sa: Dictionary=main_sections[i]
				var sb: Dictionary=main_sections[(i+1)%points.size()]
				var out_a: Vector3=sa.right*side
				var out_b: Vector3=sb.right*side
				var a:=section_point(sa,float(side))+out_a*0.3
				var b:=section_point(sb,float(side))+out_b*0.3
				var half_width:=0.10 if trim else 0.275
				var low:=1.31 if trim else 0.0
				var high:=1.45 if trim else 1.3
				var ai:=a-out_a*half_width+Vector3.UP*low
				var ao:=a+out_a*half_width+Vector3.UP*low
				var bi:=b-out_b*half_width+Vector3.UP*low
				var bo:=b+out_b*half_width+Vector3.UP*low
				var lift:=Vector3.UP*(high-low)
				var color:=CYAN if i<80 else LIME if i<160 else PURPLE
				if not trim:
					color=Color("33446c")
				add_quad(st,ai,bi,bi+lift,ai+lift,color,-out_a)
				add_quad(st,ao,ao+lift,bo+lift,bo,color,out_a)
				add_quad(st,ai+lift,bi+lift,bo+lift,ao+lift,color,Vector3.UP)
				add_quad(st,ai,ao,bo,bi,color,Vector3.DOWN)
				if side==1 and i in [113,146]:
					var end_a:=i==146
					var p1:=ai if end_a else bi
					var p2:=ao if end_a else bo
					add_quad(st,p1,p2,p2+lift,p1+lift,color,-tangent(i) if end_a else tangent(i))
			var mesh:=MeshInstance3D.new()
			mesh.name=("RailTrim" if trim else "Barrier")+("Left" if side<0 else "Right")
			mesh.mesh=st.commit()
			var material:=RushArt.mat(Color.WHITE).duplicate()
			material.vertex_color_use_as_albedo=true
			if trim:
				material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.material_override=material
			add_child(mesh)
			if not trim:
				mesh.create_trimesh_collision()

# Clip road triangles in their surface coordinates, interpolating original 3D positions.
# Markings therefore follow the exact road planes, including crests and cambers.
func clip_patch(poly: Array[Dictionary], axis: int, edge: float, keep_greater: bool) -> Array[Dictionary]:
	var output: Array[Dictionary]=[]
	if poly.is_empty():
		return output
	var previous: Dictionary=poly[-1]
	var previous_distance: float=(previous.uv[axis]-edge)*(1 if keep_greater else -1)
	for current in poly:
		var distance: float=(current.uv[axis]-edge)*(1 if keep_greater else -1)
		if (distance>=0)!=(previous_distance>=0):
			var t:=previous_distance/(previous_distance-distance)
			output.append({"pos":previous.pos.lerp(current.pos,t),"uv":previous.uv.lerp(current.uv,t)})
		if distance>=0:
			output.append(current)
		previous=current
		previous_distance=distance
	return output

func make_surface_patch(patch_name: String, start: float, length: float, left: float, right: float, kind: int) -> MeshInstance3D:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low:=start/4.0
	var high:=(start+length)/4.0
	for i in range(0,main_faces.size(),3):
		if maxf(main_uvs[i].y,maxf(main_uvs[i+1].y,main_uvs[i+2].y))<low or minf(main_uvs[i].y,minf(main_uvs[i+1].y,main_uvs[i+2].y))>high:
			continue
		var poly: Array[Dictionary]=[]
		for j in range(3):
			poly.append({"pos":main_faces[i+j],"uv":main_uvs[i+j]})
		poly=clip_patch(poly,0,left,true)
		poly=clip_patch(poly,0,right,false)
		poly=clip_patch(poly,1,low,true)
		poly=clip_patch(poly,1,high,false)
		for j in range(1,poly.size()-1):
			if (poly[j].pos-poly[0].pos).cross(poly[j+1].pos-poly[0].pos).length_squared()<0.000000001:
				continue
			for k in [0,j,j+1]:
				var uv: Vector2=poly[k].uv
				st.set_uv(Vector2((uv.x-left)/(right-left),(uv.y-low)/(high-low)))
				st.add_vertex(poly[k].pos+Vector3.UP*0.06)
	st.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.name=patch_name
	mesh.mesh=st.commit()
	if not decal_materials.has(kind):
		var material:=ShaderMaterial.new()
		material.shader=load("res://assets/shaders/markings.gdshader")
		material.set_shader_parameter("kind",kind)
		decal_materials[kind]=material
	mesh.material_override=decal_materials[kind]
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh

func road(path: PackedVector3Array, width: float, color: Color, closed: bool) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=path.size() if closed else path.size()-1
	var travelled:=0.0
	var sections:=main_sections if closed else road_sections(path,width,false)
	for i in range(count):
		var a:=path[i]
		var b:=path[(i+1)%path.size()]
		var sa: Dictionary=sections[i]
		var sb: Dictionary=sections[(i+1)%path.size()]
		var segment_length:=a.distance_to(b)
		var deck:=Color("274f76") if i<80 else Color("514279") if i<160 else Color("253f72")
		if not closed:
			deck=Color("238b87")
		var edge_color: Color=[Color("ff5bba"),Color("ffd660"),Color("51e8f1")][mini(2,i/80)]
		var stripes:=PackedFloat32Array([-1.0,-0.88,0.88,1.0] if closed else [-1.0,1.0])
		for band in range(stripes.size()-1):
			var left: float=stripes[band]
			var right: float=stripes[band+1]
			var tint:=deck
			if closed and band!=1:
				tint=edge_color if (i/2)%2==0 else Color("e8f9ff")
			var verts: Array[Vector3]=[section_point(sa,left),section_point(sb,left),section_point(sa,right),section_point(sa,right),section_point(sb,left),section_point(sb,right)]
			var uvs: Array[Vector2]=[Vector2((left+1)*0.5,travelled/4),Vector2((left+1)*0.5,(travelled+segment_length)/4),Vector2((right+1)*0.5,travelled/4),Vector2((right+1)*0.5,travelled/4),Vector2((left+1)*0.5,(travelled+segment_length)/4),Vector2((right+1)*0.5,(travelled+segment_length)/4)]
			for v in range(6):
				st.set_color(tint)
				st.set_uv(uvs[v])
				st.add_vertex(verts[v])
				if closed:
					main_faces.append(verts[v])
					main_uvs.append(uvs[v])
		travelled+=segment_length
	st.generate_normals()
	var instance:=MeshInstance3D.new()
	instance.name="CircuitDeck" if closed else "ServiceBridge"
	instance.mesh=st.commit()
	var material:=ShaderMaterial.new()
	material.shader=load("res://assets/shaders/road.gdshader")
	instance.material_override=material
	add_child(instance)
	instance.create_trimesh_collision()
	if not closed:
		# Keep collision coplanar and offset only the visible mesh: no depth fighting or step.
		for child in instance.get_children():
			if child is StaticBody3D:
				child.reparent(self,true)
		instance.position.y=0.055

func build_details() -> void:
	build_barriers()
	for i in range(points.size()):
		var p:=sample(i)
		var right:=right_at(i)
		if i%3==0:
			make_surface_patch("LaneMark_%d"%i,distances[i],1.1,0.496,0.504,2)
		if i%16==0:
			for side in [-1,1]:
				RushArt.box(self,p+right*side*7.5-Vector3.UP*8,Vector3(0.9,16,0.9),Color("18283a"))
	# Starting gantry and grid.
	var root := Node3D.new()
	add_child(root)
	root.position = sample(0)
	root.look_at(root.position+tangent(0))
	for side in [-1,1]:
		RushArt.box(root,Vector3(side*9,4,0),Vector3(0.8,8,0.9),CYAN,0.5)
	RushArt.box(root,Vector3(0,8,0),Vector3(19,1.7,1.0),Color("111a30"))
	RushArt.signboard(root,"BYTE RUSH  /  START",Vector3(0,8,0.7),Vector2(18,2.2),LIME)
	make_surface_patch("StartingGrid",0.0,2.0,0.03,0.97,1)
	for idx in [31,69,109,147,184,218]:
		for lane in [-5.0,0.0,5.0]:
			var node := Node3D.new()
			add_child(node)
			node.position = sample(idx)+right_at(idx)*lane+Vector3.UP*1.6
			# Hollow luminous item cages use geometry, avoiding text hidden inside opaque cubes.
			for x in [-0.65,0.65]:
				for y in [-0.65,0.65]:
					RushArt.box(node,Vector3(x,y,0),Vector3(0.12,0.12,1.3),Color("ff72cf"),0.5)
			for x in [-0.65,0.65]:
				for z in [-0.65,0.65]:
					RushArt.box(node,Vector3(x,0,z),Vector3(0.12,1.3,0.12),CYAN,0.6)
			for y in [-0.65,0.65]:
				for z in [-0.65,0.65]:
					RushArt.box(node,Vector3(0,y,z),Vector3(1.3,0.12,0.12),Color("ffe78a"),0.5)
			RushArt.gem(node,Vector3.ZERO,0.7,CYAN)
			pickups.append({"node":node,"timer":0.0,"base":node.position.y})
	for idx in [40,116,175]:
		make_surface_patch("BoostPad_%d"%idx,distances[idx]-3.0,6.0,0.18,0.82,0)
		pads.append({"pos":sample(idx),"index":idx})
	# Inclined jump wedges sit on top of the main road; recovery keeps landings forgiving.
	for idx in [52,132]:
		var safe_half:=5.0
		for offset in range(-2,3):
			var section: Dictionary=main_sections[posmod(idx+offset,points.size())]
			safe_half=minf(safe_half,minf(section.left_width,section.right_width)-0.9)
		var ramp:=RushArt.ramp(self,sample(idx)+Vector3.UP*0.06,safe_half*2,5,1.4,Color("527880"))
		ramp.look_at(ramp.position+tangent(idx))
		ramps.append({"pos":sample(idx),"index":idx,"width":safe_half*2})
		var marker:=RushArt.signboard(self,"JUMP",sample(idx)+right_at(idx)*11+Vector3.UP*4,Vector2(5,1.7),LIME)
		marker.look_at(marker.position+tangent(idx))
	for idx in [92,155,199]:
		var node := Node3D.new()
		add_child(node)
		node.position=sample(idx)+right_at(idx)*3.8+Vector3.UP*0.5
		RushArt.cylinder(node,Vector3.ZERO,1.3,0.5,Color("ec7198"),1.0)
		RushArt.beam(node,Vector3(-0.5,2,0),Vector3(0.4,1.5,0),0.18,Color("ffe679"),0.8)
		RushArt.beam(node,Vector3(0.4,1.5,0),Vector3(-0.4,0.8,0),0.18,Color("ffe679"),0.8)
		for a in range(3):
			var arc := RushArt.box(node,Vector3(0,1.2+a*0.25,0),Vector3(0.08,0.08,3.4),Color("ffc369"),1.5)
			arc.rotation.y=a*PI/3
		hazards.append({"node":node,"index":idx})
	# An inside service bridge cuts the motherboard hairpin. Both intervening checkpoints remain reachable from the bridge.
	var start := 114
	var end := 144
	for j in range(31):
		var t := j/30.0
		var main_pos := sample(start+j)
		var chord := sample(start).lerp(sample(end),t)
		shortcut_points.append(main_pos.lerp(chord,sin(t*PI)*0.72))
	road(shortcut_points,7.5,Color("405d56"),false)
	var service_sign:=RushArt.signboard(self,"SERVICE BRIDGE",sample(start)+right_at(start)*11+Vector3.UP*3.5,Vector2(8,1.8),LIME)
	service_sign.look_at(service_sign.position+tangent(start))
	# Checkpoint arches are visible and share the actual ordered race gates.
	for c in range(1,checkpoints.size()):
		var idx := checkpoints[c]
		var gate := Node3D.new()
		add_child(gate)
		gate.position = sample(idx)
		gate.look_at(gate.position+tangent(idx))
		for side in [-1,1]:
			RushArt.box(gate,Vector3(side*8.3,2.7,0),Vector3(0.22,5.4,0.22),CYAN if c<4 else LIME if c<8 else PURPLE,0.8)

func build_scenery() -> void:
	var board:=RushArt.box(self,Vector3(0,-8,0),Vector3(370,3,330),Color("164968"))
	var board_material:=ShaderMaterial.new()
	board_material.shader=load("res://assets/shaders/board.gdshader")
	board.material_override=board_material
	var rng:=RandomNumberGenerator.new()
	rng.seed=20261026
	var palette: Array[Color]=[Color("ff66ad"),Color("9b7afb"),Color("48d2e8"),Color("ffc35b"),Color("75e8b5")]
	var letters:="BYTE RUSH QWERTY ASDFGH ZXCVBN 0123456789"
	for row in range(5):
		for col in range(11):
			var pos:=Vector3(-40+col*10,-0.5,100+row*10)
			var cap_color:=palette[(col+row*2)%palette.size()]
			RushArt.box(self,pos,Vector3(8.8,2.5,8.8),Color("304365"))
			RushArt.box(self,pos+Vector3.UP*1.1,Vector3(8.5,0.22,8.5),cap_color,0.4)
			RushArt.box(self,pos+Vector3.UP*2,Vector3(8.0,2.6,8.0),cap_color)
			RushArt.box(self,pos+Vector3.UP*3.3,Vector3(7.2,0.20,7.2),cap_color.lightened(0.15))
			var label:=RushArt.label3d(self,letters[(row*11+col)%letters.length()],pos+Vector3.UP*3.48,Color("172a4c"),110)
			label.billboard=BaseMaterial3D.BILLBOARD_DISABLED
			label.rotation_degrees.x=-90
			label.pixel_size=0.025
	# Oversized keys frame the opening corners at kart height.
	for idx in [5,18,32,46,61]:
		var pos:=sample(idx)+right_at(idx)*16
		var color:=palette[(idx/10)%palette.size()]
		RushArt.box(self,pos+Vector3.UP*2,Vector3(7,4,7),color)
		RushArt.box(self,pos+Vector3.UP*4.15,Vector3(6.2,0.3,6.2),color.lightened(0.2))
		var key:=RushArt.label3d(self,["W","A","S","D","R"][idx/14],pos+Vector3.UP*4.35,Color("253459"),120)
		key.pixel_size=0.025
		key.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		key.rotation_degrees.x=-90
	# A colourful circuit city replaces the anonymous grey blocks.
	for i in range(70):
		var pos:=Vector3(rng.randf_range(-155,145),-6.3,rng.randf_range(-115,88))
		if nearest(pos+Vector3.UP*12).distance<21:
			continue
		var h:=rng.randf_range(4,21)
		var color:=palette[i%palette.size()]
		if i%3==0:
			RushArt.cylinder(self,pos+Vector3.UP*h*0.5,3.8,h,color.darkened(0.35))
			RushArt.cylinder(self,pos+Vector3.UP*(h+0.1),3.8,0.25,color,0.35)
			RushArt.box(self,pos+Vector3.UP*(h+0.26),Vector3(4.2,0.15,0.35),Color("d8e6ee"))
		else:
			RushArt.box(self,pos+Vector3.UP*h*0.5,Vector3(7,h,6),color.darkened(0.55))
			RushArt.box(self,pos+Vector3.UP*(h+0.12),Vector3(7.4,0.25,6.4),color,0.3)
			for line in range(3):
				RushArt.box(self,pos+Vector3(0,h*0.3+line*2,3.05),Vector3(5.6,0.25,0.15),color,0.4)
	# RAM towers and a processor plaza are landmarks visible above the race barriers.
	for i in range(5):
		var pos:=Vector3(35+i*16,-3,-107)
		RushArt.box(self,pos+Vector3.UP*12,Vector3(10,24,2),Color("356d86"))
		for chip in range(4):
			RushArt.box(self,pos+Vector3(0,5+chip*5,-1.5),Vector3(7,3,1),palette[(chip+i)%5])
		RushArt.box(self,pos+Vector3.UP*25,Vector3(11,0.7,3),palette[i],0.4)
	var cpu_pos:=Vector3(28,0,-27)
	RushArt.box(self,cpu_pos,Vector3(29,4,25),Color("442c77"))
	RushArt.box(self,cpu_pos+Vector3.UP*2.2,Vector3(26,0.4,22),Color("b07df5"),0.3)
	for x in range(7):
		RushArt.box(self,cpu_pos+Vector3(-15+x*5,3,0),Vector3(0.55,1.5,23),Color("b4e8fb"))
	# Clear zone entry portals replace distant shimmering billboard text.
	for zone in range(3):
		var idx: int=[8,80,160][zone]
		var entry:=Node3D.new()
		add_child(entry)
		entry.position=sample(idx)
		entry.look_at(entry.position+tangent(idx))
		var color:=palette[zone]
		for side in [-1,1]:
			RushArt.box(entry,Vector3(side*10,5,0),Vector3(1.3,10,1.3),color)
			RushArt.box(entry,Vector3(side*10,5,-0.72),Vector3(0.35,9,0.15),Color("fff5cf"),0.3)
		RushArt.signboard(entry,["MECHANICAL KEYBOARD","MOTHERBOARD MOTORWAY","COOLING CHAMBER"][zone],Vector3(0,10.5,0),Vector2(22,2.7),color)
	build_floating_bits(rng,palette)
	for idx in [162,181,203,221]:
		var root := Node3D.new()
		add_child(root)
		root.position=sample(idx)+right_at(idx)*18+Vector3.UP*7
		root.look_at(sample(idx)+Vector3.UP*4)
		var ring := RushArt.ring(root,Vector3.ZERO,10,PURPLE,false)
		ring.rotation.x=PI/2
		var rotor := Node3D.new()
		root.add_child(rotor)
		RushArt.cylinder(rotor,Vector3.ZERO,1.8,1.2,Color("ffbc66")).rotation.x=PI/2
		for a in range(7):
			RushArt.fan_blade(rotor,a*TAU/7,Color("779ff2"))
		fans.append(rotor)
	# Open sided cooling tunnel frames preserve visibility at every corner.
	for idx in range(170,205,3):
		var wind := RushArt.box(self,sample(idx)+Vector3.UP*3,Vector3(0.12,0.12,3),CYAN,0.7)
		wind.look_at(wind.position+tangent(idx))
		wind.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		winds.append({"node":wind,"base":wind.position,"dir":tangent(idx),"phase":idx*0.17})
		var root := Node3D.new()
		add_child(root)
		root.position=sample(idx)
		root.look_at(root.position+tangent(idx))
		for side in [-1,1]:
			RushArt.box(root,Vector3(side*10,5.3,0),Vector3(0.7,10.6,0.6),Color("3a3457"))
		RushArt.box(root,Vector3(0,10.6,0),Vector3(20.6,0.5,0.6),PURPLE,0.4)
	# Solid high-contrast geometric turn boards do not depend on distant font sampling.
	for idx in [44,66,89,108,130,153,177,201,222]:
		var root:=Node3D.new()
		add_child(root)
		root.position=sample(idx)+right_at(idx)*11+Vector3.UP*3
		root.look_at(root.position+tangent(idx))
		RushArt.box(root,Vector3.ZERO,Vector3(5.5,1.8,0.3),Color("243859"))
		for x in [-1.5,0.0,1.5]:
			RushArt.beam(root,Vector3(x-0.35,0.5,0.23),Vector3(x+0.35,0,0.23),0.16,LIME,0.25)
			RushArt.beam(root,Vector3(x+0.35,0,0.23),Vector3(x-0.35,-0.5,0.23),0.16,LIME,0.25)

func build_floating_bits(rng: RandomNumberGenerator, palette: Array[Color]) -> void:
	floating_bits=MultiMeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(0.5,0.5,0.5)
	mesh.material=RushArt.mat(Color.WHITE,0.3).duplicate()
	mesh.material.vertex_color_use_as_albedo=true
	var multimesh:=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_colors=true
	multimesh.mesh=mesh
	multimesh.instance_count=100
	floating_bits.multimesh=multimesh
	floating_bits.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floating_bits)
	for i in range(100):
		var p:=Vector3(rng.randf_range(-160,160),rng.randf_range(15,60),rng.randf_range(-120,140))
		bit_origins.append(p)
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,p))
		multimesh.set_instance_color(i,palette[i%palette.size()])

func _process(delta: float) -> void:
	if get_parent().get("paused")==true:
		return
	clock += delta
	if is_instance_valid(floating_bits):
		for i in range(bit_origins.size()):
			var p:=bit_origins[i]+Vector3(0,sin(clock*0.8+i)*1.4,0)
			floating_bits.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,clock*0.4+i),p))
	for wind in winds:
		wind.node.position=wind.base+wind.dir*fmod(clock*12+wind.phase,8)
	for fan in fans:
		fan.rotation.z+=delta*3.5
	for pickup in pickups:
		pickup.timer=maxf(0,pickup.timer-delta)
		pickup.node.visible=pickup.timer<=0
		pickup.node.rotation.y+=delta*1.8
		pickup.node.position.y=pickup.base+sin(clock*2+pickup.base)*0.25
	for hazard in hazards:
		hazard.node.rotation.y+=delta*2
