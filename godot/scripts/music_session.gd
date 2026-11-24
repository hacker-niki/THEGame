extends Node

signal analysing
signal prepared
signal failed(message: String)
signal progress_changed(value: float)

const Generator := preload("res://scripts/music_course.gd")
const DEMO_NAMES := ["После заката", "Высокое напряжение"]
const DEMOS := [preload("res://assets/audio/dusk.ogg"), preload("res://assets/audio/overdrive.ogg")]
const MAX_FILE_SIZE := 64 * 1024 * 1024

var song: AudioStream
var song_name := ""
var chart: Dictionary = {}
var _analysis
var _dialog: FileDialog
var _js_callback: JavaScriptObject
var _request := 0


func _ready() -> void:
	set_process(false)


func clear() -> void:
	_request += 1
	_analysis = null
	song = null
	chart.clear()
	song_name = ""
	set_process(false)
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func demo(which: int) -> void:
	if which >= 0 and which < DEMOS.size():
		begin(DEMOS[which].duplicate(), DEMO_NAMES[which])


func begin(source: AudioStream, title: String) -> void:
	clear()
	song = source
	# The campaign loops its soundtrack. A generated race ends with its song.
	if song is AudioStreamWAV:
		song.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif song is AudioStreamOggVorbis or song is AudioStreamMP3:
		song.loop = false
	song_name = title.strip_edges().left(80)
	_analysis = Generator.begin(song)
	analysing.emit()
	set_process(true)


func _process(_delta: float) -> void:
	if _analysis == null:
		return
	if not _analysis.advance(5):
		progress_changed.emit(_analysis.progress)
		return
	chart = _analysis.result
	_analysis = null
	set_process(false)
	if not str(chart.get("error", "")).is_empty():
		failed.emit(str(chart.error))
	else:
		prepared.emit()


func choose_file() -> void:
	clear()
	if OS.has_feature("web"):
		_pick_web()
		return
	_dialog = FileDialog.new()
	_dialog.use_native_dialog = true
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.title = "Выбери музыку"
	_dialog.filters = PackedStringArray(["*.mp3,*.ogg,*.wav;Музыка;audio/mpeg,audio/ogg,audio/wav,audio/x-wav"])
	_dialog.file_selected.connect(_read_file.bind(_request))
	_dialog.canceled.connect(_cancel_dialog.bind(_request))
	add_child(_dialog)
	_dialog.popup_centered_ratio(0.85)


func _cancel_dialog(request: int) -> void:
	if request == _request:
		clear()
		failed.emit("")


func _read_file(path: String, request: int) -> void:
	if request != _request:
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failed.emit("Не удалось открыть файл. Попробуй выбрать его ещё раз.")
		return
	if file.get_length() > MAX_FILE_SIZE:
		failed.emit("Выбери файл размером до 64 МиБ.")
		return
	var bytes := file.get_buffer(MAX_FILE_SIZE + 1 if file.get_length() <= 0 else file.get_length())
	var title := path.uri_decode().get_file().get_basename()
	if title.is_valid_int() or title.is_empty():
		title = "Моя композиция"
	_import(bytes, title)


func _import(bytes: PackedByteArray, title: String) -> void:
	if bytes.size() > MAX_FILE_SIZE:
		failed.emit("Выбери файл размером до 64 МиБ.")
		return
	if bytes.size() < 16:
		failed.emit("В файле нет звуковой дорожки.")
		return
	var signature := bytes.slice(0, 4).get_string_from_ascii()
	var source: AudioStream
	if signature == "OggS":
		source = AudioStreamOggVorbis.load_from_buffer(bytes)
	elif signature == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WAVE":
		source = AudioStreamWAV.load_from_buffer(bytes)
	elif bytes.slice(0, 3).get_string_from_ascii() == "ID3" or (bytes[0] == 255 and bytes[1] & 224 == 224):
		source = AudioStreamMP3.load_from_buffer(bytes)
	if source == null:
		failed.emit("Поддерживаются MP3, Ogg Vorbis и WAV с несжатым звуком.")
		return
	begin(source, title)


func _pick_web() -> void:
	_js_callback = JavaScriptBridge.create_callback(_web_file)
	var window := JavaScriptBridge.get_interface("window")
	window.thegameFileReady = _js_callback
	# The file stays in the browser. The callback carries its original request
	# number so a delayed file read cannot replace a more recent selection.
	window.thegameFileRequest = _request
	JavaScriptBridge.eval("""
		(() => {
			const request = window.thegameFileRequest;
			const done = window.thegameFileReady;
			const input = document.createElement('input');
			input.type = 'file';
			input.accept = '.mp3,.ogg,.wav,audio/mpeg,audio/ogg,audio/wav';
			input.style.display = 'none';
			document.body.append(input);
			input.oncancel = () => { input.remove(); done(request, '', null, ''); };
			input.onchange = async () => {
				const file = input.files[0];
				input.remove();
				if (!file) { done(request, '', null, ''); return; }
				if (file.size > 67108864) { done(request, '', null, 'Выбери файл размером до 64 МиБ.'); return; }
				try { done(request, file.name, await file.arrayBuffer(), ''); }
				catch (_) { done(request, '', null, 'Не удалось прочитать файл.'); }
			};
			input.click();
		})();
	""", true)


func _web_file(args: Array) -> void:
	if int(args[0]) != _request:
		return
	if args[2] == null:
		failed.emit(str(args[3]))
		return
	_import(JavaScriptBridge.js_buffer_to_packed_byte_array(args[2]), str(args[1]).get_basename())
