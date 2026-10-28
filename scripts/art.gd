class_name RushArt
extends RefCounted

static var materials: Dictionary = {}
static var fonts: Dictionary = {}

static func mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + str(glow)
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	m.metallic_specular=0.18
	m.metallic = 0.06
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = minf(glow*0.26,0.4)
	materials[key] = m
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: float = 0.0, solid: bool = false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat(color, glow)
	parent.add_child(m)
	m.position = pos
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		shape.shape = s
		m.add_child(body)
		body.add_child(shape)
	return m

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	m.mesh = mesh
	m.material_override = mat(color, glow)
	parent.add_child(m)
	m.position = pos
	return m

static func label3d(parent: Node3D, text: String, pos: Vector3, color: Color, size: int = 60) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font=font(650)
	l.font_size = size
	l.pixel_size = 0.018
	l.modulate = color
	l.outline_size = 0
	l.alpha_cut=Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	l.visibility_range_end=0
	l.no_depth_test=false
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	l.position = pos
	return l

static func ring(parent: Node3D, pos: Vector3, radius: float, color: Color, transparent: bool = true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	var thickness:=clampf(radius*0.025,0.035,0.16)
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 24
	mesh.ring_segments = 8
	m.mesh = mesh
	var material:=mat(color).duplicate()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if transparent else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.albedo_color=Color(color.r,color.g,color.b,0.8 if transparent else 1.0)
	m.material_override=material
	parent.add_child(m)
	m.position = pos
	return m

static func signboard(parent: Node3D, text: String, pos: Vector3, size: Vector2, color: Color) -> Node3D:
	var root:=Node3D.new()
	parent.add_child(root)
	root.position=pos
	box(root,Vector3.ZERO,Vector3(size.x,size.y,0.35),Color("1d244b"))
	box(root,Vector3(0,-size.y*0.5,0.20),Vector3(size.x,0.13,0.12),color,0.6)
	for side in [-1,1]:
		box(root,Vector3(side*(size.x*0.5-0.18),0,0.22),Vector3(0.12,size.y-0.2,0.1),color,0.5)
	var label:=label3d(root,text,Vector3(0,0,0.23),Color("f6fcff"),96)
	label.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided=false
	var text_width:=label.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,96).x
	label.pixel_size=minf((size.x-1.1)/maxf(text_width,1),(size.y-0.6)/110.0)
	return root

static func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var piece:=box(parent,(a+b)*0.5,Vector3(width,width,a.distance_to(b)),color,glow)
	piece.look_at_from_position(piece.global_position,parent.to_global(b))
	return piece

static func gem(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh:=PrismMesh.new()
	mesh.size=Vector3(radius*1.3,radius*1.8,radius*1.3)
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh
	instance.material_override=mat(color,0.25)
	parent.add_child(instance)
	instance.position=pos
	return instance

static func ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var instance:=MeshInstance3D.new()
	var mesh:=SphereMesh.new()
	mesh.radius=1
	mesh.height=2
	mesh.radial_segments=24
	mesh.rings=12
	instance.mesh=mesh
	instance.material_override=mat(color,glow)
	parent.add_child(instance)
	instance.position=pos
	instance.scale=size
	return instance

static func font(weight: int = 600) -> Font:
	if not fonts.has(weight):
		var variation:=FontVariation.new()
		variation.base_font=load("res://assets/fonts/SpaceGrotesk.ttf")
		variation.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):float(weight)}
		fonts[weight]=variation
	return fonts[weight]

static func mesh_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var verts: Array[Vector3]=[a,b,c,d]
	if (c-a).cross(b-a).dot(normal)<0:
		verts=[a,d,c,b]
	for i in [0,1,2,0,2,3]:
		st.set_normal(normal)
		st.add_vertex(verts[i])

static func fan_blade(parent: Node3D, angle: float, color: Color) -> MeshInstance3D:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(8):
		var t0:=step/8.0
		var t1:=(step+1)/8.0
		var radius0:=lerpf(1.65,9.0,t0)
		var radius1:=lerpf(1.65,9.0,t1)
		var angle0:=angle+t0*0.28
		var angle1:=angle+t1*0.28
		var half0:=0.11+sin(t0*PI)*0.06
		var half1:=0.11+sin(t1*PI)*0.06
		var a:=Vector3(sin(angle0-half0)*radius0,cos(angle0-half0)*radius0,0.25)
		var b:=Vector3(sin(angle1-half1)*radius1,cos(angle1-half1)*radius1,0.25)
		var c:=Vector3(sin(angle1+half1)*radius1,cos(angle1+half1)*radius1,0.25)
		var d:=Vector3(sin(angle0+half0)*radius0,cos(angle0+half0)*radius0,0.25)
		var back:=Vector3(0,0,-0.5)
		mesh_quad(st,a,b,c,d,Vector3.BACK)
		mesh_quad(st,a+back,d+back,c+back,b+back,Vector3.FORWARD)
		mesh_quad(st,a,a+back,b+back,b,(b-a).cross(back).normalized())
		mesh_quad(st,d,c,c+back,d+back,(c-d).cross(back).normalized())
		if step==0:
			mesh_quad(st,a,d,d+back,a+back,-Vector3(sin(angle0),cos(angle0),0))
		if step==7:
			mesh_quad(st,b,b+back,c+back,c,Vector3(sin(angle1),cos(angle1),0))
	var instance:=MeshInstance3D.new()
	instance.name="FanBlade"
	instance.set_meta("fan_blade",true)
	instance.mesh=st.commit()
	instance.material_override=mat(color)
	parent.add_child(instance)
	return instance

static func ramp(parent: Node3D, pos: Vector3, width: float, length: float, height: float, color: Color) -> MeshInstance3D:
	var half:=width*0.5
	var front:=length*0.5
	var a:=Vector3(-half,0.06,front)
	var b:=Vector3(half,0.06,front)
	var c:=Vector3(half,height,-front)
	var d:=Vector3(-half,height,-front)
	var e:=Vector3(-half,-0.35,front)
	var f:=Vector3(half,-0.35,front)
	var g:=Vector3(half,-0.35,-front)
	var h:=Vector3(-half,-0.35,-front)
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh_quad(st,a,b,c,d,Vector3(0,length,height-0.06).normalized())
	mesh_quad(st,e,h,g,f,Vector3.DOWN)
	mesh_quad(st,e,f,b,a,Vector3.BACK)
	mesh_quad(st,h,d,c,g,Vector3.FORWARD)
	mesh_quad(st,e,a,d,h,Vector3.LEFT)
	mesh_quad(st,f,g,c,b,Vector3.RIGHT)
	var mesh:=MeshInstance3D.new()
	mesh.name="JumpRamp"
	mesh.mesh=st.commit()
	mesh.material_override=mat(color)
	parent.add_child(mesh)
	mesh.position=pos
	mesh.create_trimesh_collision()
	return mesh
