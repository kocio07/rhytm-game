class_name BeatClock
extends Node

signal beat_passed(beat_index: int)
signal beat_missed(beat_index: int)

@export var music: AudioStream
@export var bpm: float = 120.0
@export var song_beats: int = 128
@export var on_beat_window: float = 0.10
@export var grace_beats: int = 4
@export var lead_in_seconds: float = 2.0

var song_time: float = -2.0
var started: bool = false
var pulse: float = 0.0
var check_beat: int = 1
var moved_beats: Dictionary = {}

var _audio: AudioStreamPlayer


func _ready() -> void:
	if music:
		_audio = AudioStreamPlayer.new()
		_audio.stream = music
		add_child(_audio)
	reset()


func reset() -> void:
	song_time = -lead_in_seconds
	started = false
	pulse = 0.0
	check_beat = 1
	moved_beats.clear()
	if _audio:
		_audio.stop()


func beat_length() -> float:
	return 60.0 / bpm


func update_clock(delta: float) -> void:
	if _audio and started:
		song_time = _audio.get_playback_position() \
			+ AudioServer.get_time_since_last_mix() \
			- AudioServer.get_output_latency()
	else:
		song_time += delta
		if _audio and not started and song_time >= 0.0:
			_audio.play()
			started = true

	var beat := beat_length()
	pulse = 1.0 - fmod(maxf(song_time, 0.0), beat) / beat

	while check_beat * beat + on_beat_window < song_time:
		if check_beat >= grace_beats and check_beat < song_beats and not moved_beats.has(check_beat):
			beat_missed.emit(check_beat)
		moved_beats.erase(check_beat)
		check_beat += 1


func try_register_on_beat() -> bool:
	if song_time < 0.0:
		return false
	var beat := beat_length()
	var bi := int(round(song_time / beat))
	var off := absf(song_time - bi * beat)
	if off <= on_beat_window:
		if moved_beats.has(bi):
			return false
		moved_beats[bi] = true
		beat_passed.emit(bi)
		return true
	return false
