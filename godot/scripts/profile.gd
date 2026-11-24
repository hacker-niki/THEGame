extends RefCounted

const SAVE_PATH := "user://progress.cfg"
const CUP_SIZE := 5
const LEVELS := CUP_SIZE * 2
var unlocked := 0
var new_unlocked := CUP_SIZE
var last_cup := 0
var cups_done: Array[bool] = [false, false]
var finished: bool:
	get: return cups_done[0] and cups_done[1]
var difficulty := 0
var sound := true
var records: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var best_times := {}


func read_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	unlocked = clampi(_integer(cfg.get_value("campaign", "unlocked", 0)), 0, CUP_SIZE - 1)
	new_unlocked = clampi(_integer(cfg.get_value("campaign", "new_unlocked", CUP_SIZE)), CUP_SIZE, LEVELS - 1)
	last_cup = clampi(_integer(cfg.get_value("campaign", "last_cup", 0)), 0, 1)
	cups_done[0] = cfg.get_value("campaign", "classic_done", cfg.get_value("campaign", "finished", false)) == true and unlocked == CUP_SIZE - 1
	cups_done[1] = cfg.get_value("campaign", "new_done", false) == true and new_unlocked == LEVELS - 1
	difficulty = clampi(_integer(cfg.get_value("options", "difficulty", 0)), 0, 2)
	sound = cfg.get_value("options", "sound", true) != false
	for index in LEVELS:
		records[index] = clampi(_integer(cfg.get_value("records", str(index), 0)), 0, 100)
	for key in cfg.get_section_keys("times") if cfg.has_section("times") else []:
		var value: Variant = cfg.get_value("times", key)
		if (value is float or value is int) and is_finite(float(value)) and value > 0:
			best_times[key] = float(value)


func _integer(value: Variant) -> int:
	return int(value) if value is int or value is float else 0


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "unlocked", unlocked)
	cfg.set_value("campaign", "new_unlocked", new_unlocked)
	cfg.set_value("campaign", "last_cup", last_cup)
	cfg.set_value("campaign", "classic_done", cups_done[0])
	cfg.set_value("campaign", "new_done", cups_done[1])
	cfg.set_value("options", "difficulty", difficulty)
	cfg.set_value("options", "sound", sound)
	for index in LEVELS:
		cfg.set_value("records", str(index), records[index])
	for key in best_times:
		cfg.set_value("times", key, best_times[key])
	var tmp := SAVE_PATH + ".tmp"
	var error := cfg.save(tmp)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))
	if error != OK:
		push_warning("Не удалось записать прогресс: %s" % error_string(error))


func record_attempt(index: int, fraction: float) -> void:
	var percent := clampi(floori(fraction * 100.0), 0, 99)
	if percent > records[index]:
		records[index] = percent
		save()


func record_finish(index: int, seconds: float) -> void:
	records[index] = 100
	if index < CUP_SIZE:
		unlocked = maxi(unlocked, mini(CUP_SIZE - 1, index + 1))
		cups_done[0] = cups_done[0] or index == CUP_SIZE - 1
	else:
		new_unlocked = maxi(new_unlocked, mini(LEVELS - 1, index + 1))
		cups_done[1] = cups_done[1] or index == LEVELS - 1
	var key := "%d/%d" % [index, difficulty]
	best_times[key] = minf(seconds, best_times.get(key, INF))
	save()


func best_time(index: int) -> float:
	return best_times.get("%d/%d" % [index, difficulty], 0.0)


func reset_progress() -> void:
	unlocked = 0
	last_cup = 0
	new_unlocked = CUP_SIZE
	cups_done.fill(false)
	records.fill(0)
	best_times.clear()
	save()


func accessible(index: int) -> bool:
	return (index >= 0 and index <= unlocked) or (index >= CUP_SIZE and index <= new_unlocked)


func continuation() -> int:
	return new_unlocked if last_cup == 1 else unlocked
