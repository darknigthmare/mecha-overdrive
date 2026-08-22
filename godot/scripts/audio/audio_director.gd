class_name AudioDirector
extends Node

## Real-time procedural mix. The game ships without copyrighted music or audio
## files; engine, ambience, rhythm bed and feedback are synthesized locally.

const MIX_RATE := 22050.0
const MAX_EVENTS := 16

var speed_ratio := 0.0
var boost_amount := 0.0
var damage_ratio := 0.0
var chassis_tone := 1.0
var master_gain := 0.72
var music_gain := 0.46
var sfx_gain := 0.8
var engine_gain := 0.72
var muted := false

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase_engine := 0.0
var _phase_motor := 0.0
var _phase_music := 0.0
var _sample_clock := 0.0
var _events: Array[Dictionary] = []
var _procedural_enabled := true
var _awaiting_web_activation := OS.has_feature("web")


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "ProceduralMix"
	# Godot Web defaults to sample playback, which cannot host a live generator.
	# Stream playback keeps the same procedural mix on desktop and in browsers.
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.28
	_player.stream = stream
	add_child(_player)
	_start_playback()
	set_process_input(_awaiting_web_activation)


func configure(settings: Dictionary) -> void:
	master_gain = clampf(float(settings.get("master_volume", settings.get("volume", 0.72))), 0.0, 1.0)
	music_gain = clampf(float(settings.get("music_volume", 0.46)), 0.0, 1.0)
	sfx_gain = clampf(float(settings.get("effects_volume", settings.get("sfx_volume", 0.8))), 0.0, 1.0)
	engine_gain = clampf(float(settings.get("engine_volume", settings.get("effects_volume", 0.72))), 0.0, 1.0)
	muted = bool(settings.get("muted", false))


func set_motion(next_speed_ratio: float, boosting: bool, next_damage_ratio: float, tone: float = 1.0) -> void:
	speed_ratio = clampf(next_speed_ratio, 0.0, 1.6)
	boost_amount = move_toward(boost_amount, 1.0 if boosting else 0.0, 0.08)
	damage_ratio = clampf(next_damage_ratio, 0.0, 1.0)
	chassis_tone = clampf(tone, 0.62, 1.55)


func play_event(event_name: String) -> void:
	var frequency := 440.0
	var duration := 0.14
	var gain := 0.22
	match event_name:
		"pickup": frequency = 880.0; duration = 0.2; gain = 0.35
		"boost": frequency = 135.0; duration = 0.38; gain = 0.5
		"impact": frequency = 72.0; duration = 0.22; gain = 0.7
		"shield": frequency = 520.0; duration = 0.5; gain = 0.32
		"emp": frequency = 94.0; duration = 0.46; gain = 0.55
		"finish": frequency = 660.0; duration = 0.95; gain = 0.42
		"count": frequency = 330.0; duration = 0.16; gain = 0.25
		"go": frequency = 760.0; duration = 0.4; gain = 0.42
	if _events.size() >= MAX_EVENTS:
		_events.remove_at(0)
	_events.append({"frequency": frequency, "remaining": duration, "duration": duration, "gain": gain, "phase": 0.0})


func procedural_audio_enabled() -> bool:
	return _procedural_enabled


func uses_stream_playback() -> bool:
	return _player != null and _player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM


func awaiting_user_activation() -> bool:
	return _awaiting_web_activation


func _start_playback() -> void:
	if _player == null:
		return
	if _player.playing:
		_player.stop()
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_procedural_enabled = _playback != null
	set_process(_procedural_enabled)


func _input(event: InputEvent) -> void:
	if not _awaiting_web_activation or not _is_activation_event(event):
		return
	# Browser AudioContext activation must happen synchronously in the trusted
	# input callback. Restarting the stream here is safe and releases autoplay.
	_awaiting_web_activation = false
	set_process_input(false)
	_start_playback()


func _is_activation_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed
	if event is InputEventJoypadButton:
		var joypad_event := event as InputEventJoypadButton
		return joypad_event.pressed
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		return touch_event.pressed
	return false


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	for _index in range(frames):
		_playback.push_frame(_sample_frame())


func _sample_frame() -> Vector2:
	var engine_hz := (42.0 + speed_ratio * 118.0 + boost_amount * 38.0) * chassis_tone
	_phase_engine = fmod(_phase_engine + engine_hz / MIX_RATE, 1.0)
	_phase_motor = fmod(_phase_motor + engine_hz * 2.013 / MIX_RATE, 1.0)
	_phase_music = fmod(_phase_music + 55.0 / MIX_RATE, 1.0)
	_sample_clock += 1.0 / MIX_RATE

	var saw := _phase_engine * 2.0 - 1.0
	var motor := sin(_phase_motor * TAU) * 0.5 + saw * 0.32
	motor *= (0.055 + speed_ratio * 0.07 + boost_amount * 0.035) * engine_gain
	motor *= 1.0 - damage_ratio * 0.2

	var beat_phase := fmod(_sample_clock * 2.4, 1.0)
	var kick := sin(_phase_music * TAU) * exp(-beat_phase * 15.0) * 0.12
	var pulse := sin(_phase_music * TAU * 1.5) * (0.018 if beat_phase < 0.5 else 0.009)
	var music := (kick + pulse) * music_gain

	var event_mix := 0.0
	var event_index := _events.size() - 1
	while event_index >= 0:
		var event: Dictionary = _events[event_index]
		var duration := float(event.get("duration", 0.0))
		var remaining := float(event.get("remaining", 0.0))
		var envelope := clampf(remaining / maxf(0.001, duration), 0.0, 1.0)
		var phase := fmod(float(event.get("phase", 0.0)) + float(event.get("frequency", 440.0)) / MIX_RATE, 1.0)
		event_mix += sin(phase * TAU) * envelope * float(event.get("gain", 0.0)) * sfx_gain
		var next_remaining := remaining - 1.0 / MIX_RATE
		if next_remaining <= 0.0:
			_events.remove_at(event_index)
		else:
			event["phase"] = phase
			event["remaining"] = next_remaining
			_events[event_index] = event
		event_index -= 1

	var sample := clampf((motor + music + event_mix) * master_gain * (0.0 if muted else 1.0), -0.92, 0.92)
	return Vector2(sample, sample)
