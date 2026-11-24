extends SceneTree

const Profile := preload("res://scripts/profile.gd")
var game
var failures := 0


func _initialize() -> void:
	call_deferred("_exercise")


func _check(result: bool, message: String) -> void:
	if not result:
		failures += 1
		printerr("FAIL: ", message)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func _wait_mode(expected: String, budget: int) -> bool:
	for i in budget:
		await physics_frame
		if game.mode == expected:
			return true
	_check(false, "Expected %s, got %s" % [expected, game.mode])
	return false


func _exercise() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty() or FileAccess.file_exists(Profile.SAVE_PATH):
		printerr("Run with a fresh XDG_DATA_HOME.")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var ui = game.ui
	_check(game.mode == "menu", "Boot to title")
	ui.action.emit("play", 6)
	_check(game.mode == "menu", "Locked track cannot start")
	for mode_index in [1, 2, 0]:
		ui.action.emit("difficulty", mode_index)
		_check(game.profile.difficulty == mode_index, "Difficulty selection")
	ui.action.emit("sound", 0)
	var saved := Profile.new()
	saved.read_save()
	_check(not saved.sound and not game.audio.enabled, "Sound persists and mutes")
	_key(KEY_ENTER)
	await physics_frame
	_check(game.mode == "countdown", "Enter activates first menu button")
	_key(KEY_ESCAPE)
	var remaining: float = game.countdown_left
	for i in 45: await physics_frame
	_check(game.mode == "paused" and is_equal_approx(remaining, game.countdown_left), "Countdown freezes on pause")
	_key(KEY_ESCAPE)
	if await _wait_mode("running", 180):
		for i in 45: await physics_frame
		Input.action_press("brake_run")
		for i in 30: await physics_frame
		_check(game.runner.braking and game.runner.speed < 21, "Brake controls forward speed")
		Input.action_release("brake_run")
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		var stopped: Vector3 = game.runner.position
		for i in 32: await physics_frame
		_check(game.mode == "paused" and stopped == game.runner.position, "Losing focus freezes the race")
		_key(KEY_ESCAPE)
		if await _wait_mode("crashed", 260):
			_check(game.crash_reason == "Столкновение", "First barrier triggers a crash")
			_check(game.profile.records[0] > 0 and game.profile.unlocked == 0, "Failed attempts record progress")
			_key(KEY_R)
			_check(game.mode == "countdown" and game.runner.speed == 0, "Instant restart resets the runner")
			if await _wait_mode("running", 180):
				Input.action_press("steer_left")
				if await _wait_mode("crashed", 220):
					_check(game.crash_reason == "Сход с трассы", "Leaving the road triggers a fall")
				Input.action_release("steer_left")
	ui.action.emit("menu", -1)
	ui.action.emit("play", 5)
	_check(game.index == 5 and game.mode == "countdown", "Second cup available independently")
	ui.action.emit("menu", -1)
	saved = Profile.new()
	saved.read_save()
	_check(saved.continuation() == 5 and saved.records[0] > 0, "Progress and latest cup survive reload")
	ui.action.emit("reset", -1)
	saved = Profile.new()
	saved.read_save()
	_check(saved.continuation() == 0 and saved.records.count(0) == 10 and not saved.sound, "Reset keeps options, clears both cups")
	game.queue_free()
	await process_frame
	# The audio mixing thread drains in real time even under --fixed-fps.
	var drain := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < drain:
		OS.delay_msec(5)
		await process_frame
	if failures == 0: print("PASS: keyboard, countdown, focus, pause, brake, collision, fall, retry, settings and persistence.")
	quit(int(failures > 0))
