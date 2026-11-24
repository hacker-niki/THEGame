extends SceneTree

const Profile := preload("res://scripts/profile.gd")
var game
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(result: bool, label: String) -> void:
	if not result:
		printerr("FAIL: ", label)
		failures += 1


func _wait_for(target: String, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while game.mode != target and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(game.mode == target, "Expected %s, got %s" % [target, game.mode])
	return game.mode == target


func _run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty() or FileAccess.file_exists(Profile.SAVE_PATH):
		printerr("Use a fresh XDG_DATA_HOME.")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.ui.action.emit("music_demo", 1)
	_check(game.mode == "music_loading", "Analysis can be cancelled before race")
	game.ui.action.emit("menu", -1)
	_check(game.mode == "menu" and not game.musical, "Cancel returns to title")
	game.ui.action.emit("music_demo", 0)
	if await _wait_for("running", 9000):
		_check(game.music_session.chart.track.obstacles.size() > 0, "Bundled music produces a playable chart")
		_check(not game.music_session.song.loop, "Song playback reaches its ending")
		await create_timer(0.45).timeout
		_check(absf(-game.runner.position.z - game.run_time * 36) < 1.5, "Distance follows audible time")
		game.ui.action.emit("pause", -1)
		var position: Vector3 = game.runner.position
		await create_timer(0.2).timeout
		_check(position == game.runner.position and game.audio.music.stream_paused, "Pause freezes audio and motion")
		game.ui.action.emit("resume", -1)
		await create_timer(0.2).timeout
		_check(game.runner.position.z < position.z, "Resumed audio advances the runner")
		game.ui.action.emit("menu", -1)
	# A quiet imported track has a clear road, so we can exercise the real finish signal.
	var samples := PackedByteArray()
	samples.resize(8000 * 7 * 2)
	var quiet := AudioStreamWAV.new()
	quiet.format = AudioStreamWAV.FORMAT_16_BITS
	quiet.mix_rate = 8000
	quiet.data = samples
	var path := "user://quiet.wav"
	quiet.save_to_wav(path)
	var bytes := FileAccess.get_file_as_bytes(path)
	game.music_session._import(bytes, "Quiet")
	if await _wait_for("music_complete", 15000):
		_check(game.music_session.song_name == "Quiet", "Imported title survives the finish")
		_check(game.profile.records.count(0) == 10, "Musical runs never change cup records")
		game.ui.action.emit("retry", -1)
		_check(game.mode == "countdown" and game.runner.position.z == 0, "Retry starts the same chart")
	game.ui.action.emit("menu", -1)
	game.queue_free()
	await create_timer(0.4).timeout
	if failures == 0: print("PASS: imported WAV finish, song analysis, playhead, cancellation, pause and retry.")
	quit(int(failures > 0))
