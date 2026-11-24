extends Control

signal action(command: String, value: int)

const ArcadeButton = preload("res://scripts/ui/arcade_button.gd")
const DrivingPad = preload("res://scripts/ui/driving_pad.gd")
const MobileLayout = preload("res://scripts/ui/mobile_layout.gd")
const BODY = preload("res://assets/fonts/Roboto-Regular.ttf")
const BOLD = preload("res://assets/fonts/Roboto-Bold.ttf")
const DISPLAY = preload("res://assets/fonts/Roboto-BlackItalic.ttf")
const PAPER = Color("#f7f5ee")
const MINT = Color("#95f6dd")
const PEACH = Color("#ffc195")
const MUTED = Color("#c4c4d1")
const DESIGN := Vector2(1280, 720)
const DIFFICULTIES := ["Спокойно", "Аркада", "Турбо"]
const CUPS := ["Классика", "Новые трассы"]
const CUP_SIZE := 5

var _mode := ""
var _page := "home"
var _cup := 0
var _info := {}
var _stage: Control
var _shade: TextureRect
var _stage_buttons: Array[Button] = []
var _touch_buttons: Array[TouchScreenButton] = []
var _distance := 0.0
var _total := 0.0
var _hud_distance: Label
var _hud_percent: Label
var _hud_bar: ProgressBar
var _countdown: Label
var _driving_hint: Control
var _loading: Label
var _compact := false
var _portrait := false
var _mobile_bounds := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade = TextureRect.new()
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = DESIGN
	add_child(_stage)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	_portrait = size.y >= size.x
	var physical := get_window().size
	_compact = _portrait or _touch_driving() or (physical.x > 100 and physical.y <= 560)
	var grid := DESIGN
	if _compact:
		grid = Vector2(390, 620) if _portrait else Vector2(720, 360)
	var factor := minf(size.x / grid.x, size.y / grid.y)
	_stage.scale = Vector2.ONE * factor
	_stage.size = size / factor if _compact else DESIGN
	_stage.position = (size - _stage.size * factor) * 0.5
	_mobile_bounds = Rect2(Vector2.ZERO, _stage.size)
	if DisplayServer.get_name() in ["Android", "iOS"] and physical.x > 0 and physical.y > 0:
		var safe := DisplayServer.get_display_safe_area()
		var window_rect := Rect2i(get_window().position, physical)
		var intersect := window_rect.intersection(safe)
		if intersect.has_area():
			var to_stage := _stage.size / Vector2(physical)
			_mobile_bounds = Rect2(Vector2(intersect.position - window_rect.position) * to_stage, Vector2(intersect.size) * to_stage)
	if not _mode.is_empty():
		_render()


func show_screen(mode: String, info: Dictionary) -> void:
	var prev := _mode
	_mode = mode
	_info = info.duplicate()
	if mode == "menu" and prev != "menu":
		_page = "home"
		_cup = 1 if int(info.get("index", 0)) >= CUP_SIZE else 0
	_render()


func is_home() -> bool:
	return _mode == "menu" and _page == "home"


func back() -> void:
	if _mode in ["credits", "music_loading", "music_complete"]:
		_emit_command("menu")
	elif _mode == "menu" and _page != "home":
		_open("settings" if _page == "reset" else "home")


func show_music_picker(error: String = "") -> void:
	_page = "music"
	_mode = "menu"
	_info.error = error
	_render()


func _render() -> void:
	var old_focus := ""
	var owner := get_viewport().gui_get_focus_owner()
	if is_instance_valid(owner) and owner.has_meta("ui_key"):
		old_focus = str(owner.get_meta("ui_key"))
	_stage_buttons.clear()
	var driving := _mode in ["running", "countdown"]
	var pad_count := 2 if _info.get("music", false) else 3
	if not driving or not _touch_driving() or _touch_buttons.size() != pad_count:
		_touch_buttons.clear()
	for child in _stage.get_children():
		if child is TouchScreenButton and child in _touch_buttons:
			continue
		_stage.remove_child(child)
		child.queue_free()
	_hud_distance = null
	_hud_percent = null
	_hud_bar = null
	_countdown = null
	_driving_hint = null
	_loading = null
	_set_shade(driving)
	match _mode:
		"menu":
			match _page:
				"tracks": _tracks()
				"settings": _settings()
				"reset": _reset_prompt()
				"authors": _authors(false)
				"music": _music_picker()
				_: _home()
		"running", "countdown":
			_hud()
		"paused":
			_paused()
		"crashed":
			_crashed()
		"complete":
			_complete()
		"credits":
			_authors(true)
		"music_loading":
			_music_loading()
		"music_complete":
			_music_complete()
	if _compact:
		MobileLayout.arrange(self, _mobile_bounds, _portrait)
	_wire_focus(old_focus, not driving)


func _set_shade(driving: bool) -> void:
	var gradient := Gradient.new()
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 128
	if driving:
		gradient.offsets = PackedFloat32Array([0.0, 0.17, 0.65, 1.0])
		gradient.colors = PackedColorArray([Color(0.045, 0.047, 0.09, 0.81), Color(0.045, 0.047, 0.09, 0.0), Color(0.045, 0.047, 0.09, 0.0), Color(0.045, 0.047, 0.09, 0.60)])
		texture.fill_to = Vector2(0, 1)
	elif _compact and _portrait:
		gradient.offsets = PackedFloat32Array([0.0, 0.27, 0.54, 1.0])
		var home := _mode == "menu" and _page == "home"
		gradient.colors = PackedColorArray([Color(0.06,0.05,0.10,0.28 if home else 0.88), Color(0.06,0.05,0.10,0.22 if home else 0.85), Color(0.05,0.05,0.09,0.94), Color(0.045,0.045,0.08,0.98)])
		texture.fill_to = Vector2(0, 1)
	else:
		gradient.offsets = PackedFloat32Array([0.0, 0.31, 0.60, 1.0])
		gradient.colors = PackedColorArray([Color(0.033, 0.039, 0.078, 0.97), Color(0.039, 0.043, 0.084, 0.90), Color(0.053, 0.055, 0.103, 0.33), Color(0.071, 0.056, 0.102, 0.04)])
		texture.fill_to = Vector2(1, 0)
	texture.gradient = gradient
	_shade.texture = texture


func _home() -> void:
	_label("THE", Rect2(66, 82, 218, 88), DISPLAY, 82, PAPER)
	_speedmark(Vector2(246, 121))
	_label("GAME", Rect2(60, 143, 470, 150), DISPLAY, 142, MINT)
	_label("Обходи блоки и держись на трассе.", Rect2(72, 307, 470, 35), BODY, 21, PAPER)
	var unlocked := int(_info.get("unlocked", 0))
	var started := unlocked > 0 or int(_info.get("new_unlocked", 5)) > 5 or _record(0) > 0 or _record(5) > 0
	var caption := "Продолжить заезд" if started else "Начать заезд"
	if _info.get("finished", false):
		caption = "Повторить заезд"
	_command(caption, "play", -1, 365, "play", "primary", 354)
	_nav("Музыкальная трасса", "music", 436, "music", 354)
	_button("Выбор трассы", Rect2(72, 495, 354, 49), "route", "row", _open.bind("tracks"), "tracks", "2 кубка")
	_nav("Настройки", "settings", 554, "settings", 354)
	_button("Авторы", Rect2(72, 644, 113, 34), "info", "link", _open.bind("authors"), "authors")
	_button("На сайт" if OS.has_feature("web") else "Выход", Rect2(212, 644, 110, 34), "exit", "link", _emit_command.bind("quit"), "quit")
	var index := int(_info.get("preview_index", _info.get("index", 0)))
	var box := Rect2(894, 610, 319, 68)
	_rect(box, Color(0.06, 0.065, 0.102, 0.78))
	_rect(Rect2(box.position + Vector2(0, 12), Vector2(3, 44)), MINT)
	_label(_sector_label(index), Rect2(915, 618, 292, 20), BOLD, 13, MINT)
	_label(_track_name(index), Rect2(914, 637, 289, 32), DISPLAY, 25, PAPER)


func _music_picker() -> void:
	_back_button()
	_kicker("МУЗЫКАЛЬНЫЙ РЕЖИМ")
	_title("Музыкальная трасса")
	_label("Выбери музыку. Её ритм задаст рисунок препятствий. На трассе управлять нужно только рулём.", Rect2(73, 219, 508, 72), BODY, 21, PAPER, true)
	_command("Выбрать аудиофайл", "music_file", -1, 311, "music", "primary", 463)
	_label("MP3, Ogg Vorbis или WAV · 6 с – 10 мин · до 64 МиБ", Rect2(73, 376, 510, 28), BODY, 16, MUTED)
	var names: Array = _info.get("demo_names", ["После заката", "Высокое напряжение"])
	for i in mini(names.size(), 2):
		_button(str(names[i]), Rect2(72, 428 + 64 * i, 463, 50), "play", "row", _emit_command.bind("music_demo", i), "demo%d" % i, "Демо")
	var error := str(_info.get("error", ""))
	if not error.is_empty():
		_label(error, Rect2(73, 565, 495, 90), BODY, 18, PEACH, true)


func _music_loading() -> void:
	_kicker("МУЗЫКАЛЬНАЯ ТРАССА")
	_title("Слушаем ритм")
	_label(str(_info.get("song_name", "")), Rect2(73, 218, 495, 45), BODY, 24, PAPER)
	_loading = _label("", Rect2(72, 279, 433, 64), DISPLAY, 46, MINT)
	update_loading(float(_info.get("progress", 0)))
	_command("Отмена", "menu", -1, 387, "back")


func update_loading(fraction: float) -> void:
	_info.progress = fraction
	if is_instance_valid(_loading):
		_loading.text = "%d%%" % roundi(clampf(fraction, 0, 1) * 100)


func _music_complete() -> void:
	_kicker(_sector_label())
	_title("Финиш!", MINT)
	_label(_track_name(), Rect2(73, 215, 602, 50), BODY, 25, PAPER)
	_label("Длительность  %s" % _race_time(float(_info.get("duration", _info.get("seconds", 0)))), Rect2(73, 287, 495, 42), BOLD, 24, MINT)
	_command("Сыграть ещё раз", "retry", -1, 378, "retry", "primary")
	_command("В главное меню", "menu", -1, 452, "back")


func _tracks() -> void:
	_back_button()
	_kicker("ДВА ЧЕМПИОНАТА  /  10 ТРАСС")
	_title("Выбор трассы")
	for i in CUPS.size():
		_button(CUPS[i], Rect2(72 + i * 258, 230, 250, 47), "", "selected_tab" if i == _cup else "tab", _select_cup.bind(i), "cup%d" % i)
	var start := _cup * CUP_SIZE
	var unlocked := int(_info.get("unlocked" if _cup == 0 else "new_unlocked", start))
	for i in range(start, start + CUP_SIZE):
		var locked := i > unlocked
		var status := "Закрыта" if locked else "Открыта"
		var progress := _record(i)
		if not locked and progress > 0:
			status = "%d%%" % progress
		var b := _button(_track_name(i), Rect2(72, 302 + 60 * (i - start), 508, 50), "", "track", _emit_command.bind("play", i), "track%d" % i, status, "%02d" % (i - start + 1))
		b.disabled = locked
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	_label("Открыто  %d / %d" % [clampi(unlocked - start + 1, 1, CUP_SIZE), CUP_SIZE], Rect2(73, 610, 470, 30), BODY, 17, MUTED)


func _select_cup(cup: int) -> void:
	if _cup != cup:
		_cup = cup
		_render()
		action.emit("ui_click", -1)


func _settings() -> void:
	_back_button()
	_kicker("ПАРАМЕТРЫ ЗАЕЗДА")
	_title("Настройки")
	var difficulty := clampi(int(_info.get("difficulty", 0)), 0, DIFFICULTIES.size() - 1)
	_label("Сложность задаёт скорость на трассе.", Rect2(73, 215, 525, 32), BODY, 20, MUTED)
	_button("Сложность", Rect2(72, 283, 465, 57), "settings", "row", _change_setting.bind("difficulty", (difficulty + 1) % DIFFICULTIES.size()), "difficulty", DIFFICULTIES[difficulty])
	var sound: bool = _info.get("sound", true)
	_button("Звук", Rect2(72, 353, 465, 57), "sound", "row", _change_setting.bind("sound", int(not sound)), "sound", "Вкл" if sound else "Выкл")
	_nav("Сбросить прогресс", "reset", 467, "retry", 465)


func _change_setting(key: String, value: int) -> void:
	_info[key] = bool(value) if key == "sound" else value
	_render()
	action.emit(key, value)


func _reset_prompt() -> void:
	_back_button()
	_kicker("СОХРАНЕНИЕ")
	_title("Сброс прогресса")
	_label("Рекорды удалятся. Оба чемпионата начнутся с первой трассы.", Rect2(73, 217, 492, 90), BODY, 22, PAPER, true)
	_button("Оставить прогресс", Rect2(72, 349, 396, 56), "back", "primary", _open.bind("settings"), "cancel")
	_button("Сбросить", Rect2(72, 420, 396, 52), "retry", "row", _confirm_reset, "reset")


func _confirm_reset() -> void:
	_page = "settings"
	_info.unlocked = 0
	_info.new_unlocked = 5
	_info.cups_done = [false, false]
	_info.finished = false
	_info.records = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	_render()
	_emit_command("reset")


func _paused() -> void:
	_kicker(_sector_label())
	_title("Пауза")
	_label(_track_name(), Rect2(73, 211, 479, 42), BODY, 27, PAPER)
	_command("Продолжить", "resume", -1, 302, "play", "primary")
	_command("Начать заново", "retry", -1, 374, "retry")
	_command("В главное меню", "menu", -1, 438, "back")
	_controls(72, 553, true)


func _crashed() -> void:
	_kicker(_sector_label(), PEACH)
	_title("Авария", PEACH)
	var reason := str(_info.get("reason", ""))
	if reason.is_empty():
		reason = "Попробуй пройти трассу ещё раз."
	if _info.get("music", false):
		reason = "%s  ·  %s" % [_track_name(), reason]
	_label(reason, Rect2(73, 210, 480, 62), BODY, 22, PAPER, true)
	_run_stats()
	_command("Ещё попытка", "retry", -1, 377, "retry", "primary")
	_command("В главное меню", "menu", -1, 448, "back")


func _complete() -> void:
	var index := int(_info.get("index", 0))
	var last := index % CUP_SIZE == CUP_SIZE - 1
	_kicker(_sector_label())
	_title("Финиш!", MINT)
	var line := "Чемпионат «%s» пройден." % _cup_name(index) if last else "Открыта трасса «%s»." % _track_name(index + 1)
	_label(line, Rect2(73, 213, 505, 42), BODY, 22, PAPER)
	_finish_times()
	_command("К титрам" if last else "Следующая трасса", "next", -1, 377, "play", "primary")
	_command("Пройти ещё раз", "retry", -1, 448, "retry")
	_command("В главное меню", "menu", -1, 510, "back")


func _run_stats() -> void:
	var percent := clampi(floori(100.0 * _distance / maxf(_total, 1.0)), 0, 99)
	_label("ДИСТАНЦИЯ", Rect2(73, 291, 151, 22), BOLD, 13, MUTED)
	_label("%d м" % roundi(_distance), Rect2(72, 312, 180, 36), DISPLAY, 32, PAPER)
	_rect(Rect2(247, 293, 1, 48), Color("#6c697b"))
	_label("ТРАССА", Rect2(274, 291, 150, 22), BOLD, 13, MUTED)
	_label("%d%%" % percent, Rect2(273, 312, 140, 36), DISPLAY, 32, PAPER)


func _finish_times() -> void:
	var seconds := float(_info.get("seconds", 0.0))
	var best := float(_info.get("best_time", 0.0))
	_label("ВРЕМЯ ЗАЕЗДА", Rect2(73, 291, 180, 22), BOLD, 13, MUTED)
	_label(_race_time(seconds), Rect2(72, 312, 190, 39), DISPLAY, 32, PAPER)
	_rect(Rect2(247, 293, 1, 48), Color("#6c697b"))
	_label("РЕКОРД РЕЖИМА", Rect2(274, 291, 200, 22), BOLD, 13, MUTED)
	_label(_race_time(best) if best > 0.0 else "—", Rect2(273, 312, 200, 39), DISPLAY, 32, MINT)


func _race_time(value: float) -> String:
	var tenths := roundi(maxf(value, 0.0) * 10.0)
	return "%02d:%02d,%d" % [floori(tenths / 600.0), floori(tenths / 10.0) % 60, tenths % 10]


func _authors(ending: bool) -> void:
	if not ending:
		_back_button()
	var index := int(_info.get("index", 0))
	_kicker("ВСЕ ТРАССЫ ПРОЙДЕНЫ" if ending and _info.get("finished", false) else ("КУБОК • %s" % _cup_name(index).to_upper() if ending else "THEGAME"))
	_title("Спасибо за игру!" if ending else "Авторы", MINT if ending else PAPER)
	_label("АВТОР ОРИГИНАЛА", Rect2(73, 261, 432, 28), BOLD, 14, MUTED)
	_label("hacker-niki", Rect2(72, 292, 440, 58), DISPLAY, 45, PAPER)
	if ending:
		var other := 0 if index >= CUP_SIZE else CUP_SIZE
		_command("Кубок «%s»" % _cup_name(other), "play", other, 416, "play", "primary")
		_command("В главное меню", "menu", -1, 487, "back")


func _hud() -> void:
	_label(_sector_label(), Rect2(38, 22, 318, 20), BOLD, 13, MINT)
	_label(_track_name(), Rect2(36, 42, 316, 45), DISPLAY, 30, PAPER)
	_hud_distance = _label("0 м", Rect2(412, 23, 246, 34), BOLD, 22, PAPER)
	_hud_percent = _label("0%", Rect2(735, 26, 133, 31), BOLD, 16, PAPER)
	_hud_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_bar = ProgressBar.new()
	_hud_bar.show_percentage = false
	_hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_bar.add_theme_stylebox_override("background", _bar_style(Color(0.23, 0.23, 0.29, 0.8)))
	_hud_bar.add_theme_stylebox_override("fill", _bar_style(MINT))
	_place(_hud_bar, Rect2(413, 65, 454, 5))
	var p := _button("", Rect2(1180, 28, 62, 46), "pause", "icon", _emit_command.bind("pause"), "pause")
	p.tooltip_text = "Пауза (Esc)"
	p.focus_mode = Control.FOCUS_NONE
	_driving_hint = _controls(38, 619)
	if _touch_driving():
		_add_touch_pads()
	if _mode == "countdown":
		_countdown = _label("", Rect2(490, 216, 300, 170), DISPLAY, 122, PAPER)
		_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_countdown.add_theme_constant_override("outline_size", 7)
		_countdown.add_theme_color_override("font_outline_color", Color(0.07, 0.07, 0.12, 0.8))


func update_run(distance: float, total: float, countdown: int) -> void:
	_distance = distance
	_total = total
	if not is_instance_valid(_hud_bar):
		return
	var percent := clampf(100.0 * distance / maxf(1.0, total), 0.0, 100.0)
	_hud_bar.value = percent
	_hud_distance.text = "%d / %d м" % [floori(distance), roundi(total)]
	_hud_percent.text = "%d%%" % floori(percent)
	if is_instance_valid(_countdown):
		_countdown.text = str(countdown) if countdown > 0 else ""
	_driving_hint.visible = distance < 90.0 and not _touch_driving()


func _touch_driving() -> bool:
	return OS.has_feature("mobile") or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())


func _add_touch_pads() -> void:
	var bindings := ["steer_left", "steer_right", "brake_run"]
	var labels := ["", "", "Тормоз"]
	var count := 2 if _info.get("music", false) else 3
	for i in range(_touch_buttons.size(), count):
		var pad := DrivingPad.new()
		pad.configure(bindings[i], labels[i], Vector2(76, 64) if _compact else Vector2(150, 142))
		_stage.add_child(pad)
		_touch_buttons.append(pad)
	_layout_touch_pads()
	_driving_hint.hide()


func _layout_touch_pads() -> void:
	if _touch_buttons.is_empty() or _stage.scale.x <= 0.0:
		return
	var left := _mobile_bounds.position.x + 54.0 if _compact else 100.0
	var right := _mobile_bounds.end.x - 54.0 if _compact else 1180.0
	var gap := 82.0 if _compact else 164.0
	var pad_y := _mobile_bounds.end.y - 49.0 if _compact else 601.0
	var centers := [left, right if _touch_buttons.size() == 2 else left + gap, right]
	for i in _touch_buttons.size():
		_touch_buttons[i].position = Vector2(centers[i], pad_y)


func _controls(x: float, y: float, expanded: bool = false) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(holder, Rect2(x, y, 470, 95))
	var gamepad := not Input.get_connected_joypads().is_empty()
	var keys := ["A / D  ·  ← / →", "Пробел / S"]
	if expanded and _touch_driving():
		keys = ["Стрелки слева", "Кнопка справа"]
	elif gamepad and not expanded:
		keys = ["Левый стик", "LT"]
	elif expanded:
		keys = ["A / D  ·  ← / →  ·  Левый стик", "Пробел / S  ·  LT"]
	var captions := ["Руление", "Тормоз"]
	for i in (1 if _info.get("music", false) else keys.size()):
		var caption := _label(captions[i], Rect2(0, 30 * i, 85, 26), BODY, 16, MUTED)
		_hint_shadow(caption)
		caption.reparent(holder, false)
		var key := _label(keys[i], Rect2(85, 30 * i, 270, 26), BOLD, 16, PAPER)
		_hint_shadow(key)
		key.reparent(holder, false)
	return holder


func _hint_shadow(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.055, 0.055, 0.09, 0.85))


func _bar_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box


func _cup_name(index: int) -> String:
	return CUPS[1 if index >= CUP_SIZE else 0]


func _sector_label(index: int = -1) -> String:
	if index < 0 and _info.get("music", false):
		var tempo := roundi(float(_info.get("tempo", 0)))
		return "МУЗЫКАЛЬНАЯ ТРАССА" + ("  /  %d BPM" % tempo if tempo > 0 else "")
	if index < 0:
		index = int(_info.get("index", 0))
	return "%s  /  %02d ИЗ %02d" % [_cup_name(index).to_upper(), index % CUP_SIZE + 1, CUP_SIZE]


func _track_name(index: int = -1) -> String:
	if index < 0:
		if _info.get("music", false):
			return str(_info.get("song_name", "Музыка"))
		index = int(_info.get("index", 0))
	var names: Array = _info.get("names", [])
	return str(names[index]) if index < names.size() else "Трасса %d" % (index % CUP_SIZE + 1)


func _record(index: int) -> int:
	var records: Array = _info.get("records", [])
	return clampi(roundi(float(records[index])), 0, 100) if index < records.size() else 0


func _kicker(value: String, color: Color = MINT) -> void:
	_rect(Rect2(73, 120, 26, 2), color)
	_label(value, Rect2(111, 108, 500, 26), BOLD, 14, color).set_meta("role", "kicker")


func _title(value: String, color: Color = PAPER) -> void:
	_label(value, Rect2(68, 137, 658, 73), DISPLAY, 59, color).set_meta("role", "title")


func _speedmark(origin: Vector2) -> void:
	for i in range(3):
		var marking := Polygon2D.new()
		var x := 17.0 * i
		marking.polygon = PackedVector2Array([Vector2(x + 12, 0), Vector2(x + 22, 0), Vector2(x + 9, 29), Vector2(x, 29)])
		marking.color = PEACH
		marking.position = origin
		_stage.add_child(marking)


func _back_button() -> void:
	_button("Назад", Rect2(73, 42, 110, 35), "back", "link", back, "back")


func _nav(caption: String, target: String, y: float, icon: String, width: float) -> void:
	_button(caption, Rect2(72, y, width, 49), icon, "row", _open.bind(target), target)


func _command(caption: String, command: String, value: int, y: float, icon: String, variant: String = "row", width: float = 385) -> void:
	_button(caption, Rect2(72, y, width, 57 if variant == "primary" else 49), icon, variant, _emit_command.bind(command, value), command)


func _open(target: String) -> void:
	if _page == "music" and target != "music":
		action.emit("cancel_picker", -1)
	_page = target
	if target == "music":
		_info.error = ""
	_render()
	action.emit("ui_click", -1)


func _emit_command(command: String, value: int = -1) -> void:
	action.emit(command, value)


func _button(caption: String, bounds: Rect2, icon: String, variant: String, callback: Callable, key: String, note: String = "", number: String = "") -> Button:
	var result := ArcadeButton.new()
	result.configure(caption, icon, variant, note, number)
	result.set_meta("ui_key", key)
	result.pressed.connect(callback)
	_place(result, bounds)
	_stage_buttons.append(result)
	return result


func _label(value: String, bounds: Rect2, font: Font, font_size: int, color: Color, wrap: bool = false) -> Label:
	var item := Label.new()
	item.text = value
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.clip_text = true
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(item, bounds)
	return item


func _rect(bounds: Rect2, color: Color) -> void:
	var item := ColorRect.new()
	item.color = color
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(item, bounds)


func _place(item: Control, bounds: Rect2) -> void:
	_stage.add_child(item)
	item.position = bounds.position
	item.size = bounds.size


func _wire_focus(previous: String, grab: bool) -> void:
	var active: Array[Button] = []
	for button in _stage_buttons:
		if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			active.append(button)
	if active.is_empty():
		return
	var initial := active[0]
	if active.size() > 1 and initial.get_meta("ui_key") == "back":
		initial = active[1]
	if _mode == "menu" and _page == "tracks":
		initial = _stage_buttons[3]
	for i in active.size():
		var b := active[i]
		var before := b.get_path_to(active[posmod(i - 1, active.size())])
		var after := b.get_path_to(active[(i + 1) % active.size()])
		b.focus_neighbor_top = before
		b.focus_neighbor_left = before
		b.focus_previous = before
		b.focus_neighbor_bottom = after
		b.focus_neighbor_right = after
		b.focus_next = after
		if str(b.get_meta("ui_key")) == previous:
			initial = b
	if _mode == "menu" and _page == "tracks":
		var first := _stage_buttons[3]
		var tab := _stage_buttons[_cup + 1]
		first.focus_neighbor_top = first.get_path_to(tab)
		for i in CUPS.size():
			var current := _stage_buttons[1 + i]
			current.focus_neighbor_top = current.get_path_to(_stage_buttons[0])
			current.focus_neighbor_bottom = current.get_path_to(first)
			var other := current.get_path_to(_stage_buttons[2 - i])
			current.focus_neighbor_left = other
			current.focus_neighbor_right = other
	if grab:
		initial.grab_focus()
