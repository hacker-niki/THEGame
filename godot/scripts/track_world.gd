extends Node3D

const EXPEDITION_LANDMARKS = preload("res://scripts/track_landmarks.gd")
const EXPEDITION_SKY = preload("res://shaders/expedition_sky.gdshader")
const EXPEDITION_FLOOR = preload("res://shaders/expedition_floor.gdshader")
const SKY_SHADER = preload("res://shaders/pass_sky.gdshader")
const ROAD_SHADER = preload("res://shaders/relay_road.gdshader")
const BARRIER_SHADER = preload("res://shaders/relay_barrier.gdshader")
const DIORAMA_SHADER = preload("res://shaders/relay_diorama.gdshader")
const SEA_SHADER = preload("res://shaders/relay_sea.gdshader")
const CHUNK_LENGTH := 160.0
# Sky, mid-sky, horizon, sun, sunset, distant ridge, near ridge, road lights.
const PALETTES := [
	["382e55", "b45775", "ffac83", "ffe5a7", "ff805a", "ba7588", "564460", "73edd6"],
	["482f50", "b7615c", "ffc184", "fff0b3", "ff924e", "bb776d", "604351", "ffd182"],
	["263755", "756d99", "efa9a0", "fff3d0", "fa9f8b", "887c9e", "454d70", "8de5ff"],
	["33294e", "895185", "f7a2a1", "ffe0ac", "ff8e83", "ab789d", "584268", "b2aaff"],
	["293557", "a75981", "ffaf93", "fff4ba", "ff7660", "b57592", "554469", "91f2c9"],
	["287c96", "6dbfb9", "eee6c4", "ffffde", "fbefc5", "a7c8be", "5b8c91", "80f8dd"],
	["54404d", "e07c54", "ffbf80", "fff1c3", "ff9f63", "d08972", "835058", "ffd389"],
	["44679d", "83c4e1", "e4f1e8", "ffffff", "deffff", "89b6ca", "537f9b", "c1faff"],
	["10152e", "1e2643", "62446e", "f7e9ff", "acbdfb", "4e496e", "30314d", "bc99ff"],
	["914958", "e59b60", "ffe19b", "ffefb7", "ffbd62", "c89871", "80595d", "ffe59b"],
]
# Asphalt, shoulder, lane paint, kerb paint, valley floor, mineral/water detail.
const EXPEDITION_SURFACES := [
	["233e4a", "456467", "9db9ac", "e2d5a9", "d9d5bb", "78b7b0"],
	["432c39", "63414a", "c19677", "ffb882", "b55f49", "72a39d"],
	["24364c", "46627b", "9ab9ca", "c4f5ed", "87b9cc", "dff5ed"],
	["1e2036", "3c3556", "8b7baf", "e89cf5", "302841", "a779d9"],
	["3f2d37", "624550", "bd957d", "ffe3a1", "c59169", "e2ac76"],
]
const MODEL_PATH := "res://assets/world/%s"
var _furniture: Dictionary = {}
var _colors: Array
var _unit := BoxMesh.new()
var _climate := -1
var _beat_materials: Array[ShaderMaterial] = []
var _roads: Array

func build(track: Dictionary, index: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_furniture.clear()
	_beat_materials.clear()
	_colors = PALETTES[clampi(index, 0, PALETTES.size() - 1)]
	var finish := float(track.finish[2])
	_roads = track.roads
	_climate = index - 5
	var limits := Vector2(INF, -INF)
	for road in _roads:
		limits.x = minf(limits.x, road[0] - road[3] * 0.5)
		limits.y = maxf(limits.y, road[0] + road[3] * 0.5)
	_environment(index)
	for road in track.roads:
		_road(road)
	_barriers(track.obstacles)
	_landscape(limits.y - limits.x, finish, index, track.get("scenery", []))
	_roadside(finish)
	if _climate >= 0:
		var landmarks := EXPEDITION_LANDMARKS.new()
		add_child(landmarks)
		landmarks.build(limits, finish, _climate)
		_junction_paint()
	_original_scenery(track.get("scenery", []))
	var finish_edges := _bounds_at(finish)
	_finish_gate(_unity_position(track.finish), finish_edges.y - finish_edges.x)
	_draw_furniture()

func _environment(index: int) -> void:
	var shader := ShaderMaterial.new()
	shader.shader = EXPEDITION_SKY if _climate >= 0 else SKY_SHADER
	for i in 7:
		shader.set_shader_parameter(["zenith", "middle", "horizon", "sun_top", "sun_base", "far_ridge", "near_ridge"][i], Color(_colors[i]))
	if _climate >= 0:
		shader.set_shader_parameter("climate", _climate)
	else:
		shader.set_shader_parameter("sector", float(index))
	var sky := Sky.new()
	sky.sky_material = shader
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("efd9dd")
	env.ambient_light_energy = 0.70 if _climate == 3 else 0.82
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_light_color = Color(_colors[6]).lerp(Color(_colors[5]), 0.3)
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	sun.light_color = Color("ffe0ba")
	if _climate == 0 or _climate == 2:
		sun.light_color = Color("e4f2ff")
	elif _climate == 3:
		sun.light_color = Color("b0b6e8")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 52.0
	add_child(sun)

func _unity_position(data: Array) -> Vector3:
	return Vector3(data[0], data[1], -data[2])

func _box_body(layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	return body

func _road(data: Array) -> void:
	var size := Vector3(data[3], data[4], data[5])
	var body := _box_body(1)
	body.position = _unity_position(data)
	body.rotation.y = -deg_to_rad(data[6])
	var obstacle := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	obstacle.shape = shape
	body.add_child(obstacle)
	var road_mesh := BoxMesh.new()
	road_mesh.size = size
	var mat := ShaderMaterial.new()
	mat.shader = ROAD_SHADER
	mat.set_shader_parameter("track_width", size.x)
	mat.set_shader_parameter("edge_color", Color(_colors[7]))
	if _climate >= 0:
		var surface: Array = EXPEDITION_SURFACES[_climate]
		mat.set_shader_parameter("surface_color", Color(surface[0]))
		mat.set_shader_parameter("shoulder_color", Color(surface[1]))
		mat.set_shader_parameter("lane_paint", Color(surface[2]))
		mat.set_shader_parameter("warm_paint", Color(surface[3]))
	_beat_materials.append(mat)
	road_mesh.material = mat
	var deck := MeshInstance3D.new()
	deck.mesh = road_mesh
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(deck)

func _barriers(obstacles: Array) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = BARRIER_SHADER
	mat.set_shader_parameter("front_color", Color("de6353"))
	mat.set_shader_parameter("top_color", Color("ff9977"))
	mat.set_shader_parameter("dark_color", Color("512f43"))
	mat.set_shader_parameter("light_color", Color("ffe3aa"))
	var visual := BoxMesh.new()
	visual.material = mat
	var batches := {}
	var bodies := {}
	var shapes := {}
	for data in obstacles:
		var center := _unity_position(data)
		var group_id := floori(-center.z / CHUNK_LENGTH)
		if not bodies.has(group_id):
			bodies[group_id] = _box_body(2)
			batches[group_id] = []
		var size := Vector3(data[3], data[4], data[5])
		if not shapes.has(size):
			var collision := BoxShape3D.new()
			collision.size = size
			shapes[size] = collision
		var blocker := CollisionShape3D.new()
		blocker.position = center
		blocker.rotation.y = -deg_to_rad(data[6])
		blocker.shape = shapes[size]
		bodies[group_id].add_child(blocker)
		batches[group_id].append([Transform3D(blocker.basis * Basis.from_scale(size), center)])
	for batch in batches.values():
		_draw_batch(visual, batch, false)

func _draw_batch(mesh: Mesh, entries: Array, colored: bool) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = colored
	multi.mesh = mesh
	multi.instance_count = entries.size()
	# Anchor each batch in its own sector so Godot can distance-cull the whole batch.
	var anchor: Vector3 = entries[0][0].origin
	for i in entries.size():
		var transform_local: Transform3D = entries[i][0]
		transform_local.origin -= anchor
		multi.set_instance_transform(i, transform_local)
		if colored:
			multi.set_instance_color(i, entries[i][1])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = multi
	inst.position = anchor
	inst.visibility_range_end = 470.0 + CHUNK_LENGTH
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if colored else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(inst)

func _colored_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	return material

func _beam(center: Vector3, size: Vector3, color: Color, tilt: float = 0.0) -> void:
	var chunk := floori(-center.z / CHUNK_LENGTH)
	if not _furniture.has(chunk):
		_furniture[chunk] = []
	var axes := Basis(Vector3.BACK, tilt) * Basis.from_scale(size)
	_furniture[chunk].append([Transform3D(axes, center), color])

func _draw_furniture() -> void:
	_unit.material = _colored_material()
	for entries in _furniture.values():
		_draw_batch(_unit, entries, true)
	_furniture.clear()

func _bounds_at(distance: float) -> Vector2:
	var bounds := Vector2(INF, -INF)
	for road in _roads:
		if absf(distance - road[2]) <= road[5] * 0.5 + 0.001:
			bounds.x = minf(bounds.x, road[0] - road[3] * 0.5)
			bounds.y = maxf(bounds.y, road[0] + road[3] * 0.5)
	return bounds

func _roadside(finish: float) -> void:
	var glow := Color(_colors[7])
	var post := Color("47394e")
	for d in range(-18, ceili(finish), 12):
		var bounds := _bounds_at(d)
		if not is_finite(bounds.x):
			continue
		for sign_x in [-1.0, 1.0]:
			var edge := bounds.y if sign_x > 0.0 else bounds.x
			var x: float = edge + 0.30 * sign_x
			_beam(Vector3(x, 0.52, -d), Vector3(0.15, 1.06, 0.20), post)
			_beam(Vector3(x, 1.04, -d), Vector3(0.18, 0.14, 0.24), glow)
			_beam(Vector3(x, 0.78, -d), Vector3(0.16, 0.10, 0.22), Color("c68982"))
	# Cantilever light pylons rise out of the viaduct, always beyond the drivable deck.
	for i in range(ceili(finish / 56.0) + 1):
		var z := -11.0 - float(i) * 56.0
		var side := 1.0 if i % 2 == 0 else -1.0
		var bounds := _bounds_at(-z)
		if not is_finite(bounds.x):
			continue
		var edge := bounds.y if side > 0.0 else bounds.x
		var x := edge + side * 2.35
		_beam(Vector3(x, -1.3, z), Vector3(1.16, 5.0, 1.17), Color("40334a"))
		_beam(Vector3(x, 2.08, z), Vector3(0.49, 2.42, 0.69), post)
		_beam(Vector3(x + 0.34 * side, 3.79, z), Vector3(0.52, 1.62, 0.66), Color("80556a"), -0.47 * side)
		_beam(Vector3(x + 0.65 * side, 4.49, z), Vector3(0.96, 0.35, 0.78), Color("65465b"))
		_beam(Vector3(x + 0.65 * side, 4.51, z + 0.398), Vector3(0.69, 0.11, 0.027), Color("ffc391"))
		_beam(Vector3(x, 1.96, z + 0.35), Vector3(0.105, 1.70, 0.04), glow)
		_beam(Vector3(edge + side * 1.16, -0.46, z), Vector3(2.38, 0.45, 0.63), post)

func _landscape(width: float, finish: float, index: int, props: Array) -> void:
	var ocean_material := ShaderMaterial.new()
	ocean_material.shader = SEA_SHADER
	ocean_material.set_shader_parameter("deep_color", Color(_colors[6]).darkened(0.42))
	ocean_material.set_shader_parameter("ripple_color", Color(_colors[5]))
	ocean_material.set_shader_parameter("reflection", Color(_colors[2]))
	if _climate >= 0:
		ocean_material.shader = EXPEDITION_FLOOR
		ocean_material.set_shader_parameter("climate", _climate)
		ocean_material.set_shader_parameter("base_color", Color(EXPEDITION_SURFACES[_climate][4]))
		ocean_material.set_shader_parameter("line_color", Color(EXPEDITION_SURFACES[_climate][5]))
	var sea := PlaneMesh.new()
	sea.size = Vector2(1750.0, finish + 1600.0)
	sea.material = ocean_material
	var water := MeshInstance3D.new()
	water.position = Vector3(0.0, -9.2, -finish / 2.0)
	if _climate == 0:
		water.position.y = -5.8
	water.mesh = sea
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	var material := _colored_material()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	for side in [-1.0, 1.0]:
		rng.seed = 937 + index * 47 + int(side) * 300
		var previous := PackedVector3Array()
		var mesh_builder := SurfaceTool.new()
		mesh_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segment := 0
		for d in range(-340, ceili(finish) + 355, 15):
			var points := PackedVector3Array()
			var wake := 0.5 + 0.5 * sin(float(d) * 0.024 + side * 2.39)
			for k in 5:
				var offsets := [10.5, 19.5, 32.0, 53.0, 82.0]
				var x: float = side * (width * 0.5 + offsets[k] + rng.randf_range(-3.4, 3.4))
				var z := -float(d) + rng.randf_range(-5.3, 5.3)
				var heights := [-12.1, -9.3 + wake * 3.9, -7.2 + wake * 9.4, -2.2 + wake * 13.8, -5.0]
				var height: float = heights[k] + rng.randf_range(-2.8, 2.8)
				if _climate == 0:
					height = -8.7 + (height + 9.0) * 0.27
				elif _climate == 2:
					height = -8.6 + (height + 9.0) * 1.35
				for prop in props:
					if absf(x - prop[1]) < 17.0 and absf(z + prop[3]) < 21.0:
						height = minf(height, -8.7)
				points.append(Vector3(x, height, z))
			if not previous.is_empty():
				for col in 4:
					_rock_face(mesh_builder, points[col], previous[col], previous[col + 1], rng)
					_rock_face(mesh_builder, previous[col + 1], points[col + 1], points[col], rng)
			previous = points
			segment += 1
			if segment % 12 == 0 or d + 15 >= ceili(finish) + 355:
				var ridge := MeshInstance3D.new()
				ridge.mesh = mesh_builder.commit()
				ridge.material_override = material
				ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(ridge)
				mesh_builder = SurfaceTool.new()
				mesh_builder.begin(Mesh.PRIMITIVE_TRIANGLES)

func _rock_face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, rng: RandomNumberGenerator) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.y < 0.0:
		normal = -normal
	var exposure := clampf(normal.dot(Vector3(-0.76, 0.4, -0.51)) * 0.66 + 0.38 + rng.randf_range(-0.08, 0.08), 0.0, 1.0)
	var shade := Color(_colors[6]).darkened(0.52).lerp(Color(_colors[5]).darkened(0.10), exposure)
	if _climate == 0:
		shade = Color("9fbfb6").lerp(Color("e9e4c8"), exposure)
	elif _climate == 2:
		var summit := smoothstep(-1.0, 6.0, (a.y + b.y + c.y) / 3.0)
		shade = shade.lerp(Color("eaf4e9"), summit * (0.33 + exposure * 0.55))
	for point in [a, b, c]:
		surface.set_color(shade)
		surface.add_vertex(point)

func _original_scenery(props: Array) -> void:
	for data in props:
		var model_name: String = data[0]
		var mesh := load(MODEL_PATH % (model_name + ".obj")) as Mesh
		if mesh == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = DIORAMA_SHADER
		material.set_shader_parameter("palette", load(MODEL_PATH % (model_name + ".png")))
		var prop := MeshInstance3D.new()
		prop.mesh = mesh
		prop.material_override = material
		prop.position = Vector3(data[1], data[2], -data[3])
		prop.rotation.y = -deg_to_rad(data[7])
		prop.scale = Vector3(data[4], data[5], data[6])
		prop.visibility_range_end = 410.0
		add_child(prop)

func _finish_gate(center: Vector3, width: float) -> void:
	var x := center.x
	var z := center.z
	var edge := width * 0.5 + 0.75
	var dark := Color("443148")
	var bright := Color(_colors[7])
	for side in [-1.0, 1.0]:
		var leg_x: float = x + side * edge
		_beam(Vector3(leg_x, 2.9, z), Vector3(0.78, 5.8, 1.32), dark)
		_beam(Vector3(leg_x, 3.0, z + 0.67), Vector3(0.22, 5.0, 0.06), bright)
	_beam(Vector3(x, 6.09, z), Vector3(edge * 2.0 + 0.8, 1.34, 1.38), dark)
	_beam(Vector3(x, 6.80, z), Vector3(edge * 2.0 + 0.8, 0.09, 1.38), bright)
	var finish_sign := Label3D.new()
	finish_sign.text = "Ф И Н И Ш"
	finish_sign.font_size = 120
	finish_sign.outline_size = 0
	finish_sign.pixel_size = 0.0065
	finish_sign.modulate = Color("ffe3bd")
	finish_sign.position = Vector3(x, 6.09, z + 0.714)
	add_child(finish_sign)
	var sz := width / 22.0
	for i in 22:
		for j in 2:
			var check := Color("f6d6ae") if (i + j) % 2 == 0 else dark
			_beam(Vector3(x - width * 0.5 + (i + 0.5) * sz, 0.514, z + (j - 0.5) * sz), Vector3(sz, 0.018, sz), check)

# Paint the upcoming branches on the deck. Chevrons sit inside the intersection of
# both platforms, so every indicated line leads to drivable ground beyond the seam.
func _junction_paint() -> void:
	var arrows := SurfaceTool.new()
	arrows.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := Color(EXPEDITION_SURFACES[_climate][2]).darkened(0.10)
	var count := 0
	for upcoming in _roads:
		var distance: float = upcoming[2] - upcoming[5] * 0.5
		if distance < 0:
			continue
		for previous in _roads:
			if absf(previous[2] + previous[5] * 0.5 - distance) > 0.01:
				continue
			var left := maxf(upcoming[0] - upcoming[3] * 0.5, previous[0] - previous[3] * 0.5)
			var right := minf(upcoming[0] + upcoming[3] * 0.5, previous[0] + previous[3] * 0.5)
			if right - left < 2.8 or upcoming[3] > previous[3] + 0.1:
				continue
			var x := (left + right) * 0.5
			for distance_back in [9.0, 12.5]:
				var y: float = previous[1] + previous[4] * 0.5 + 0.013
				var origin := Vector3(x, y, -distance + distance_back)
				for side in [-1.0, 1.0]:
					var wing := Vector3(side * 0.83, 0.0, 1.13)
					for corner in [Vector3.ZERO, wing, wing + Vector3.BACK * 0.38, Vector3.ZERO, wing + Vector3.BACK * 0.38, Vector3.BACK * 0.38]:
						arrows.set_color(paint)
						arrows.add_vertex(origin + corner)
				count += 1
	if count:
		var decal := MeshInstance3D.new()
		decal.mesh = arrows.commit()
		var material := _colored_material()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		decal.material_override = material
		decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(decal)


func set_beat(strength: float) -> void:
	for material in _beat_materials:
		material.set_shader_parameter("beat_strength", strength)
