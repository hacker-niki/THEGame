extends CharacterBody3D

# Gentle, arcade and turbo. Lateral authority stays independent of forward speed.
const CRUISE := [41.0, 57.0, 76.0]
const LATERAL_SPEED := 13.0
const TRAIL_POINTS := 15
const HULL_SHADER := preload("res://shaders/hull.gdshader")

var speed := 0.0
var side_speed := 0.0
var braking := false
var appearance := Node3D.new()
var trail := MeshInstance3D.new()
var ribbons := ImmediateMesh.new()
var trail_material := StandardMaterial3D.new()
var history := PackedVector3Array()
var exhaust := CPUParticles3D.new()


func _ready() -> void:
	add_child(appearance)
	_build_cube()
	trail.mesh = ribbons
	trail.top_level = true
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.vertex_color_use_as_albedo = true
	trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(trail)
	_build_fragments()


func _material(color: String, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.42
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(color)
		mat.emission_energy_multiplier = glow
	return mat


func _trim(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = at
	appearance.add_child(mesh_instance)
	return mesh_instance


func _build_cube() -> void:
	var paint := ShaderMaterial.new()
	paint.shader = HULL_SHADER
	var shell := _trim(Vector3.ONE, Vector3.ZERO, paint)
	var mesh: BoxMesh = shell.mesh
	mesh.subdivide_width = 11
	mesh.subdivide_height = 11
	mesh.subdivide_depth = 11
	var ivory := _material("#fff2ce", 0.24)
	var dark := _material("#142842")
	var light := _material("#98ffe5", 1.1)
	# An off-centre racing stripe wraps over the roof and down the back.
	for spec in [[-0.21, 0.13], [-0.095, 0.045]]:
		_trim(Vector3(spec[1], 0.009, 0.83), Vector3(spec[0], 0.501, 0.0), ivory)
		_trim(Vector3(spec[1], 0.82, 0.009), Vector3(spec[0], 0.0, 0.501), ivory)
	var rear := _trim(Vector3(0.9, 0.25, 0.035), Vector3(0, -0.19, 0.506), dark)
	for x in [-0.34, 0.34]:
		var lamp := _trim(Vector3(0.17, 0.065, 0.025), Vector3(x, -0.15, 0.53), light)
		lamp.rotation.z = signf(x) * 0.12
	for x in [-0.1, 0.0, 0.1]:
		_trim(Vector3(0.042, 0.09, 0.022), rear.position + Vector3(x, -0.02, 0.023), light)
	# Side number plates and two short stripes read in the menu's three-quarter view.
	for x in [-0.502, 0.502]:
		_trim(Vector3(0.012, 0.22, 0.48), Vector3(x, -0.04, 0.0), dark)
		for z in [-0.09, 0.035]:
			var slash := _trim(Vector3(0.014, 0.15, 0.046), Vector3(x * 1.015, -0.04, z), ivory)
			slash.rotation.x = -0.3


func _build_fragments() -> void:
	add_child(exhaust)
	exhaust.emitting = false
	exhaust.one_shot = true
	exhaust.amount = 32
	exhaust.lifetime = 0.85
	exhaust.explosiveness = 1.0
	exhaust.direction = Vector3.UP
	exhaust.spread = 82
	exhaust.initial_velocity_min = 2.0
	exhaust.initial_velocity_max = 7.0
	exhaust.gravity = Vector3(0, -13, 0)
	exhaust.angular_velocity_min = -260
	exhaust.angular_velocity_max = 260
	exhaust.scale_amount_min = 0.5
	exhaust.scale_amount_max = 1.6
	var chip := BoxMesh.new()
	chip.size = Vector3(0.13, 0.12, 0.2)
	chip.material = _material("#81f3df", 0.3)
	exhaust.mesh = chip


func reset_for_run(at: Vector3) -> void:
	position = at
	velocity = Vector3.ZERO
	side_speed = 0
	speed = 0
	braking = false
	appearance.show()
	appearance.rotation = Vector3.ZERO
	exhaust.emitting = false
	history.clear()
	ribbons.clear_surfaces()
	reset_physics_interpolation()


func advance(delta: float, steer: float, difficulty: int, brake: float) -> String:
	braking = brake > 0.04
	var target_speed: float = CRUISE[difficulty] * lerpf(1.0, 0.46, brake)
	speed = move_toward(speed, target_speed, (70.0 if braking else 26.0) * delta)
	return _move(delta, steer)


func advance_with_song(delta: float, steer: float, song_seconds: float, meters_per_second: float) -> String:
	braking = false
	# Move towards the audible playhead. Swept physics still resolves every hit.
	var remaining := song_seconds * meters_per_second + position.z
	speed = clampf(remaining / delta, 0, meters_per_second * 2.5)
	return _move(delta, steer)


func _move(delta: float, steer: float) -> String:
	side_speed = move_toward(side_speed, steer * LATERAL_SPEED, (60.0 if steer else 79.0) * delta)
	velocity.x = side_speed
	velocity.z = -speed
	velocity.y -= 32.0 * delta
	move_and_slide()
	for index in get_slide_collision_count():
		var collider := get_slide_collision(index).get_collider() as CollisionObject3D
		if collider and (collider.collision_layer & 2) != 0:
			return "Столкновение"
	if position.y < -1.0:
		return "Сход с трассы"
	pose(delta, side_speed / LATERAL_SPEED)
	return ""


func pose(delta: float, steer: float) -> void:
	appearance.rotation.z = lerpf(appearance.rotation.z, -0.11 * steer, 1.0 - exp(-12.0 * delta))
	appearance.rotation.y = lerpf(appearance.rotation.y, -0.14 * steer, 1.0 - exp(-12.0 * delta))
	if history.is_empty() or position.distance_squared_to(history[0]) > 0.025:
		history.insert(0, position)
		if history.size() > TRAIL_POINTS:
			history.resize(TRAIL_POINTS)
		_draw_trail()


func _draw_trail() -> void:
	ribbons.clear_surfaces()
	if history.size() < 2:
		return
	for side in [-0.34, 0.34]:
		ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, trail_material)
		for idx in history.size():
			var strength := 1.0 - float(idx) / (history.size() - 1)
			var center := history[idx] + Vector3(side, -0.43, 0.48)
			var tint := Color(0.20, 1.0, 0.88, 0.44)
			tint.a *= strength
			ribbons.surface_set_color(tint)
			var half_width := 0.105 * strength + 0.012
			ribbons.surface_add_vertex(center + Vector3.LEFT * half_width)
			ribbons.surface_add_vertex(center + Vector3.RIGHT * half_width)
		ribbons.surface_end()


func shatter() -> void:
	appearance.hide()
	exhaust.restart()
	exhaust.emitting = true
