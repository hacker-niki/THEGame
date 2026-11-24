extends RefCounted

# The runner's longitudinal velocity is constant so metres on the course map to audio time.
const RUN_SPEED := 36.0
const MIN_DURATION := 6.0
const MAX_DURATION := 600.0
const SAMPLE_RATE := 4000.0
const HOP := 64
const BATCH := HOP * 24
const LANE_X := [-5.0, 0.0, 5.0]
const BPM_MIN := 65
const BPM_MAX := 185

static func begin(stream: AudioStream) -> Analysis:
	return Analysis.new(stream)

static func generate(stream: AudioStream) -> Dictionary:
	var job := begin(stream)
	while not job.advance(100):
		pass
	return job.result

class Analysis extends RefCounted:
	enum Phase { DECODE, TEMPO, LAYOUT, DONE }
	var progress := 0.0
	var result: Dictionary = {}

	var _phase := Phase.DECODE
	var _playback: AudioStreamPlayback
	var _duration := 0.0
	var _rate := 1.0
	var _total := 0
	var _decoded := 0
	var _cursor := 0
	var _bass_left := 0.0
	var _bass_right := 0.0
	var _previous := Vector3.ZERO
	var _previous_flux := 0.0
	var _previous_gate := 0.0
	var _previous_rising := false
	var _flux_average := 0.0
	var _level_average := 0.0
	var _fingerprint: int = 27449
	var _beats: Array[float] = []
	var _strength := PackedFloat32Array()
	var _brightness := PackedFloat32Array()
	var _energy_seconds := PackedFloat32Array()
	var _bright_seconds := PackedFloat32Array()
	var _votes := PackedFloat64Array()
	var _strength_sum := 0.0
	var _tempo := 0.0
	var _rng := RandomNumberGenerator.new()
	var _blocks: Array = []
	var _row_time := -10.0
	var _required_gap := 0.80
	var _safe_lane := 1
	var _stationary_rows := 0

	func _init(stream: AudioStream) -> void:
		if not (stream is AudioStreamWAV or stream is AudioStreamOggVorbis or stream is AudioStreamMP3):
			_fail("Нужен аудиофайл WAV, Ogg Vorbis или MP3.")
			return
		_duration = stream.get_length()
		if not is_finite(_duration) or _duration < MIN_DURATION or _duration > MAX_DURATION:
			_fail("Длительность трека должна быть от 6 секунд до 10 минут.")
			return
		_playback = stream.instantiate_playback()
		if _playback == null:
			_fail("Не удалось открыть аудиопоток.")
			return
		_total = ceili(_duration * SAMPLE_RATE)
		_rate = AudioServer.get_mix_rate() / SAMPLE_RATE
		_votes.resize(BPM_MAX + 1)
		_energy_seconds.resize(ceili(_duration))
		_bright_seconds.resize(ceili(_duration))
		_playback.start(0.0)

	func _fail(message: String) -> void:
		_phase = Phase.DONE
		progress = 1.0
		result = {"track": {}, "tempo": 0.0, "duration": _duration, "beats": [], "error": message}
		if _playback != null:
			_playback.stop()
			_playback = null

	# At most one decode batch or one block of 48 accents can overrun the requested slice.
	func advance(budget_ms := 8) -> bool:
		var deadline := Time.get_ticks_usec() + maxi(1, budget_ms) * 1000
		while _phase != Phase.DONE:
			match _phase:
				Phase.DECODE:
					_decode_batch()
				Phase.TEMPO:
					_vote_batch()
				Phase.LAYOUT:
					_layout_batch()
			if Time.get_ticks_usec() >= deadline:
				break
		return _phase == Phase.DONE

	func _decode_batch() -> void:
		var count := mini(BATCH, _total - _decoded)
		var audio := _playback.mix_audio(_rate, count)
		if audio.size() < count and _total - _decoded - audio.size() > SAMPLE_RATE * 0.12:
			_fail("Звуковой поток закончился раньше указанной длительности.")
			return
		for offset in range(0, audio.size(), HOP):
			var end := mini(offset + HOP, audio.size())
			_measure_window(audio, offset, end)
		_decoded += count
		progress = 0.87 * float(_decoded) / _total
		if _decoded >= _total:
			_playback.stop()
			_playback = null
			_phase = Phase.TEMPO

	func _measure_window(audio: PackedVector2Array, start: int, end: int) -> void:
		var energy := 0.0
		var bass := 0.0
		var high := 0.0
		for i in range(start, end):
			var lr := audio[i]
			# A one-pole ~155 Hz crossover separates low attacks from brighter accents.
			# Preserve both channels: out-of-phase stereo drums still register.
			_bass_left += 0.215 * (lr.x - _bass_left)
			_bass_right += 0.215 * (lr.y - _bass_right)
			energy += lr.length_squared()
			bass += _bass_left * _bass_left + _bass_right * _bass_right
			var high_left := lr.x - _bass_left
			var high_right := lr.y - _bass_right
			high += high_left * high_left + high_right * high_right
		var gain := 0.5 / (end - start)
		var instant := Vector3(sqrt(energy * gain), sqrt(bass * gain), sqrt(high * gain))
		var second := mini(_energy_seconds.size() - 1, floori((_decoded + start) / SAMPLE_RATE))
		var elapsed := (end - start) / SAMPLE_RATE
		_energy_seconds[second] += instant.x * elapsed
		_bright_seconds[second] += instant.z * elapsed
		var bands := _previous.lerp(instant, 0.70)
		var rise := (bands - _previous).max(Vector3.ZERO)
		var flux := rise.dot(Vector3(0.62, 0.78, 0.53))
		var gate := 0.0018 + _flux_average * 1.85 + _level_average * 0.070
		if _previous_rising and flux <= _previous_flux and _previous_flux > _previous_gate and _previous.x > 0.0025:
			var time := maxf(0.0, (float(_decoded + start) - HOP * 0.75) / SAMPLE_RATE)
			_append_accent(time, _previous_flux + _previous.x * 0.16, _previous.z / maxf(0.001, _previous.x))
		_previous_rising = flux > _previous_flux
		_previous_gate = gate
		_previous_flux = flux
		_previous = bands
		_level_average = lerpf(_level_average, bands.x, 0.048)
		_flux_average = lerpf(_flux_average, flux, 0.085)
		_fingerprint = (_fingerprint * 33 + roundi(bands.x * 211) + roundi(bands.z * 337)) % 2147483647

	func _append_accent(time: float, strength: float, brightness: float) -> void:
		var last := _beats.size() - 1
		# Collapse several edges of one kick/snare into its strongest onset.
		if last >= 0 and time - _beats[last] < 0.15:
			if strength > _strength[last]:
				_beats[last] = time
				_strength[last] = strength
				_brightness[last] = brightness
			return
		_beats.append(time)
		_strength.append(strength)
		_brightness.append(brightness)

	func _vote_batch() -> void:
		var stop := mini(_cursor + 48, _beats.size())
		while _cursor < stop:
			_strength_sum += _strength[_cursor]
			# Repeated onset intervals vote for a pulse at several distances. Folding
			# permits subdivisions and missed hits without forcing a grid onto silence.
			for steps in range(1, mini(5, _cursor) + 1):
				var period := (_beats[_cursor] - _beats[_cursor - steps]) / steps
				var bpm := 60.0 / period
				var weight := 1.0 / sqrt(float(steps))
				while bpm < BPM_MIN:
					bpm *= 2.0
					weight *= 0.70
				while bpm > BPM_MAX:
					bpm *= 0.5
					weight *= 0.70
				var center := roundi(bpm)
				for candidate in range(maxi(BPM_MIN, center - 4), mini(BPM_MAX, center + 4) + 1):
					_votes[candidate] += weight * maxf(0.0, 1.0 - absf(bpm - candidate) / 4.4)
			_cursor += 1
		progress = 0.87 + 0.07 * float(_cursor) / maxi(1, _beats.size())
		if _cursor == _beats.size():
			var winner := BPM_MIN
			for bpm in range(BPM_MIN + 1, BPM_MAX + 1):
				if _votes[bpm] > _votes[winner]:
					winner = bpm
			# Sparse isolated sounds can still shape the road without a credible BPM.
			if _beats.size() >= 4 and _votes[winner] >= _beats.size() * 0.28:
				_tempo = float(winner)
			_rng.seed = _fingerprint
			_cursor = 0
			_phase = Phase.LAYOUT

	func _layout_batch() -> void:
		var stop := mini(_cursor + 48, _beats.size())
		while _cursor < stop:
			var time := _beats[_cursor]
			if time >= 1.45 and time <= _duration - 0.74 and time - _row_time >= _required_gap:
				_place_row(_cursor, time)
			_cursor += 1
		progress = 0.94 + 0.06 * float(_cursor) / maxi(1, _beats.size())
		if _cursor == _beats.size():
			var finish := _duration * RUN_SPEED
			var roads := _build_roads()
			var final_road: Array = roads.back()
			var track := {
				"start": [0, 1, 0],
				"finish": [final_road[0], 1, finish],
				"roads": roads,
				"obstacles": _blocks,
				"scenery": [],
			}
			result = {"track": track, "tempo": _tempo, "duration": _duration, "beats": _beats, "error": ""}
			progress = 1.0
			_phase = Phase.DONE

	# Road sections follow eight-bar phrases. All three racing lines remain at least
	# a cube width from the edge, including at a change in the platform's centre.
	func _build_roads() -> Array:
		var roads: Array = []
		var phrase := 32.0 * 60.0 / _tempo if _tempo > 0.0 else 12.0
		var peak := 0.0
		for value in _energy_seconds:
			peak = maxf(peak, value)
		var start_time := 0.0
		while start_time < _duration:
			var end_time := minf(_duration, start_time + phrase)
			if _duration - end_time < 3.0:
				end_time = _duration
			var energy := 0.0
			var brightness := 0.0
			for i in range(floori(start_time), ceili(end_time)):
				var overlap := minf(end_time, i + 1.0) - maxf(start_time, i)
				energy += _energy_seconds[i] * overlap
				brightness += _bright_seconds[i] * overlap
			var width := 16.0
			var center := 0.0
			if peak > 0.001:
				var intensity := clampf(energy / ((end_time - start_time) * peak), 0.0, 1.0)
				width = snappedf(14.6 + intensity * 4.0, 0.10)
				center = snappedf(clampf((brightness / maxf(energy, 0.0001) - 0.50) * 2.6, -0.9, 0.9), 0.05)
			var first_z := -24.0 if start_time == 0.0 else start_time * RUN_SPEED
			var last_z := end_time * RUN_SPEED + (24.0 if end_time == _duration else 0.0)
			roads.append([center, 0, (first_z + last_z) * 0.5, width, 1, last_z - first_z, 0])
			start_time = end_time
		return roads

	func _place_row(index: int, time: float) -> void:
		var dt := time - _row_time
		var intensity := _strength[index] * _beats.size() / maxf(0.0001, _strength_sum)
		# A forced shift spans at most 5 m, with at least 0.90 s available. With
		# the runner's 13 m/s and acceleration this leaves time to settle in lane.
		var change := dt >= 0.90 and (_stationary_rows >= 2 or _rng.randf() < 0.60)
		if change:
			if _safe_lane == 1:
				_safe_lane = 0 if _rng.randf() < 0.5 else 2
			else:
				_safe_lane = 1
			_stationary_rows = 0
		else:
			_stationary_rows += 1
		var lanes := [0, 1, 2]
		lanes.erase(_safe_lane)
		var double := intensity >= 1.06 or (intensity > 0.74 and _rng.randf() < 0.37)
		if not double:
			lanes.remove_at(_rng.randi_range(0, 1))
		var block_width := clampf(2.25 + intensity * 0.95, 2.65, 4.45)
		var height := clampf(0.87 + intensity * 0.24 + _brightness[index] * 0.20, 0.9, 1.68)
		var depth := clampf(0.92 + (1.0 - _brightness[index]) * 0.58, 0.90, 1.65)
		for lane in lanes:
			_blocks.append([LANE_X[lane], 0.5 + height * 0.5, time * RUN_SPEED, block_width, height, depth, 0])
		_row_time = time
		_required_gap = clampf(1.03 - intensity * 0.24, 0.60, 0.91)
		if _stationary_rows >= 2:
			_required_gap = maxf(_required_gap, 0.91)
