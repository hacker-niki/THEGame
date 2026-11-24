extends SceneTree

const Course := preload("res://scripts/music_course.gd")
const RATE := 12000
const OFFSET := 0.22
var failures := 0

func _initialize() -> void:
	call_deferred("_exercise")

func _check(ok: bool, message: String) -> void:
	if not ok:
		printerr("FAIL: ", message)
		failures += 1

# Kicks alternate pitch and brightness. Stereo channels are deliberately opposite
# in phase so a naive mono sum would mistake every fixture for silence.
func _clicks(bpm: float, seconds: float, quiet_from := -1.0, quiet_to := -1.0) -> AudioStreamWAV:
	var total := roundi(seconds * RATE)
	var pcm := PackedByteArray()
	pcm.resize(total * 4)
	if bpm > 0:
		var step := 60.0 / bpm
		var t := OFFSET
		var hit := 0
		while t < seconds:
			if t < quiet_from or t >= quiet_to:
				var first := roundi(t * RATE)
				for n in mini(roundi(RATE * 0.16), total - first):
					var age := float(n) / RATE
					var deep := 0.56 * sin(TAU * (68.0 + (hit % 3) * 9.0) * age)
					var snare := (0.16 if hit % 2 else 0.26) * sin(TAU * 779.0 * age)
					var value := roundi((deep + snare) * exp(-age * 31.0) * 30000.0)
					pcm.encode_s16((first + n) * 4, value)
					pcm.encode_s16((first + n) * 4 + 2, -value)
			t += step
			hit += 1
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = true
	stream.data = pcm
	return stream

func _assert_route(map: Dictionary) -> void:
	var roads: Array = map.track.roads
	var previous_edge := -24.0
	for road in roads:
		_check(absf(road[2] - road[5] * 0.5 - previous_edge) < 0.001, "Adjacent phrase decks connect")
		previous_edge = road[2] + road[5] * 0.5
		for lane_x in Course.LANE_X:
			_check(absf(lane_x - road[0]) + 0.6 <= road[3] * 0.5, "Safe racing line inside the deck")
	_check(previous_edge >= map.track.finish[2], "Track extends to finish")
	var reachable := [false, true, false]
	var previous_t := 0.0
	var blocks: Array = map.track.obstacles
	var cursor := 0
	while cursor < blocks.size():
		var z: float = blocks[cursor][2]
		var t: float = z / Course.RUN_SPEED
		var allowed := [true, true, true]
		while cursor < blocks.size() and is_equal_approx(z, blocks[cursor][2]):
			var box: Array = blocks[cursor]
			for lane in 3:
				if absf(Course.LANE_X[lane] - box[0]) <= box[3] * 0.5 + 0.6:
					allowed[lane] = false
			cursor += 1
		var next := [false, false, false]
		for lane in 3:
			if not allowed[lane]:
				continue
			for from in 3:
				if reachable[from] and (from == lane or (absi(lane - from) == 1 and t - previous_t >= 0.89)):
					next[lane] = true
		_check(next.has(true), "Reachable lane at %.3f s" % t)
		_check(t - previous_t >= 0.59, "Reaction window at %.3f s" % t)
		var aligned := false
		for beat in map.beats:
			if absf(beat - t) < 0.001:
				aligned = true
				break
		_check(aligned, "Obstacle row lands on a measured accent")
		reachable = next
		previous_t = t

func _assert_clicks(map: Dictionary, bpm: float, quiet_from := -1.0, quiet_to := -1.0, first_hit := OFFSET) -> void:
	_check(map.error.is_empty(), "Decode click track")
	_check(absf(map.tempo - bpm) <= 2.0, "Expected %.0f BPM, measured %.0f" % [bpm, map.tempo])
	var expected := 0
	var matched := 0
	var t := first_hit
	while t < map.duration:
		if t < quiet_from or t >= quiet_to:
			expected += 1
			for beat in map.beats:
				if absf(beat - t) <= 0.044:
					matched += 1
					break
		t += 60.0 / bpm
	_check(matched >= expected * 0.95, "Known beat times: %d/%d at %.0f BPM" % [matched, expected, bpm])
	_check(map.beats.size() <= expected + 2, "One onset per hit")
	_check(map.track.obstacles.size() >= 4, "Rhythmic audio populates the road")
	_check(absf(map.track.finish[2] - map.duration * 36.0) < 0.001, "Finish and recording end coincide")
	_assert_route(map)
	print("clicks ", bpm, " measured ", map.tempo, " BPM, timed hits ", matched, "/", expected)

# Godot can retain MP3 encoder delay. Compare compressed fixtures with their
# actual playback timeline by measuring the first click at the full mixer rate.
func _first_click(stream: AudioStream) -> float:
	var player := stream.instantiate_playback()
	player.start()
	var rate := AudioServer.get_mix_rate()
	var audio := player.mix_audio(1.0, ceili(rate * 0.60))
	player.stop()
	for i in audio.size():
		if absf(audio[i].x) > 0.10:
			return i / rate
	return -1.0

func _exercise() -> void:
	var slow := _clicks(90.0, 18.0)
	var fast := _clicks(120.0, 18.0)
	var slow_map := Course.generate(slow)
	var fast_map := Course.generate(fast)
	_assert_clicks(slow_map, 90.0)
	_assert_clicks(fast_map, 120.0)
	_check(slow_map.track.obstacles != fast_map.track.obstacles, "Different audio gives different layout")
	var sliced := Course.begin(fast)
	var last_progress := 0.0
	while not sliced.advance(1):
		_check(sliced.progress >= last_progress and sliced.progress <= 1.0, "Monotonic incremental analysis")
		last_progress = sliced.progress
	_check(sliced.result == fast_map, "Different analysis budgets produce identical charts")
	var with_break := Course.generate(_clicks(120.0, 20.0, 5.0, 12.0))
	_assert_clicks(with_break, 120.0, 5.0, 12.0)
	for box in with_break.track.obstacles:
		var t: float = box[2] / Course.RUN_SPEED
		_check(t < 5.20 or t >= 12.0, "Musical rest is clear")
	var silent := Course.generate(_clicks(0.0, 6.0))
	_check(silent.error.is_empty() and silent.tempo == 0.0 and silent.beats.is_empty() and silent.track.obstacles.is_empty(), "Silence is playable without phantom BPM or obstacles")
	_check(not Course.generate(null).error.is_empty(), "Missing input produces an error")
	_check(not Course.generate(_clicks(0.0, 5.0)).error.is_empty(), "Reject too-short audio")
	var oversized := AudioStreamWAV.new()
	oversized.mix_rate = 1000
	oversized.format = AudioStreamWAV.FORMAT_8_BITS
	var raw := PackedByteArray()
	raw.resize(601001)
	oversized.data = raw
	_check(not Course.generate(oversized).error.is_empty(), "Reject audio longer than 10 minutes")
	var built_in := Course.generate(load("res://assets/audio/overdrive.ogg"))
	_check(built_in.error.is_empty() and built_in.beats.size() > 10, "Shipped Ogg Vorbis decodes")
	_assert_route(built_in)
	# Optional compressed fixtures created outside Godot from the same 120 BPM clicks.
	for path in OS.get_cmdline_user_args():
		var audio: AudioStream
		match path.get_extension().to_lower():
			"mp3": audio = AudioStreamMP3.load_from_file(path)
			"ogg": audio = AudioStreamOggVorbis.load_from_file(path)
			"wav": audio = AudioStreamWAV.load_from_file(path)
		if audio != null:
			_assert_clicks(Course.generate(audio), 120.0, -1.0, -1.0, _first_click(audio))
		else:
			_check(false, "Could not load fixture " + path)
	print("music course failures: ", failures)
	quit(1 if failures else 0)
