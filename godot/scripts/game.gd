extends Node3D

const MusicSession := preload("res://scripts/music_session.gd")
const PROFILE := preload("res://scripts/profile.gd")
const TRACKS := preload("res://data/tracks.json")
const NEW_TRACKS := preload("res://data/new_tracks.json")
const NAMES := ["Перевал", "Медный каньон", "Синие пики", "Лиловый разлом", "Горизонт",
	"Соляные ворота", "Красная дельта", "Ледяной мост", "Ночной разлом", "Солнечное кольцо"]
const COUNTDOWN_SECONDS := 2.4

@onready var world := $Track
@onready var runner := $Runner
@onready var camera := $ChaseCamera as Camera3D
@onready var ui := $Canvas/Interface
@onready var audio := $Soundtrack
var profile := PROFILE.new()
var tracks: Array = TRACKS.data + NEW_TRACKS.data
var music_session := MusicSession.new()
var musical := false
var beat_cursor := 0
var pulse := 0.0
var exiting := false
var mode := ""
var index := 0
var built_index := -1
var before_pause := ""
var finish_z := 0.0
var run_time := 0.0
var countdown_left := 0.0
var last_tick := 0
var crash_reason := ""
var camera_kick := 0.0
var demo_time := 0.0
var demo_row := 0
var demo_lane := 2.3


func _ready() -> void:
	get_tree().auto_accept_quit = false
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		get_window().min_size = Vector2i(320, 320)
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		get_viewport().scaling_3d_scale = 0.8
	add_child(music_session)
	music_session.analysing.connect(func(): _screen("music_loading"))
	music_session.prepared.connect(_music_ready)
	music_session.failed.connect(_music_failed)
	music_session.progress_changed.connect(func(value: float): ui.update_loading(value))
	profile.read_save()
	audio.set_enabled(profile.sound)
	ui.action.connect(_on_action)
	_open_menu()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and mode in ["running", "countdown"]:
		_pause()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if mode == "menu" and ui.is_home():
			_on_action("quit")
		else:
			_back()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_quit_game()


func _ensure_track(next_index: int) -> void:
	index = next_index
	finish_z = float(tracks[index].finish[2])
	if built_index != index:
		world.build(tracks[index], index)
		built_index = index


func _info() -> Dictionary:
	return {
		"index": index, "names": NAMES, "unlocked": profile.unlocked,
		"new_unlocked": profile.new_unlocked, "cups_done": profile.cups_done.duplicate(),
		"records": profile.records.duplicate(), "difficulty": profile.difficulty,
		"sound": profile.sound, "reason": crash_reason, "finished": profile.finished,
		"seconds": run_time, "best_time": profile.best_time(index),
		"music": musical, "song_name": music_session.song_name, "demo_names": MusicSession.DEMO_NAMES,
		"duration": music_session.chart.get("duration", 0.0), "tempo": music_session.chart.get("tempo", 0.0),
	}


func _screen(new_mode: String) -> void:
	var previous := mode
	mode = new_mode
	ui.show_screen(mode, _info())
	if musical:
		if mode == "running":
			if previous == "paused":
				audio.music.stream_paused = false
			else:
				audio.start_song()
		elif mode in ["paused", "crashed", "music_complete"]:
			audio.music.stream_paused = true
		return
	if mode in ["paused", "crashed", "complete"]:
		audio.score("run", true)
	elif mode in ["menu", "credits", "music_loading"]:
		audio.score("menu")
	else:
		audio.score("run")


func _open_menu() -> void:
	if mode in ["running", "paused"]:
		_save_attempt()
	musical = false
	music_session.clear()
	_ensure_track(profile.continuation())
	demo_time = 0.0
	demo_row = 0
	demo_lane = 2.3
	runner.reset_for_run(Vector3(demo_lane, 1.0, -34.0))
	_menu_camera()
	_screen("menu")


func _start(which: int) -> void:
	if not profile.accessible(which):
		return
	music_session.clear()
	_ensure_track(which)
	var cup := int(which >= PROFILE.CUP_SIZE)
	if profile.last_cup != cup:
		profile.last_cup = cup
		profile.save()
	_count_in(tracks[index].start)


func _count_in(start: Array) -> void:
	runner.reset_for_run(Vector3(start[0], start[1], -start[2]))
	run_time = 0
	crash_reason = ""
	camera_kick = 0.0
	countdown_left = COUNTDOWN_SECONDS
	last_tick = ceili(countdown_left)
	_chase_camera(1.0, true)
	_screen("countdown")
	_update_hud()
	audio.cue("tick")


func _on_action(command: String, value: int = -1) -> void:
	match command:
		"cancel_picker":
			music_session.clear()
		"music_demo", "music_file":
			if mode == "menu":
				if command == "music_demo":
					music_session.demo(value)
				else:
					music_session.choose_file()
		"play":
			if mode in ["menu", "credits", "complete"]:
				_start(profile.continuation() if value == -1 else value)
		"next":
			if mode == "complete":
				if (index + 1) % PROFILE.CUP_SIZE == 0:
					_screen("credits")
				else:
					_start(index + 1)
		"retry":
			if musical:
				_restart_song()
			elif mode in ["running", "countdown", "paused", "crashed", "complete", "credits"]:
				_save_attempt()
				_start(index)
		"pause":
			_pause()
		"resume":
			if mode == "paused":
				_screen(before_pause)
				_update_hud()
		"menu":
			_open_menu()
		"quit":
			_quit_game()
		"difficulty", "sound", "reset":
			if mode != "menu":
				return
			if command == "reset":
				profile.reset_progress()
				_open_menu()
			else:
				if command == "difficulty":
					profile.difficulty = clampi(value, 0, 2)
				else:
					profile.sound = value == 1
					audio.set_enabled(profile.sound)
				profile.save()
				ui.show_screen(mode, _info())
			audio.cue("select")
		"ui_click":
			audio.cue("select")


func _quit_game() -> void:
	if exiting:
		return
	exiting = true
	_save_attempt()
	set_physics_process(false)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.assign('../')", true)
		return
	audio.music.stop()
	audio.fx.stop()
	audio.music.stream = null
	audio.fx.stream = null
	# Stop commands reach the audio mixer asynchronously on desktop.
	await get_tree().create_timer(0.35, true, false, true).timeout
	get_tree().quit()


func _music_ready() -> void:
	musical = true
	built_index = -1
	var track: Dictionary = music_session.chart.track
	finish_z = float(track.finish[2])
	world.build(track, 8)
	_restart_song()


func _restart_song() -> void:
	beat_cursor = 0
	pulse = 0
	world.set_beat(0)
	audio.prepare_song(music_session.song)
	_count_in(music_session.chart.track.start)


func _music_failed(message: String) -> void:
	_open_menu()
	ui.show_music_picker(message)


func _pause() -> void:
	if mode in ["running", "countdown"]:
		before_pause = mode
		_save_attempt()
		_screen("paused")


func _save_attempt() -> void:
	if not musical and mode in ["running", "paused", "crashed"]:
		profile.record_attempt(index, -runner.position.z / finish_z)


func _input(event: InputEvent) -> void:
	if not is_node_ready() or event.is_echo():
		return
	if event.is_action_pressed("pause_run"):
		_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("retry_run") and mode in ["running", "paused", "countdown", "crashed", "complete", "music_complete"]:
		_on_action("retry")
		get_viewport().set_input_as_handled()


func _back() -> void:
	match mode:
		"running", "countdown": _pause()
		"paused": _on_action("resume")
		"menu": ui.back()
		"crashed", "complete", "credits", "music_complete", "music_loading": _open_menu()


func _physics_process(delta: float) -> void:
	match mode:
		"menu":
			_advance_demo(delta)
		"countdown":
			countdown_left = maxf(0, countdown_left - delta)
			if countdown_left <= 0.0:
				_screen("running")
				audio.cue("start")
			elif ceili(countdown_left) != last_tick:
				last_tick = ceili(countdown_left)
				audio.cue("tick")
			_update_hud()
		"running":
			var steer := Input.get_axis("steer_left", "steer_right")
			var reason: String
			if musical:
				run_time = maxf(run_time, audio.song_seconds(music_session.chart.duration))
				reason = runner.advance_with_song(delta, steer, run_time, music_session.Generator.RUN_SPEED)
				_pulse_at_playhead(delta)
			else:
				run_time += delta
				reason = runner.advance(delta, steer, profile.difficulty, Input.get_action_strength("brake_run"))
			_chase_camera(delta)
			_update_hud()
			if not reason.is_empty():
				crash_reason = reason
				camera_kick = 0.35
				_save_attempt()
				runner.shatter()
				_screen("crashed")
				audio.cue("impact")
			elif -runner.position.z >= finish_z - 0.005 and _inside_finish():
				if musical:
					_screen("music_complete")
				else:
					profile.record_finish(index, run_time)
					_screen("complete")
				audio.cue("finish")
		"crashed":
			if camera_kick > 0.0:
				camera_kick = maxf(0.0, camera_kick - delta)
				camera.h_offset = sin(camera_kick * 70.0) * camera_kick * 0.21
				camera.v_offset = sin(camera_kick * 87.0) * camera_kick * 0.1


func _pulse_at_playhead(delta: float) -> void:
	var beats: Array = music_session.chart.beats
	pulse = maxf(0.0, pulse - delta * 4.5)
	while beat_cursor < beats.size() and float(beats[beat_cursor]) <= run_time:
		var elapsed := run_time - float(beats[beat_cursor])
		pulse = maxf(pulse, 1.0 - elapsed * 4.5)
		beat_cursor += 1
	world.set_beat(pulse)


func _inside_finish() -> bool:
	return runner.position.y > 0.45 and _on_road(runner.position.x, finish_z, -0.4)


func _update_hud() -> void:
	ui.update_run(clampf(-runner.position.z, 0, finish_z), finish_z, ceili(countdown_left))


func _chase_camera(delta: float, snap := false) -> void:
	var factor := 1.0 if snap else 1.0 - exp(-9.0 * delta)
	var planar: Vector3 = runner.position
	var mount := Vector3(planar.x * 0.80, maxf(planar.y, 0.82) + 2.2, planar.z + 5.75)
	camera.position.x = lerpf(camera.position.x, mount.x, factor)
	camera.position.y = lerpf(camera.position.y, mount.y, factor)
	camera.position.z = mount.z
	camera.h_offset = 0
	camera.v_offset = 0
	var target_fov: float = 61.5 if musical else 59.5 + 4.0 * runner.speed / 76.0
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		# Widen the vertical FOV on a narrow phone to show both adjacent lanes.
		target_fov = clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(28.0)) * viewport_size.y / viewport_size.x)), 65.0, 102.0)
	camera.fov = lerpf(camera.fov, target_fov, factor)
	camera.look_at(Vector3(planar.x * 0.57, 1.47, planar.z - 12))


func _advance_demo(delta: float) -> void:
	demo_time += delta
	var distance: float = -runner.position.z
	if distance > finish_z - 18:
		demo_row = 0
		runner.reset_for_run(Vector3(2.3, 1, -34))
		distance = 34.0
	var barriers: Array = tracks[index].obstacles
	while demo_row < barriers.size() and float(barriers[demo_row][2]) < distance - 2.0:
		demo_row += 1
	if not _on_road(demo_lane, distance + 13.0, 0.8) or (demo_row < barriers.size() and float(barriers[demo_row][2]) - distance < 16.0):
		demo_lane = _preview_gap(barriers)
	var old_x: float = runner.position.x
	runner.position.x = move_toward(old_x, demo_lane, delta * 5.0)
	runner.position.z -= 11.0 * delta
	runner.pose(delta, (runner.position.x - old_x) / (5.0 * delta))
	_menu_camera()


func _on_road(x: float, distance: float, margin: float) -> bool:
	var road_list: Array = music_session.chart.track.roads if musical else tracks[index].roads
	for road in road_list:
		if absf(distance - float(road[2])) <= float(road[5]) * 0.5 + 0.01:
			if absf(x - float(road[0])) < float(road[3]) * 0.5 - margin:
				return true
	return false


func _preview_gap(barriers: Array) -> float:
	var distance: float = -runner.position.z
	var best := demo_lane
	var best_cost := INF
	for step in range(-24, 25):
		var lane := step * 0.5
		if not _on_road(lane, distance, 0.8) or not _on_road(lane, distance + 13, 0.8):
			continue
		var clear := true
		for j in range(demo_row, barriers.size()):
			var box: Array = barriers[j]
			if float(box[2]) - distance > 16.0:
				break
			if absf(lane - float(box[0])) < float(box[3]) * 0.5 + 0.75:
				clear = false
				break
		var cost := absf(lane - demo_lane) + absf(lane) * 0.16
		if clear and cost < best_cost:
			best_cost = cost
			best = lane
	return best


func _menu_camera() -> void:
	var pos: Vector3 = runner.position
	camera.h_offset = 0
	camera.v_offset = 0
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		camera.fov = 77.0
		camera.position = pos + Vector3(-2.8, 1.9, 5.0)
		camera.look_at(pos + Vector3(1.4, -1.65, -5.0))
		return
	camera.fov = 54
	camera.position = pos + Vector3(-3.0 + 0.28 * sin(demo_time * 0.13), 1.50, 3.85)
	camera.look_at(pos + Vector3(-0.65, 0.14, -8))
