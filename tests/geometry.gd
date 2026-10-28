extends SceneTree
# Geometric regression checks exercise the generated resources, not source-code text.
var game
var failures:=0
var checks: Array[String]=[]
var metrics: Dictionary={}

func _initialize() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	var message:=("PASS " if ok else "FAIL ")+description
	checks.append(message)
	print(message)
	if not ok:
		failures+=1

func polygon_area(poly: PackedVector2Array) -> float:
	var area:=0.0
	for i in range(poly.size()):
		area+=poly[i].cross(poly[(i+1)%poly.size()])
	return absf(area)*0.5

func height_at(tri: Dictionary, p: Vector2) -> float:
	var a: Vector3=tri.vertices[0]
	var n: Vector3=tri.normal
	return a.y-(n.x*(p.x-a.x)+n.z*(p.y-a.z))/n.y

func triangles(mesh: MeshInstance3D, top_only: bool = false) -> Array[Dictionary]:
	var faces:=mesh.mesh.get_faces()
	var result: Array[Dictionary]=[]
	for i in range(0,faces.size(),3):
		var a:=mesh.to_global(faces[i])
		var b:=mesh.to_global(faces[i+1])
		var c:=mesh.to_global(faces[i+2])
		var normal: Vector3=(c-a).cross(b-a)
		if top_only and normal.normalized().y<0.9:
			continue
		result.append({"vertices":[a,b,c],"normal":normal,"poly":PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])})
	return result

func overlapping_pairs(data: Array[Dictionary], flat: bool = false) -> int:
	var grid: Dictionary={}
	var tested: Dictionary={}
	var count:=0
	for i in range(data.size()):
		var poly: PackedVector2Array=data[i].poly
		var lo:=poly[0]
		var hi:=poly[0]
		for p in poly:
			lo=lo.min(p)
			hi=hi.max(p)
		for x in range(floori(lo.x/8),floori(hi.x/8)+1):
			for z in range(floori(lo.y/8),floori(hi.y/8)+1):
				var cell:=Vector2i(x,z)
				if not grid.has(cell):
					grid[cell]=[]
				for j in grid[cell]:
					var key:=Vector2i(i,j)
					if tested.has(key):
						continue
					tested[key]=true
					for overlap in Geometry2D.intersect_polygons(poly,data[j].poly):
						if polygon_area(overlap)<=0.0001:
							continue
						var center:=Vector2.ZERO
						for point in overlap:
							center+=point
						center/=overlap.size()
						if flat or absf(height_at(data[i],center)-height_at(data[j],center))<0.03:
							count+=1
							break
				grid[cell].append(i)
	return count

func run() -> void:
	await physics_frame
	await physics_frame
	for name in ["CircuitDeck","ServiceBridge"]:
		var data:=triangles(game.track.get_node(name))
		var inverted:=0
		var degenerate:=0
		for tri in data:
			if tri.normal.y< -0.00001:
				inverted+=1
			if tri.normal.length_squared()<0.000000001:
				degenerate+=1
		var overlaps:=overlapping_pairs(data)
		metrics[name]={"triangles":data.size(),"inverted":inverted,"degenerate":degenerate,"overlap_pairs":overlaps}
		check(inverted==0 and degenerate==0,name+" has no folded or degenerate triangles")
		check(overlaps==0,name+" has no coplanar self-overlap")
	for name in ["BarrierLeft","BarrierRight","RailTrimLeft","RailTrimRight"]:
		var mesh: MeshInstance3D=game.track.get_node(name)
		check(overlapping_pairs(triangles(mesh,true))==0,name+" has no overlapping top surfaces")
	var front_faces: Array[Dictionary]=[]
	for blade in game.track.fans[0].get_children():
		if not blade.has_meta("fan_blade"):
			continue
		var faces: PackedVector3Array=blade.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var a:=faces[i]
			var b:=faces[i+1]
			var c:=faces[i+2]
			if (c-a).cross(b-a).normalized().z>0.9:
				front_faces.append({"poly":PackedVector2Array([Vector2(a.x,a.y),Vector2(b.x,b.y),Vector2(c.x,c.y)])})
	var fan_overlap:=overlapping_pairs(front_faces,true)
	metrics.fan_blade_overlap_pairs=fan_overlap
	check(front_faces.size()>0 and fan_overlap==0,"Fan blades have no coplanar intersections")
	var rings_opaque:=true
	var labels_stable:=true
	for node in game.track.find_children("*","MeshInstance3D",true,false):
		if node.mesh is TorusMesh and node.mesh.outer_radius>9:
			rings_opaque=rings_opaque and node.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED
	for label in game.track.find_children("*","Label3D",true,false):
		labels_stable=labels_stable and label.visibility_range_end==0
	check(rings_opaque,"Solid fan rings do not use alpha sorting")
	check(labels_stable,"Sign lettering cannot disappear before its backing")
	var markings_clear:=true
	var worst_clearance:=INF
	for name in ["BoostPad_40","BoostPad_116","BoostPad_175","StartingGrid"]:
		var patch: MeshInstance3D=game.track.get_node(name)
		for p in patch.mesh.get_faces():
			var position:=patch.to_global(p)
			var ray:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*0.01,position-Vector3.UP,1)
			var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty():
				markings_clear=false
				continue
			var clearance: float=position.y-hit.position.y
			worst_clearance=minf(worst_clearance,clearance)
			markings_clear=markings_clear and clearance>0.05 and clearance<0.07
	metrics.minimum_marking_clearance=worst_clearance
	check(markings_clear,"Boost pads and starting grid conform to the physical road")
	var ramps_valid:=true
	for ramp in game.track.find_children("*","MeshInstance3D",true,false):
		if not str(ramp.name).begins_with("JumpRamp"):
			continue
		var faces: PackedVector3Array=ramp.mesh.get_faces()
		var top_faces:=0
		for index in range(0,faces.size(),3):
			if (faces[index+2]-faces[index]).cross(faces[index+1]-faces[index]).normalized().y>0.5:
				top_faces+=1
		var exclusions: Array[RID]=[]
		for body in ramp.get_children():
			if body is StaticBody3D:
				exclusions.append(body.get_rid())
		for vertex in faces:
			var position: Vector3=ramp.to_global(vertex)
			var query:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*4,position-Vector3.UP*3,1)
			query.exclude=exclusions
			var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
			ramps_valid=ramps_valid and not hit.is_empty() and hit.collider.get_parent()==game.track.get_node("CircuitDeck")
		ramps_valid=ramps_valid and top_faces==2 and faces.size()==36
	check(ramps_valid,"Solid ramps have upward driving faces and stay within the road")
	var before: float=game.track.clock
	var rotation: Vector3=game.track.fans[0].rotation
	game.paused=true
	await process_frame
	await process_frame
	check(game.track.clock==before and game.track.fans[0].rotation==rotation,"Pause freezes scenery animation and item timers")
	var report:={"passed":failures==0,"metrics":metrics,"checks":checks}
	var file:=FileAccess.open("user://geometry_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("GEOMETRY_REPORT "+ProjectSettings.globalize_path("user://geometry_results.json"))
	game.free()
	quit(0 if failures==0 else 1)
