extends Node

const MUSIC := {
	"menu": preload("res://assets/audio/dusk.ogg"),
	"run": preload("res://assets/audio/overdrive.ogg"),
}
const CUES := {
	"select": preload("res://assets/audio/select.ogg"),
	"tick": preload("res://assets/audio/tick.ogg"),
	"start": preload("res://assets/audio/start.ogg"),
	"impact": preload("res://assets/audio/impact.ogg"),
	"finish": preload("res://assets/audio/finish.ogg"),
}
var music := AudioStreamPlayer.new()
var fx := AudioStreamPlayer.new()
var active_piece := ""
var enabled := true
var output_latency := 0.0


func _ready() -> void:
	add_child(music)
	add_child(fx)
	music.volume_db = -9.0
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	fx.volume_db = -6.0


func set_enabled(on: bool) -> void:
	enabled = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not enabled)
	if not enabled:
		fx.stop()


func score(piece: String, subdued := false) -> void:
	if active_piece != piece:
		active_piece = piece
		var stream: AudioStreamOggVorbis = MUSIC[piece]
		stream.loop = true
		music.stream = stream
		music.play()
	music.volume_db = -18.0 if subdued else -9.0
	music.stream_paused = false


func cue(which: String) -> void:
	if enabled:
		fx.stream = CUES[which]
		fx.play()

func prepare_song(stream: AudioStream) -> void:
	music.stop()
	active_piece = "custom"
	music.stream = stream
	music.volume_db = -3.0


func start_song() -> void:
	output_latency = AudioServer.get_output_latency()
	music.stream_paused = false
	music.play(0.0)


func song_seconds(duration: float) -> float:
	if not music.playing:
		return duration
	return clampf(music.get_playback_position() + AudioServer.get_time_since_last_mix() - output_latency, 0, duration)


func _exit_tree() -> void:
	music.stop()
	fx.stop()
