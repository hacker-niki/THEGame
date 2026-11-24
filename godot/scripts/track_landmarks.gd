extends Node3D

# Large silhouettes of the expedition circuits. Meshes are baked by sector so each
# group remains one draw call even when many crystal faces or beacon lamps are visible.
var _surface := SurfaceTool.new()
var _material := StandardMaterial3D.new()
var _rng := RandomNumberGenerator.new()
var _sun := Vector3(-0.62, 0.61, -0.49)

func build(limits: Vector2, finish: float, climate: int) -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rng.seed = 313 + climate * 109
	var center := (limits.x + limits.y) * 0.5
	var half_span := (limits.y - limits.x) * 0.5
	var count := ceili((finish + 220.0) / 68.0)
	var first := true
	for i in count:
		if first:
			_surface = SurfaceTool.new()
			_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			first = false
		var d := 32.0 + i * 68.0
		var side := 1.0 if i % 2 == 0 else -1.0
		var border := limits.y if side > 0.0 else limits.x
		var point := Vector3(border + side * 10.0, -7.8, -d)
		match climate:
			0:
				if i % 3 == 0:
					_salt_gate(Vector3(center, 0, -d), half_span + 3.5)
				_salt_columns(point + Vector3(side * 14.0, 0, -13.0))
			1:
				_mesa(point + Vector3(side * 11.0, 0, 1), 0.64 + _rng.randf() * 0.40)
				_mesa(Vector3(center - side * (half_span + 48.0), -8.0, -d - 22.0), 1.4)
			2:
				_glacier(point, side)
				_glacier(Vector3(center - side * (half_span + 35.0), -8.0, -d - 22.0), -side)
			3:
				_beacon(point + Vector3(-side * 2.0, 0, 0), 11.0 + _rng.randf_range(1.0, 9.0), side)
				_beacon(Vector3(center - side * (half_span + 26), -7.9, -d - 18.0), 17.8, -side)
			4:
				if i % 3 == 0:
					_solar_hoop(Vector3(center, 3.0, -d), half_span + 6.0)
				else:
					_solar_hoop(point + Vector3(side * 12.0, 16.0, -4.5), 9.0)
		if i % 3 == 2 or i == count - 1:
			var inst := MeshInstance3D.new()
			inst.mesh = _surface.commit()
			inst.material_override = _material
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(inst)
			first = true

func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for p in [a, b, c]:
		_surface.set_color(color)
		_surface.add_vertex(p)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(a, b, c, color)
	_triangle(a, c, d, color)

# An offset top ring makes both wind-sheared columns and oblique crystal points.
func _prism(base: Vector3, height: float, bottom: Vector2, top: Vector2, slide: Vector2, sides: int, turn: float, tint: Color) -> void:
	var tip := base + Vector3(slide.x, height, slide.y)
	for i in sides:
		var angle := TAU * float(i) / sides + turn
		var next := TAU * float(i + 1) / sides + turn
		var outward := Vector3(cos((angle + next) * 0.5), 0, sin((angle + next) * 0.5))
		var shade := tint.darkened(0.24 - 0.20 * outward.dot(_sun))
		var a := base + Vector3(cos(angle) * bottom.x, 0, sin(angle) * bottom.y)
		var b := base + Vector3(cos(next) * bottom.x, 0, sin(next) * bottom.y)
		var c := tip + Vector3(cos(next) * top.x, 0, sin(next) * top.y)
		var d := tip + Vector3(cos(angle) * top.x, 0, sin(angle) * top.y)
		_quad(a, b, c, d, shade)
		_triangle(d, c, tip, tint.lightened(0.09))

func _hoop(center: Vector3, radius: Vector2, thickness: float, depth: float, angle0: float, angle1: float, steps: int, front: Color, side: Color) -> void:
	var behind := Vector3(0, 0, -depth)
	for i in steps:
		var a0 := lerpf(angle0, angle1, float(i) / steps)
		var a1 := lerpf(angle0, angle1, float(i + 1) / steps)
		var normal0 := Vector2(cos(a0), sin(a0))
		var normal1 := Vector2(cos(a1), sin(a1))
		var p := center + Vector3(normal0.x * radius.x, normal0.y * radius.y, 0)
		var q := center + Vector3(normal1.x * radius.x, normal1.y * radius.y, 0)
		var inside_p := p - Vector3(normal0.x, normal0.y, 0) * thickness
		var inside_q := q - Vector3(normal1.x, normal1.y, 0) * thickness
		_quad(p, q, inside_q, inside_p, front)
		_quad(p + behind, q + behind, inside_q + behind, inside_p + behind, side)
		_quad(p, q, q + behind, p + behind, side.lightened(maxf(0.0, normal0.y) * 0.12))
		_quad(inside_p, inside_q, inside_q + behind, inside_p + behind, side.darkened(0.15))
		if i == 0:
			_quad(p, inside_p, inside_p + behind, p + behind, side)
		if i == steps - 1:
			_quad(q, inside_q, inside_q + behind, q + behind, side)

func _salt_gate(center: Vector3, radius: float) -> void:
	var base := center + Vector3(0, -2.5, 0)
	_hoop(base, Vector2(radius, 17.0), 1.70, 2.3, 0.0, PI, 6, Color("f4e9c8"), Color("92b9b7"))
	_hoop(base + Vector3(0, 0, 0.035), Vector2(radius - 0.48, 16.52), 0.20, 0.025, 0.0, PI, 6, Color("36a89f"), Color("368887"))
	for s in [-1.0, 1.0]:
		_prism(base + Vector3(s * (radius - 0.8), -4.0, -1.0), 5.0, Vector2(2.2, 2.0), Vector2(1.7, 1.7), Vector2.ZERO, 4, PI * 0.25, Color("d6c5a8"))

func _salt_columns(base: Vector3) -> void:
	for i in 5:
		var point := base + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
		var r := _rng.randf_range(2.3, 5.0)
		var h := _rng.randf_range(5.0, 10.0)
		_prism(point, h, Vector2(r, r), Vector2(r * 0.63, r * 0.63), Vector2(0.3, 0), 6, 0.3, Color("d4decd"))
		_prism(point + Vector3(0.3, h, 0), 0.66, Vector2.ONE * r * 0.67, Vector2.ONE * r * 0.61, Vector2.ZERO, 6, 0.3, Color("fff2d6"))

func _mesa(base: Vector3, scale_factor: float) -> void:
	var r := _rng.randf_range(3.7, 6.5) * scale_factor
	var h := _rng.randf_range(13.0, 23.0) * scale_factor
	var lean := Vector2(_rng.randf_range(-1.2, 1.2), 0)
	var turn := _rng.randf() * 0.7
	_prism(base, h * 0.31, Vector2(r * 1.6, r * 1.2), Vector2(r, r * 0.71), lean, 7, turn, Color("a3423b"))
	var shaft := base + Vector3(lean.x, h * 0.31, 0)
	_prism(shaft, h * 0.46, Vector2(r, r * 0.71), Vector2(r * 0.78, r * 0.61), -lean * 0.6, 7, turn, Color("d36848"))
	var band := shaft + Vector3(-lean.x * 0.6, h * 0.46, 0)
	_prism(band, h * 0.065, Vector2(r * 0.83, r * 0.66), Vector2(r * 0.82, r * 0.68), Vector2.ZERO, 7, turn, Color("f39b65"))
	_prism(band + Vector3.UP * h * 0.065, h * 0.16, Vector2(r * 0.82, r * 0.68), Vector2(r * 1.05, r * 0.79), Vector2.ZERO, 7, turn, Color("be5543"))

func _glacier(base: Vector3, side: float) -> void:
	for i in 4:
		var r := _rng.randf_range(1.8, 3.2)
		var h := _rng.randf_range(12.0, 26.0) * (1.0 if i == 0 else 0.68)
		var foot := base + Vector3(side * i * 2.7, 0, i * 3.8)
		var slide := Vector2(side * _rng.randf_range(0.3, 3.0), _rng.randf_range(-1.8, 1.8))
		var bottom := Vector2(r * 1.18, r)
		var top := Vector2(r * 0.82, r * 0.72)
		var turn := i * 0.47
		_prism(foot, h * 0.71, bottom, top, slide, 5, turn, Color("58b9ca") if i % 2 == 0 else Color("6695c1"))
		_prism(foot + Vector3(slide.x, h * 0.71, slide.y), h * 0.29, top, Vector2(0.07, 0.12), slide * 0.65, 5, turn, Color("c9f3f0"))

func _beacon(base: Vector3, h: float, side: float) -> void:
	var offset := Vector2(1.6 * side, 0)
	_prism(base, h, Vector2(2.3, 1.6), Vector2(0.73, 0.65), offset, 4, PI * 0.25, Color("463653"))
	var lamp := base + Vector3(offset.x, h, 0)
	_prism(lamp, 0.54, Vector2(1.24, 1.24), Vector2(1.21, 1.21), Vector2.ZERO, 4, PI * 0.25, Color("a984ff"))
	_prism(lamp + Vector3.UP * 0.54, 1.6, Vector2(0.34, 0.34), Vector2(1.30, 1.30), Vector2.ZERO, 4, 0.0, Color("ae85fa"))
	_prism(lamp + Vector3.UP * 2.14, 2.0, Vector2(1.30, 1.30), Vector2(0.04, 0.04), Vector2.ZERO, 4, 0.0, Color("efa6ff"))
	_prism(base + Vector3(0, 0, 1.16), h * 0.87, Vector2(0.12, 0.12), Vector2(0.09, 0.09), offset * 0.87, 4, 0.0, Color("8e83ef"))

func _solar_hoop(center: Vector3, radius: float) -> void:
	_hoop(center, Vector2.ONE * radius, 1.25, 1.9, 0, TAU, 24, Color("e49148"), Color("94543c"))
	_hoop(center + Vector3(0, 0, 0.035), Vector2.ONE * (radius - 0.25), 0.24, 0.04, 0, TAU, 24, Color("ffe4a0"), Color("ebbb70"))
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.50
		_hoop(center + Vector3(0, 0, 0.08), Vector2.ONE * (radius + 0.19), 1.63, 2.1, a - 0.057, a + 0.057, 2, Color("67483f"), Color("5a3d38"))
