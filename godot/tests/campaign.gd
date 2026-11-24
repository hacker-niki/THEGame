extends SceneTree

# Run with a fresh XDG_DATA_HOME and --headless --fixed-fps 60.
# The driver uses only steering input. The game owns motion, contact and progress.
const Runner = preload("res://scripts/runner.gd")
const GRID := 0.25
const HULL_HALF := 0.48
const BRAKE := 79.0
const ACCEL := 60.0

var game
var steering := 0


func _initialize() -> void:
	call_deferred("_campaign")


func _campaign() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty() or FileAccess.file_exists("user://progress.cfg"):
		_fail("Use a fresh XDG_DATA_HOME, e.g. XDG_DATA_HOME=$(mktemp -d).")
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var ui = game.get_node("Canvas/Interface")
	# Optional -- 0, -- 1 or -- 2 selects the difficulty through the settings UI.
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		if args.size() != 1 or args[0] not in ["0", "1", "2"]:
			_fail("Expected one difficulty (0, 1 or 2) after --.")
			return
		ui.action.emit("difficulty", int(args[0]))
	for cup in range(2):
		var first := cup * 5
		ui.action.emit("play", first)
		for index in range(first, first + 5):
			if not await _drive(index):
				return
			var unlocked: int = game.profile.unlocked if cup == 0 else game.profile.new_unlocked
			if unlocked != mini(first + 4, index + 1) or game.profile.records[index] != 100:
				_fail("Finish did not unlock the next track or record completion.")
				return
			ui.action.emit("next", -1)
		if game.mode != "credits" or not game.profile.cups_done[cup]:
			_fail("Finishing cup %d did not open the credits." % (cup + 1))
			return
	ui.action.emit("play", 0)
	if not await _drive(0):
		return
	if game.profile.unlocked != 4 or game.profile.new_unlocked != 9 or false in game.profile.cups_done:
		_fail("Replaying the first track damaged campaign progress.")
		return
	game.queue_free()
	await process_frame
	# --fixed-fps accelerates the scene, while the audio mixer runs in wall time.
	# Let it consume queued stop commands before the accelerated process exits.
	var drain_until := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < drain_until:
		OS.delay_msec(5)
		await process_frame
	print("PASS: all ten tracks and a replay cleared through steering input.")
	quit(0)


func _drive(index: int) -> bool:
	if game.index != index:
		return _fail("Expected track %d, got %d." % [index + 1, game.index + 1])
	var track: Dictionary = game.tracks[index]
	var rows := _checkpoints(track)
	var cruise: float = Runner.CRUISE[game.profile.difficulty]
	var targets := _plan(rows, track.roads, cruise)
	if targets.is_empty():
		# Brake for tightly spaced chicanes that the driver cannot clear at cruise speed.
		cruise *= 0.46
		targets = _plan(rows, track.roads, cruise)
		Input.action_press("brake_run")
	if targets.is_empty():
		return _fail("No route found for track %d." % (index + 1))
	var next_row := 0
	var frame_budget := ceili((float(track.finish[2]) / cruise + 15.0) * 60)
	for frame in frame_budget:
		await physics_frame
		if game.mode == "countdown":
			continue
		if game.mode == "complete":
			_steer(0)
			Input.action_release("brake_run")
			print("Track %d, cleared %d checkpoints in %d frames." % [index + 1, rows.size(), frame])
			return true
		if game.mode != "running":
			return _fail("Track %d ended in %s at %s." % [index + 1, game.mode, game.runner.position])
		var distance: float = -game.runner.position.z
		while next_row + 1 < rows.size() and distance > float(rows[next_row].z) + float(rows[next_row].pad):
			next_row += 1
		_drive_towards(targets[next_row])
	return _fail("Track %d timed out." % (index + 1))


func _checkpoints(track: Dictionary) -> Array:
	var events := []
	for box in track.obstacles:
		events.append({"z": box[2], "box": box})
	for road in track.roads:
		for end in [-0.5, 0.5]:
			var z := float(road[2]) + float(end) * float(road[5])
			if z > 0 and z < float(track.finish[2]):
				events.append({"z": z, "box": []})
	events.append({"z": track.finish[2], "box": []})
	events.sort_custom(func(a, b): return a.z < b.z)
	var rows := []
	for e in events:
		if rows.is_empty() or float(e.z) - float(rows[-1].z) > 0.1:
			rows.append({"z": e.z, "boxes": [], "pad": 0.7})
		if not e.box.is_empty():
			rows[-1].boxes.append(e.box)
			rows[-1].pad = maxf(rows[-1].pad, float(e.box[5]) * 0.5 + HULL_HALF + 0.20)
	return rows


func _road_spans(roads: Array, z: float) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for road in roads:
		if absf(z - float(road[2])) <= float(road[5]) * 0.5:
			var x := float(road[0])
			var half := float(road[3]) * 0.5 - 0.65
			spans.append(Vector2(x - half, x + half))
	return spans


func _plan(rows: Array, roads: Array, cruise: float) -> Array[float]:
	# Dynamic programming picks safe positions at obstacles and road transitions.
	# Each move fits one uninterrupted road branch and leaves time for braking.
	var costs := {0: 0.0}
	var ancestry := []
	var last_z := 0.0
	var last_pad := 1.18
	for row in rows:
		var new_costs := {}
		var parents := {}
		var available := (float(row.z) - last_z - last_pad - float(row.pad) - 0.24) / cruise
		var onward := _road_spans(roads, float(row.z) + 0.02)
		for span in _road_spans(roads, (float(row.z) + last_z) * 0.5):
			for lane in range(ceili(span.x / GRID), floori(span.y / GRID) + 1):
				var x := lane * GRID
				if not onward.any(func(road: Vector2): return road.x <= x and x <= road.y):
					continue
				var clearance := INF
				for box in row.boxes:
					clearance = minf(clearance, absf(x - float(box[0])) - float(box[3]) * 0.5 - HULL_HALF)
				if clearance < 0.13:
					continue
				for previous in costs:
					var from_x := int(previous) * GRID
					if from_x < span.x or from_x > span.y:
						continue
					var move := absf(x - from_x)
					if move > 0.0 and _travel_time(move) >= available:
						continue
					var cost := float(costs[previous]) + move * 0.1 + float(lane != previous)
					cost += x * x * 0.001 + 0.012 / clearance
					if cost < float(new_costs.get(lane, INF)):
						new_costs[lane] = cost
						parents[lane] = previous
		if new_costs.is_empty():
			return []
		costs = new_costs
		ancestry.append(parents)
		last_z = row.z
		last_pad = row.pad
	var lane: int = costs.find_key(costs.values().min())
	var path: Array[float] = []
	for i in range(ancestry.size() - 1, -1, -1):
		path.push_front(lane * GRID)
		lane = ancestry[i][lane]
	return path


func _travel_time(distance: float) -> float:
	var ramp := Runner.LATERAL_SPEED * (1.0 / ACCEL + 1.0 / BRAKE)
	if distance < Runner.LATERAL_SPEED * ramp * 0.5:
		return sqrt(2.0 * distance * (1.0 / ACCEL + 1.0 / BRAKE)) + 0.05
	return distance / Runner.LATERAL_SPEED + ramp * 0.5 + 0.05


func _drive_towards(target: float) -> void:
	var error: float = target - game.runner.position.x
	var speed: float = game.runner.side_speed
	var frames := maxi(0, ceili(absf(speed) * 60.0 / BRAKE) - 1)
	var braking_distance := (absf(speed) * frames - BRAKE / 60.0 * frames * (frames + 1) * 0.5) / 60.0
	var brake := signf(speed) == signf(error) and braking_distance >= absf(error) - 0.012
	_steer(0 if absf(error) < 0.005 or brake else int(signf(error)))


func _steer(direction: int) -> void:
	if direction == steering:
		return
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if direction != 0:
		Input.action_press("steer_left" if direction < 0 else "steer_right")
	steering = direction


func _fail(message: String) -> bool:
	printerr(message)
	quit(1)
	return false
